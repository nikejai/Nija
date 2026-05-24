import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import '../../core/config/guardian_profiles.dart';
import '../../domain/models/vault.dart';
import '../../domain/models/vault_file.dart';
import '../../domain/models/vault_payload.dart';
import '../../domain/models/vault_registry_entry.dart';
import '../../domain/models/vault_transfer_result.dart';
import '../../infrastructure/adapters/crypto_adapter.dart';
import '../../infrastructure/adapters/private_vault_store.dart';
import '../../infrastructure/adapters/vault_storage_adapter.dart';
import 'vault_migrator.dart';
import 'vault_service.dart';

class DefaultVaultService implements VaultService {
  DefaultVaultService({
    required VaultStorageAdapter storageAdapter,
    required CryptoAdapter cryptoAdapter,
    PrivateVaultStore? privateVaultStore,
    VaultRegistryStore? registryStore,
    String? deviceId,
  }) : _storageAdapter = storageAdapter,
       _cryptoAdapter = cryptoAdapter,
       _privateVaultStore = privateVaultStore ?? InMemoryPrivateVaultStore(),
       _registryStore = registryStore ?? InMemoryVaultRegistryStore(),
       _deviceId = deviceId;

  static const _manifestFile = 'manifest.enc';
  static const _itemsFile = 'items.enc';
  static const _notesFile = 'notes.enc';
  static const _settingsFile = 'settings.enc';
  static const _tagsFile = 'tags.enc';
  static const _headerFile = 'header.json';

  final VaultStorageAdapter _storageAdapter;
  final CryptoAdapter _cryptoAdapter;
  final PrivateVaultStore _privateVaultStore;
  final VaultRegistryStore _registryStore;
  final String? _deviceId;
  final Random _random = Random.secure();
  final Map<String, String> _handleToVaultStoreId = <String, String>{};

  @override
  Future<String> readRawVaultFile({required String filePath}) async {
    final file = await _snapshotForHandle(filePath);
    return jsonEncode(file.toJson());
  }

  @override
  Future<void> writeRawVaultFile({
    required String filePath,
    required String rawContent,
  }) async {
    await _storageAdapter.write(filePath: filePath, content: rawContent);
  }

  @override
  Future<bool> vaultExists({required String filePath}) async {
    if (_handleToVaultStoreId.containsKey(filePath) &&
        await _privateVaultStore.vaultExists(
          _handleToVaultStoreId[filePath]!,
        )) {
      return true;
    }
    if (await _privateVaultStore.vaultExists(filePath)) {
      return true;
    }
    try {
      await _storageAdapter.read(filePath: filePath);
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<Vault> createVault({
    required String filePath,
    required String vaultId,
    required String vaultName,
    required String guardianProfileId,
    required String password,
    required String recoveryPhrase,
    VaultProgressCallback? onProgress,
  }) async {
    onProgress?.call(
      const VaultOperationProgress(
        value: 0.05,
        message: 'Preparing vault parameters...',
      ),
    );
    final guardian = _guardianById(guardianProfileId);
    final now = DateTime.now().toUtc().toIso8601String();
    final saltBytes = utf8.encode('salt-$now-${guardian.id}');
    final nonceBytes = utf8.encode('nonce-$now-${guardian.id}');
    final recoverySaltBytes = utf8.encode('recovery-salt-$now-${guardian.id}');

    onProgress?.call(
      const VaultOperationProgress(
        value: 0.15,
        message: 'Generating vault encryption key...',
      ),
    );
    final vaultKeyBytes = _randomBytes(32);

    onProgress?.call(
      const VaultOperationProgress(
        value: 0.25,
        message: 'Deriving master key (Argon2id)...',
      ),
    );
    final passwordKey = await _cryptoAdapter.deriveKey(
      password: password,
      salt: saltBytes,
      memoryKb: guardian.memoryKb,
      iterations: guardian.iterations,
      parallelism: guardian.parallelism,
    );
    onProgress?.call(
      const VaultOperationProgress(
        value: 0.40,
        message: 'Deriving recovery key (Argon2id)...',
      ),
    );
    final recoveryKey = await _cryptoAdapter.deriveKey(
      password: recoveryPhrase,
      salt: recoverySaltBytes,
      memoryKb: guardian.memoryKb,
      iterations: guardian.iterations,
      parallelism: guardian.parallelism,
    );

    onProgress?.call(
      const VaultOperationProgress(
        value: 0.55,
        message: 'Wrapping vault key with master key...',
      ),
    );
    final encryptedVaultKeyBytes = await _cryptoAdapter.encrypt(
      plain: vaultKeyBytes,
      key: passwordKey,
    );
    onProgress?.call(
      const VaultOperationProgress(
        value: 0.65,
        message: 'Wrapping vault key with recovery key...',
      ),
    );
    final encryptedVaultKeyByRecoveryBytes = await _cryptoAdapter.encrypt(
      plain: vaultKeyBytes,
      key: recoveryKey,
    );

    onProgress?.call(
      const VaultOperationProgress(
        value: 0.75,
        message: 'Encrypting vault sections...',
      ),
    );
    final header = VaultFile(
      format: 'Nija',
      formatVersion: VaultMigrator.currentVaultFormatVersion,
      schemaVersion: VaultMigrator.currentPayloadSchemaVersion,
      storageLayoutVersion: VaultMigrator.currentStorageLayoutVersion,
      manifestVersion: VaultMigrator.currentManifestVersion,
      vaultId: vaultId,
      vaultName: null,
      createdAt: now,
      updatedAt: now,
      vaultVersionId: _newUuidV4(),
      revision: 1,
      lastModifiedByDeviceId: _deviceId,
      guardian: GuardianMetadata(
        id: guardian.displayName.toLowerCase(),
        profile: guardian.id,
      ),
      kdf: KdfMetadata(
        name: 'argon2id',
        version: 19,
        memoryKb: guardian.memoryKb,
        iterations: guardian.iterations,
        parallelism: guardian.parallelism,
        salt: base64Encode(saltBytes),
      ),
      recoveryKdf: KdfMetadata(
        name: 'argon2id',
        version: 19,
        memoryKb: guardian.memoryKb,
        iterations: guardian.iterations,
        parallelism: guardian.parallelism,
        salt: base64Encode(recoverySaltBytes),
      ),
      cipher: CipherMetadata(
        name: guardian.cipher,
        nonce: base64Encode(nonceBytes),
      ),
      encryptedVaultKey: base64Encode(encryptedVaultKeyBytes),
      encryptedVaultKeyByRecovery: base64Encode(
        encryptedVaultKeyByRecoveryBytes,
      ),
    );

    final payload = VaultPayload.empty();
    await _commitPayload(
      vaultStoreId: vaultId,
      header: header,
      payload: payload,
      vaultKey: vaultKeyBytes,
    );
    await _rememberRegistry(header, label: vaultName.trim());
    _handleToVaultStoreId[filePath] = vaultId;

    onProgress?.call(
      const VaultOperationProgress(
        value: 0.90,
        message: 'Writing encrypted vault snapshot...',
      ),
    );
    await _storageAdapter.write(
      filePath: filePath,
      content: await readRawVaultFile(filePath: vaultId),
    );

    onProgress?.call(
      const VaultOperationProgress(
        value: 1.0,
        message: 'Vault created successfully.',
      ),
    );
    return Vault(
      id: header.vaultId,
      formatVersion: header.formatVersion,
      guardianProfileId: header.guardian.profile,
      items: const <String>[],
      notes: const <String>[],
    );
  }

  @override
  Future<Vault> unlockVault({
    required String filePath,
    required String password,
    VaultProgressCallback? onProgress,
  }) async {
    final file = await _readMigratedVaultFile(filePath: filePath);
    return _unlockWithDerivedKey(
      filePath: filePath,
      file: file,
      secret: password,
      kdf: file.kdf,
      encryptedVaultKeyBase64: file.encryptedVaultKey,
      onProgress: onProgress,
      deriveMessage: 'Deriving master key (Argon2id)...',
    );
  }

  @override
  Future<Vault> unlockVaultWithRecoveryPhrase({
    required String filePath,
    required String recoveryPhrase,
    VaultProgressCallback? onProgress,
  }) async {
    final file = await _readMigratedVaultFile(filePath: filePath);
    return _unlockWithDerivedKey(
      filePath: filePath,
      file: file,
      secret: recoveryPhrase,
      kdf: file.recoveryKdf,
      encryptedVaultKeyBase64: file.encryptedVaultKeyByRecovery,
      onProgress: onProgress,
      deriveMessage: 'Deriving recovery key (Argon2id)...',
    );
  }

  @override
  Future<void> resetMasterPasswordAfterRecovery({
    required String filePath,
    required String recoveryPhrase,
    required String newPassword,
    VaultProgressCallback? onProgress,
  }) async {
    final file = await _readMigratedVaultFile(filePath: filePath);
    final recoveryKey = await _deriveKey(recoveryPhrase, file.recoveryKdf);
    final vaultKey = await _cryptoAdapter.decrypt(
      cipher: base64Decode(file.encryptedVaultKeyByRecovery),
      key: recoveryKey,
    );
    final now = DateTime.now().toUtc().toIso8601String();
    final newSaltBytes = utf8.encode('salt-$now-${file.guardian.profile}');
    final newPasswordKey = await _cryptoAdapter.deriveKey(
      password: newPassword,
      salt: newSaltBytes,
      memoryKb: file.kdf.memoryKb,
      iterations: file.kdf.iterations,
      parallelism: file.kdf.parallelism,
    );
    final newEncryptedVaultKey = await _cryptoAdapter.encrypt(
      plain: vaultKey,
      key: newPasswordKey,
    );
    await _commitHeaderMutation(
      filePath: filePath,
      file: file,
      vaultKey: vaultKey,
      update: (next) => next.copyWith(
        kdf: KdfMetadata(
          name: file.kdf.name,
          version: file.kdf.version,
          memoryKb: file.kdf.memoryKb,
          iterations: file.kdf.iterations,
          parallelism: file.kdf.parallelism,
          salt: base64Encode(newSaltBytes),
        ),
        encryptedVaultKey: base64Encode(newEncryptedVaultKey),
      ),
    );
    onProgress?.call(
      const VaultOperationProgress(
        value: 1.0,
        message: 'Master password updated.',
      ),
    );
  }

  @override
  Future<void> rotateMasterPassword({
    required String filePath,
    required String currentPassword,
    required String newPassword,
    VaultProgressCallback? onProgress,
  }) async {
    final file = await _readMigratedVaultFile(filePath: filePath);
    final currentMasterKey = await _deriveKey(currentPassword, file.kdf);
    final vaultKey = await _cryptoAdapter.decrypt(
      cipher: base64Decode(file.encryptedVaultKey),
      key: currentMasterKey,
    );
    final now = DateTime.now().toUtc().toIso8601String();
    final newSaltBytes = utf8.encode('salt-$now-${file.guardian.profile}');
    final newMasterKey = await _cryptoAdapter.deriveKey(
      password: newPassword,
      salt: newSaltBytes,
      memoryKb: file.kdf.memoryKb,
      iterations: file.kdf.iterations,
      parallelism: file.kdf.parallelism,
    );
    final newEncryptedVaultKey = await _cryptoAdapter.encrypt(
      plain: vaultKey,
      key: newMasterKey,
    );
    await _commitHeaderMutation(
      filePath: filePath,
      file: file,
      vaultKey: vaultKey,
      update: (next) => next.copyWith(
        kdf: KdfMetadata(
          name: file.kdf.name,
          version: file.kdf.version,
          memoryKb: file.kdf.memoryKb,
          iterations: file.kdf.iterations,
          parallelism: file.kdf.parallelism,
          salt: base64Encode(newSaltBytes),
        ),
        encryptedVaultKey: base64Encode(newEncryptedVaultKey),
      ),
    );
    onProgress?.call(
      const VaultOperationProgress(
        value: 1.0,
        message: 'Master password rotated.',
      ),
    );
  }

  @override
  Future<void> rotateRecoveryPhrase({
    required String filePath,
    required String currentRecoveryPhrase,
    required String newRecoveryPhrase,
    VaultProgressCallback? onProgress,
  }) async {
    final file = await _readMigratedVaultFile(filePath: filePath);
    final currentRecoveryKey = await _deriveKey(
      currentRecoveryPhrase,
      file.recoveryKdf,
    );
    final vaultKey = await _cryptoAdapter.decrypt(
      cipher: base64Decode(file.encryptedVaultKeyByRecovery),
      key: currentRecoveryKey,
    );
    final now = DateTime.now().toUtc().toIso8601String();
    final newRecoverySaltBytes = utf8.encode(
      'recovery-salt-$now-${file.guardian.profile}',
    );
    final newRecoveryKey = await _cryptoAdapter.deriveKey(
      password: newRecoveryPhrase,
      salt: newRecoverySaltBytes,
      memoryKb: file.recoveryKdf.memoryKb,
      iterations: file.recoveryKdf.iterations,
      parallelism: file.recoveryKdf.parallelism,
    );
    final newEncryptedByRecovery = await _cryptoAdapter.encrypt(
      plain: vaultKey,
      key: newRecoveryKey,
    );
    await _commitHeaderMutation(
      filePath: filePath,
      file: file,
      vaultKey: vaultKey,
      update: (next) => next.copyWith(
        recoveryKdf: KdfMetadata(
          name: file.recoveryKdf.name,
          version: file.recoveryKdf.version,
          memoryKb: file.recoveryKdf.memoryKb,
          iterations: file.recoveryKdf.iterations,
          parallelism: file.recoveryKdf.parallelism,
          salt: base64Encode(newRecoverySaltBytes),
        ),
        encryptedVaultKeyByRecovery: base64Encode(newEncryptedByRecovery),
      ),
    );
    onProgress?.call(
      const VaultOperationProgress(
        value: 1.0,
        message: 'Recovery phrase rotated.',
      ),
    );
  }

  @override
  Future<VaultPayload> readVaultPayload({
    required String filePath,
    required String password,
    VaultProgressCallback? onProgress,
  }) async {
    final file = await _readMigratedVaultFile(filePath: filePath);
    final passwordKey = await _deriveKey(password, file.kdf);
    final vaultKey = await _cryptoAdapter.decrypt(
      cipher: base64Decode(file.encryptedVaultKey),
      key: passwordKey,
    );
    final payload = await _payloadFromWorkingOrSnapshot(
      filePath: filePath,
      file: file,
      vaultKey: vaultKey,
    );
    onProgress?.call(
      const VaultOperationProgress(
        value: 1.0,
        message: 'Vault payload loaded.',
      ),
    );
    return payload;
  }

  @override
  Future<void> persistVaultPayload({
    required String filePath,
    required String password,
    required VaultPayload payload,
    VaultProgressCallback? onProgress,
  }) async {
    final file = await _readMigratedVaultFile(filePath: filePath);
    final passwordKey = await _deriveKey(password, file.kdf);
    final vaultKey = await _cryptoAdapter.decrypt(
      cipher: base64Decode(file.encryptedVaultKey),
      key: passwordKey,
    );
    final nextHeader = _nextMutationHeader(file);
    await _commitPayload(
      vaultStoreId: _storeIdFor(filePath, file),
      header: nextHeader,
      payload: payload,
      vaultKey: vaultKey,
    );
    await _rememberRegistry(nextHeader, label: _displayLabel(nextHeader));
    _handleToVaultStoreId[filePath] = nextHeader.vaultId;
    await _writeSnapshotToHandle(filePath, nextHeader.vaultId);
    onProgress?.call(
      const VaultOperationProgress(
        value: 1.0,
        message: 'Vault payload persisted.',
      ),
    );
  }

  @override
  Future<String> persistVaultDocument({
    required String filePath,
    required String password,
    required List<int> bytes,
    required String documentId,
    VaultProgressCallback? onProgress,
  }) async {
    final file = await _readMigratedVaultFile(filePath: filePath);
    final passwordKey = await _deriveKey(password, file.kdf);
    final vaultKey = await _cryptoAdapter.decrypt(
      cipher: base64Decode(file.encryptedVaultKey),
      key: passwordKey,
    );
    final storeId = _storeIdFor(filePath, file);
    final sections = await _readExistingWorkingSections(storeId);
    final sectionName = _documentSectionFile(documentId);
    sections[sectionName] = Uint8List.fromList(
      await _cryptoAdapter.encrypt(plain: bytes, key: vaultKey),
    );
    final nextHeader = _nextMutationHeader(file);
    await _privateVaultStore.commitVault(
      vaultStoreId: storeId,
      header: nextHeader,
      sections: sections,
    );
    await _rememberRegistry(nextHeader, label: _displayLabel(nextHeader));
    _handleToVaultStoreId[filePath] = nextHeader.vaultId;
    await _writeSnapshotToHandle(filePath, nextHeader.vaultId);
    onProgress?.call(
      const VaultOperationProgress(
        value: 1.0,
        message: 'Document encrypted and stored.',
      ),
    );
    return sectionName;
  }

  @override
  Future<List<int>> readVaultDocument({
    required String filePath,
    required String password,
    required String sectionName,
    VaultProgressCallback? onProgress,
  }) async {
    final file = await _readMigratedVaultFile(filePath: filePath);
    final passwordKey = await _deriveKey(password, file.kdf);
    final vaultKey = await _cryptoAdapter.decrypt(
      cipher: base64Decode(file.encryptedVaultKey),
      key: passwordKey,
    );
    final storeId = _storeIdFor(filePath, file);
    final cipher = await _privateVaultStore.readSection(storeId, sectionName);
    final plain = await _cryptoAdapter.decrypt(cipher: cipher, key: vaultKey);
    onProgress?.call(
      const VaultOperationProgress(value: 1.0, message: 'Document decrypted.'),
    );
    return plain;
  }

  @override
  Future<int> readVaultSizeBytes({required String filePath}) async {
    final storeId = _handleToVaultStoreId[filePath] ?? filePath;
    if (await _privateVaultStore.vaultExists(storeId)) {
      final structure = await _privateVaultStore.describeVault(storeId);
      final files = Map<String, dynamic>.from(
        structure['files'] as Map? ?? const <String, dynamic>{},
      );
      var total = 0;
      for (final value in files.values) {
        if (value is int) {
          total += value;
        } else {
          total += int.tryParse(value.toString()) ?? 0;
        }
      }
      return total;
    }
    final snapshot = await _snapshotForHandle(filePath);
    return utf8.encode(jsonEncode(snapshot.toJson())).length;
  }

  @override
  Future<void> renameVault({
    required String filePath,
    required String label,
  }) async {
    final file = await _readMigratedVaultFile(filePath: filePath);
    final storeId = _storeIdFor(filePath, file);
    final nextHeader = _nextMutationHeader(file).copyWith(clearVaultName: true);
    final sections = await _readExistingWorkingSections(storeId);
    await _privateVaultStore.commitVault(
      vaultStoreId: storeId,
      header: nextHeader,
      sections: sections,
    );
    await _rememberRegistry(nextHeader, label: label);
    _handleToVaultStoreId[filePath] = storeId;
    await _writeSnapshotToHandle(filePath, storeId);
  }

  @override
  Future<void> markVaultConflictResolved({
    required String filePath,
    required String resolvedVaultVersionId,
  }) async {
    final cleaned = resolvedVaultVersionId.trim();
    if (cleaned.isEmpty) return;
    final file = await _readMigratedVaultFile(filePath: filePath);
    final storeId = _storeIdFor(filePath, file);
    final nextResolved = <String>{
      ...file.resolvedFromVersionIds,
      cleaned,
    }.toList()..sort();
    final nextHeader = _nextMutationHeader(
      file,
    ).copyWith(resolvedFromVersionIds: nextResolved);
    final sections = await _readExistingWorkingSections(storeId);
    await _privateVaultStore.commitVault(
      vaultStoreId: storeId,
      header: nextHeader,
      sections: sections,
    );
    await _rememberRegistry(nextHeader, label: _displayLabel(nextHeader));
    _handleToVaultStoreId[filePath] = storeId;
    await _writeSnapshotToHandle(filePath, storeId);
  }

  @override
  Future<ImportResult> importNijaFile({
    required String filePath,
    required String unlockCredential,
    bool confirmReplace = false,
  }) async {
    try {
      final incomingRaw = await _readSnapshotFile(filePath);
      final incoming = incomingRaw.copyWith(clearVaultName: true);
      if (incoming.format != 'Nija') {
        throw StateError('Unsupported vault file format.');
      }
      final existing = await _registryStore.findActiveByVaultId(
        incoming.vaultId,
      );
      final vaultKey = await _unwrapVaultKey(incoming, unlockCredential);
      final payload = await _payloadFromSnapshot(incoming, vaultKey);
      final sections = await _sectionsForPayload(
        header: incoming,
        payload: payload,
        vaultKey: vaultKey,
      );
      _addSnapshotExtraSections(incoming, sections);

      if (existing == null) {
        await _privateVaultStore.commitVault(
          vaultStoreId: incoming.vaultId,
          header: incoming,
          sections: sections,
        );
        await _rememberRegistry(incoming, label: _displayLabel(incoming));
        _handleToVaultStoreId[filePath] = incoming.vaultId;
        return ImportResult(
          status: ImportStatus.imported,
          vaultId: incoming.vaultId,
          incomingRevision: incoming.revision,
          incomingUpdatedAt: incoming.updatedAt,
          userSafeMessage: 'Vault imported.',
        );
      }

      final local = await _privateVaultStore.readHeader(existing.id);
      if (incoming.vaultVersionId == local.vaultVersionId) {
        return ImportResult(
          status: ImportStatus.alreadyUpToDate,
          vaultId: incoming.vaultId,
          localRevision: local.revision,
          incomingRevision: incoming.revision,
          localUpdatedAt: local.updatedAt,
          incomingUpdatedAt: incoming.updatedAt,
          userSafeMessage: 'Vault already up to date.',
        );
      }
      if (local.resolvedFromVersionIds.contains(incoming.vaultVersionId)) {
        return ImportResult(
          status: ImportStatus.alreadyUpToDate,
          vaultId: incoming.vaultId,
          localRevision: local.revision,
          incomingRevision: incoming.revision,
          localUpdatedAt: local.updatedAt,
          incomingUpdatedAt: incoming.updatedAt,
          userSafeMessage: 'This vault version was already merged.',
        );
      }
      if (_hasRevision(incoming) && _hasRevision(local)) {
        if (incoming.revision > local.revision) {
          if (!confirmReplace) {
            return ImportResult(
              status: ImportStatus.failed,
              vaultId: incoming.vaultId,
              localRevision: local.revision,
              incomingRevision: incoming.revision,
              localUpdatedAt: local.updatedAt,
              incomingUpdatedAt: incoming.updatedAt,
              userSafeMessage: 'Imported vault is newer. Confirm replace.',
            );
          }
          return _replaceImportedVault(
            filePath: filePath,
            existing: existing,
            incoming: incoming,
            sections: sections,
            statusMessage: 'Vault updated from imported file.',
          );
        }
        if (incoming.revision < local.revision) {
          return _createConflictCopy(
            incoming: incoming,
            sections: sections,
            local: local,
            message:
                'Imported vault is older. Review it before merging anything.',
          );
        }
        return _createConflictCopy(
          incoming: incoming,
          sections: sections,
          local: local,
        );
      }

      final fallback = _compareUpdatedAt(incoming.updatedAt, local.updatedAt);
      if (fallback > 0 && confirmReplace) {
        return _replaceImportedVault(
          filePath: filePath,
          existing: existing,
          incoming: incoming,
          sections: sections,
          statusMessage: 'Vault updated from imported legacy file.',
        );
      }
      if (fallback < 0) {
        return _createConflictCopy(
          incoming: incoming,
          sections: sections,
          local: local,
          message:
              'Imported legacy vault is older. Review it before merging anything.',
        );
      }
      return _createConflictCopy(
        incoming: incoming,
        sections: sections,
        local: local,
      );
    } catch (error) {
      return ImportResult(
        status: ImportStatus.failed,
        vaultId: '',
        userSafeMessage: 'Failed to import vault. $error',
      );
    }
  }

  @override
  Future<ExportResult> exportVault({
    required String vaultId,
    required String destinationPath,
  }) async {
    try {
      final snapshot = await _snapshotForHandle(vaultId);
      await _storageAdapter.write(
        filePath: destinationPath,
        content: jsonEncode(snapshot.toJson()),
      );
      return ExportResult(
        status: ExportStatus.exported,
        vaultId: snapshot.vaultId,
        vaultVersionId: snapshot.vaultVersionId,
        revision: snapshot.revision,
        updatedAt: snapshot.updatedAt,
        destinationPath: destinationPath,
        userSafeMessage: 'Vault exported.',
      );
    } catch (error) {
      return ExportResult(
        status: ExportStatus.failed,
        vaultId: vaultId,
        vaultVersionId: '',
        revision: 0,
        updatedAt: '',
        destinationPath: destinationPath,
        userSafeMessage: 'Failed to export vault. $error',
      );
    }
  }

  @override
  Future<Map<String, dynamic>> readVaultInternals({
    required String filePath,
  }) async {
    final storeId = _handleToVaultStoreId[filePath] ?? filePath;
    final snapshot = await _snapshotForHandle(filePath);
    final structure = await _privateVaultStore.describeVault(storeId);
    return <String, dynamic>{
      'format': snapshot.format,
      'formatVersion': snapshot.formatVersion,
      'schemaVersion': snapshot.schemaVersion,
      'storageLayoutVersion': snapshot.storageLayoutVersion,
      'manifestVersion': snapshot.manifestVersion,
      'snapshotBytes': utf8.encode(jsonEncode(snapshot.toJson())).length,
      'vaultId': snapshot.vaultId,
      'vaultVersionId': snapshot.vaultVersionId,
      'revision': snapshot.revision,
      'createdAt': snapshot.createdAt,
      'updatedAt': snapshot.updatedAt,
      'lastModifiedByDeviceId': snapshot.lastModifiedByDeviceId ?? '',
      'crypto': <String, dynamic>{
        'guardianProfile': snapshot.guardian.profile,
        'kdf': snapshot.kdf.name,
        'kdfMemoryKb': snapshot.kdf.memoryKb,
        'kdfIterations': snapshot.kdf.iterations,
        'kdfParallelism': snapshot.kdf.parallelism,
        'kdfSaltBytes': _base64ByteLength(snapshot.kdf.salt),
        'recoveryKdfSaltBytes': _base64ByteLength(snapshot.recoveryKdf.salt),
        'cipher': snapshot.cipher.name,
        'cipherNonceBytes': _base64ByteLength(snapshot.cipher.nonce),
        'encryptedVaultKeyBytes': _base64ByteLength(snapshot.encryptedVaultKey),
        'encryptedRecoveryKeyBytes': _base64ByteLength(
          snapshot.encryptedVaultKeyByRecovery,
        ),
      },
      'encryptedSections': snapshot.encryptedSections.map(
        (name, value) => MapEntry<String, int>(name, _base64ByteLength(value)),
      ),
      'workingStore': structure,
    };
  }

  Future<Vault> _unlockWithDerivedKey({
    required String filePath,
    required VaultFile file,
    required String secret,
    required KdfMetadata kdf,
    required String encryptedVaultKeyBase64,
    required String deriveMessage,
    VaultProgressCallback? onProgress,
  }) async {
    onProgress?.call(
      VaultOperationProgress(value: 0.35, message: deriveMessage),
    );
    final passwordKey = await _deriveKey(secret, kdf);
    onProgress?.call(
      const VaultOperationProgress(
        value: 0.60,
        message: 'Decrypting vault key...',
      ),
    );
    final vaultKey = await _cryptoAdapter.decrypt(
      cipher: base64Decode(encryptedVaultKeyBase64),
      key: passwordKey,
    );
    onProgress?.call(
      const VaultOperationProgress(
        value: 0.80,
        message: 'Decrypting vault payload...',
      ),
    );
    final payload = await _payloadFromWorkingOrSnapshot(
      filePath: filePath,
      file: file,
      vaultKey: vaultKey,
    );
    if (!await _privateVaultStore.vaultExists(_storeIdFor(filePath, file))) {
      final sections = await _sectionsForPayload(
        header: file,
        payload: payload,
        vaultKey: vaultKey,
      );
      _addSnapshotExtraSections(file, sections);
      await _privateVaultStore.commitVault(
        vaultStoreId: file.vaultId,
        header: file,
        sections: sections,
      );
    }
    await _rememberRegistry(file, label: _displayLabel(file));
    _handleToVaultStoreId[filePath] = file.vaultId;

    onProgress?.call(
      const VaultOperationProgress(value: 1.0, message: 'Vault unlocked.'),
    );
    return Vault(
      id: file.vaultId,
      formatVersion: file.formatVersion,
      guardianProfileId: file.guardian.profile,
      items: payload.items.map((item) => item['id']?.toString() ?? '').toList(),
      notes: payload.notes.map((note) => note['id']?.toString() ?? '').toList(),
    );
  }

  Future<void> _commitHeaderMutation({
    required String filePath,
    required VaultFile file,
    required List<int> vaultKey,
    required VaultFile Function(VaultFile next) update,
  }) async {
    final payload = await _payloadFromWorkingOrSnapshot(
      filePath: filePath,
      file: file,
      vaultKey: vaultKey,
    );
    final nextHeader = update(_nextMutationHeader(file));
    await _commitPayload(
      vaultStoreId: _storeIdFor(filePath, file),
      header: nextHeader,
      payload: payload,
      vaultKey: vaultKey,
    );
    await _rememberRegistry(nextHeader, label: _displayLabel(nextHeader));
    await _writeSnapshotToHandle(filePath, nextHeader.vaultId);
  }

  Future<ImportResult> _replaceImportedVault({
    required String filePath,
    required VaultRegistryEntry existing,
    required VaultFile incoming,
    required Map<String, Uint8List> sections,
    required String statusMessage,
  }) async {
    final stagedId = await _privateVaultStore.stageVault(
      vaultStoreId: existing.id,
      header: incoming,
      sections: sections,
    );
    await _privateVaultStore.promoteStagedVault(
      stagedVaultStoreId: stagedId,
      vaultStoreId: existing.id,
    );
    await _rememberRegistry(incoming, label: existing.label);
    _handleToVaultStoreId[filePath] = existing.id;
    return ImportResult(
      status: ImportStatus.imported,
      vaultId: incoming.vaultId,
      localRevision: existing.revision,
      incomingRevision: incoming.revision,
      localUpdatedAt: existing.updatedAt,
      incomingUpdatedAt: incoming.updatedAt,
      userSafeMessage: statusMessage,
    );
  }

  Future<ImportResult> _createConflictCopy({
    required VaultFile incoming,
    required Map<String, Uint8List> sections,
    required VaultFile local,
    String message = 'Conflict copy created.',
  }) async {
    final conflictId =
        '${incoming.vaultId}-conflict-${DateTime.now().millisecondsSinceEpoch}';
    final label = '${_displayLabel(incoming)} Conflict ${_timestampForName()}';
    await _privateVaultStore.commitVault(
      vaultStoreId: conflictId,
      header: incoming,
      sections: sections,
    );
    final now = DateTime.now().millisecondsSinceEpoch;
    await _registryStore.upsert(
      VaultRegistryEntry(
        id: conflictId,
        vaultId: incoming.vaultId,
        label: label,
        revision: incoming.revision,
        vaultVersionId: incoming.vaultVersionId,
        updatedAt: incoming.updatedAt,
        addedAtEpochMs: now,
        isConflict: true,
      ),
    );
    _handleToVaultStoreId[conflictId] = conflictId;
    return ImportResult(
      status: ImportStatus.conflictCreated,
      vaultId: incoming.vaultId,
      conflictVaultId: conflictId,
      localRevision: local.revision,
      incomingRevision: incoming.revision,
      localUpdatedAt: local.updatedAt,
      incomingUpdatedAt: incoming.updatedAt,
      userSafeMessage: message,
    );
  }

  Future<VaultFile> _snapshotForHandle(String handle) async {
    final storeId = _handleToVaultStoreId[handle] ?? handle;
    if (await _privateVaultStore.vaultExists(storeId)) {
      final header = await _privateVaultStore.readHeader(storeId);
      final sections = await _readExistingWorkingSections(storeId);
      final manifest = sections.remove(_manifestFile);
      if (manifest == null) {
        throw StateError('Working vault missing manifest section.');
      }
      return header.copyWith(
        formatVersion: VaultMigrator.currentVaultFormatVersion,
        encryptedPayload: null,
        encryptedManifest: base64Encode(manifest),
        encryptedSections: sections.map(
          (name, bytes) => MapEntry<String, String>(name, base64Encode(bytes)),
        ),
      );
    }
    return _readSnapshotFile(handle);
  }

  Future<VaultFile> _readMigratedVaultFile({required String filePath}) async {
    final storeId = _handleToVaultStoreId[filePath] ?? filePath;
    if (await _privateVaultStore.vaultExists(storeId)) {
      return _privateVaultStore.readHeader(storeId);
    }
    return _readSnapshotFile(filePath);
  }

  Future<VaultFile> _readSnapshotFile(String filePath) async {
    final raw = await _storageAdapter.read(filePath: filePath);
    final decoded = Map<String, dynamic>.from(jsonDecode(raw) as Map);
    final migrated = VaultMigrator.migrateVaultFileJson(decoded);
    return VaultFile.fromJson(migrated);
  }

  Future<VaultPayload> _payloadFromWorkingOrSnapshot({
    required String filePath,
    required VaultFile file,
    required List<int> vaultKey,
  }) async {
    final storeId = _storeIdFor(filePath, file);
    if (await _privateVaultStore.vaultExists(storeId)) {
      return _payloadFromWorking(storeId, vaultKey);
    }
    return _payloadFromSnapshot(file, vaultKey);
  }

  Future<VaultPayload> _payloadFromWorking(
    String vaultStoreId,
    List<int> vaultKey,
  ) async {
    final items = await _decryptSection(vaultStoreId, _itemsFile, vaultKey);
    final notes = await _decryptSection(vaultStoreId, _notesFile, vaultKey);
    final settings = await _decryptSection(
      vaultStoreId,
      _settingsFile,
      vaultKey,
    );
    final tags = await _decryptSection(vaultStoreId, _tagsFile, vaultKey);
    final header = await _privateVaultStore.readHeader(vaultStoreId);
    return VaultPayload.fromJson(
      VaultMigrator.migratePayloadJson(<String, dynamic>{
        'schemaVersion': header.schemaVersion,
        'items': items,
        'notes': notes,
        'settings': settings,
        'tags': tags,
        'audit': const <Map<String, dynamic>>[],
      }),
    );
  }

  Future<dynamic> _decryptSection(
    String vaultStoreId,
    String fileName,
    List<int> vaultKey,
  ) async {
    final cipher = await _privateVaultStore.readSection(vaultStoreId, fileName);
    final plain = await _cryptoAdapter.decrypt(cipher: cipher, key: vaultKey);
    return jsonDecode(utf8.decode(plain));
  }

  Future<VaultPayload> _payloadFromSnapshot(
    VaultFile file,
    List<int> vaultKey,
  ) async {
    if (file.encryptedSections.isNotEmpty) {
      final items = await _decryptSnapshotSection(file, _itemsFile, vaultKey);
      final notes = await _decryptSnapshotSection(file, _notesFile, vaultKey);
      final settings = await _decryptSnapshotSection(
        file,
        _settingsFile,
        vaultKey,
      );
      final tags = await _decryptSnapshotSection(file, _tagsFile, vaultKey);
      return VaultPayload.fromJson(
        VaultMigrator.migratePayloadJson(<String, dynamic>{
          'schemaVersion': file.schemaVersion,
          'items': items,
          'notes': notes,
          'settings': settings,
          'tags': tags,
          'audit': const <Map<String, dynamic>>[],
        }),
      );
    }
    final encryptedPayload = file.encryptedPayload;
    if (encryptedPayload == null || encryptedPayload.isEmpty) {
      throw StateError('Vault snapshot has no encrypted payload.');
    }
    final payloadBytes = await _cryptoAdapter.decrypt(
      cipher: base64Decode(encryptedPayload),
      key: vaultKey,
    );
    final decoded = Map<String, dynamic>.from(
      jsonDecode(utf8.decode(payloadBytes)) as Map,
    );
    return VaultPayload.fromJson(VaultMigrator.migratePayloadJson(decoded));
  }

  Future<dynamic> _decryptSnapshotSection(
    VaultFile file,
    String fileName,
    List<int> vaultKey,
  ) async {
    final section = file.encryptedSections[fileName];
    if (section == null) {
      throw StateError('Vault snapshot missing section: $fileName');
    }
    final plain = await _cryptoAdapter.decrypt(
      cipher: base64Decode(section),
      key: vaultKey,
    );
    return jsonDecode(utf8.decode(plain));
  }

  Future<void> _commitPayload({
    required String vaultStoreId,
    required VaultFile header,
    required VaultPayload payload,
    required List<int> vaultKey,
  }) async {
    final sections = await _sectionsForPayload(
      header: header,
      payload: payload,
      vaultKey: vaultKey,
    );
    final existing = await _readExistingWorkingSections(vaultStoreId);
    for (final entry in existing.entries) {
      sections.putIfAbsent(entry.key, () => entry.value);
    }
    await _privateVaultStore.commitVault(
      vaultStoreId: vaultStoreId,
      header: header,
      sections: sections,
    );
  }

  Future<Map<String, Uint8List>> _readExistingWorkingSections(
    String vaultStoreId,
  ) async {
    if (!await _privateVaultStore.vaultExists(vaultStoreId)) {
      return <String, Uint8List>{};
    }
    final structure = await _privateVaultStore.describeVault(vaultStoreId);
    final files = Map<String, dynamic>.from(
      structure['files'] as Map? ?? const <String, dynamic>{},
    );
    final sections = <String, Uint8List>{};
    for (final name in files.keys) {
      if (name == _headerFile) continue;
      sections[name] = await _privateVaultStore.readSection(vaultStoreId, name);
    }
    return sections;
  }

  Future<Map<String, Uint8List>> _sectionsForPayload({
    required VaultFile header,
    required VaultPayload payload,
    required List<int> vaultKey,
  }) async {
    final manifest = <String, dynamic>{
      'manifestVersion': header.manifestVersion,
      'storageLayoutVersion': header.storageLayoutVersion,
      'sections': const <String>[
        _itemsFile,
        _notesFile,
        _settingsFile,
        _tagsFile,
      ],
    };
    return <String, Uint8List>{
      _itemsFile: await _encryptJson(payload.items, vaultKey),
      _notesFile: await _encryptJson(payload.notes, vaultKey),
      _settingsFile: await _encryptJson(payload.settings, vaultKey),
      _tagsFile: await _encryptJson(payload.tags, vaultKey),
      _manifestFile: await _encryptJson(manifest, vaultKey),
    };
  }

  void _addSnapshotExtraSections(
    VaultFile snapshot,
    Map<String, Uint8List> sections,
  ) {
    for (final entry in snapshot.encryptedSections.entries) {
      if (_isCoreSection(entry.key)) continue;
      sections.putIfAbsent(entry.key, () => base64Decode(entry.value));
    }
  }

  bool _isCoreSection(String name) {
    return name == _manifestFile ||
        name == _itemsFile ||
        name == _notesFile ||
        name == _settingsFile ||
        name == _tagsFile;
  }

  Future<Uint8List> _encryptJson(dynamic value, List<int> vaultKey) async {
    final encrypted = await _cryptoAdapter.encrypt(
      plain: utf8.encode(jsonEncode(value)),
      key: vaultKey,
    );
    return Uint8List.fromList(encrypted);
  }

  String _documentSectionFile(String documentId) {
    final cleaned = documentId.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
    return 'document_$cleaned.enc';
  }

  Future<List<int>> _unwrapVaultKey(VaultFile file, String password) async {
    final passwordKey = await _deriveKey(password, file.kdf);
    return _cryptoAdapter.decrypt(
      cipher: base64Decode(file.encryptedVaultKey),
      key: passwordKey,
    );
  }

  Future<List<int>> _deriveKey(String secret, KdfMetadata kdf) {
    return _cryptoAdapter.deriveKey(
      password: secret,
      salt: base64Decode(kdf.salt),
      memoryKb: kdf.memoryKb,
      iterations: kdf.iterations,
      parallelism: kdf.parallelism,
    );
  }

  VaultFile _nextMutationHeader(VaultFile file) {
    final now = DateTime.now().toUtc().toIso8601String();
    return file.copyWith(
      formatVersion: VaultMigrator.currentVaultFormatVersion,
      schemaVersion: VaultMigrator.currentPayloadSchemaVersion,
      storageLayoutVersion: VaultMigrator.currentStorageLayoutVersion,
      manifestVersion: VaultMigrator.currentManifestVersion,
      updatedAt: now,
      revision: file.revision + 1,
      vaultVersionId: _newUuidV4(),
      lastModifiedByDeviceId: _deviceId,
      resolvedFromVersionIds: const <String>[],
      encryptedPayload: null,
    );
  }

  String _storeIdFor(String handle, VaultFile file) {
    return _handleToVaultStoreId[handle] ?? file.vaultId;
  }

  Future<void> _writeSnapshotToHandle(
    String handle,
    String vaultStoreId,
  ) async {
    try {
      final snapshot = await _snapshotForHandle(vaultStoreId);
      await _storageAdapter.write(
        filePath: handle,
        content: jsonEncode(snapshot.toJson()),
      );
    } catch (_) {
      // The private working copy is the active source of truth.
    }
  }

  Future<void> _rememberRegistry(
    VaultFile header, {
    required String label,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final existing = await _registryStore.findActiveByVaultId(header.vaultId);
    await _registryStore.upsert(
      VaultRegistryEntry(
        id: header.vaultId,
        vaultId: header.vaultId,
        label: label.trim().isEmpty ? 'vault.nija' : label.trim(),
        revision: header.revision,
        vaultVersionId: header.vaultVersionId,
        updatedAt: header.updatedAt,
        addedAtEpochMs: existing?.addedAtEpochMs ?? now,
        lastOpenedAtEpochMs: existing?.lastOpenedAtEpochMs ?? 0,
      ),
    );
  }

  bool _hasRevision(VaultFile file) {
    return file.revision > 0 && !file.vaultVersionId.startsWith('legacy-');
  }

  int _compareUpdatedAt(String incoming, String local) {
    final incomingDate = DateTime.tryParse(incoming);
    final localDate = DateTime.tryParse(local);
    if (incomingDate == null || localDate == null) return 0;
    return incomingDate.compareTo(localDate);
  }

  String _displayLabel(VaultFile file) {
    return file.vaultName?.trim().isNotEmpty == true
        ? file.vaultName!.trim()
        : 'vault.nija';
  }

  String _timestampForName() {
    final now = DateTime.now();
    String two(int value) => value.toString().padLeft(2, '0');
    return '${now.year}${two(now.month)}${two(now.day)}-'
        '${two(now.hour)}${two(now.minute)}';
  }

  GuardianProfile _guardianById(String guardianProfileId) {
    return GuardianProfiles.all.firstWhere(
      (profile) => profile.id == guardianProfileId,
      orElse: () => GuardianProfiles.owl,
    );
  }

  List<int> _randomBytes(int length) {
    return List<int>.generate(length, (_) => _random.nextInt(256));
  }

  String _newUuidV4() {
    final bytes = _randomBytes(16);
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-'
        '${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-'
        '${hex.substring(16, 20)}-'
        '${hex.substring(20)}';
  }

  int _base64ByteLength(String value) {
    if (value.isEmpty) return 0;
    try {
      return base64Decode(value).length;
    } catch (_) {
      return 0;
    }
  }
}

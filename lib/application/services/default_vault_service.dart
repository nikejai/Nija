import 'dart:convert';
import 'dart:math';

import '../../core/config/guardian_profiles.dart';
import '../../domain/models/vault.dart';
import '../../domain/models/vault_file.dart';
import '../../domain/models/vault_payload.dart';
import '../../infrastructure/adapters/crypto_adapter.dart';
import '../../infrastructure/adapters/vault_storage_adapter.dart';
import 'vault_migrator.dart';
import 'vault_service.dart';

class DefaultVaultService implements VaultService {
  DefaultVaultService({
    required VaultStorageAdapter storageAdapter,
    required CryptoAdapter cryptoAdapter,
  })  : _storageAdapter = storageAdapter,
        _cryptoAdapter = cryptoAdapter;

  final VaultStorageAdapter _storageAdapter;
  final CryptoAdapter _cryptoAdapter;
  final Random _random = Random.secure();

  @override
  Future<String> readRawVaultFile({
    required String filePath,
  }) {
    return _storageAdapter.read(filePath: filePath);
  }

  @override
  Future<void> writeRawVaultFile({
    required String filePath,
    required String rawContent,
  }) {
    return _storageAdapter.write(filePath: filePath, content: rawContent);
  }

  @override
  Future<bool> vaultExists({
    required String filePath,
  }) async {
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
    onProgress?.call(const VaultOperationProgress(value: 0.05, message: 'Preparing vault parameters...'));
    final guardian = _guardianById(guardianProfileId);
    final now = DateTime.now().toUtc().toIso8601String();
    final saltBytes = utf8.encode('salt-$now-${guardian.id}');
    final nonceBytes = utf8.encode('nonce-$now-${guardian.id}');
    onProgress?.call(const VaultOperationProgress(value: 0.15, message: 'Generating vault encryption key...'));
    final vaultKeyBytes = List<int>.generate(32, (_) => _random.nextInt(256));

    onProgress?.call(const VaultOperationProgress(value: 0.25, message: 'Deriving master key (Argon2id)...'));
    final passwordKey = await _cryptoAdapter.deriveKey(
      password: password,
      salt: saltBytes,
      memoryKb: guardian.memoryKb,
      iterations: guardian.iterations,
      parallelism: guardian.parallelism,
    );
    onProgress?.call(const VaultOperationProgress(value: 0.40, message: 'Deriving recovery key (Argon2id)...'));
    final recoverySaltBytes = utf8.encode('recovery-salt-$now-${guardian.id}');
    final recoveryKey = await _cryptoAdapter.deriveKey(
      password: recoveryPhrase,
      salt: recoverySaltBytes,
      memoryKb: guardian.memoryKb,
      iterations: guardian.iterations,
      parallelism: guardian.parallelism,
    );
    onProgress?.call(const VaultOperationProgress(value: 0.55, message: 'Wrapping vault key with master key...'));
    final encryptedVaultKeyBytes = await _cryptoAdapter.encrypt(
      plain: vaultKeyBytes,
      key: passwordKey,
    );
    onProgress?.call(const VaultOperationProgress(value: 0.65, message: 'Wrapping vault key with recovery key...'));
    final encryptedVaultKeyByRecoveryBytes = await _cryptoAdapter.encrypt(
      plain: vaultKeyBytes,
      key: recoveryKey,
    );

    onProgress?.call(const VaultOperationProgress(value: 0.75, message: 'Encrypting vault payload...'));
    final payload = VaultPayload.empty();
    final payloadBytes = utf8.encode(jsonEncode(payload.toJson()));
    final encryptedPayloadBytes = await _cryptoAdapter.encrypt(
      plain: payloadBytes,
      key: vaultKeyBytes,
    );

    onProgress?.call(const VaultOperationProgress(value: 0.90, message: 'Writing encrypted vault file...'));
    final file = VaultFile(
      format: 'Nija',
      formatVersion: VaultMigrator.currentVaultFormatVersion,
      vaultId: vaultId,
      vaultName: vaultName.trim(),
      createdAt: now,
      updatedAt: now,
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
      encryptedVaultKeyByRecovery: base64Encode(encryptedVaultKeyByRecoveryBytes),
      encryptedPayload: base64Encode(encryptedPayloadBytes),
    );

    await _storageAdapter.write(
      filePath: filePath,
      content: jsonEncode(file.toJson()),
    );

    onProgress?.call(const VaultOperationProgress(value: 1.0, message: 'Vault created successfully.'));
    return Vault(
      id: file.vaultId,
      formatVersion: file.formatVersion,
      guardianProfileId: file.guardian.profile,
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
    onProgress?.call(const VaultOperationProgress(value: 0.10, message: 'Reading vault file...'));
    final file = await _readMigratedVaultFile(filePath: filePath);
    return _unlockWithDerivedKey(
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
    onProgress?.call(const VaultOperationProgress(value: 0.10, message: 'Reading vault file...'));
    final file = await _readMigratedVaultFile(filePath: filePath);
    return _unlockWithDerivedKey(
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
    onProgress?.call(const VaultOperationProgress(value: 0.10, message: 'Reading vault file...'));
    final file = await _readMigratedVaultFile(filePath: filePath);

    onProgress?.call(const VaultOperationProgress(value: 0.30, message: 'Deriving recovery key (Argon2id)...'));
    final recoverySalt = base64Decode(file.recoveryKdf.salt);
    final recoveryKey = await _cryptoAdapter.deriveKey(
      password: recoveryPhrase,
      salt: recoverySalt,
      memoryKb: file.recoveryKdf.memoryKb,
      iterations: file.recoveryKdf.iterations,
      parallelism: file.recoveryKdf.parallelism,
    );

    onProgress?.call(const VaultOperationProgress(value: 0.50, message: 'Unwrapping vault key...'));
    final encryptedVaultKeyByRecovery = base64Decode(file.encryptedVaultKeyByRecovery);
    final vaultKey = await _cryptoAdapter.decrypt(cipher: encryptedVaultKeyByRecovery, key: recoveryKey);

    onProgress?.call(const VaultOperationProgress(value: 0.70, message: 'Deriving new master key (Argon2id)...'));
    final now = DateTime.now().toUtc().toIso8601String();
    final newSaltBytes = utf8.encode('salt-$now-${file.guardian.profile}');
    final newPasswordKey = await _cryptoAdapter.deriveKey(
      password: newPassword,
      salt: newSaltBytes,
      memoryKb: file.kdf.memoryKb,
      iterations: file.kdf.iterations,
      parallelism: file.kdf.parallelism,
    );

    onProgress?.call(const VaultOperationProgress(value: 0.85, message: 'Wrapping vault key with new master key...'));
    final newEncryptedVaultKey = await _cryptoAdapter.encrypt(
      plain: vaultKey,
      key: newPasswordKey,
    );

    onProgress?.call(const VaultOperationProgress(value: 0.95, message: 'Writing updated vault file...'));
    final updatedFile = VaultFile(
      format: file.format,
      formatVersion: file.formatVersion,
      vaultId: file.vaultId,
      vaultName: file.vaultName,
      createdAt: file.createdAt,
      updatedAt: now,
      guardian: file.guardian,
      kdf: KdfMetadata(
        name: file.kdf.name,
        version: file.kdf.version,
        memoryKb: file.kdf.memoryKb,
        iterations: file.kdf.iterations,
        parallelism: file.kdf.parallelism,
        salt: base64Encode(newSaltBytes),
      ),
      recoveryKdf: file.recoveryKdf,
      cipher: file.cipher,
      encryptedVaultKey: base64Encode(newEncryptedVaultKey),
      encryptedVaultKeyByRecovery: file.encryptedVaultKeyByRecovery,
      encryptedPayload: file.encryptedPayload,
    );

    await _storageAdapter.write(
      filePath: filePath,
      content: jsonEncode(updatedFile.toJson()),
    );
    onProgress?.call(const VaultOperationProgress(value: 1.0, message: 'Master password updated.'));
  }

  @override
  Future<void> rotateMasterPassword({
    required String filePath,
    required String currentPassword,
    required String newPassword,
    VaultProgressCallback? onProgress,
  }) async {
    onProgress?.call(const VaultOperationProgress(value: 0.10, message: 'Reading vault file...'));
    final file = await _readMigratedVaultFile(filePath: filePath);

    onProgress?.call(const VaultOperationProgress(value: 0.30, message: 'Deriving current master key (Argon2id)...'));
    final currentSalt = base64Decode(file.kdf.salt);
    final currentMasterKey = await _cryptoAdapter.deriveKey(
      password: currentPassword,
      salt: currentSalt,
      memoryKb: file.kdf.memoryKb,
      iterations: file.kdf.iterations,
      parallelism: file.kdf.parallelism,
    );

    onProgress?.call(const VaultOperationProgress(value: 0.50, message: 'Unwrapping vault key...'));
    final encryptedVaultKey = base64Decode(file.encryptedVaultKey);
    final vaultKey = await _cryptoAdapter.decrypt(cipher: encryptedVaultKey, key: currentMasterKey);

    onProgress?.call(const VaultOperationProgress(value: 0.70, message: 'Deriving new master key (Argon2id)...'));
    final now = DateTime.now().toUtc().toIso8601String();
    final newSaltBytes = utf8.encode('salt-$now-${file.guardian.profile}');
    final newMasterKey = await _cryptoAdapter.deriveKey(
      password: newPassword,
      salt: newSaltBytes,
      memoryKb: file.kdf.memoryKb,
      iterations: file.kdf.iterations,
      parallelism: file.kdf.parallelism,
    );

    onProgress?.call(const VaultOperationProgress(value: 0.85, message: 'Re-wrapping vault key with new master key...'));
    final newEncryptedVaultKey = await _cryptoAdapter.encrypt(
      plain: vaultKey,
      key: newMasterKey,
    );

    onProgress?.call(const VaultOperationProgress(value: 0.95, message: 'Persisting updated vault metadata...'));
    final updatedFile = VaultFile(
      format: file.format,
      formatVersion: file.formatVersion,
      vaultId: file.vaultId,
      vaultName: file.vaultName,
      createdAt: file.createdAt,
      updatedAt: now,
      guardian: file.guardian,
      kdf: KdfMetadata(
        name: file.kdf.name,
        version: file.kdf.version,
        memoryKb: file.kdf.memoryKb,
        iterations: file.kdf.iterations,
        parallelism: file.kdf.parallelism,
        salt: base64Encode(newSaltBytes),
      ),
      recoveryKdf: file.recoveryKdf,
      cipher: file.cipher,
      encryptedVaultKey: base64Encode(newEncryptedVaultKey),
      encryptedVaultKeyByRecovery: file.encryptedVaultKeyByRecovery,
      encryptedPayload: file.encryptedPayload,
    );

    await _storageAdapter.write(
      filePath: filePath,
      content: jsonEncode(updatedFile.toJson()),
    );
    onProgress?.call(const VaultOperationProgress(value: 1.0, message: 'Master password rotated.'));
  }

  @override
  Future<void> rotateRecoveryPhrase({
    required String filePath,
    required String currentRecoveryPhrase,
    required String newRecoveryPhrase,
    VaultProgressCallback? onProgress,
  }) async {
    onProgress?.call(const VaultOperationProgress(value: 0.10, message: 'Reading vault file...'));
    final file = await _readMigratedVaultFile(filePath: filePath);

    onProgress?.call(const VaultOperationProgress(value: 0.30, message: 'Deriving current recovery key (Argon2id)...'));
    final currentRecoverySalt = base64Decode(file.recoveryKdf.salt);
    final currentRecoveryKey = await _cryptoAdapter.deriveKey(
      password: currentRecoveryPhrase,
      salt: currentRecoverySalt,
      memoryKb: file.recoveryKdf.memoryKb,
      iterations: file.recoveryKdf.iterations,
      parallelism: file.recoveryKdf.parallelism,
    );

    onProgress?.call(const VaultOperationProgress(value: 0.50, message: 'Unwrapping vault key...'));
    final encryptedByRecovery = base64Decode(file.encryptedVaultKeyByRecovery);
    final vaultKey = await _cryptoAdapter.decrypt(cipher: encryptedByRecovery, key: currentRecoveryKey);

    onProgress?.call(const VaultOperationProgress(value: 0.70, message: 'Deriving new recovery key (Argon2id)...'));
    final now = DateTime.now().toUtc().toIso8601String();
    final newRecoverySaltBytes = utf8.encode('recovery-salt-$now-${file.guardian.profile}');
    final newRecoveryKey = await _cryptoAdapter.deriveKey(
      password: newRecoveryPhrase,
      salt: newRecoverySaltBytes,
      memoryKb: file.recoveryKdf.memoryKb,
      iterations: file.recoveryKdf.iterations,
      parallelism: file.recoveryKdf.parallelism,
    );

    onProgress?.call(const VaultOperationProgress(value: 0.85, message: 'Re-wrapping vault key with new recovery key...'));
    final newEncryptedByRecovery = await _cryptoAdapter.encrypt(
      plain: vaultKey,
      key: newRecoveryKey,
    );

    onProgress?.call(const VaultOperationProgress(value: 0.95, message: 'Persisting updated vault metadata...'));
    final updatedFile = VaultFile(
      format: file.format,
      formatVersion: file.formatVersion,
      vaultId: file.vaultId,
      vaultName: file.vaultName,
      createdAt: file.createdAt,
      updatedAt: now,
      guardian: file.guardian,
      kdf: file.kdf,
      recoveryKdf: KdfMetadata(
        name: file.recoveryKdf.name,
        version: file.recoveryKdf.version,
        memoryKb: file.recoveryKdf.memoryKb,
        iterations: file.recoveryKdf.iterations,
        parallelism: file.recoveryKdf.parallelism,
        salt: base64Encode(newRecoverySaltBytes),
      ),
      cipher: file.cipher,
      encryptedVaultKey: file.encryptedVaultKey,
      encryptedVaultKeyByRecovery: base64Encode(newEncryptedByRecovery),
      encryptedPayload: file.encryptedPayload,
    );

    await _storageAdapter.write(
      filePath: filePath,
      content: jsonEncode(updatedFile.toJson()),
    );
    onProgress?.call(const VaultOperationProgress(value: 1.0, message: 'Recovery phrase rotated.'));
  }

  @override
  Future<VaultPayload> readVaultPayload({
    required String filePath,
    required String password,
    VaultProgressCallback? onProgress,
  }) async {
    onProgress?.call(const VaultOperationProgress(value: 0.10, message: 'Reading vault file...'));
    final file = await _readMigratedVaultFile(filePath: filePath);

    onProgress?.call(const VaultOperationProgress(value: 0.35, message: 'Deriving master key (Argon2id)...'));
    final passwordKey = await _cryptoAdapter.deriveKey(
      password: password,
      salt: base64Decode(file.kdf.salt),
      memoryKb: file.kdf.memoryKb,
      iterations: file.kdf.iterations,
      parallelism: file.kdf.parallelism,
    );

    onProgress?.call(const VaultOperationProgress(value: 0.60, message: 'Decrypting vault key...'));
    final vaultKey = await _cryptoAdapter.decrypt(
      cipher: base64Decode(file.encryptedVaultKey),
      key: passwordKey,
    );

    onProgress?.call(const VaultOperationProgress(value: 0.80, message: 'Decrypting vault payload...'));
    final payloadBytes = await _cryptoAdapter.decrypt(
      cipher: base64Decode(file.encryptedPayload),
      key: vaultKey,
    );
    final payloadMap = _decodeMigratedPayload(payloadBytes);
    onProgress?.call(const VaultOperationProgress(value: 1.0, message: 'Vault payload loaded.'));
    return VaultPayload.fromJson(payloadMap);
  }

  @override
  Future<void> persistVaultPayload({
    required String filePath,
    required String password,
    required VaultPayload payload,
    VaultProgressCallback? onProgress,
  }) async {
    onProgress?.call(const VaultOperationProgress(value: 0.10, message: 'Reading vault file...'));
    final file = await _readMigratedVaultFile(filePath: filePath);

    onProgress?.call(const VaultOperationProgress(value: 0.30, message: 'Deriving master key (Argon2id)...'));
    final passwordKey = await _cryptoAdapter.deriveKey(
      password: password,
      salt: base64Decode(file.kdf.salt),
      memoryKb: file.kdf.memoryKb,
      iterations: file.kdf.iterations,
      parallelism: file.kdf.parallelism,
    );

    onProgress?.call(const VaultOperationProgress(value: 0.50, message: 'Decrypting vault key...'));
    final vaultKey = await _cryptoAdapter.decrypt(
      cipher: base64Decode(file.encryptedVaultKey),
      key: passwordKey,
    );

    onProgress?.call(const VaultOperationProgress(value: 0.75, message: 'Encrypting updated payload...'));
    final payloadBytes = utf8.encode(jsonEncode(payload.toJson()));
    final encryptedPayload = await _cryptoAdapter.encrypt(
      plain: payloadBytes,
      key: vaultKey,
    );

    onProgress?.call(const VaultOperationProgress(value: 0.90, message: 'Writing vault file...'));
    final now = DateTime.now().toUtc().toIso8601String();
    final updatedFile = VaultFile(
      format: file.format,
      formatVersion: file.formatVersion,
      vaultId: file.vaultId,
      vaultName: file.vaultName,
      createdAt: file.createdAt,
      updatedAt: now,
      guardian: file.guardian,
      kdf: file.kdf,
      recoveryKdf: file.recoveryKdf,
      cipher: file.cipher,
      encryptedVaultKey: file.encryptedVaultKey,
      encryptedVaultKeyByRecovery: file.encryptedVaultKeyByRecovery,
      encryptedPayload: base64Encode(encryptedPayload),
    );
    await _storageAdapter.write(
      filePath: filePath,
      content: jsonEncode(updatedFile.toJson()),
    );
    onProgress?.call(const VaultOperationProgress(value: 1.0, message: 'Vault payload persisted.'));
  }

  Future<Vault> _unlockWithDerivedKey({
    required VaultFile file,
    required String secret,
    required KdfMetadata kdf,
    required String encryptedVaultKeyBase64,
    required String deriveMessage,
    VaultProgressCallback? onProgress,
  }) async {
    final salt = base64Decode(kdf.salt);
    onProgress?.call(VaultOperationProgress(value: 0.35, message: deriveMessage));
    final passwordKey = await _cryptoAdapter.deriveKey(
      password: secret,
      salt: salt,
      memoryKb: kdf.memoryKb,
      iterations: kdf.iterations,
      parallelism: kdf.parallelism,
    );
    onProgress?.call(const VaultOperationProgress(value: 0.60, message: 'Decrypting vault key...'));
    final encryptedVaultKey = base64Decode(encryptedVaultKeyBase64);
    final vaultKey = await _cryptoAdapter.decrypt(cipher: encryptedVaultKey, key: passwordKey);
    onProgress?.call(const VaultOperationProgress(value: 0.80, message: 'Decrypting vault payload...'));
    final encryptedPayload = base64Decode(file.encryptedPayload);
    final payloadBytes = await _cryptoAdapter.decrypt(cipher: encryptedPayload, key: vaultKey);

    final payloadMap = _decodeMigratedPayload(payloadBytes);
    final payload = VaultPayload.fromJson(payloadMap);

    onProgress?.call(const VaultOperationProgress(value: 1.0, message: 'Vault unlocked.'));
    return Vault(
      id: file.vaultId,
      formatVersion: file.formatVersion,
      guardianProfileId: file.guardian.profile,
      items: payload.items.map((item) => item['id']?.toString() ?? '').toList(),
      notes: payload.notes.map((note) => note['id']?.toString() ?? '').toList(),
    );
  }

  GuardianProfile _guardianById(String guardianProfileId) {
    return GuardianProfiles.all.firstWhere(
      (profile) => profile.id == guardianProfileId,
      orElse: () => GuardianProfiles.owl,
    );
  }

  Future<VaultFile> _readMigratedVaultFile({required String filePath}) async {
    final raw = await _storageAdapter.read(filePath: filePath);
    final decoded = Map<String, dynamic>.from(jsonDecode(raw) as Map);
    final migrated = VaultMigrator.migrateVaultFileJson(decoded);
    return VaultFile.fromJson(migrated);
  }

  Map<String, dynamic> _decodeMigratedPayload(List<int> payloadBytes) {
    final decoded = Map<String, dynamic>.from(
      jsonDecode(utf8.decode(payloadBytes)) as Map,
    );
    return VaultMigrator.migratePayloadJson(decoded);
  }
}

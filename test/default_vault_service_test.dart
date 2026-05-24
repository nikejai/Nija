import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:nija/application/services/default_vault_service.dart';
import 'package:nija/core/config/guardian_profiles.dart';
import 'package:nija/domain/models/vault_payload.dart';
import 'package:nija/domain/models/vault_transfer_result.dart';
import 'package:nija/infrastructure/adapters/private_vault_store.dart';
import 'package:nija/infrastructure/adapters/in_memory_vault_storage_adapter.dart';
import 'package:nija/infrastructure/adapters/secure_crypto_adapter.dart';

void main() {
  const basePhrase =
      'anchor apple arrow atlas beacon breeze canyon cedar cobalt ember harbor willow';

  test('create and unlock vault roundtrip', () async {
    final service = DefaultVaultService(
      storageAdapter: InMemoryVaultStorageAdapter(),
      cryptoAdapter: SecureCryptoAdapter(),
    );

    final created = await service.createVault(
      filePath: 'sample.nija',
      vaultId: 'sample.nija-id',
      vaultName: 'sample.nija-id',
      guardianProfileId: GuardianProfiles.owl.id,
      password: 'StrongPass123',
      recoveryPhrase: basePhrase,
    );

    final unlocked = await service.unlockVault(
      filePath: 'sample.nija',
      password: 'StrongPass123',
    );

    expect(created.id, isNotEmpty);
    expect(unlocked.id, created.id);
    expect(unlocked.guardianProfileId, GuardianProfiles.owl.id);

    final recovered = await service.unlockVaultWithRecoveryPhrase(
      filePath: 'sample.nija',
      recoveryPhrase: basePhrase,
    );
    expect(recovered.id, created.id);
  });

  test('recovery reset rotates master password immediately', () async {
    final service = DefaultVaultService(
      storageAdapter: InMemoryVaultStorageAdapter(),
      cryptoAdapter: SecureCryptoAdapter(),
    );

    await service.createVault(
      filePath: 'sample-reset.nija',
      vaultId: 'sample-reset.nija-id',
      vaultName: 'sample-reset.nija-id',
      guardianProfileId: GuardianProfiles.owl.id,
      password: 'OldPass123',
      recoveryPhrase: basePhrase,
    );

    await service.resetMasterPasswordAfterRecovery(
      filePath: 'sample-reset.nija',
      recoveryPhrase: basePhrase,
      newPassword: 'NewPass456',
    );

    expect(
      () => service.unlockVault(
        filePath: 'sample-reset.nija',
        password: 'OldPass123',
      ),
      throwsA(anything),
    );

    final unlocked = await service.unlockVault(
      filePath: 'sample-reset.nija',
      password: 'NewPass456',
    );
    expect(unlocked.id, isNotEmpty);
  });

  test('key rotation workflows rotate master and recovery wrappers', () async {
    final service = DefaultVaultService(
      storageAdapter: InMemoryVaultStorageAdapter(),
      cryptoAdapter: SecureCryptoAdapter(),
    );

    const phraseA = basePhrase;
    const phraseB =
        'amber arcade aspen basket blade bloom canyon comet coral drift ember galaxy';

    await service.createVault(
      filePath: 'sample-rotation.nija',
      vaultId: 'sample-rotation.nija-id',
      vaultName: 'sample-rotation.nija-id',
      guardianProfileId: GuardianProfiles.owl.id,
      password: 'MasterOne123',
      recoveryPhrase: phraseA,
    );

    await service.rotateMasterPassword(
      filePath: 'sample-rotation.nija',
      currentPassword: 'MasterOne123',
      newPassword: 'MasterTwo456',
    );

    expect(
      () => service.unlockVault(
        filePath: 'sample-rotation.nija',
        password: 'MasterOne123',
      ),
      throwsA(anything),
    );
    final unlockedByNewMaster = await service.unlockVault(
      filePath: 'sample-rotation.nija',
      password: 'MasterTwo456',
    );
    expect(unlockedByNewMaster.id, isNotEmpty);

    await service.rotateRecoveryPhrase(
      filePath: 'sample-rotation.nija',
      currentRecoveryPhrase: phraseA,
      newRecoveryPhrase: phraseB,
    );

    expect(
      () => service.unlockVaultWithRecoveryPhrase(
        filePath: 'sample-rotation.nija',
        recoveryPhrase: phraseA,
      ),
      throwsA(anything),
    );
    final unlockedByNewRecovery = await service.unlockVaultWithRecoveryPhrase(
      filePath: 'sample-rotation.nija',
      recoveryPhrase: phraseB,
    );
    expect(unlockedByNewRecovery.id, isNotEmpty);
  });

  test('unlock supports legacy file metadata migration', () async {
    final storage = InMemoryVaultStorageAdapter();
    final service = DefaultVaultService(
      storageAdapter: storage,
      cryptoAdapter: SecureCryptoAdapter(),
    );

    await service.createVault(
      filePath: 'legacy-file.nija',
      vaultId: 'legacy-file.nija-id',
      vaultName: 'legacy-file.nija-id',
      guardianProfileId: GuardianProfiles.owl.id,
      password: 'StrongPass123',
      recoveryPhrase: basePhrase,
    );

    final raw = await storage.read(filePath: 'legacy-file.nija');
    final jsonMap = Map<String, dynamic>.from(jsonDecode(raw) as Map)
      ..remove('formatVersion')
      ..remove('recoveryKdf')
      ..remove('encryptedVaultKeyByRecovery');
    await storage.write(
      filePath: 'legacy-file.nija',
      content: jsonEncode(jsonMap),
    );

    final unlocked = await service.unlockVault(
      filePath: 'legacy-file.nija',
      password: 'StrongPass123',
    );
    expect(unlocked.id, isNotEmpty);
  });

  test('wrong master password fails unlock', () async {
    final service = DefaultVaultService(
      storageAdapter: InMemoryVaultStorageAdapter(),
      cryptoAdapter: SecureCryptoAdapter(),
    );

    await service.createVault(
      filePath: 'wrong-master.nija',
      vaultId: 'wrong-master.nija-id',
      vaultName: 'wrong-master.nija-id',
      guardianProfileId: GuardianProfiles.owl.id,
      password: 'CorrectPass123',
      recoveryPhrase: basePhrase,
    );

    expect(
      () => service.unlockVault(
        filePath: 'wrong-master.nija',
        password: 'WrongPass123',
      ),
      throwsA(anything),
    );
  });

  test('wrong recovery phrase fails unlock', () async {
    final service = DefaultVaultService(
      storageAdapter: InMemoryVaultStorageAdapter(),
      cryptoAdapter: SecureCryptoAdapter(),
    );

    await service.createVault(
      filePath: 'wrong-recovery.nija',
      vaultId: 'wrong-recovery.nija-id',
      vaultName: 'wrong-recovery.nija-id',
      guardianProfileId: GuardianProfiles.owl.id,
      password: 'CorrectPass123',
      recoveryPhrase: basePhrase,
    );

    expect(
      () => service.unlockVaultWithRecoveryPhrase(
        filePath: 'wrong-recovery.nija',
        recoveryPhrase:
            'anchor apple arrow atlas beacon breeze canyon cedar cobalt ember harbor galaxy',
      ),
      throwsA(anything),
    );
  });

  test(
    'tampered metadata with unsupported format version is rejected',
    () async {
      final storage = InMemoryVaultStorageAdapter();
      final service = DefaultVaultService(
        storageAdapter: storage,
        cryptoAdapter: SecureCryptoAdapter(),
      );

      await service.createVault(
        filePath: 'tampered-version.nija',
        vaultId: 'tampered-version.nija-id',
        vaultName: 'tampered-version.nija-id',
        guardianProfileId: GuardianProfiles.owl.id,
        password: 'CorrectPass123',
        recoveryPhrase: basePhrase,
      );

      final raw = await storage.read(filePath: 'tampered-version.nija');
      final jsonMap = Map<String, dynamic>.from(jsonDecode(raw) as Map)
        ..['formatVersion'] = 99;
      await storage.write(
        filePath: 'tampered-version.nija',
        content: jsonEncode(jsonMap),
      );

      final unlocked = await service.unlockVault(
        filePath: 'tampered-version.nija',
        password: 'CorrectPass123',
      );
      expect(unlocked.id, 'tampered-version.nija-id');

      final importResult = await service.importNijaFile(
        filePath: 'tampered-version.nija',
        unlockCredential: 'CorrectPass123',
      );
      expect(importResult.status, ImportStatus.failed);
    },
  );

  test('corrupted encrypted payload fails decrypt', () async {
    final storage = InMemoryVaultStorageAdapter();
    final service = DefaultVaultService(
      storageAdapter: storage,
      cryptoAdapter: SecureCryptoAdapter(),
    );

    await service.createVault(
      filePath: 'corrupted-payload.nija',
      vaultId: 'corrupted-payload.nija-id',
      vaultName: 'corrupted-payload.nija-id',
      guardianProfileId: GuardianProfiles.owl.id,
      password: 'CorrectPass123',
      recoveryPhrase: basePhrase,
    );

    final raw = await storage.read(filePath: 'corrupted-payload.nija');
    final jsonMap = Map<String, dynamic>.from(jsonDecode(raw) as Map);
    final sections = Map<String, dynamic>.from(
      jsonMap['encryptedSections'] as Map,
    )..['items.enc'] = 'AQID';
    jsonMap['encryptedSections'] = sections;
    await storage.write(
      filePath: 'corrupted-payload.nija',
      content: jsonEncode(jsonMap),
    );

    final unlocked = await service.unlockVault(
      filePath: 'corrupted-payload.nija',
      password: 'CorrectPass123',
    );
    expect(unlocked.id, 'corrupted-payload.nija-id');

    final importResult = await service.importNijaFile(
      filePath: 'corrupted-payload.nija',
      unlockCredential: 'CorrectPass123',
    );
    expect(importResult.status, ImportStatus.failed);
  });

  test(
    'recovery, reset, and rotation workflow remains consistent end-to-end',
    () async {
      final service = DefaultVaultService(
        storageAdapter: InMemoryVaultStorageAdapter(),
        cryptoAdapter: SecureCryptoAdapter(),
      );

      const rotatedRecovery =
          'amber arcade aspen basket blade bloom canyon comet coral drift ember galaxy';

      await service.createVault(
        filePath: 'full-security-flow.nija',
        vaultId: 'full-security-flow.nija-id',
        vaultName: 'full-security-flow.nija-id',
        guardianProfileId: GuardianProfiles.owl.id,
        password: 'FirstPass123',
        recoveryPhrase: basePhrase,
      );

      final recovered = await service.unlockVaultWithRecoveryPhrase(
        filePath: 'full-security-flow.nija',
        recoveryPhrase: basePhrase,
      );
      expect(recovered.id, isNotEmpty);

      await service.resetMasterPasswordAfterRecovery(
        filePath: 'full-security-flow.nija',
        recoveryPhrase: basePhrase,
        newPassword: 'SecondPass456',
      );

      await service.rotateMasterPassword(
        filePath: 'full-security-flow.nija',
        currentPassword: 'SecondPass456',
        newPassword: 'ThirdPass789',
      );

      await service.rotateRecoveryPhrase(
        filePath: 'full-security-flow.nija',
        currentRecoveryPhrase: basePhrase,
        newRecoveryPhrase: rotatedRecovery,
      );

      expect(
        () => service.unlockVault(
          filePath: 'full-security-flow.nija',
          password: 'FirstPass123',
        ),
        throwsA(anything),
      );
      expect(
        () => service.unlockVaultWithRecoveryPhrase(
          filePath: 'full-security-flow.nija',
          recoveryPhrase: basePhrase,
        ),
        throwsA(anything),
      );

      final unlockedByMaster = await service.unlockVault(
        filePath: 'full-security-flow.nija',
        password: 'ThirdPass789',
      );
      final unlockedByRecovery = await service.unlockVaultWithRecoveryPhrase(
        filePath: 'full-security-flow.nija',
        recoveryPhrase: rotatedRecovery,
      );
      expect(unlockedByMaster.id, unlockedByRecovery.id);
    },
  );

  test(
    'working store writes encrypted binary sections without plaintext labels',
    () async {
      final privateStore = InMemoryPrivateVaultStore();
      final service = DefaultVaultService(
        storageAdapter: InMemoryVaultStorageAdapter(),
        cryptoAdapter: SecureCryptoAdapter(),
        privateVaultStore: privateStore,
      );

      await service.createVault(
        filePath: 'private-sections.nija',
        vaultId: 'private-sections-id',
        vaultName: 'Sensitive Family Vault',
        guardianProfileId: GuardianProfiles.owl.id,
        password: 'CorrectPass123',
        recoveryPhrase: basePhrase,
      );

      await service.persistVaultPayload(
        filePath: 'private-sections.nija',
        password: 'CorrectPass123',
        payload: const VaultPayload(
          schemaVersion: 1,
          items: [
            {'id': 'item-1', 'title': 'Bank Account'},
          ],
          notes: [
            {'id': 'note-1', 'title': 'Secret Note'},
          ],
          tags: ['private-tag'],
          settings: {},
          audit: [],
        ),
      );

      final header = await privateStore.readHeader('private-sections-id');
      expect(header.vaultName, isNull);
      expect(header.revision, 2);

      final itemsBytes = await privateStore.readSection(
        'private-sections-id',
        'items.enc',
      );
      final rawItems = utf8.decode(itemsBytes, allowMalformed: true);
      expect(rawItems, isNot(contains('Bank Account')));
    },
  );

  test(
    'same revision with different vaultVersionId creates conflict copy',
    () async {
      final storage = InMemoryVaultStorageAdapter();
      final service = DefaultVaultService(
        storageAdapter: storage,
        cryptoAdapter: SecureCryptoAdapter(),
      );

      await service.createVault(
        filePath: 'conflict.nija',
        vaultId: 'conflict-id',
        vaultName: 'Conflict vault',
        guardianProfileId: GuardianProfiles.owl.id,
        password: 'CorrectPass123',
        recoveryPhrase: basePhrase,
      );

      final raw = await storage.read(filePath: 'conflict.nija');
      final jsonMap = Map<String, dynamic>.from(jsonDecode(raw) as Map)
        ..['vaultVersionId'] = '00000000-0000-4000-8000-000000000000';
      await storage.write(
        filePath: 'incoming-conflict.nija',
        content: jsonEncode(jsonMap),
      );

      final result = await service.importNijaFile(
        filePath: 'incoming-conflict.nija',
        unlockCredential: 'CorrectPass123',
      );

      expect(result.status, ImportStatus.conflictCreated);
      expect(result.conflictVaultId, isNotEmpty);
    },
  );

  test(
    'incoming newer revision requires confirmation before replace',
    () async {
      final storage = InMemoryVaultStorageAdapter();
      final service = DefaultVaultService(
        storageAdapter: storage,
        cryptoAdapter: SecureCryptoAdapter(),
      );

      await service.createVault(
        filePath: 'replace.nija',
        vaultId: 'replace-id',
        vaultName: 'Replace vault',
        guardianProfileId: GuardianProfiles.owl.id,
        password: 'CorrectPass123',
        recoveryPhrase: basePhrase,
      );

      final raw = await storage.read(filePath: 'replace.nija');
      final jsonMap = Map<String, dynamic>.from(jsonDecode(raw) as Map)
        ..['revision'] = 2
        ..['vaultVersionId'] = '00000000-0000-4000-8000-000000000001';
      await storage.write(
        filePath: 'incoming-newer.nija',
        content: jsonEncode(jsonMap),
      );

      final unconfirmed = await service.importNijaFile(
        filePath: 'incoming-newer.nija',
        unlockCredential: 'CorrectPass123',
      );
      expect(unconfirmed.status, ImportStatus.failed);

      final confirmed = await service.importNijaFile(
        filePath: 'incoming-newer.nija',
        unlockCredential: 'CorrectPass123',
        confirmReplace: true,
      );
      expect(confirmed.status, ImportStatus.imported);
      expect(confirmed.incomingRevision, 2);
    },
  );

  test(
    'incoming older revision creates merge candidate instead of overwrite',
    () async {
      final storage = InMemoryVaultStorageAdapter();
      final service = DefaultVaultService(
        storageAdapter: storage,
        cryptoAdapter: SecureCryptoAdapter(),
      );

      await service.createVault(
        filePath: 'older-merge.nija',
        vaultId: 'older-merge-id',
        vaultName: 'Older merge vault',
        guardianProfileId: GuardianProfiles.owl.id,
        password: 'CorrectPass123',
        recoveryPhrase: basePhrase,
      );
      final exportedBeforeEdit = await storage.read(
        filePath: 'older-merge.nija',
      );

      await service.persistVaultPayload(
        filePath: 'older-merge.nija',
        password: 'CorrectPass123',
        payload: const VaultPayload(
          schemaVersion: 1,
          items: [
            {'id': 'new-item', 'title': 'New item', 'type': 'Login'},
          ],
          notes: [],
          tags: [],
          settings: {},
          audit: [],
        ),
      );
      await storage.write(
        filePath: 'older-import.nija',
        content: exportedBeforeEdit,
      );

      final result = await service.importNijaFile(
        filePath: 'older-import.nija',
        unlockCredential: 'CorrectPass123',
      );

      expect(result.status, ImportStatus.conflictCreated);
      expect(result.conflictVaultId, isNotEmpty);

      final activePayload = await service.readVaultPayload(
        filePath: 'older-merge.nija',
        password: 'CorrectPass123',
      );
      expect(
        activePayload.items.map((entry) => entry['id']),
        contains('new-item'),
      );
    },
  );

  test(
    'new mutations clear previously resolved incoming version markers',
    () async {
      final privateStore = InMemoryPrivateVaultStore();
      final service = DefaultVaultService(
        storageAdapter: InMemoryVaultStorageAdapter(),
        cryptoAdapter: SecureCryptoAdapter(),
        privateVaultStore: privateStore,
      );

      await service.createVault(
        filePath: 'resolved-marker.nija',
        vaultId: 'resolved-marker-id',
        vaultName: 'Resolved marker vault',
        guardianProfileId: GuardianProfiles.owl.id,
        password: 'CorrectPass123',
        recoveryPhrase: basePhrase,
      );

      await service.markVaultConflictResolved(
        filePath: 'resolved-marker.nija',
        resolvedVaultVersionId: 'incoming-version-1',
      );
      var header = await privateStore.readHeader('resolved-marker-id');
      expect(header.resolvedFromVersionIds, contains('incoming-version-1'));
      final resolvedRevision = header.revision;

      await service.persistVaultPayload(
        filePath: 'resolved-marker.nija',
        password: 'CorrectPass123',
        payload: const VaultPayload(
          schemaVersion: 1,
          items: [],
          notes: [
            {'id': 'note-after-resolve', 'title': 'After resolve'},
          ],
          tags: [],
          settings: {},
          audit: [],
        ),
      );

      header = await privateStore.readHeader('resolved-marker-id');
      expect(header.resolvedFromVersionIds, isEmpty);
      expect(header.revision, resolvedRevision + 1);
    },
  );
}

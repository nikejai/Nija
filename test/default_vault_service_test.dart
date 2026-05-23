import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:nija/application/services/default_vault_service.dart';
import 'package:nija/core/config/guardian_profiles.dart';
import 'package:nija/infrastructure/adapters/in_memory_vault_storage_adapter.dart';
import 'package:nija/infrastructure/adapters/secure_crypto_adapter.dart';

void main() {
  const basePhrase = 'anchor apple arrow atlas beacon breeze canyon cedar cobalt ember harbor willow';

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
      () => service.unlockVault(filePath: 'sample-reset.nija', password: 'OldPass123'),
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
    const phraseB = 'amber arcade aspen basket blade bloom canyon comet coral drift ember galaxy';

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
      () => service.unlockVault(filePath: 'sample-rotation.nija', password: 'MasterOne123'),
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
      () => service.unlockVaultWithRecoveryPhrase(filePath: 'sample-rotation.nija', recoveryPhrase: phraseA),
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
    await storage.write(filePath: 'legacy-file.nija', content: jsonEncode(jsonMap));

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
      () => service.unlockVault(filePath: 'wrong-master.nija', password: 'WrongPass123'),
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
        recoveryPhrase: 'anchor apple arrow atlas beacon breeze canyon cedar cobalt ember harbor galaxy',
      ),
      throwsA(anything),
    );
  });

  test('tampered metadata with unsupported format version is rejected', () async {
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
    await storage.write(filePath: 'tampered-version.nija', content: jsonEncode(jsonMap));

    expect(
      () => service.unlockVault(filePath: 'tampered-version.nija', password: 'CorrectPass123'),
      throwsA(isA<UnsupportedError>()),
    );
  });

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
    final jsonMap = Map<String, dynamic>.from(jsonDecode(raw) as Map)
      ..['encryptedPayload'] = 'AQID';
    await storage.write(filePath: 'corrupted-payload.nija', content: jsonEncode(jsonMap));

    expect(
      () => service.unlockVault(filePath: 'corrupted-payload.nija', password: 'CorrectPass123'),
      throwsA(anything),
    );
  });

  test('recovery, reset, and rotation workflow remains consistent end-to-end', () async {
    final service = DefaultVaultService(
      storageAdapter: InMemoryVaultStorageAdapter(),
      cryptoAdapter: SecureCryptoAdapter(),
    );

    const rotatedRecovery = 'amber arcade aspen basket blade bloom canyon comet coral drift ember galaxy';

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
      () => service.unlockVault(filePath: 'full-security-flow.nija', password: 'FirstPass123'),
      throwsA(anything),
    );
    expect(
      () => service.unlockVaultWithRecoveryPhrase(filePath: 'full-security-flow.nija', recoveryPhrase: basePhrase),
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
  });
}

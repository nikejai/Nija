import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:nija/domain/models/vault_file.dart';

void main() {
  test('vault file serializes and deserializes', () {
    const file = VaultFile(
      format: 'Nija',
      formatVersion: 1,
      vaultId: 'vault_1',
      vaultName: 'Personal Vault',
      createdAt: '2026-05-06T00:00:00Z',
      updatedAt: '2026-05-06T00:00:00Z',
      guardian: GuardianMetadata(id: 'owl', profile: 'owl_v1'),
      kdf: KdfMetadata(
        name: 'argon2id',
        version: 19,
        memoryKb: 65536,
        iterations: 4,
        parallelism: 2,
        salt: 'salt',
      ),
      recoveryKdf: KdfMetadata(
        name: 'argon2id',
        version: 19,
        memoryKb: 65536,
        iterations: 4,
        parallelism: 2,
        salt: 'recovery_salt',
      ),
      cipher: CipherMetadata(name: 'xchacha20-poly1305', nonce: 'nonce'),
      encryptedVaultKey: 'key',
      encryptedVaultKeyByRecovery: 'key_recovery',
      encryptedPayload: 'payload',
    );

    final jsonMap = file.toJson();
    final decoded = VaultFile.fromJson(Map<String, dynamic>.from(json.decode(json.encode(jsonMap)) as Map));

    expect(decoded.vaultId, 'vault_1');
    expect(decoded.vaultName, 'Personal Vault');
    expect(decoded.kdf.name, 'argon2id');
    expect(decoded.cipher.name, 'xchacha20-poly1305');
  });
}

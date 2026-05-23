import 'package:flutter_test/flutter_test.dart';
import 'package:nija/application/services/vault_migrator.dart';

void main() {
  test('migrates legacy vault file json from v0 to current', () {
    final migrated = VaultMigrator.migrateVaultFileJson({
      'format': 'Nija',
      'vaultId': 'vault_legacy',
      'createdAt': '2026-01-01T00:00:00Z',
      'updatedAt': '2026-01-01T00:00:00Z',
      'guardian': {'id': 'owl', 'profile': 'owl_v1'},
      'kdf': {
        'name': 'argon2id',
        'version': 19,
        'memoryKb': 65536,
        'iterations': 4,
        'parallelism': 2,
        'salt': 'salt',
      },
      'cipher': {'name': 'xchacha20-poly1305', 'nonce': 'nonce'},
      'encryptedVaultKey': 'key',
      'encryptedPayload': 'payload',
    });

    expect(migrated['formatVersion'], VaultMigrator.currentVaultFormatVersion);
    expect(migrated['recoveryKdf'], isNotNull);
    expect(migrated['encryptedVaultKeyByRecovery'], 'key');
  });

  test('rejects unsupported future vault file version', () {
    expect(
      () => VaultMigrator.migrateVaultFileJson({
        'formatVersion': VaultMigrator.currentVaultFormatVersion + 1,
      }),
      throwsA(isA<UnsupportedError>()),
    );
  });

  test('migrates legacy payload schema from v0 to current', () {
    final migrated = VaultMigrator.migratePayloadJson({
      'items': [
        {'id': '1'}
      ],
    });

    expect(migrated['schemaVersion'], VaultMigrator.currentPayloadSchemaVersion);
    expect(migrated['notes'], isA<List<dynamic>>());
    expect(migrated['settings'], isA<Map<String, dynamic>>());
  });

  test('rejects unsupported future payload schema version', () {
    expect(
      () => VaultMigrator.migratePayloadJson({
        'schemaVersion': VaultMigrator.currentPayloadSchemaVersion + 1,
      }),
      throwsA(isA<UnsupportedError>()),
    );
  });
}


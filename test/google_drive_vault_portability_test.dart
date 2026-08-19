import 'package:flutter_test/flutter_test.dart';
import 'package:nija/core/config/google_oauth_config.dart';
import 'package:nija/infrastructure/adapters/google_drive_vault_portability.dart';
import 'package:nija/infrastructure/adapters/vault_portability_model.dart';

void main() {
  test('web client id is configured for Google Sign-In', () {
    expect(GoogleOAuthConfig.webClientId, isNotEmpty);
    expect(GoogleOAuthConfig.webClientId, endsWith('.apps.googleusercontent.com'));
  });

  test('looksLikeNijaVaultContent accepts encrypted Nija vault snapshots', () {
    const content = '''
{
  "format": "Nija",
  "vaultId": "vault-123",
  "encryptedVaultKey": "abc"
}
''';
    expect(looksLikeNijaVaultContent(content), isTrue);
  });

  test('looksLikeNijaVaultContent rejects unrelated json', () {
    expect(looksLikeNijaVaultContent('{"hello":"world"}'), isFalse);
  });

  test('looksLikeVaultBackupName accepts backup file naming patterns', () {
    expect(looksLikeVaultBackupName('backup_20260813_family.nija'), isTrue);
    expect(looksLikeVaultBackupName('notes.txt'), isFalse);
  });

  test('cloudBackupLabelFromContent prefers vaultName metadata', () {
    const content = '''
{
  "format": "Nija",
  "vaultId": "vault-123",
  "vaultName": "Family Vault",
  "encryptedVaultKey": "abc"
}
''';
    expect(
      cloudBackupLabelFromContent(
        fallbackName: 'backup_20260813.nija',
        content: content,
      ),
      'Family Vault',
    );
  });

  test('cloudBackupDisplayTitle falls back to short vault id', () {
    const content = '''
{
  "format": "Nija",
  "vaultId": "86a6b061-3acb-423a-9521-4556bfd5fdab",
  "encryptedVaultKey": "abc"
}
''';
    final backup = CloudVaultBackupFile(
      storageId: 'gdrive_test.nija',
      label: 'backup_20260809_1501_86a6b061-3acb-423a-9521-4556bfd5fdab.nija',
      content: content,
      fileName: 'backup_20260809_1501_86a6b061-3acb-423a-9521-4556bfd5fdab.nija',
      modifiedAt: DateTime(2026, 8, 9, 9, 31),
    );
    expect(cloudBackupDisplayTitle(backup), 'Vault 86a6b061');
    expect(
      cloudBackupLastUpdatedSubtitle(backup),
      'Last updated 2026-08-09 09:31',
    );
  });

  test('cloudBackupDisplayTitle uses listedVaultId for metadata-only listings', () {
    final backup = CloudVaultBackupFile(
      storageId: 'gdrive_test.nija',
      label: 'backup_20260809_1501_86a6b061.nija',
      content: '',
      fileName: 'backup_20260809_1501_86a6b061.nija',
      listedVaultId: '86a6b061-3acb-423a-9521-4556bfd5fdab',
    );
    expect(cloudBackupDisplayTitle(backup), 'Vault 86a6b061');
    expect(backup.hasContent, isFalse);
  });

  test('cloudBackupEffectiveUpdatedAt prefers Drive modified time', () {
    const content = '''
{
  "format": "Nija",
  "vaultId": "vault-123",
  "updatedAt": "2026-01-01T00:00:00Z",
  "encryptedVaultKey": "abc"
}
''';
    final driveTime = DateTime(2026, 8, 9, 15, 1);
    final backup = CloudVaultBackupFile(
      storageId: 'gdrive_test.nija',
      label: 'backup.nija',
      content: content,
      modifiedAt: driveTime,
      updatedAt: vaultUpdatedAtFromNijaVaultContent(content),
    );
    expect(cloudBackupEffectiveUpdatedAt(backup), driveTime);
  });

  test('cloudBackupEffectiveUpdatedAt falls back to filename timestamp', () {
    const content = '''
{
  "format": "Nija",
  "vaultId": "vault-123",
  "encryptedVaultKey": "abc"
}
''';
    final backup = CloudVaultBackupFile(
      storageId: 'gdrive_test.nija',
      label: 'backup_20260809_1501_vault.nija',
      content: content,
      fileName: 'backup_20260809_1501_vault.nija',
    );
    expect(
      cloudBackupEffectiveUpdatedAt(backup),
      DateTime(2026, 8, 9, 15, 1),
    );
  });

  test('backupTimestampFromFileName parses backup filename timestamps', () {
    final parsed = backupTimestampFromFileName(
      'backup_20260809_1501_86a6b061.nija',
    );
    expect(parsed, DateTime(2026, 8, 9, 15, 1));
  });
}

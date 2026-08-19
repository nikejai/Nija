import 'vault_portability_model.dart';

abstract class VaultPortabilityAdapter {
  Future<ImportedVaultFile?> importVaultFromLocal();
  Future<String?> exportVaultToLocal({
    required String suggestedName,
    required String content,
  });
  Future<bool> backupVaultToCloud({
    required String vaultId,
    required String suggestedName,
    required String content,
    bool forceAccountChooser = false,
  });
  Future<List<CloudVaultBackupFile>> listCloudBackups({
    bool forceAccountChooser = false,
  });
  Future<CloudVaultBackupFile> hydrateCloudBackupContent(
    CloudVaultBackupFile listing, {
    bool forceAccountChooser = false,
  });
  Future<CloudVaultBackupFile?> readCloudBackup({
    required String vaultId,
    bool forceAccountChooser = false,
  });
  Future<String?> getCloudBackupAccountLabel();
  Future<bool> changeCloudBackupAccount();
  Future<bool> ensureCloudBackupAccountSelected({
    bool forceAccountChooser = false,
  });
}

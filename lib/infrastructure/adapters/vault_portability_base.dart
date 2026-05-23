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
  });
  Future<String?> getCloudBackupAccountLabel();
  Future<bool> changeCloudBackupAccount();
}

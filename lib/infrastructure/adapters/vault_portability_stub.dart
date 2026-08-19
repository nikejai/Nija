import 'vault_portability_base.dart';
import 'vault_portability_model.dart';

class VaultPortabilityAdapterImpl implements VaultPortabilityAdapter {
  @override
  Future<ImportedVaultFile?> importVaultFromLocal() {
    throw UnsupportedError('Vault import is not supported on this platform.');
  }

  @override
  Future<String?> exportVaultToLocal({
    required String suggestedName,
    required String content,
  }) {
    throw UnsupportedError('Vault export is not supported on this platform.');
  }

  @override
  Future<bool> backupVaultToCloud({
    required String vaultId,
    required String suggestedName,
    required String content,
    bool forceAccountChooser = true,
  }) {
    throw UnsupportedError(
      'Cloud vault backup is not supported on this platform.',
    );
  }

  @override
  Future<List<CloudVaultBackupFile>> listCloudBackups({
    bool forceAccountChooser = true,
  }) async {
    return const <CloudVaultBackupFile>[];
  }

  @override
  Future<CloudVaultBackupFile> hydrateCloudBackupContent(
    CloudVaultBackupFile listing, {
    bool forceAccountChooser = false,
  }) async {
    if (listing.hasContent) return listing;
    throw UnsupportedError(
      'Cloud vault restore is not supported on this platform.',
    );
  }

  @override
  Future<CloudVaultBackupFile?> readCloudBackup({
    required String vaultId,
    bool forceAccountChooser = true,
  }) {
    throw UnsupportedError(
      'Cloud vault restore is not supported on this platform.',
    );
  }

  @override
  Future<String?> getCloudBackupAccountLabel() async => null;

  @override
  Future<bool> changeCloudBackupAccount() async => false;

  @override
  Future<bool> ensureCloudBackupAccountSelected({
    bool forceAccountChooser = false,
  }) async {
    return true;
  }
}

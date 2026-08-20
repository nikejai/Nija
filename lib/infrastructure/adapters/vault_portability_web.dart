import 'dart:convert';

import '../../../core/platform/nija_browser_bridge.dart';
import 'google_drive_vault_portability.dart';
import 'vault_portability_base.dart';
import 'vault_portability_model.dart';

class VaultPortabilityAdapterImpl implements VaultPortabilityAdapter {
  const VaultPortabilityAdapterImpl();

  static const _googleDrive = GoogleDriveVaultPortability();

  @override
  Future<ImportedVaultFile?> importVaultFromLocal() async {
    final file = await nijaPickTextFile('.nija,.json,.txt');
    if (file == null) return null;
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return ImportedVaultFile(
      storageId: 'web_imported_${timestamp}_${file.name}',
      label: _importLabel(file.name, file.content),
      content: file.content,
      sourceDescription: file.name,
    );
  }

  String _importLabel(String fileName, String content) {
    try {
      final decoded = jsonDecode(content);
      if (decoded is Map) {
        final vaultName = decoded['vaultName']?.toString().trim() ?? '';
        if (vaultName.isNotEmpty) return vaultName;
      }
    } catch (_) {
      // Fall back to the selected file name.
    }
    final withoutExtension = fileName.toLowerCase().endsWith('.nija')
        ? fileName.substring(0, fileName.length - 5)
        : fileName;
    final humanized = withoutExtension
        .replaceAll(RegExp(r'[_-]+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    return humanized.isEmpty ? fileName : humanized;
  }

  @override
  Future<String?> exportVaultToLocal({
    required String suggestedName,
    required String content,
  }) async {
    try {
      final downloaded = nijaDownloadTextFile(
        fileName: suggestedName,
        content: content,
        mimeType: 'application/json',
      );
      return downloaded ? '__web_download__' : null;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<bool> backupVaultToCloud({
    required String vaultId,
    required String suggestedName,
    required String content,
    bool forceAccountChooser = true,
  }) {
    return _googleDrive.backupVaultToCloud(
      vaultId: vaultId,
      suggestedName: suggestedName,
      content: content,
      forceAccountChooser: forceAccountChooser,
    );
  }

  @override
  Future<List<CloudVaultBackupFile>> listCloudBackups({
    bool forceAccountChooser = false,
  }) {
    return _googleDrive.listCloudBackups(
      forceAccountChooser: forceAccountChooser,
    );
  }

  @override
  Future<CloudVaultBackupFile> hydrateCloudBackupContent(
    CloudVaultBackupFile listing, {
    bool forceAccountChooser = false,
  }) {
    return _googleDrive.hydrateCloudBackupContent(
      listing,
      forceAccountChooser: forceAccountChooser,
    );
  }

  @override
  Future<CloudVaultBackupFile?> readCloudBackup({
    required String vaultId,
    bool forceAccountChooser = true,
  }) {
    return _googleDrive.readCloudBackup(
      vaultId: vaultId,
      forceAccountChooser: forceAccountChooser,
    );
  }

  @override
  Future<String?> getCloudBackupAccountLabel() {
    return _googleDrive.getCloudBackupAccountLabel();
  }

  @override
  Future<bool> changeCloudBackupAccount() {
    return _googleDrive.changeCloudBackupAccount();
  }

  @override
  Future<bool> ensureCloudBackupAccountSelected({
    bool forceAccountChooser = false,
  }) {
    return _googleDrive.ensureCloudBackupAccountSelected(
      forceAccountChooser: forceAccountChooser,
    );
  }
}

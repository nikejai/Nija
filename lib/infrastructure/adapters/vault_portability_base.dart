import 'dart:async';

import 'vault_portability_model.dart';

abstract class VaultPortabilityAdapter {
  Future<ImportedVaultFile?> importVaultFromLocal();
  Future<String?> exportVaultToLocal({
    required String suggestedName,
    required String content,
    Future<bool> Function(String destinationPath)? streamWriter,
  });
  Future<bool> backupVaultToCloud({
    required String vaultId,
    required String suggestedName,
    required String content,
    bool forceAccountChooser = false,
    void Function(int bytesSent, int totalBytes)? onProgress,
  });
  Future<bool> backupVaultStreamToCloud({
    required String vaultId,
    required String suggestedName,
    required Stream<List<int>> stream,
    required int lengthBytes,
    String mimeType = 'application/octet-stream',
    Map<String, String>? extraProperties,
    bool forceAccountChooser = false,
    void Function(int bytesSent, int totalBytes)? onProgress,
  });
  Future<List<CloudVaultBackupFile>> listCloudBackups({
    bool forceAccountChooser = false,
  });
  Future<CloudVaultBackupFile> hydrateCloudBackupContent(
    CloudVaultBackupFile listing, {
    bool forceAccountChooser = false,
  });
  Future<bool> downloadCloudBackupToSink(
    String driveFileId,
    EventSink<List<int>> sink, {
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

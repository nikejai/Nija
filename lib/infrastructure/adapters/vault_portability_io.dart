import 'dart:io';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'google_drive_vault_portability.dart';
import 'vault_portability_base.dart';
import 'vault_portability_model.dart';

class VaultPortabilityAdapterImpl implements VaultPortabilityAdapter {
  static const _googleDrive = GoogleDriveVaultPortability();

  @override
  Future<ImportedVaultFile?> importVaultFromLocal() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const <String>['nija', 'json', 'txt'],
        withData: false,
      );
      final file = result?.files.isNotEmpty == true
          ? result!.files.first
          : null;
      final path = file?.path;
      if (path == null || path.isEmpty) return null;
      final content = await File(path).readAsString();
      return ImportedVaultFile(
        storageId: path,
        label: _importLabel(file!.name, content),
        content: content,
      );
    } on PlatformException catch (error) {
      if (_isPickerCancellation(error)) return null;
      rethrow;
    }
  }

  bool _isPickerCancellation(PlatformException error) {
    final text = '${error.code} ${error.message ?? ''}'.toLowerCase();
    return text.contains('cancel') || text.contains('abort');
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
    final bytes = Uint8List.fromList(utf8.encode(content));
    if (Platform.isAndroid || Platform.isIOS) {
      return FilePicker.platform.saveFile(
        dialogTitle: 'Export vault file',
        fileName: suggestedName,
        type: FileType.custom,
        allowedExtensions: const <String>['nija'],
        bytes: bytes,
      );
    }

    final outputPath = await FilePicker.platform.saveFile(
      dialogTitle: 'Export vault file',
      fileName: suggestedName,
      type: FileType.custom,
      allowedExtensions: const <String>['nija'],
    );
    if (outputPath == null || outputPath.isEmpty) return null;
    await File(outputPath).writeAsString(content, flush: true);
    return outputPath;
  }

  String _joinPath(String directory, String fileName) {
    final separator = Platform.pathSeparator;
    if (directory.endsWith(separator)) {
      return '$directory$fileName';
    }
    return '$directory$separator$fileName';
  }

  @override
  Future<bool> backupVaultToCloud({
    required String vaultId,
    required String suggestedName,
    required String content,
    bool forceAccountChooser = true,
  }) {
    if (Platform.isAndroid || Platform.isIOS) {
      return _googleDrive.backupVaultToCloud(
        vaultId: vaultId,
        suggestedName: suggestedName,
        content: content,
        forceAccountChooser: forceAccountChooser,
      );
    }
    return Future<bool>.value(false);
  }

  @override
  Future<CloudVaultBackupFile?> readCloudBackup({
    required String vaultId,
    bool forceAccountChooser = true,
  }) {
    if (Platform.isAndroid || Platform.isIOS) {
      return _googleDrive.readCloudBackup(
        vaultId: vaultId,
        forceAccountChooser: forceAccountChooser,
      );
    }
    return Future<CloudVaultBackupFile?>.value(null);
  }

  @override
  Future<List<CloudVaultBackupFile>> listCloudBackups({
    bool forceAccountChooser = true,
  }) {
    if (Platform.isAndroid || Platform.isIOS) {
      return _googleDrive.listCloudBackups(
        forceAccountChooser: forceAccountChooser,
      );
    }
    return Future<List<CloudVaultBackupFile>>.value(const []);
  }

  @override
  Future<CloudVaultBackupFile> hydrateCloudBackupContent(
    CloudVaultBackupFile listing, {
    bool forceAccountChooser = false,
  }) {
    if (Platform.isAndroid || Platform.isIOS) {
      return _googleDrive.hydrateCloudBackupContent(
        listing,
        forceAccountChooser: forceAccountChooser,
      );
    }
    return Future<CloudVaultBackupFile>.error(
      UnsupportedError('Cloud vault restore is not supported on this platform.'),
    );
  }

  @override
  Future<String?> getCloudBackupAccountLabel() {
    if (Platform.isAndroid || Platform.isIOS) {
      return _googleDrive.getCloudBackupAccountLabel();
    }
    return Future<String?>.value(null);
  }

  @override
  Future<bool> changeCloudBackupAccount() {
    if (Platform.isAndroid || Platform.isIOS) {
      return _googleDrive.changeCloudBackupAccount();
    }
    return Future<bool>.value(false);
  }

  @override
  Future<bool> ensureCloudBackupAccountSelected({
    bool forceAccountChooser = false,
  }) {
    if (Platform.isAndroid || Platform.isIOS) {
      return _googleDrive.ensureCloudBackupAccountSelected(
        forceAccountChooser: forceAccountChooser,
      );
    }
    return Future<bool>.value(false);
  }

  Future<bool> shareBackupFallback({
    required String suggestedName,
    required String content,
  }) async {
    final tempDir = await getTemporaryDirectory();
    final filePath = _joinPath(tempDir.path, suggestedName);
    final file = File(filePath);
    await file.writeAsString(content, flush: true);
    try {
      final result = await SharePlus.instance.share(
        ShareParams(
          files: <XFile>[XFile(file.path, mimeType: 'application/json')],
        ),
      );
      return result.status == ShareResultStatus.success;
    } finally {
      try {
        if (await file.exists()) {
          await file.delete();
        }
      } catch (_) {
        // Temp file cleanup is best-effort.
      }
    }
  }
}

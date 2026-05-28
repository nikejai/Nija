// ignore_for_file: deprecated_member_use, avoid_web_libraries_in_flutter

import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;

import 'vault_portability_base.dart';
import 'vault_portability_model.dart';

class VaultPortabilityAdapterImpl implements VaultPortabilityAdapter {
  @override
  Future<ImportedVaultFile?> importVaultFromLocal() async {
    final input = html.FileUploadInputElement()..accept = '.nija,.json,.txt';
    final completer = Completer<ImportedVaultFile?>();

    input.onChange.first.then((_) {
      final file = input.files?.isNotEmpty == true ? input.files!.first : null;
      if (file == null) {
        completer.complete(null);
        return;
      }
      final reader = html.FileReader();
      reader.readAsText(file);
      reader.onLoad.first.then((_) {
        final content = reader.result?.toString();
        if (content == null || content.isEmpty) {
          completer.complete(null);
          return;
        }
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        completer.complete(
          ImportedVaultFile(
            storageId: 'web_imported_${timestamp}_${file.name}',
            label: _importLabel(file.name, content),
            content: content,
          ),
        );
      });
      reader.onError.first.then((_) => completer.complete(null));
    });

    input.click();
    return completer.future;
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
      final bytes = utf8.encode(content);
      final blob = html.Blob(<dynamic>[bytes], 'application/json');
      final url = html.Url.createObjectUrlFromBlob(blob);
      final anchor = html.AnchorElement(href: url)
        ..download = suggestedName
        ..style.display = 'none';
      html.document.body?.append(anchor);
      anchor.click();
      anchor.remove();
      html.Url.revokeObjectUrl(url);
      return '__web_download__';
    } catch (_) {
      return null;
    }
  }

  @override
  Future<bool> backupVaultToCloud({
    required String vaultId,
    required String suggestedName,
    required String content,
  }) async {
    final result = await exportVaultToLocal(
      suggestedName: suggestedName,
      content: content,
    );
    return result != null && result.isNotEmpty;
  }

  @override
  Future<List<CloudVaultBackupFile>> listCloudBackups() async {
    return const <CloudVaultBackupFile>[];
  }

  @override
  Future<CloudVaultBackupFile?> readCloudBackup({
    required String vaultId,
  }) async {
    return null;
  }

  @override
  Future<String?> getCloudBackupAccountLabel() async => 'Browser download';

  @override
  Future<bool> changeCloudBackupAccount() async => false;
}

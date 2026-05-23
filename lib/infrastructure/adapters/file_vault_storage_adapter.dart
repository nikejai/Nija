import 'dart:io';

import 'vault_storage_adapter.dart';

class FileVaultStorageAdapter implements VaultStorageAdapter {
  const FileVaultStorageAdapter();

  @override
  Future<String> read({required String filePath}) async {
    final file = File(filePath);
    if (!await file.exists()) {
      throw StateError('Vault file not found at path: $filePath');
    }
    return file.readAsString();
  }

  @override
  Future<void> write({required String filePath, required String content}) async {
    final file = File(filePath);
    await file.parent.create(recursive: true);
    await file.writeAsString(content, flush: true);
  }
}

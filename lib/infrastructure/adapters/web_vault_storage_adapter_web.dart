// ignore_for_file: deprecated_member_use, avoid_web_libraries_in_flutter

import 'dart:html' as html;

import 'vault_storage_adapter.dart';

class WebVaultStorageAdapter implements VaultStorageAdapter {
  const WebVaultStorageAdapter();

  static const _prefix = 'nija_vault::';

  String _key(String filePath) => '$_prefix$filePath';

  @override
  Future<String> read({required String filePath}) async {
    final value = html.window.localStorage[_key(filePath)];
    if (value == null) {
      throw StateError('Vault file not found at path: $filePath');
    }
    return value;
  }

  @override
  Future<void> write({required String filePath, required String content}) async {
    html.window.localStorage[_key(filePath)] = content;
  }
}

import 'vault_storage_adapter.dart';

class WebVaultStorageAdapter implements VaultStorageAdapter {
  const WebVaultStorageAdapter();

  @override
  Future<String> read({required String filePath}) async {
    throw UnsupportedError('WebVaultStorageAdapter is only available on web.');
  }

  @override
  Future<void> write({required String filePath, required String content}) async {
    throw UnsupportedError('WebVaultStorageAdapter is only available on web.');
  }
}


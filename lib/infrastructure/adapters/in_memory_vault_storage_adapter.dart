import 'vault_storage_adapter.dart';

class InMemoryVaultStorageAdapter implements VaultStorageAdapter {
  final Map<String, String> _store = <String, String>{};

  @override
  Future<String> read({required String filePath}) async {
    final value = _store[filePath];
    if (value == null) {
      throw StateError('Vault file not found at path: $filePath');
    }
    return value;
  }

  @override
  Future<void> write({required String filePath, required String content}) async {
    _store[filePath] = content;
  }
}

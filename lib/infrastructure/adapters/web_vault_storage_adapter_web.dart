import '../../../core/platform/nija_browser_bridge.dart';

import 'vault_storage_adapter.dart';

/// Persists encrypted vault snapshots in IndexedDB (large payloads) with a
/// one-time migration path from legacy `localStorage` entries.
class WebVaultStorageAdapter implements VaultStorageAdapter {
  const WebVaultStorageAdapter();

  static const _legacyPrefix = 'nija_vault::';
  static const _dbName = 'nija_vault';
  static const _storeName = 'files';
  static const _dbVersion = 1;

  String _legacyKey(String filePath) => '$_legacyPrefix$filePath';

  Future<String?> _readLegacyLocalStorage(String filePath) async {
    try {
      return nijaReadLocalText(_legacyKey(filePath));
    } catch (_) {
      return null;
    }
  }

  void _removeLegacyLocalStorage(String filePath) {
    try {
      nijaRemoveLocalText(_legacyKey(filePath));
    } catch (_) {
      // Ignore cleanup failures.
    }
  }

  @override
  Future<String> read({required String filePath}) async {
    final result = await nijaReadIndexedText(
      dbName: _dbName,
      storeName: _storeName,
      key: filePath,
      version: _dbVersion,
    );
    if (result != null && result.isNotEmpty) {
      return result;
    }

    final legacy = await _readLegacyLocalStorage(filePath);
    if (legacy != null) {
      await write(filePath: filePath, content: legacy);
      return legacy;
    }
    throw StateError('Vault file not found at path: $filePath');
  }

  @override
  Future<void> write({
    required String filePath,
    required String content,
  }) async {
    await nijaWriteIndexedText(
      dbName: _dbName,
      storeName: _storeName,
      key: filePath,
      value: content,
      version: _dbVersion,
    );
    _removeLegacyLocalStorage(filePath);
  }
}

// ignore_for_file: deprecated_member_use, avoid_web_libraries_in_flutter, uri_does_not_exist

import 'dart:html' as html;
import 'dart:indexed_db' as idb;

import 'vault_storage_adapter.dart';

/// Persists encrypted vault snapshots in IndexedDB (large payloads) with a
/// one-time migration path from legacy `localStorage` entries.
class WebVaultStorageAdapter implements VaultStorageAdapter {
  const WebVaultStorageAdapter();

  static const _legacyPrefix = 'nija_vault::';
  static const _dbName = 'nija_vault';
  static const _storeName = 'files';
  static const _dbVersion = 1;

  static idb.Database? _db;

  String _legacyKey(String filePath) => '$_legacyPrefix$filePath';

  Future<idb.Database> _openDatabase() async {
    if (_db != null) return _db!;
    _db = await html.window.indexedDB!.open(
      _dbName,
      version: _dbVersion,
      onUpgradeNeeded: (idb.VersionChangeEvent event) {
        final db = event.target.result as idb.Database;
        if (!db.objectStoreNames!.contains(_storeName)) {
          db.createObjectStore(_storeName);
        }
      },
    );
    return _db!;
  }

  Future<String?> _readLegacyLocalStorage(String filePath) async {
    try {
      return html.window.localStorage[_legacyKey(filePath)];
    } catch (_) {
      return null;
    }
  }

  void _removeLegacyLocalStorage(String filePath) {
    try {
      html.window.localStorage.remove(_legacyKey(filePath));
    } catch (_) {
      // Ignore cleanup failures.
    }
  }

  @override
  Future<String> read({required String filePath}) async {
    final db = await _openDatabase();
    final txn = db.transaction(_storeName, 'readonly');
    final result = await txn.objectStore(_storeName).getObject(filePath);
    await txn.completed;
    if (result is String && result.isNotEmpty) {
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
    final db = await _openDatabase();
    final txn = db.transaction(_storeName, 'readwrite');
    await txn.objectStore(_storeName).put(content, filePath);
    await txn.completed;
    _removeLegacyLocalStorage(filePath);
  }
}

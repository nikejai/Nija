abstract class VaultStorageAdapter {
  Future<void> write({required String filePath, required String content});
  Future<String> read({required String filePath});
}

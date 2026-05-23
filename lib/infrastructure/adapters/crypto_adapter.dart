abstract class CryptoAdapter {
  Future<List<int>> deriveKey({
    required String password,
    required List<int> salt,
    required int memoryKb,
    required int iterations,
    required int parallelism,
  });
  Future<List<int>> encrypt({required List<int> plain, required List<int> key});
  Future<List<int>> decrypt({required List<int> cipher, required List<int> key});
}

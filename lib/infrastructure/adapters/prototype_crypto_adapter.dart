import 'dart:convert';

import 'crypto_adapter.dart';

class PrototypeCryptoAdapter implements CryptoAdapter {
  @override
  Future<List<int>> decrypt({required List<int> cipher, required List<int> key}) async {
    return _xor(cipher, key);
  }

  @override
  Future<List<int>> deriveKey({
    required String password,
    required List<int> salt,
    required int memoryKb,
    required int iterations,
    required int parallelism,
  }) async {
    final seed = <int>[...utf8.encode(password), ...salt];
    final key = List<int>.filled(32, 0);
    for (var i = 0; i < seed.length; i++) {
      key[i % 32] = (key[i % 32] + seed[i] + i) & 0xFF;
    }
    return key;
  }

  @override
  Future<List<int>> encrypt({required List<int> plain, required List<int> key}) async {
    return _xor(plain, key);
  }

  List<int> _xor(List<int> input, List<int> key) {
    return List<int>.generate(input.length, (i) => input[i] ^ key[i % key.length]);
  }
}

import 'dart:math';

import 'package:cryptography/cryptography.dart';

import 'crypto_adapter.dart';

class SecureCryptoAdapter implements CryptoAdapter {
  SecureCryptoAdapter({
    AesGcm? aesGcm,
  }) : _aesGcm = aesGcm ?? AesGcm.with256bits();

  static const _nonceLength = 12;
  static const _macLength = 16;

  final AesGcm _aesGcm;
  final Random _random = Random.secure();

  @override
  Future<List<int>> deriveKey({
    required String password,
    required List<int> salt,
    required int memoryKb,
    required int iterations,
    required int parallelism,
  }) async {
    final algorithm = Argon2id(
      memory: memoryKb,
      iterations: iterations,
      parallelism: parallelism,
      hashLength: 32,
    );
    final secretKey = await algorithm.deriveKeyFromPassword(
      password: password,
      nonce: salt,
    );
    return secretKey.extractBytes();
  }

  @override
  Future<List<int>> encrypt({required List<int> plain, required List<int> key}) async {
    final nonce = _randomBytes(_nonceLength);
    final secretBox = await _aesGcm.encrypt(
      plain,
      secretKey: SecretKey(key),
      nonce: nonce,
    );
    final out = <int>[
      ...nonce,
      ...secretBox.cipherText,
      ...secretBox.mac.bytes,
    ];
    return out;
  }

  @override
  Future<List<int>> decrypt({required List<int> cipher, required List<int> key}) async {
    if (cipher.length < _nonceLength + _macLength) {
      throw StateError('Ciphertext is too short.');
    }
    final nonce = cipher.sublist(0, _nonceLength);
    final macStart = cipher.length - _macLength;
    final ciphertext = cipher.sublist(_nonceLength, macStart);
    final macBytes = cipher.sublist(macStart);

    final secretBox = SecretBox(
      ciphertext,
      nonce: nonce,
      mac: Mac(macBytes),
    );
    return _aesGcm.decrypt(
      secretBox,
      secretKey: SecretKey(key),
    );
  }

  List<int> _randomBytes(int length) {
    return List<int>.generate(length, (_) => _random.nextInt(256));
  }
}

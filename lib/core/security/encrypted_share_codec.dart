import 'dart:convert';
import 'dart:math';

import 'package:cryptography/cryptography.dart';

class EncryptedShareCodec {
  EncryptedShareCodec();

  static const int _schemaVersion = 1;
  static const int _saltBytes = 16;
  static const int _nonceBytes = 12;
  static const int _pbkdf2Iterations = 150000;

  final _random = Random.secure();
  final _aes = AesGcm.with256bits();
  final _pbkdf2 = Pbkdf2(
    macAlgorithm: Hmac.sha256(),
    iterations: _pbkdf2Iterations,
    bits: 256,
  );

  Future<String> encode({
    required String plainText,
    required String password,
    required String fileName,
    required String contentType,
  }) async {
    final salt = _randomBytes(_saltBytes);
    final nonce = _randomBytes(_nonceBytes);
    final key = await _deriveKey(password: password, salt: salt);
    final secretBox = await _aes.encrypt(
      utf8.encode(plainText),
      secretKey: key,
      nonce: nonce,
    );
    return jsonEncode({
      'schemaVersion': _schemaVersion,
      'contentType': contentType,
      'fileName': fileName,
      'kdf': {
        'name': 'PBKDF2-HMAC-SHA256',
        'iterations': _pbkdf2Iterations,
        'salt': base64Encode(salt),
      },
      'cipher': {
        'alg': 'AES-256-GCM',
        'nonce': base64Encode(secretBox.nonce),
        'cipherText': base64Encode(secretBox.cipherText),
        'mac': base64Encode(secretBox.mac.bytes),
      },
    });
  }

  Future<DecryptedSharePayload> decode({
    required String encoded,
    required String password,
  }) async {
    final rawRoot = jsonDecode(encoded);
    if (rawRoot is! Map) {
      throw const FormatException('Invalid encrypted share payload.');
    }
    final root = Map<String, dynamic>.from(rawRoot);
    final schemaVersion = root['schemaVersion'] as int? ?? 0;
    if (schemaVersion != _schemaVersion) {
      throw const FormatException('Unsupported encrypted share schema.');
    }
    final contentType = root['contentType']?.toString() ?? 'secret';
    final fileName = root['fileName']?.toString() ?? 'secret.nijas';
    final kdf = Map<String, dynamic>.from(
      root['kdf'] as Map? ?? const <String, dynamic>{},
    );
    final cipher = Map<String, dynamic>.from(
      root['cipher'] as Map? ?? const <String, dynamic>{},
    );
    final salt = base64Decode(kdf['salt']?.toString() ?? '');
    final nonce = base64Decode(cipher['nonce']?.toString() ?? '');
    final cipherText = base64Decode(cipher['cipherText']?.toString() ?? '');
    final macBytes = base64Decode(cipher['mac']?.toString() ?? '');
    final key = await _deriveKey(password: password, salt: salt);
    final plain = await _aes.decrypt(
      SecretBox(cipherText, nonce: nonce, mac: Mac(macBytes)),
      secretKey: key,
    );
    return DecryptedSharePayload(
      contentType: contentType,
      fileName: fileName,
      plainText: utf8.decode(plain),
    );
  }

  Future<SecretKey> _deriveKey({
    required String password,
    required List<int> salt,
  }) async {
    return _pbkdf2.deriveKey(
      secretKey: SecretKey(utf8.encode(password)),
      nonce: salt,
    );
  }

  List<int> _randomBytes(int length) {
    return List<int>.generate(length, (_) => _random.nextInt(256));
  }
}

class DecryptedSharePayload {
  const DecryptedSharePayload({
    required this.contentType,
    required this.fileName,
    required this.plainText,
  });

  final String contentType;
  final String fileName;
  final String plainText;
}

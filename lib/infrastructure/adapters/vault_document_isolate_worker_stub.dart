import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

Future<List<int>> decryptCipherWorker({
  required List<int> cipher,
  required List<int> key,
}) async {
  const nonceLength = 12;
  const macLength = 16;
  if (cipher.length < nonceLength + macLength) {
    throw StateError('Ciphertext is too short.');
  }
  final algorithm = AesGcm.with256bits();
  final nonce = cipher.sublist(0, nonceLength);
  final macStart = cipher.length - macLength;
  final ciphertext = cipher.sublist(nonceLength, macStart);
  final macBytes = cipher.sublist(macStart);
  final secretBox = SecretBox(ciphertext, nonce: nonce, mac: Mac(macBytes));
  return algorithm.decrypt(secretBox, secretKey: SecretKey(key));
}

Future<List<int>> encryptCipherWorker({
  required List<int> plain,
  required List<int> key,
  required List<int> nonce,
}) async {
  final algorithm = AesGcm.with256bits();
  final secretBox = await algorithm.encrypt(
    plain,
    secretKey: SecretKey(key),
    nonce: nonce,
  );
  final out = Uint8List(
    nonce.length + secretBox.cipherText.length + secretBox.mac.bytes.length,
  );
  out.setRange(0, nonce.length, nonce);
  out.setRange(
    nonce.length,
    nonce.length + secretBox.cipherText.length,
    secretBox.cipherText,
  );
  out.setRange(
    nonce.length + secretBox.cipherText.length,
    out.length,
    secretBox.mac.bytes,
  );
  return out;
}

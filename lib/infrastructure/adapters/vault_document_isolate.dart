import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';

class VaultDecryptRequest {
  const VaultDecryptRequest({
    required this.cipherBase64,
    required this.keyBase64,
  });

  final String cipherBase64;
  final String keyBase64;

  Map<String, Object> toJson() => <String, Object>{
    'cipherBase64': cipherBase64,
    'keyBase64': keyBase64,
  };

  factory VaultDecryptRequest.fromJson(Map<String, Object?> json) {
    return VaultDecryptRequest(
      cipherBase64: json['cipherBase64']?.toString() ?? '',
      keyBase64: json['keyBase64']?.toString() ?? '',
    );
  }
}

Future<List<int>> decryptVaultCipherInBackground({
  required List<int> cipher,
  required List<int> key,
}) {
  final request = VaultDecryptRequest(
    cipherBase64: base64Encode(cipher),
    keyBase64: base64Encode(key),
  );
  return compute(_decryptVaultCipherWorker, request.toJson());
}

Future<List<int>> _decryptVaultCipherWorker(Map<String, Object?> requestJson) async {
  const nonceLength = 12;
  const macLength = 16;
  final request = VaultDecryptRequest.fromJson(requestJson);
  final cipher = base64Decode(request.cipherBase64);
  final key = base64Decode(request.keyBase64);
  if (cipher.length < nonceLength + macLength) {
    throw StateError('Ciphertext is too short.');
  }

  final algorithm = AesGcm.with256bits();
  final nonce = cipher.sublist(0, nonceLength);
  final macStart = cipher.length - macLength;
  final ciphertext = cipher.sublist(nonceLength, macStart);
  final macBytes = cipher.sublist(macStart);
  final secretBox = SecretBox(
    ciphertext,
    nonce: nonce,
    mac: Mac(macBytes),
  );
  return algorithm.decrypt(
    secretBox,
    secretKey: SecretKey(key),
  );
}

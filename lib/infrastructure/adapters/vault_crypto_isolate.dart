import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';

class VaultDeriveKeyRequest {
  const VaultDeriveKeyRequest({
    required this.password,
    required this.saltBase64,
    required this.memoryKb,
    required this.iterations,
    required this.parallelism,
  });

  final String password;
  final String saltBase64;
  final int memoryKb;
  final int iterations;
  final int parallelism;

  Map<String, Object> toJson() => <String, Object>{
    'password': password,
    'saltBase64': saltBase64,
    'memoryKb': memoryKb,
    'iterations': iterations,
    'parallelism': parallelism,
  };

  factory VaultDeriveKeyRequest.fromJson(Map<String, Object?> json) {
    return VaultDeriveKeyRequest(
      password: json['password']?.toString() ?? '',
      saltBase64: json['saltBase64']?.toString() ?? '',
      memoryKb: (json['memoryKb'] as num?)?.toInt() ?? 0,
      iterations: (json['iterations'] as num?)?.toInt() ?? 0,
      parallelism: (json['parallelism'] as num?)?.toInt() ?? 0,
    );
  }
}

Future<List<int>> deriveVaultKeyInBackground({
  required String password,
  required List<int> salt,
  required int memoryKb,
  required int iterations,
  required int parallelism,
}) {
  final request = VaultDeriveKeyRequest(
    password: password,
    saltBase64: base64Encode(salt),
    memoryKb: memoryKb,
    iterations: iterations,
    parallelism: parallelism,
  );
  // compute() uses a background isolate on mobile/desktop and runs on the
  // main thread on web, where dart:isolate is unavailable.
  return compute(_deriveVaultKeyWorker, request.toJson());
}

Future<List<int>> _deriveVaultKeyWorker(Map<String, Object?> requestJson) async {
  final request = VaultDeriveKeyRequest.fromJson(requestJson);
  final algorithm = Argon2id(
    memory: request.memoryKb,
    iterations: request.iterations,
    parallelism: request.parallelism,
    hashLength: 32,
  );
  final secretKey = await algorithm.deriveKeyFromPassword(
    password: request.password,
    nonce: base64Decode(request.saltBase64),
  );
  return secretKey.extractBytes();
}

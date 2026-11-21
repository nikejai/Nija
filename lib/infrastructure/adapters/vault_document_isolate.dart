import 'vault_document_isolate_worker_stub.dart'
    if (dart.library.io) 'vault_document_isolate_worker_io.dart' as worker;

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
  return worker.decryptCipherWorker(cipher: cipher, key: key);
}

class VaultEncryptRequest {
  const VaultEncryptRequest({
    required this.plainBase64,
    required this.keyBase64,
    required this.nonceBase64,
  });

  final String plainBase64;
  final String keyBase64;
  final String nonceBase64;

  Map<String, Object> toJson() => <String, Object>{
    'plainBase64': plainBase64,
    'keyBase64': keyBase64,
    'nonceBase64': nonceBase64,
  };

  factory VaultEncryptRequest.fromJson(Map<String, Object?> json) {
    return VaultEncryptRequest(
      plainBase64: json['plainBase64']?.toString() ?? '',
      keyBase64: json['keyBase64']?.toString() ?? '',
      nonceBase64: json['nonceBase64']?.toString() ?? '',
    );
  }
}

Future<List<int>> encryptVaultCipherInBackground({
  required List<int> plain,
  required List<int> key,
  required List<int> nonce,
}) {
  return worker.encryptCipherWorker(plain: plain, key: key, nonce: nonce);
}

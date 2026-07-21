import 'dart:typed_data';

import 'secret_share_model.dart';

abstract class SecretSharePortabilityAdapter {
  Future<bool> shareEncryptedFile({
    required String suggestedName,
    required String content,
  });
  Future<bool> exportEncryptedFile({
    required String suggestedName,
    required String content,
  });
  Future<bool> exportPlainFile({
    required String suggestedName,
    required Uint8List bytes,
    required String mimeType,
  });

  Future<ImportedSecretFile?> importEncryptedFile();
}

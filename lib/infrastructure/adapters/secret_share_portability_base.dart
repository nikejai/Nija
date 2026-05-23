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

  Future<ImportedSecretFile?> importEncryptedFile();
}

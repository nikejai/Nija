import 'secret_share_portability_base.dart';
import 'secret_share_model.dart';

class SecretSharePortabilityAdapterImpl
    implements SecretSharePortabilityAdapter {
  @override
  Future<bool> shareEncryptedFile({
    required String suggestedName,
    required String content,
  }) {
    throw UnsupportedError(
      'Encrypted secret sharing is not supported on this platform.',
    );
  }

  @override
  Future<bool> exportEncryptedFile({
    required String suggestedName,
    required String content,
  }) {
    throw UnsupportedError(
      'Encrypted secret export is not supported on this platform.',
    );
  }

  @override
  Future<ImportedSecretFile?> importEncryptedFile() {
    throw UnsupportedError(
      'Encrypted secret import is not supported on this platform.',
    );
  }
}

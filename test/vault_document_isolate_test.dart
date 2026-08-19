import 'package:flutter_test/flutter_test.dart';
import 'package:nija/infrastructure/adapters/secure_crypto_adapter.dart';
import 'package:nija/infrastructure/adapters/vault_document_isolate.dart';

void main() {
  test('decryptVaultCipherInBackground roundtrips with SecureCryptoAdapter', () async {
    const plainText = 'encrypted marriage certificate payload';
    final crypto = SecureCryptoAdapter();
    final key = List<int>.generate(32, (index) => index);
    final cipher = await crypto.encrypt(
      plain: plainText.codeUnits,
      key: key,
    );

    final decrypted = await decryptVaultCipherInBackground(
      cipher: cipher,
      key: key,
    );

    expect(String.fromCharCodes(decrypted), plainText);
  });
}

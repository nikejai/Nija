import 'package:flutter_test/flutter_test.dart';
import 'package:nija/infrastructure/adapters/vault_crypto_isolate.dart';

void main() {
  test('deriveVaultKeyInBackground returns stable 32-byte key', () async {
    const password = 'test-password';
    final salt = List<int>.generate(16, (index) => index);

    final first = await deriveVaultKeyInBackground(
      password: password,
      salt: salt,
      memoryKb: 64,
      iterations: 2,
      parallelism: 1,
    );
    final second = await deriveVaultKeyInBackground(
      password: password,
      salt: salt,
      memoryKb: 64,
      iterations: 2,
      parallelism: 1,
    );

    expect(first, hasLength(32));
    expect(second, first);
  });
}

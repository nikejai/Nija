import 'package:flutter_test/flutter_test.dart';
import 'package:nija/core/security/pin_credential_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('stores master password behind the configured PIN', () async {
    final store = PinCredentialStore();

    await store.saveMasterPassword(
      vaultId: 'vault-a',
      pin: '123456',
      password: 'master-secret',
    );

    expect(await store.hasPin(vaultId: 'vault-a'), isTrue);
    expect(
      await store.readMasterPassword(vaultId: 'vault-a', pin: '000000'),
      isNull,
    );
    expect(
      await store.readMasterPassword(vaultId: 'vault-a', pin: '123456'),
      'master-secret',
    );
  });

  test('remove clears PIN enrollment', () async {
    final store = PinCredentialStore();

    await store.saveMasterPassword(
      vaultId: 'vault-a',
      pin: '123456',
      password: 'master-secret',
    );
    await store.remove(vaultId: 'vault-a');

    expect(await store.hasPin(vaultId: 'vault-a'), isFalse);
    expect(
      await store.readMasterPassword(vaultId: 'vault-a', pin: '123456'),
      isNull,
    );
  });
}

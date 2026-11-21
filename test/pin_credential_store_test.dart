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

  test('enforces cooldown after 3 failures and wipes PIN after 5 failures', () async {
    var currentTime = DateTime(2026, 11, 19, 12, 0, 0);
    final store = PinCredentialStore(now: () => currentTime);

    await store.saveMasterPassword(
      vaultId: 'vault-rate',
      pin: '654321',
      password: 'master-secret',
    );

    for (var i = 0; i < PinCredentialStore.cooldownThreshold; i++) {
      expect(
        await store.readMasterPassword(vaultId: 'vault-rate', pin: '000000'),
        isNull,
      );
    }

    // Even the correct PIN is blocked during the 30-second cooldown.
    expect(
      await store.readMasterPassword(vaultId: 'vault-rate', pin: '654321'),
      isNull,
    );

    // Advance past cooldown and fail 2 more times (total 5 failures -> wipe).
    currentTime = currentTime.add(const Duration(seconds: 31));
    expect(
      await store.readMasterPassword(vaultId: 'vault-rate', pin: '000000'),
      isNull,
    );
    currentTime = currentTime.add(const Duration(seconds: 31));
    expect(
      await store.readMasterPassword(vaultId: 'vault-rate', pin: '000000'),
      isNull,
    );

    expect(await store.hasPin(vaultId: 'vault-rate'), isFalse);
    expect(
      await store.readMasterPassword(vaultId: 'vault-rate', pin: '654321'),
      isNull,
    );
  });
}

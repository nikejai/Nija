import 'package:flutter_test/flutter_test.dart';
import 'package:nija/core/security/web_quick_unlock_vault_base.dart';

class _FakeWebQuickUnlockVault extends WebQuickUnlockVault {
  bool available = true;
  bool secureQuickUnlock = true;
  final Map<String, String> enrolled = <String, String>{};
  final Set<String> legacy = <String>{};
  String? authenticatedVaultId;

  @override
  Future<bool> isAvailable() async => available;

  @override
  Future<bool> supportsSecureQuickUnlock() async => secureQuickUnlock;

  @override
  Future<bool> hasLegacyEnrollment({required String vaultId}) async {
    return legacy.contains(vaultId);
  }

  @override
  void clearAuthentication() {
    authenticatedVaultId = null;
  }

  @override
  Future<void> enroll({
    required String vaultId,
    required String password,
    required String displayName,
    bool newEnrollment = false,
  }) async {
    enrolled[vaultId] = password;
    authenticatedVaultId = null;
  }

  @override
  Future<bool> authenticate({required String vaultId}) async {
    if (!enrolled.containsKey(vaultId)) return false;
    authenticatedVaultId = vaultId;
    return true;
  }

  @override
  Future<String?> readUnlockedPassword({required String vaultId}) async {
    if (authenticatedVaultId != vaultId) return null;
    authenticatedVaultId = null;
    return enrolled[vaultId];
  }

  @override
  Future<void> remove({required String vaultId}) async {
    enrolled.remove(vaultId);
    if (authenticatedVaultId == vaultId) {
      authenticatedVaultId = null;
    }
  }

  @override
  Future<bool> hasEnrollment({required String vaultId}) async {
    return enrolled.containsKey(vaultId);
  }
}

void main() {
  group('WebQuickUnlockVault stub', () {
    test('defaults to unavailable with no enrollment', () async {
      final vault = WebQuickUnlockVault();

      expect(await vault.isAvailable(), isFalse);
      expect(await vault.hasEnrollment(vaultId: 'vault-a'), isFalse);
      expect(await vault.authenticate(vaultId: 'vault-a'), isFalse);
      expect(await vault.readUnlockedPassword(vaultId: 'vault-a'), isNull);
    });
  });

  group('WebQuickUnlockVault contract', () {
    test('requires authentication before returning stored password', () async {
      final vault = _FakeWebQuickUnlockVault();
      await vault.enroll(
        vaultId: 'vault-a',
        password: 'secret-password',
        displayName: 'Vault A',
      );

      expect(await vault.hasEnrollment(vaultId: 'vault-a'), isTrue);
      expect(await vault.readUnlockedPassword(vaultId: 'vault-a'), isNull);

      expect(await vault.authenticate(vaultId: 'vault-a'), isTrue);
      expect(
        await vault.readUnlockedPassword(vaultId: 'vault-a'),
        'secret-password',
      );
      expect(await vault.readUnlockedPassword(vaultId: 'vault-a'), isNull);
    });

    test('re-enroll updates stored password without requiring new auth', () async {
      final vault = _FakeWebQuickUnlockVault();
      await vault.enroll(
        vaultId: 'vault-a',
        password: 'old-password',
        displayName: 'Vault A',
      );
      await vault.enroll(
        vaultId: 'vault-a',
        password: 'new-password',
        displayName: 'Vault A',
      );

      expect(await vault.authenticate(vaultId: 'vault-a'), isTrue);
      expect(
        await vault.readUnlockedPassword(vaultId: 'vault-a'),
        'new-password',
      );
    });

    test('remove clears enrollment', () async {
      final vault = _FakeWebQuickUnlockVault();
      await vault.enroll(
        vaultId: 'vault-a',
        password: 'secret-password',
        displayName: 'Vault A',
      );

      await vault.remove(vaultId: 'vault-a');

      expect(await vault.hasEnrollment(vaultId: 'vault-a'), isFalse);
      expect(await vault.authenticate(vaultId: 'vault-a'), isFalse);
    });
  });
}

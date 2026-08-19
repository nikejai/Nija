class WebQuickUnlockVault {
  Future<bool> isAvailable() async => false;

  Future<bool> isWebAuthnSupported() async => false;

  Future<bool> supportsSecureQuickUnlock() async => false;

  Future<bool> hasLegacyEnrollment({required String vaultId}) async => false;

  Future<void> enroll({
    required String vaultId,
    required String password,
    required String displayName,
    bool newEnrollment = false,
  }) async {}

  Future<bool> authenticate({required String vaultId}) async => false;

  Future<String?> readUnlockedPassword({required String vaultId}) async => null;

  Future<void> remove({required String vaultId}) async {}

  Future<bool> hasEnrollment({required String vaultId}) async => false;

  void clearAuthentication() {}
}

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';

import 'biometric_unlock_presentation.dart';
import 'web_quick_unlock_vault.dart';

class BiometricAuthService {
  BiometricAuthService({
    LocalAuthentication? localAuth,
    WebQuickUnlockVault? webQuickUnlock,
  }) : _localAuth = localAuth ?? LocalAuthentication(),
       _webQuickUnlock = webQuickUnlock ?? webQuickUnlockVault;

  final LocalAuthentication _localAuth;
  final WebQuickUnlockVault _webQuickUnlock;
  String? _webAuthenticatedVaultId;

  Future<List<BiometricType>> getAvailableBiometricTypes() async {
    if (kIsWeb) return const <BiometricType>[];
    try {
      return await _localAuth.getAvailableBiometrics();
    } catch (_) {
      return const <BiometricType>[];
    }
  }

  Future<bool> supportsSecureWebQuickUnlock() async {
    if (!kIsWeb) return false;
    final available = await _webQuickUnlock.isAvailable();
    if (!available) return false;
    return _webQuickUnlock.supportsSecureQuickUnlock();
  }

  Future<bool> canAttemptWebBiometricEnrollment() async {
    if (kIsWeb) {
      if (!await _webQuickUnlock.isWebAuthnSupported()) return false;
      if (!await _webQuickUnlock.isAvailable()) return false;
      return _webQuickUnlock.supportsSecureQuickUnlock();
    }
    return canUseBiometrics();
  }

  Future<bool> canUseBiometrics() async {
    if (kIsWeb) {
      return canAttemptWebBiometricEnrollment();
    }
    try {
      final supported = await _localAuth.isDeviceSupported();
      if (!supported) return false;
      final types = await getAvailableBiometricTypes();
      if (types.isNotEmpty) return true;
      return await _localAuth.canCheckBiometrics;
    } catch (_) {
      return false;
    }
  }

  Future<BiometricUnlockPresentation> describeUnlockPresentation({
    required String genericLabel,
    required String fingerprintLabel,
    required String faceIdLabel,
    required String deviceLockLabel,
  }) async {
    if (kIsWeb) {
      return BiometricUnlockPresentation(
        label: deviceLockLabel,
        icon: Icons.fingerprint,
      );
    }
    final types = await getAvailableBiometricTypes();
    return biometricUnlockPresentationFor(
      types: types,
      genericLabel: genericLabel,
      fingerprintLabel: fingerprintLabel,
      faceIdLabel: faceIdLabel,
      deviceLockLabel: deviceLockLabel,
    );
  }

  Future<bool> authenticateForUnlock({
    required String localizedReason,
    String? vaultId,
  }) async {
    if (kIsWeb) {
      if (vaultId == null || vaultId.isEmpty) return false;
      if (!await supportsSecureWebQuickUnlock()) return false;
      final ok = await _webQuickUnlock.authenticate(vaultId: vaultId);
      if (ok) {
        _webAuthenticatedVaultId = vaultId;
      }
      return ok;
    }
    try {
      return await _localAuth.authenticate(
        localizedReason: localizedReason,
        biometricOnly: true,
        persistAcrossBackgrounding: true,
      );
    } catch (_) {
      return false;
    }
  }

  void clearWebAuthentication() {
    _webAuthenticatedVaultId = null;
    if (kIsWeb) {
      _webQuickUnlock.clearAuthentication();
    }
  }

  bool get hasWebAuthentication => _webAuthenticatedVaultId != null;

  String? get webAuthenticatedVaultId => _webAuthenticatedVaultId;
}

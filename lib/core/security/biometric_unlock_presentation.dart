import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';

class BiometricUnlockPresentation {
  const BiometricUnlockPresentation({
    required this.label,
    required this.icon,
  });

  final String label;
  final IconData icon;
}

BiometricUnlockPresentation biometricUnlockPresentationFor({
  required List<BiometricType> types,
  required String genericLabel,
  required String fingerprintLabel,
  required String faceIdLabel,
  required String deviceLockLabel,
}) {
  if (types.contains(BiometricType.face)) {
    return BiometricUnlockPresentation(
      label: faceIdLabel,
      icon: Icons.face_unlock_outlined,
    );
  }
  if (types.contains(BiometricType.fingerprint)) {
    return BiometricUnlockPresentation(
      label: fingerprintLabel,
      icon: Icons.fingerprint,
    );
  }
  if (types.contains(BiometricType.strong) ||
      types.contains(BiometricType.weak)) {
    return BiometricUnlockPresentation(
      label: deviceLockLabel,
      icon: Icons.lock_outline,
    );
  }
  return BiometricUnlockPresentation(
    label: genericLabel,
    icon: Icons.fingerprint,
  );
}

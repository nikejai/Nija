import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_auth/local_auth.dart';
import 'package:nija/core/security/biometric_unlock_presentation.dart';

void main() {
  test('prefers face label when face biometrics are available', () {
    final presentation = biometricUnlockPresentationFor(
      types: const [BiometricType.face, BiometricType.fingerprint],
      genericLabel: 'Use biometrics',
      fingerprintLabel: 'Use fingerprint',
      faceIdLabel: 'Use Face ID',
      deviceLockLabel: 'Use device lock',
    );

    expect(presentation.label, 'Use Face ID');
    expect(presentation.icon, Icons.face_unlock_outlined);
  });

  test('uses fingerprint label when only fingerprint is available', () {
    final presentation = biometricUnlockPresentationFor(
      types: const [BiometricType.fingerprint],
      genericLabel: 'Use biometrics',
      fingerprintLabel: 'Use fingerprint',
      faceIdLabel: 'Use Face ID',
      deviceLockLabel: 'Use device lock',
    );

    expect(presentation.label, 'Use fingerprint');
    expect(presentation.icon, Icons.fingerprint);
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:nija/core/web_integrity/web_integrity_manifest.dart';
import 'package:nija/core/web_integrity/web_integrity_signature.dart';

void main() {
  NijaWebIntegrityManifest manifest({String buildId = 'build-123'}) {
    return NijaWebIntegrityManifest(
      formatVersion: nijaWebIntegrityManifestVersion,
      appVersion: '0.1.1+2',
      buildId: buildId,
      flavor: 'compat-js',
      generatedAt: '2026-08-22T00:00:00.000Z',
      publicKeyId: 'test-key',
      files: const {'main.dart.js': 'abc123'},
      verifierGroups: const {
        'startup': ['main.dart.js'],
      },
    );
  }

  test('signature verification passes with matching key', () async {
    final keyPair = await generateNijaWebIntegrityTestKeyPair();
    final tested = manifest();
    final signature = await signNijaWebIntegrityManifest(
      manifest: tested,
      privateSeedBase64: keyPair.seedBase64,
    );

    expect(
      await verifyNijaWebIntegrityManifestSignature(
        manifest: tested,
        signatureBase64: signature,
        publicKeyBase64: keyPair.publicKeyBase64,
      ),
      isTrue,
    );
  });

  test('signature verification fails when manifest changes', () async {
    final keyPair = await generateNijaWebIntegrityTestKeyPair();
    final signature = await signNijaWebIntegrityManifest(
      manifest: manifest(),
      privateSeedBase64: keyPair.seedBase64,
    );

    expect(
      await verifyNijaWebIntegrityManifestSignature(
        manifest: manifest(buildId: 'changed'),
        signatureBase64: signature,
        publicKeyBase64: keyPair.publicKeyBase64,
      ),
      isFalse,
    );
  });

  test('signature verification fails with wrong public key', () async {
    final signingKey = await generateNijaWebIntegrityTestKeyPair();
    final wrongKey = await generateNijaWebIntegrityTestKeyPair();
    final tested = manifest();
    final signature = await signNijaWebIntegrityManifest(
      manifest: tested,
      privateSeedBase64: signingKey.seedBase64,
    );

    expect(
      await verifyNijaWebIntegrityManifestSignature(
        manifest: tested,
        signatureBase64: signature,
        publicKeyBase64: wrongKey.publicKeyBase64,
      ),
      isFalse,
    );
  });

  test('signature verification fails with missing signature', () async {
    final keyPair = await generateNijaWebIntegrityTestKeyPair();

    expect(
      await verifyNijaWebIntegrityManifestSignature(
        manifest: manifest(),
        signatureBase64: '',
        publicKeyBase64: keyPair.publicKeyBase64,
      ),
      isFalse,
    );
  });
}

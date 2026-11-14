import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nija/core/web_integrity/web_integrity_manifest.dart';
import 'package:nija/core/web_integrity/web_integrity_signature.dart';

void main() {
  test('create-key writes private and public key files', () async {
    final dir = await Directory.systemTemp.createTemp('nija_web_keygen_');

    final result = await Process.run('dart', [
      'run',
      'tool/web_integrity.dart',
      'create-key',
      '--output-dir',
      dir.path,
    ]);

    expect(result.exitCode, 0, reason: result.stderr.toString());
    final privateKey = File('${dir.path}/private_seed.b64').readAsStringSync();
    final publicKey = File('${dir.path}/public_key.b64').readAsStringSync();
    expect(privateKey.trim(), isNotEmpty);
    expect(publicKey.trim(), isNotEmpty);

    final manifest = NijaWebIntegrityManifest(
      formatVersion: nijaWebIntegrityManifestVersion,
      appVersion: '0.1.1+2',
      buildId: 'keygen-test',
      flavor: 'compat-js',
      generatedAt: '2026-08-22T00:00:00.000Z',
      publicKeyId: 'test-key',
      files: const {'main.dart.js': 'abc123'},
      verifierGroups: const {
        'startup': ['main.dart.js'],
      },
    );
    final signature = await signNijaWebIntegrityManifest(
      manifest: manifest,
      privateSeedBase64: privateKey,
    );

    expect(
      await verifyNijaWebIntegrityManifestSignature(
        manifest: manifest,
        signatureBase64: signature,
        publicKeyBase64: publicKey,
      ),
      isTrue,
    );
  });

  test('compat release build script exposes key-dir option', () async {
    final result = await Process.run('./scripts/build_web_compat_release.sh', [
      '--help',
    ]);

    expect(result.exitCode, 0);
    expect(result.stdout.toString(), contains('--key-dir'));
    expect(result.stdout.toString(), contains('--zip-path'));
    expect(result.stdout.toString(), contains('--no-zip'));
  });
}

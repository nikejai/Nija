import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:nija/core/web_integrity/web_integrity_manifest.dart';

void main() {
  NijaWebIntegrityManifest manifest() => const NijaWebIntegrityManifest(
    formatVersion: nijaWebIntegrityManifestVersion,
    appVersion: '0.1.1+2',
    buildId: 'build-123',
    flavor: 'compat-js',
    generatedAt: '2026-08-22T00:00:00.000Z',
    publicKeyId: 'test-key',
    files: {'main.dart.js': 'a', 'main.dart.wasm': 'b'},
    verifierGroups: {
      'startup': ['main.dart.js'],
      'assets': ['main.dart.wasm'],
    },
  );

  test('manifest parsing accepts valid json', () {
    final parsed = NijaWebIntegrityManifest.fromJsonString(
      jsonEncode(manifest().toJson()),
    );

    expect(parsed.formatVersion, nijaWebIntegrityManifestVersion);
    expect(parsed.files['main.dart.js'], 'a');
    expect(parsed.verifierGroups['startup'], ['main.dart.js']);
  });

  test('manifest canonical json is stable', () {
    final first = manifest().toCanonicalJson();
    final second = NijaWebIntegrityManifest.fromJsonString(
      jsonEncode({
        'verifierGroups': {
          'assets': ['main.dart.wasm'],
          'startup': ['main.dart.js'],
        },
        'files': {'main.dart.wasm': 'b', 'main.dart.js': 'a'},
        'publicKeyId': 'test-key',
        'generatedAt': '2026-08-22T00:00:00.000Z',
        'flavor': 'compat-js',
        'buildId': 'build-123',
        'appVersion': '0.1.1+2',
        'formatVersion': nijaWebIntegrityManifestVersion,
      }),
    ).toCanonicalJson();

    expect(second, first);
  });

  test('hash verification passes for matching bytes', () async {
    final jsHash = await nijaWebIntegritySha256Hex(utf8.encode('js'));
    final wasmHash = await nijaWebIntegritySha256Hex(utf8.encode('wasm'));
    final tested = NijaWebIntegrityManifest(
      formatVersion: nijaWebIntegrityManifestVersion,
      appVersion: '0.1.1+2',
      buildId: 'build-123',
      flavor: 'compat-js',
      generatedAt: '2026-08-22T00:00:00.000Z',
      publicKeyId: 'test-key',
      files: {'main.dart.js': jsHash, 'main.dart.wasm': wasmHash},
      verifierGroups: const {},
    );

    await verifyNijaWebIntegrityHashes(
      manifest: tested,
      readBytes: (path) async =>
          utf8.encode(path.endsWith('.js') ? 'js' : 'wasm'),
    );
  });

  test('hash verification fails for changed bytes', () async {
    final tested = NijaWebIntegrityManifest(
      formatVersion: nijaWebIntegrityManifestVersion,
      appVersion: '0.1.1+2',
      buildId: 'build-123',
      flavor: 'compat-js',
      generatedAt: '2026-08-22T00:00:00.000Z',
      publicKeyId: 'test-key',
      files: {
        'main.dart.js': await nijaWebIntegritySha256Hex(utf8.encode('js')),
      },
      verifierGroups: const {},
    );

    expect(
      verifyNijaWebIntegrityHashes(
        manifest: tested,
        readBytes: (_) async => utf8.encode('changed'),
      ),
      throwsStateError,
    );
  });

  test('hash verification fails for missing artifact', () async {
    final tested = NijaWebIntegrityManifest(
      formatVersion: nijaWebIntegrityManifestVersion,
      appVersion: '0.1.1+2',
      buildId: 'build-123',
      flavor: 'compat-js',
      generatedAt: '2026-08-22T00:00:00.000Z',
      publicKeyId: 'test-key',
      files: {
        'main.dart.js': await nijaWebIntegritySha256Hex(utf8.encode('js')),
      },
      verifierGroups: const {},
    );

    expect(
      verifyNijaWebIntegrityHashes(
        manifest: tested,
        readBytes: (_) async => null,
      ),
      throwsStateError,
    );
  });
}

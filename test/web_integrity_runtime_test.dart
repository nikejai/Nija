import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nija/core/web_integrity/web_integrity_manifest.dart';
import 'package:nija/core/web_integrity/web_integrity_signature.dart';
import 'package:nija/core/web_integrity/web_integrity_startup.dart';

void main() {
  test('non-web verifier is success and does not require artifacts', () async {
    final verifier = NijaWebIntegrityStartupVerifier(
      enabled: true,
      isWeb: false,
      publicKeyBase64: '',
      client: MockClient((_) async => http.Response('missing', 404)),
    );

    expect(await verifier.verify(), NijaWebIntegrityStartupResult.passed);
  });

  test(
    'non-web group verification is success and does not require artifacts',
    () async {
      final verifier = NijaWebIntegrityRuntimeVerifier(
        enabled: true,
        isWeb: false,
        publicKeyBase64: '',
        client: MockClient((_) async => http.Response('missing', 404)),
      );

      expect(
        await verifier.verifyGroup('unlock'),
        NijaWebIntegrityStartupResult.passed,
      );
    },
  );

  test(
    'web verifier passes with matching manifest signature and files',
    () async {
      final fixture = await _runtimeFixture();
      final verifier = NijaWebIntegrityStartupVerifier(
        enabled: true,
        isWeb: true,
        publicKeyBase64: fixture.publicKeyBase64,
        baseUri: Uri.parse('https://nija.test/'),
        client: MockClient((request) async {
          final path = request.url.pathSegments.join('/');
          final body = fixture.files[path];
          if (body == null) return http.Response('missing', 404);
          return http.Response.bytes(body, 200);
        }),
      );

      expect(await verifier.verify(), NijaWebIntegrityStartupResult.passed);
    },
  );

  test('web verifier fails with changed artifact', () async {
    final fixture = await _runtimeFixture();
    final verifier = NijaWebIntegrityStartupVerifier(
      enabled: true,
      isWeb: true,
      publicKeyBase64: fixture.publicKeyBase64,
      baseUri: Uri.parse('https://nija.test/'),
      client: MockClient((request) async {
        final path = request.url.pathSegments.join('/');
        if (path == 'main.dart.js') {
          return http.Response.bytes(utf8.encode('changed'), 200);
        }
        final body = fixture.files[path];
        if (body == null) return http.Response('missing', 404);
        return http.Response.bytes(body, 200);
      }),
    );

    expect(await verifier.verify(), NijaWebIntegrityStartupResult.unavailable);
  });

  test('verifyGroup hashes only requested manifest group', () async {
    final fixture = await _runtimeFixture(
      groups: const {
        'startup': ['main.dart.wasm'],
        'unlock': ['main.dart.js'],
      },
    );
    final verifier = NijaWebIntegrityRuntimeVerifier(
      enabled: true,
      isWeb: true,
      publicKeyBase64: fixture.publicKeyBase64,
      baseUri: Uri.parse('https://nija.test/'),
      client: MockClient((request) async {
        final path = request.url.pathSegments.join('/');
        if (path == 'main.dart.js') {
          return http.Response.bytes(utf8.encode('changed'), 200);
        }
        final body = fixture.files[path];
        if (body == null) return http.Response('missing', 404);
        return http.Response.bytes(body, 200);
      }),
    );

    expect(
      await verifier.verifyGroup('startup'),
      NijaWebIntegrityStartupResult.passed,
    );
    expect(
      await verifier.verifyGroup('unlock'),
      NijaWebIntegrityStartupResult.unavailable,
    );
  });

  test('verifyGroup fails closed for missing group', () async {
    final fixture = await _runtimeFixture();
    final verifier = NijaWebIntegrityRuntimeVerifier(
      enabled: true,
      isWeb: true,
      publicKeyBase64: fixture.publicKeyBase64,
      baseUri: Uri.parse('https://nija.test/'),
      client: MockClient((request) async {
        final path = request.url.pathSegments.join('/');
        final body = fixture.files[path];
        if (body == null) return http.Response('missing', 404);
        return http.Response.bytes(body, 200);
      }),
    );

    expect(
      await verifier.verifyGroup('missing'),
      NijaWebIntegrityStartupResult.unavailable,
    );
  });

  test('manifest and signature fetch are cached across group checks', () async {
    final fixture = await _runtimeFixture(
      groups: const {
        'startup': ['main.dart.wasm'],
        'unlock': ['main.dart.js'],
      },
    );
    var manifestFetches = 0;
    var signatureFetches = 0;
    final verifier = NijaWebIntegrityRuntimeVerifier(
      enabled: true,
      isWeb: true,
      publicKeyBase64: fixture.publicKeyBase64,
      baseUri: Uri.parse('https://nija.test/'),
      client: MockClient((request) async {
        final path = request.url.pathSegments.join('/');
        if (path == nijaWebIntegrityManifestFile) manifestFetches++;
        if (path == nijaWebIntegritySignatureFile) signatureFetches++;
        final body = fixture.files[path];
        if (body == null) return http.Response('missing', 404);
        return http.Response.bytes(body, 200);
      }),
    );

    expect(
      await verifier.verifyGroup('startup'),
      NijaWebIntegrityStartupResult.passed,
    );
    expect(
      await verifier.verifyGroup('unlock'),
      NijaWebIntegrityStartupResult.passed,
    );
    expect(manifestFetches, 1);
    expect(signatureFetches, 1);
  });

  test('artifact hash fetches include build id cache buster', () async {
    final fixture = await _runtimeFixture(
      groups: const {
        'startup': ['main.dart.wasm'],
      },
    );
    final artifactQueries = <String>[];
    final verifier = NijaWebIntegrityRuntimeVerifier(
      enabled: true,
      isWeb: true,
      publicKeyBase64: fixture.publicKeyBase64,
      baseUri: Uri.parse('https://nija.test/'),
      client: MockClient((request) async {
        final path = request.url.pathSegments.join('/');
        if (path == 'main.dart.wasm') {
          artifactQueries.add(request.url.query);
        }
        final body = fixture.files[path];
        if (body == null) return http.Response('missing', 404);
        return http.Response.bytes(body, 200);
      }),
    );

    expect(
      await verifier.verifyGroup('startup'),
      NijaWebIntegrityStartupResult.passed,
    );
    expect(artifactQueries, contains('nijaBuildId=runtime-test'));
  });

  test('capacity group fails on web when build marker mismatches', () async {
    final fixture = await _runtimeFixture(
      groups: const {
        'capacity': ['main.dart.wasm'],
      },
    );
    final verifier = NijaWebIntegrityRuntimeVerifier(
      enabled: true,
      isWeb: true,
      publicKeyBase64: fixture.publicKeyBase64,
      buildId: 'different-build',
      baseUri: Uri.parse('https://nija.test/'),
      client: MockClient((request) async {
        final path = request.url.pathSegments.join('/');
        final body = fixture.files[path];
        if (body == null) return http.Response('missing', 404);
        return http.Response.bytes(body, 200);
      }),
    );

    expect(
      await verifier.verifyGroup('capacity'),
      NijaWebIntegrityStartupResult.unavailable,
    );
  });

  test('generic unavailable copy avoids distinctive failure wording', () {
    final combined =
        '${nijaWebIntegrityGenericUnavailableTitle()} '
        '${nijaWebIntegrityGenericUnavailableMessage()}';

    expect(nijaWebIntegrityContainsForbiddenFailureLanguage(combined), isFalse);
  });
}

Future<_RuntimeFixture> _runtimeFixture({
  Map<String, List<String>> groups = const {
    'startup': ['main.dart.js', 'main.dart.wasm'],
  },
}) async {
  final keyPair = await generateNijaWebIntegrityTestKeyPair();
  final js = utf8.encode('js');
  final wasm = utf8.encode('wasm');
  final manifest = NijaWebIntegrityManifest(
    formatVersion: nijaWebIntegrityManifestVersion,
    appVersion: '0.1.1+2',
    buildId: 'runtime-test',
    flavor: 'compat-js',
    generatedAt: '2026-08-22T00:00:00.000Z',
    publicKeyId: 'test-key',
    files: {
      'main.dart.js': await nijaWebIntegritySha256Hex(js),
      'main.dart.wasm': await nijaWebIntegritySha256Hex(wasm),
    },
    verifierGroups: groups,
  );
  final signature = await signNijaWebIntegrityManifest(
    manifest: manifest,
    privateSeedBase64: keyPair.seedBase64,
  );
  return _RuntimeFixture(
    publicKeyBase64: keyPair.publicKeyBase64,
    files: {
      nijaWebIntegrityManifestFile: utf8.encode(jsonEncode(manifest.toJson())),
      nijaWebIntegritySignatureFile: utf8.encode(signature),
      'main.dart.js': js,
      'main.dart.wasm': wasm,
    },
  );
}

class _RuntimeFixture {
  const _RuntimeFixture({required this.publicKeyBase64, required this.files});

  final String publicKeyBase64;
  final Map<String, List<int>> files;
}

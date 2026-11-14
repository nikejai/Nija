import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'web_integrity_manifest.dart';
import 'web_integrity_signature.dart';

enum NijaWebIntegrityStartupResult { passed, unavailable }

typedef NijaWebIntegrityGroupProbe =
    Future<NijaWebIntegrityStartupResult> Function(String groupName);

NijaWebIntegrityGroupProbe? debugNijaWebIntegrityGroupProbe;

class NijaWebIntegrityRuntimeVerifier {
  NijaWebIntegrityRuntimeVerifier({
    http.Client? client,
    Uri? baseUri,
    bool? enabled,
    bool? isWeb,
    String? publicKeyBase64,
    String? buildId,
  }) : _client = client ?? http.Client(),
       _baseUri = baseUri ?? Uri.base,
       _enabled =
           enabled ?? const bool.fromEnvironment('NIJA_WEB_INTEGRITY_ENABLED'),
       _isWeb = isWeb ?? kIsWeb,
       _publicKeyBase64 =
           publicKeyBase64 ??
           const String.fromEnvironment('NIJA_WEB_INTEGRITY_PUBLIC_KEY_B64'),
       _buildId =
           buildId ??
           const String.fromEnvironment('NIJA_WEB_INTEGRITY_BUILD_ID');

  static final NijaWebIntegrityRuntimeVerifier instance =
      NijaWebIntegrityRuntimeVerifier();

  final http.Client _client;
  final Uri _baseUri;
  final bool _enabled;
  final bool _isWeb;
  final String _publicKeyBase64;
  final String _buildId;
  Future<NijaWebIntegrityManifest?>? _verifiedManifest;

  Future<NijaWebIntegrityStartupResult> verifyStartup() {
    return verifyGroup('startup');
  }

  Future<NijaWebIntegrityStartupResult> verifyGroup(String groupName) async {
    if (!_isWeb || !_enabled) return NijaWebIntegrityStartupResult.passed;
    if (_publicKeyBase64.trim().isEmpty) {
      return NijaWebIntegrityStartupResult.unavailable;
    }
    try {
      final manifest = await _loadVerifiedManifest();
      if (manifest == null) return NijaWebIntegrityStartupResult.unavailable;
      if (groupName == 'capacity' &&
          (_buildId.trim().isEmpty || manifest.buildId != _buildId.trim())) {
        return NijaWebIntegrityStartupResult.unavailable;
      }
      final group = manifest.verifierGroups[groupName];
      if (group == null || group.isEmpty) {
        return NijaWebIntegrityStartupResult.unavailable;
      }
      await verifyNijaWebIntegrityHashEntries(
        manifest: manifest,
        paths: group,
        readBytes: (path) => _readBuildFile(path, manifest.buildId),
      );
      return NijaWebIntegrityStartupResult.passed;
    } catch (_) {
      return NijaWebIntegrityStartupResult.unavailable;
    }
  }

  Future<NijaWebIntegrityManifest?> _loadVerifiedManifest() {
    return _verifiedManifest ??= _fetchAndVerifyManifest();
  }

  Future<NijaWebIntegrityManifest?> _fetchAndVerifyManifest() async {
    final manifestResponse = await _client.get(
      _baseUri.resolve(nijaWebIntegrityManifestFile),
    );
    final signatureResponse = await _client.get(
      _baseUri.resolve(nijaWebIntegritySignatureFile),
    );
    if (manifestResponse.statusCode != 200 ||
        signatureResponse.statusCode != 200) {
      return null;
    }
    final manifest = NijaWebIntegrityManifest.fromJsonString(
      manifestResponse.body,
    )..validate();
    final signatureOk = await verifyNijaWebIntegrityManifestSignature(
      manifest: manifest,
      signatureBase64: signatureResponse.body,
      publicKeyBase64: _publicKeyBase64,
    );
    return signatureOk ? manifest : null;
  }

  Future<List<int>?> _readBuildFile(String path, String buildId) async {
    final uri = _baseUri
        .resolve(path)
        .replace(queryParameters: <String, String>{'nijaBuildId': buildId});
    final response = await _client.get(uri);
    if (response.statusCode != 200) return null;
    return response.bodyBytes;
  }

  void close() {
    _client.close();
  }
}

class NijaWebIntegrityStartupVerifier {
  NijaWebIntegrityStartupVerifier({
    http.Client? client,
    Uri? baseUri,
    bool? enabled,
    bool? isWeb,
    String? publicKeyBase64,
    String? buildId,
  }) : _runtime = NijaWebIntegrityRuntimeVerifier(
         client: client,
         baseUri: baseUri,
         enabled: enabled,
         isWeb: isWeb,
         publicKeyBase64: publicKeyBase64,
         buildId: buildId,
       );

  final NijaWebIntegrityRuntimeVerifier _runtime;

  Future<NijaWebIntegrityStartupResult> verify() async {
    return _runtime.verifyStartup();
  }

  void close() {
    _runtime.close();
  }
}

String nijaWebIntegrityGenericUnavailableTitle() => 'Nija is unavailable';

String nijaWebIntegrityGenericUnavailableMessage() {
  return 'Reload the app or reinstall it from the official release.';
}

bool nijaWebIntegrityContainsForbiddenFailureLanguage(String value) {
  final normalized = value.toLowerCase();
  return normalized.contains('tamper') ||
      normalized.contains('integrity failed') ||
      normalized.contains('integrity failure');
}

Map<String, String> nijaWebIntegrityDecodeTextFixture(
  Map<String, List<int>> files,
) {
  return files.map(
    (key, value) => MapEntry(key, utf8.decode(value, allowMalformed: false)),
  );
}

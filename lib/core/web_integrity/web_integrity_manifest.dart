import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

const int nijaWebIntegrityManifestVersion = 1;
const String nijaWebIntegrityManifestFile = 'nija_integrity_manifest.json';
const String nijaWebIntegritySignatureFile = 'nija_integrity_manifest.sig';

class NijaWebIntegrityManifest {
  const NijaWebIntegrityManifest({
    required this.formatVersion,
    required this.appVersion,
    required this.buildId,
    required this.flavor,
    required this.generatedAt,
    required this.publicKeyId,
    required this.files,
    required this.verifierGroups,
  });

  factory NijaWebIntegrityManifest.fromJson(Map<String, dynamic> json) {
    final filesJson = json['files'];
    final groupsJson = json['verifierGroups'];
    if (filesJson is! Map) {
      throw const FormatException('Invalid web manifest files.');
    }
    if (groupsJson is! Map) {
      throw const FormatException('Invalid web manifest groups.');
    }
    return NijaWebIntegrityManifest(
      formatVersion: _readInt(json['formatVersion']),
      appVersion: _readString(json['appVersion']),
      buildId: _readString(json['buildId']),
      flavor: _readString(json['flavor']),
      generatedAt: _readString(json['generatedAt']),
      publicKeyId: _readString(json['publicKeyId']),
      files: Map<String, String>.fromEntries(
        filesJson.entries.map(
          (entry) => MapEntry(entry.key.toString(), entry.value.toString()),
        ),
      ),
      verifierGroups: Map<String, List<String>>.fromEntries(
        groupsJson.entries.map((entry) {
          final rawList = entry.value;
          if (rawList is! List) {
            throw const FormatException('Invalid web manifest group entry.');
          }
          return MapEntry(
            entry.key.toString(),
            rawList.map((value) => value.toString()).toList(growable: false),
          );
        }),
      ),
    );
  }

  factory NijaWebIntegrityManifest.fromJsonString(String source) {
    final decoded = jsonDecode(source);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Invalid web manifest JSON.');
    }
    return NijaWebIntegrityManifest.fromJson(decoded);
  }

  final int formatVersion;
  final String appVersion;
  final String buildId;
  final String flavor;
  final String generatedAt;
  final String publicKeyId;
  final Map<String, String> files;
  final Map<String, List<String>> verifierGroups;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'formatVersion': formatVersion,
      'appVersion': appVersion,
      'buildId': buildId,
      'flavor': flavor,
      'generatedAt': generatedAt,
      'publicKeyId': publicKeyId,
      'files': Map<String, String>.fromEntries(_sortedEntries(files)),
      'verifierGroups': Map<String, List<String>>.fromEntries(
        _sortedEntries(
          verifierGroups.map(
            (key, value) => MapEntry(key, List<String>.from(value)..sort()),
          ),
        ),
      ),
    };
  }

  String toCanonicalJson() => _canonicalJson(toJson());

  List<int> canonicalBytes() => utf8.encode(toCanonicalJson());

  void validate() {
    if (formatVersion != nijaWebIntegrityManifestVersion) {
      throw const FormatException('Unsupported web manifest version.');
    }
    if (appVersion.trim().isEmpty ||
        buildId.trim().isEmpty ||
        flavor.trim().isEmpty ||
        generatedAt.trim().isEmpty ||
        publicKeyId.trim().isEmpty) {
      throw const FormatException('Incomplete web manifest metadata.');
    }
    if (files.isEmpty) {
      throw const FormatException('Web manifest has no files.');
    }
    for (final entry in files.entries) {
      if (entry.key.trim().isEmpty || entry.value.trim().isEmpty) {
        throw const FormatException('Invalid web manifest file entry.');
      }
    }
  }
}

Future<String> nijaWebIntegritySha256Hex(List<int> bytes) async {
  final digest = await Sha256().hash(bytes);
  return _hex(digest.bytes);
}

Future<void> verifyNijaWebIntegrityHashes({
  required NijaWebIntegrityManifest manifest,
  required Future<List<int>?> Function(String path) readBytes,
}) async {
  manifest.validate();
  await verifyNijaWebIntegrityHashEntries(
    manifest: manifest,
    paths: manifest.files.keys,
    readBytes: readBytes,
  );
}

Future<void> verifyNijaWebIntegrityHashEntries({
  required NijaWebIntegrityManifest manifest,
  required Iterable<String> paths,
  required Future<List<int>?> Function(String path) readBytes,
}) async {
  manifest.validate();
  for (final path in paths) {
    final expected = manifest.files[path];
    if (expected == null) {
      throw StateError('Web artifact unavailable.');
    }
    final bytes = await readBytes(path);
    if (bytes == null) {
      throw StateError('Web artifact unavailable.');
    }
    final actual = await nijaWebIntegritySha256Hex(bytes);
    if (actual != expected.toLowerCase()) {
      throw StateError('Web artifact unavailable.');
    }
  }
}

String _canonicalJson(Object? value) {
  if (value == null || value is num || value is bool) {
    return jsonEncode(value);
  }
  if (value is String) return jsonEncode(value);
  if (value is List) {
    return '[${value.map(_canonicalJson).join(',')}]';
  }
  if (value is Map) {
    final entries = value.entries.toList()
      ..sort((a, b) => a.key.toString().compareTo(b.key.toString()));
    return '{${entries.map((entry) {
      return '${jsonEncode(entry.key.toString())}:${_canonicalJson(entry.value)}';
    }).join(',')}}';
  }
  return jsonEncode(value.toString());
}

Iterable<MapEntry<String, T>> _sortedEntries<T>(Map<String, T> source) {
  final entries = source.entries.toList()
    ..sort((a, b) => a.key.compareTo(b.key));
  return entries;
}

int _readInt(Object? value) {
  final parsed = int.tryParse(value?.toString() ?? '');
  if (parsed == null) {
    throw const FormatException('Invalid web manifest integer.');
  }
  return parsed;
}

String _readString(Object? value) {
  final text = value?.toString().trim() ?? '';
  if (text.isEmpty) {
    throw const FormatException('Invalid web manifest string.');
  }
  return text;
}

String _hex(List<int> bytes) {
  final buffer = StringBuffer();
  for (final byte in bytes) {
    buffer.write(byte.toRadixString(16).padLeft(2, '0'));
  }
  return buffer.toString();
}

Uint8List nijaWebIntegrityBytes(String value) {
  return Uint8List.fromList(utf8.encode(value));
}

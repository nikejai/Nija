import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:flutter_web_plugins/flutter_web_plugins.dart';

/// Wasm-safe web registrar for `flutter_secure_storage`.
///
/// Nija routes web secrets through its own WebAuthn/IndexedDB helpers and uses
/// this package only to keep Flutter's generated web plugin registrant from
/// importing the upstream `dart:html` implementation during wasm builds.
class FlutterSecureStorageWeb extends FlutterSecureStoragePlatform {
  static final Map<String, String> _sessionValues = <String, String>{};

  static void registerWith(Registrar registrar) {
    FlutterSecureStoragePlatform.instance = FlutterSecureStorageWeb();
  }

  String _scopedKey(String key, Map<String, String> options) {
    final prefix = options['publicKey'] ?? 'flutter_secure_storage';
    return '$prefix.$key';
  }

  @override
  Future<bool> containsKey({
    required String key,
    required Map<String, String> options,
  }) async {
    return _sessionValues.containsKey(_scopedKey(key, options));
  }

  @override
  Future<void> delete({
    required String key,
    required Map<String, String> options,
  }) async {
    _sessionValues.remove(_scopedKey(key, options));
  }

  @override
  Future<void> deleteAll({required Map<String, String> options}) async {
    final prefix = '${options['publicKey'] ?? 'flutter_secure_storage'}.';
    _sessionValues.removeWhere((key, value) => key.startsWith(prefix));
  }

  @override
  Future<String?> read({
    required String key,
    required Map<String, String> options,
  }) async {
    return _sessionValues[_scopedKey(key, options)];
  }

  @override
  Future<Map<String, String>> readAll({
    required Map<String, String> options,
  }) async {
    final prefix = '${options['publicKey'] ?? 'flutter_secure_storage'}.';
    final result = <String, String>{};
    for (final entry in _sessionValues.entries) {
      if (entry.key.startsWith(prefix)) {
        result[entry.key.substring(prefix.length)] = entry.value;
      }
    }
    return result;
  }

  @override
  Future<void> write({
    required String key,
    required String value,
    required Map<String, String> options,
  }) async {
    _sessionValues[_scopedKey(key, options)] = value;
  }
}

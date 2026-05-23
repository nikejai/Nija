import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class BiometricCredentialStore {
  static const _storageKey = 'nija_biometric_credentials_v1';
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  Future<void> saveMasterPassword({
    required String vaultId,
    required String password,
  }) async {
    if (kIsWeb) return;
    final map = await _readAll();
    map[vaultId] = password;
    await _storage.write(key: _storageKey, value: jsonEncode(map));
  }

  Future<String?> readMasterPassword({required String vaultId}) async {
    if (kIsWeb) return null;
    final map = await _readAll();
    return map[vaultId];
  }

  Future<void> removeMasterPassword({required String vaultId}) async {
    if (kIsWeb) return;
    final map = await _readAll();
    map.remove(vaultId);
    await _storage.write(key: _storageKey, value: jsonEncode(map));
  }

  Future<Map<String, String>> _readAll() async {
    try {
      final raw = await _storage.read(key: _storageKey);
      if (raw == null || raw.isEmpty) return <String, String>{};
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return <String, String>{};
      return decoded.map((key, value) => MapEntry(key.toString(), value.toString()));
    } catch (_) {
      return <String, String>{};
    }
  }
}

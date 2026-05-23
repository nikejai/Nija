import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class BiometricEnrollmentStore {
  static const _storageKey = 'nija_biometric_enrollment_v1';

  Future<bool> isEnrolledForVault(String vaultId) async {
    final map = await _readMap();
    return map[vaultId] == true;
  }

  Future<void> setEnrolledForVault({
    required String vaultId,
    required bool enrolled,
  }) async {
    final map = await _readMap();
    if (enrolled) {
      map[vaultId] = true;
    } else {
      map.remove(vaultId);
    }
    await _writeMap(map);
  }

  Future<Map<String, bool>> _readMap() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_storageKey);
      if (raw == null || raw.isEmpty) return <String, bool>{};
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return <String, bool>{};
      return decoded.map<String, bool>(
        (key, value) => MapEntry(key.toString(), value == true),
      );
    } on MissingPluginException {
      return <String, bool>{};
    } catch (_) {
      return <String, bool>{};
    }
  }

  Future<void> _writeMap(Map<String, bool> map) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_storageKey, jsonEncode(map));
    } on MissingPluginException {
      // Ignore in tests.
    } catch (_) {
      // Ignore in tests.
    }
  }
}

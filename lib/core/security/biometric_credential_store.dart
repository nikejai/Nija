import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'web_quick_unlock_vault.dart';

class BiometricCredentialStore {
  BiometricCredentialStore({WebQuickUnlockVault? webQuickUnlock})
    : _webQuickUnlock = webQuickUnlock ?? webQuickUnlockVault;

  static const _storageKey = 'nija_biometric_credentials_v1';
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  final WebQuickUnlockVault _webQuickUnlock;

  Future<void> saveMasterPassword({
    required String vaultId,
    required String password,
    String displayName = '',
    bool newEnrollment = false,
  }) async {
    if (kIsWeb) {
      await _webQuickUnlock.enroll(
        vaultId: vaultId,
        password: password,
        displayName: displayName.isEmpty ? vaultId : displayName,
        newEnrollment: newEnrollment,
      );
      return;
    }
    try {
      final map = await _readAll();
      map[vaultId] = password;
      await _storage.write(key: _storageKey, value: jsonEncode(map));
    } catch (_) {
      // Ignore when secure storage is unavailable, such as widget tests.
    }
  }

  Future<String?> readMasterPassword({
    required String vaultId,
    bool webAuthCompleted = false,
  }) async {
    if (kIsWeb) {
      if (!webAuthCompleted) return null;
      return _webQuickUnlock.readUnlockedPassword(vaultId: vaultId);
    }
    final map = await _readAll();
    return map[vaultId];
  }

  Future<void> removeMasterPassword({required String vaultId}) async {
    if (kIsWeb) {
      await _webQuickUnlock.remove(vaultId: vaultId);
      return;
    }
    try {
      final map = await _readAll();
      map.remove(vaultId);
      await _storage.write(key: _storageKey, value: jsonEncode(map));
    } catch (_) {
      // Ignore when secure storage is unavailable, such as widget tests.
    }
  }

  Future<bool> hasStoredCredential({required String vaultId}) async {
    if (kIsWeb) {
      if (!await _webQuickUnlock.isAvailable()) {
        return false;
      }
      return _webQuickUnlock.hasEnrollment(vaultId: vaultId);
    }
    final map = await _readAll();
    return map.containsKey(vaultId);
  }

  Future<bool> purgeLegacyWebEnrollment({required String vaultId}) async {
    if (!kIsWeb) return false;
    if (!await _webQuickUnlock.hasLegacyEnrollment(vaultId: vaultId)) {
      return false;
    }
    await _webQuickUnlock.remove(vaultId: vaultId);
    return true;
  }

  Future<Map<String, String>> _readAll() async {
    try {
      final raw = await _storage.read(key: _storageKey);
      if (raw == null || raw.isEmpty) return <String, String>{};
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return <String, String>{};
      return decoded.map(
        (key, value) => MapEntry(key.toString(), value.toString()),
      );
    } catch (_) {
      return <String, String>{};
    }
  }
}

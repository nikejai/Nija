import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PinCredentialStore {
  static const _storageKey = 'nija_pin_unlock_v1';
  static const _version = 1;
  static const _iterations = 310000;
  static const _saltLength = 16;

  Future<void> saveMasterPassword({
    required String vaultId,
    required String pin,
    required String password,
  }) async {
    final salt = _randomBytes(_saltLength);
    final key = await _deriveKey(pin: pin, salt: salt);
    final encrypted = await _encryptPassword(
      secretKey: key,
      password: password,
    );
    final records = await _readAll();
    records[vaultId] = <String, Object>{
      'version': _version,
      'kdf': 'pbkdf2-hmac-sha256',
      'iterations': _iterations,
      'salt': base64Encode(salt),
      'cipherText': encrypted.cipherTextBase64,
      'nonce': encrypted.nonceBase64,
      'mac': encrypted.macBase64,
    };
    await _writeAll(records);
  }

  Future<String?> readMasterPassword({
    required String vaultId,
    required String pin,
  }) async {
    final records = await _readAll();
    final record = records[vaultId];
    if (record == null) return null;
    try {
      final salt = base64Decode(record['salt']?.toString() ?? '');
      final iterationsRaw = record['iterations'];
      final iterations = iterationsRaw is num
          ? iterationsRaw.toInt()
          : _iterations;
      final key = await _deriveKey(
        pin: pin,
        salt: salt,
        iterations: iterations,
      );
      return await _decryptPassword(
        secretKey: key,
        cipherTextBase64: record['cipherText']?.toString() ?? '',
        nonceBase64: record['nonce']?.toString() ?? '',
        macBase64: record['mac']?.toString() ?? '',
      );
    } catch (_) {
      return null;
    }
  }

  Future<bool> hasPin({required String vaultId}) async {
    final records = await _readAll();
    return records.containsKey(vaultId);
  }

  Future<void> remove({required String vaultId}) async {
    final records = await _readAll();
    records.remove(vaultId);
    await _writeAll(records);
  }

  Future<Map<String, Map<String, Object?>>> _readAll() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_storageKey);
      if (raw == null || raw.isEmpty) return <String, Map<String, Object?>>{};
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return <String, Map<String, Object?>>{};
      return decoded.map((key, value) {
        if (value is Map) {
          return MapEntry(key.toString(), Map<String, Object?>.from(value));
        }
        return MapEntry(key.toString(), <String, Object?>{});
      });
    } catch (_) {
      return <String, Map<String, Object?>>{};
    }
  }

  Future<void> _writeAll(Map<String, Map<String, Object?>> records) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey, jsonEncode(records));
  }

  Future<SecretKey> _deriveKey({
    required String pin,
    required List<int> salt,
    int iterations = _iterations,
  }) {
    final pbkdf2 = Pbkdf2(
      macAlgorithm: Hmac.sha256(),
      iterations: iterations,
      bits: 256,
    );
    return pbkdf2.deriveKey(
      secretKey: SecretKey(utf8.encode(pin)),
      nonce: salt,
    );
  }

  Future<_EncryptedPasswordPayload> _encryptPassword({
    required SecretKey secretKey,
    required String password,
  }) async {
    final algorithm = AesGcm.with256bits();
    final nonce = algorithm.newNonce();
    final secretBox = await algorithm.encrypt(
      utf8.encode(password),
      secretKey: secretKey,
      nonce: nonce,
    );
    return _EncryptedPasswordPayload(
      cipherTextBase64: base64Encode(secretBox.cipherText),
      nonceBase64: base64Encode(secretBox.nonce),
      macBase64: base64Encode(secretBox.mac.bytes),
    );
  }

  Future<String> _decryptPassword({
    required SecretKey secretKey,
    required String cipherTextBase64,
    required String nonceBase64,
    required String macBase64,
  }) async {
    final algorithm = AesGcm.with256bits();
    final secretBox = SecretBox(
      base64Decode(cipherTextBase64),
      nonce: base64Decode(nonceBase64),
      mac: Mac(base64Decode(macBase64)),
    );
    final clearText = await algorithm.decrypt(secretBox, secretKey: secretKey);
    return utf8.decode(clearText);
  }

  List<int> _randomBytes(int length) {
    final random = Random.secure();
    return Uint8List.fromList(
      List<int>.generate(length, (_) => random.nextInt(256)),
    );
  }
}

class _EncryptedPasswordPayload {
  const _EncryptedPasswordPayload({
    required this.cipherTextBase64,
    required this.nonceBase64,
    required this.macBase64,
  });

  final String cipherTextBase64;
  final String nonceBase64;
  final String macBase64;
}

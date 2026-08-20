import 'dart:convert';

import 'package:cryptography/cryptography.dart';

import '../platform/nija_browser_bridge.dart';
import 'web_quick_unlock_vault_base.dart';

WebQuickUnlockVault createWebQuickUnlockVault() => WebQuickUnlockVaultWeb();

class WebQuickUnlockVaultWeb extends WebQuickUnlockVault {
  static const _dbName = 'nija_quick_unlock';
  static const _storeName = 'records';
  static const _dbVersion = 1;
  static const _recordVersion = 4;

  String? _authenticatedVaultId;
  String? _authenticatedPrfKeyBase64Url;

  @override
  Future<bool> isAvailable() async {
    try {
      return nijaWebAuthnIsAvailable();
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> isWebAuthnSupported() async {
    try {
      return nijaWebAuthnIsSupported();
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> supportsSecureQuickUnlock() async {
    try {
      return nijaWebAuthnSupportsPrf();
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> hasLegacyEnrollment({required String vaultId}) async {
    final record = await _readRecord(vaultId);
    if (record == null) return false;
    return record.version != _recordVersion;
  }

  @override
  Future<void> enroll({
    required String vaultId,
    required String password,
    required String displayName,
    bool newEnrollment = false,
  }) async {
    if (newEnrollment) {
      await _registerAndPersistNewCredential(
        vaultId: vaultId,
        password: password,
        displayName: displayName,
      );
      return;
    }

    final existing = await _readRecord(vaultId);
    if (existing != null && existing.version != _recordVersion) {
      await remove(vaultId: vaultId);
    }

    final current = await _readRecord(vaultId);
    if (current != null && current.version == _recordVersion) {
      final authenticated = await authenticate(vaultId: vaultId);
      if (!authenticated) {
        throw StateError(
          'WebAuthn verification failed while updating quick unlock.',
        );
      }
      final encrypted = await _encryptPassword(
        secretKey: _secretKeyFromPrfBase64Url(_authenticatedPrfKeyBase64Url),
        password: password,
      );
      await _writeRecord(
        vaultId: vaultId,
        record: _QuickUnlockRecord(
          version: _recordVersion,
          credentialId: current.credentialId,
          prfSaltBase64Url: current.prfSaltBase64Url,
          cipherTextBase64: encrypted.cipherTextBase64,
          nonceBase64: encrypted.nonceBase64,
          macBase64: encrypted.macBase64,
        ),
      );
      clearAuthentication();
      return;
    }

    await _registerAndPersistNewCredential(
      vaultId: vaultId,
      password: password,
      displayName: displayName,
    );
  }

  Future<void> _registerAndPersistNewCredential({
    required String vaultId,
    required String password,
    required String displayName,
  }) async {
    NijaWebAuthnRegistration? registration;
    try {
      registration = await nijaWebAuthnRegisterQuickUnlock(
        vaultId: vaultId,
        displayName: displayName,
      );
    } catch (error) {
      throw StateError(
        _webAuthnErrorMessage(error, fallback: 'registration_failed'),
      );
    }
    if (registration == null) {
      throw StateError('WebAuthn registration failed.');
    }
    final credentialId = registration.credentialId;
    final prfSaltBase64Url = registration.prfSalt;
    final prfKeyBase64Url = registration.prfKey;
    if (credentialId.isEmpty) {
      throw StateError('WebAuthn registration failed.');
    }
    if (prfSaltBase64Url.isEmpty || prfKeyBase64Url.isEmpty) {
      throw StateError('prf_unavailable');
    }
    final encrypted = await _encryptPassword(
      secretKey: _secretKeyFromPrfBase64Url(prfKeyBase64Url),
      password: password,
    );
    await _writeRecord(
      vaultId: vaultId,
      record: _QuickUnlockRecord(
        version: _recordVersion,
        credentialId: credentialId,
        prfSaltBase64Url: prfSaltBase64Url,
        cipherTextBase64: encrypted.cipherTextBase64,
        nonceBase64: encrypted.nonceBase64,
        macBase64: encrypted.macBase64,
      ),
    );
    clearAuthentication();
  }

  String _webAuthnErrorMessage(Object? error, {required String fallback}) {
    final raw = error?.toString() ?? fallback;
    if (raw.contains('NotAllowedError')) {
      return 'not_allowed:Confirm with Touch ID or Windows Hello to continue.';
    }
    if (raw.contains('InvalidStateError')) {
      return 'credential_exists:Device unlock is already set up for this vault in the browser.';
    }
    return raw;
  }

  @override
  Future<bool> authenticate({required String vaultId}) async {
    clearAuthentication();
    final record = await _readRecord(vaultId);
    if (record == null || record.version != _recordVersion) return false;
    try {
      final result = await nijaWebAuthnAuthenticateQuickUnlock(
        credentialId: record.credentialId,
        prfSalt: record.prfSaltBase64Url,
      );
      if (result == null) return false;
      if (!result.ok) return false;
      final prfKeyBase64Url = result.prfKey;
      if (prfKeyBase64Url.isEmpty) return false;
      _authenticatedVaultId = vaultId;
      _authenticatedPrfKeyBase64Url = prfKeyBase64Url;
      return true;
    } catch (_) {
      clearAuthentication();
      return false;
    }
  }

  @override
  Future<String?> readUnlockedPassword({required String vaultId}) async {
    if (_authenticatedVaultId != vaultId) {
      return null;
    }
    final record = await _readRecord(vaultId);
    if (record == null || record.version != _recordVersion) {
      clearAuthentication();
      return null;
    }
    try {
      final password = await _decryptPassword(
        secretKey: _secretKeyFromPrfBase64Url(_authenticatedPrfKeyBase64Url),
        cipherTextBase64: record.cipherTextBase64,
        nonceBase64: record.nonceBase64,
        macBase64: record.macBase64,
      );
      clearAuthentication();
      return password;
    } catch (_) {
      clearAuthentication();
      return null;
    }
  }

  @override
  Future<void> remove({required String vaultId}) async {
    await nijaDeleteIndexedText(
      dbName: _dbName,
      storeName: _storeName,
      key: vaultId,
      version: _dbVersion,
    );
    if (_authenticatedVaultId == vaultId) {
      clearAuthentication();
    }
  }

  @override
  Future<bool> hasEnrollment({required String vaultId}) async {
    final record = await _readRecord(vaultId);
    return record != null && record.version == _recordVersion;
  }

  @override
  void clearAuthentication() {
    _authenticatedVaultId = null;
    _authenticatedPrfKeyBase64Url = null;
  }

  Future<void> _writeRecord({
    required String vaultId,
    required _QuickUnlockRecord record,
  }) async {
    await nijaWriteIndexedText(
      dbName: _dbName,
      storeName: _storeName,
      key: vaultId,
      value: jsonEncode(<String, Object>{
        'version': record.version,
        'credentialId': record.credentialId,
        'prfSalt': record.prfSaltBase64Url,
        'cipherText': record.cipherTextBase64,
        'nonce': record.nonceBase64,
        'mac': record.macBase64,
      }),
      version: _dbVersion,
    );
  }

  Future<_QuickUnlockRecord?> _readRecord(String vaultId) async {
    final rawResult = await nijaReadIndexedText(
      dbName: _dbName,
      storeName: _storeName,
      key: vaultId,
      version: _dbVersion,
    );
    if (rawResult == null || rawResult.isEmpty) return null;
    final decoded = jsonDecode(rawResult);
    if (decoded is! Map) return null;
    final result = decoded;
    final versionRaw = result['version'];
    final version = versionRaw is num ? versionRaw.toInt() : 0;
    final credentialId = result['credentialId']?.toString() ?? '';
    final prfSaltBase64Url = result['prfSalt']?.toString() ?? '';
    final cipherTextBase64 = result['cipherText']?.toString() ?? '';
    final nonceBase64 = result['nonce']?.toString() ?? '';
    final macBase64 = result['mac']?.toString() ?? '';
    if (credentialId.isEmpty ||
        cipherTextBase64.isEmpty ||
        nonceBase64.isEmpty ||
        macBase64.isEmpty) {
      return null;
    }
    if (version == _recordVersion && prfSaltBase64Url.isEmpty) {
      return null;
    }
    return _QuickUnlockRecord(
      version: version,
      credentialId: credentialId,
      prfSaltBase64Url: prfSaltBase64Url,
      cipherTextBase64: cipherTextBase64,
      nonceBase64: nonceBase64,
      macBase64: macBase64,
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

  SecretKey _secretKeyFromPrfBase64Url(String? keyBase64Url) {
    if (keyBase64Url == null || keyBase64Url.isEmpty) {
      throw StateError('Missing web quick unlock key.');
    }
    final bytes = base64Url.decode(base64Url.normalize(keyBase64Url));
    if (bytes.length != 32) {
      throw StateError('Invalid web quick unlock key.');
    }
    return SecretKey(bytes);
  }
}

class _QuickUnlockRecord {
  const _QuickUnlockRecord({
    required this.version,
    required this.credentialId,
    required this.prfSaltBase64Url,
    required this.cipherTextBase64,
    required this.nonceBase64,
    required this.macBase64,
  });

  final int version;
  final String credentialId;
  final String prfSaltBase64Url;
  final String cipherTextBase64;
  final String nonceBase64;
  final String macBase64;
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

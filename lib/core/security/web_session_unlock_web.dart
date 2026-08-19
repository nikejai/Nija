// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'web_session_unlock_stub.dart';

WebSessionUnlock createWebSessionUnlock() => WebSessionUnlockWeb();

class WebSessionUnlockWeb extends WebSessionUnlock {
  final Map<String, String> _passwords = <String, String>{};

  @override
  void rememberPassword({required String vaultId, required String password}) {
    if (vaultId.isEmpty || password.isEmpty) return;
    _passwords[vaultId] = password;
  }

  @override
  String? readPassword({required String vaultId}) {
    return _passwords[vaultId];
  }

  @override
  bool hasPassword({required String vaultId}) {
    return _passwords.containsKey(vaultId);
  }

  @override
  void clearPassword({required String vaultId}) {
    _passwords.remove(vaultId);
  }

  @override
  void clearAll() {
    _passwords.clear();
  }
}

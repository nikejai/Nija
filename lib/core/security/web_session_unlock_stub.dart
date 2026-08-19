class WebSessionUnlock {
  void rememberPassword({required String vaultId, required String password}) {}

  String? readPassword({required String vaultId}) => null;

  bool hasPassword({required String vaultId}) => false;

  void clearPassword({required String vaultId}) {}

  void clearAll() {}
}

WebSessionUnlock createWebSessionUnlock() => WebSessionUnlock();

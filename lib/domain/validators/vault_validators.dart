class VaultValidators {
  static bool isStrongEnoughMasterPassword(String value) {
    if (value.length < 10) return false;
    final hasLetter = value.contains(RegExp(r'[A-Za-z]'));
    final hasDigit = value.contains(RegExp(r'\d'));
    return hasLetter && hasDigit;
  }

  static bool isValidSensitiveFieldLabel(String value) {
    final normalized = value.trim();
    return normalized.isNotEmpty && normalized.length <= 40;
  }
}

class VaultLimits {
  VaultLimits._();

  static const int freeVaultBytes = 1024 * 1024 * 1024;
  static const int legacyWebVaultBytes = 1024 * 1024 * 1024;
  static const int paidVaultBytes = 1024 * 1024 * 1024;
  static const int maxDocumentBytes = 25 * 1024 * 1024;
  static const int freeVaultCount = 99;
  static const int paidAndroidVaultCount = 99;

  static int get maxVaultBytes => freeVaultBytes;

  static int maxVaultBytesFor({
    required int currentVaultSizeBytes,
    bool expandedStorageEntitled = true,
  }) {
    if (currentVaultSizeBytes > paidVaultBytes) {
      return currentVaultSizeBytes;
    }
    return paidVaultBytes;
  }

  static int maxVaultCountFor({
    required bool isAndroid,
    bool expandedStorageEntitled = true,
  }) {
    return freeVaultCount;
  }

  static String formatBytes(int bytes) {
    if (bytes <= 0) return '0 B';
    const units = <String>['B', 'KB', 'MB', 'GB'];
    var value = bytes.toDouble();
    var unit = 0;
    while (value >= 1024 && unit < units.length - 1) {
      value /= 1024;
      unit += 1;
    }
    final decimals = value >= 100
        ? 0
        : value >= 10
        ? 1
        : 2;
    return '${value.toStringAsFixed(decimals)} ${units[unit]}';
  }
}

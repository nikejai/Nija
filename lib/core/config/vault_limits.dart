import 'app_features.dart';

class VaultLimits {
  VaultLimits._();

  static const int freeVaultBytes = 100 * 1024 * 1024;
  static const int legacyWebVaultBytes = 1024 * 1024 * 1024;
  static const int paidVaultBytes = legacyWebVaultBytes;
  static const int maxDocumentBytes = 5 * 1024 * 1024;

  static int get maxVaultBytes => AppFeatures.supportsExpandedVaultStorage
      ? paidVaultBytes
      : freeVaultBytes;

  static int maxVaultBytesFor({
    required int currentVaultSizeBytes,
    bool expandedStorageEntitled = false,
  }) {
    if (expandedStorageEntitled || AppFeatures.supportsExpandedVaultStorage) {
      return paidVaultBytes;
    }
    if (currentVaultSizeBytes > freeVaultBytes) {
      return currentVaultSizeBytes > legacyWebVaultBytes
          ? currentVaultSizeBytes
          : legacyWebVaultBytes;
    }
    return freeVaultBytes;
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

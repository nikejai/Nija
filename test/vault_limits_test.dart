import 'package:flutter_test/flutter_test.dart';
import 'package:nija/core/config/vault_limits.dart';

void main() {
  test('vault capacity is 1 GB local storage by default', () {
    expect(VaultLimits.freeVaultBytes, 1024 * 1024 * 1024);
    expect(
      VaultLimits.maxVaultBytesFor(currentVaultSizeBytes: 0),
      VaultLimits.freeVaultBytes,
    );
  });

  test('vaults already above 1 GB can open safely', () {
    const oversized = VaultLimits.legacyWebVaultBytes + 4096;

    expect(
      VaultLimits.maxVaultBytesFor(currentVaultSizeBytes: oversized),
      oversized,
    );
  });

  test('multi-vault is free and unlimited across platforms', () {
    expect(
      VaultLimits.maxVaultCountFor(isAndroid: false),
      VaultLimits.freeVaultCount,
    );
    expect(
      VaultLimits.maxVaultCountFor(
        isAndroid: true,
        expandedStorageEntitled: false,
      ),
      VaultLimits.freeVaultCount,
    );
    expect(
      VaultLimits.maxVaultCountFor(
        isAndroid: true,
        expandedStorageEntitled: true,
      ),
      VaultLimits.paidAndroidVaultCount,
    );
  });
}

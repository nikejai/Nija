import 'package:flutter_test/flutter_test.dart';
import 'package:nija/core/config/vault_limits.dart';

void main() {
  test('vault capacity is 151 MB for free users and 1 GB for paid users', () {
    expect(VaultLimits.freeVaultBytes, 151 * 1024 * 1024);
    expect(VaultLimits.paidVaultBytes, 1024 * 1024 * 1024);
    expect(
      VaultLimits.maxVaultBytesFor(currentVaultSizeBytes: 0),
      VaultLimits.freeVaultBytes,
    );
    expect(
      VaultLimits.maxVaultBytesFor(
        currentVaultSizeBytes: 0,
        expandedStorageEntitled: true,
      ),
      VaultLimits.paidVaultBytes,
    );
  });

  test('vaults already above tier limit can open safely', () {
    const oversizedFree = VaultLimits.freeVaultBytes + 4096;
    const oversizedPaid = VaultLimits.paidVaultBytes + 4096;

    expect(
      VaultLimits.maxVaultBytesFor(currentVaultSizeBytes: oversizedFree),
      oversizedFree,
    );
    expect(
      VaultLimits.maxVaultBytesFor(
        currentVaultSizeBytes: oversizedPaid,
        expandedStorageEntitled: true,
      ),
      oversizedPaid,
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

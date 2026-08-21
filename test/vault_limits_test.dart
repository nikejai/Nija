import 'package:flutter_test/flutter_test.dart';
import 'package:nija/core/config/vault_limits.dart';

void main() {
  test('free vault limit is 151 MB for new and small vaults', () {
    expect(VaultLimits.freeVaultBytes, 151 * 1024 * 1024);
    expect(
      VaultLimits.maxVaultBytesFor(currentVaultSizeBytes: 0),
      VaultLimits.freeVaultBytes,
    );
    expect(
      VaultLimits.maxVaultBytesFor(
        currentVaultSizeBytes: VaultLimits.freeVaultBytes - 1,
      ),
      VaultLimits.freeVaultBytes,
    );
  });

  test('legacy vaults above 151 MB can continue up to 1 GB', () {
    expect(
      VaultLimits.maxVaultBytesFor(
        currentVaultSizeBytes: VaultLimits.freeVaultBytes + 1,
      ),
      VaultLimits.legacyWebVaultBytes,
    );
  });

  test('expanded storage entitlement unlocks the 1 GB limit', () {
    expect(
      VaultLimits.maxVaultBytesFor(
        currentVaultSizeBytes: 0,
        expandedStorageEntitled: true,
      ),
      VaultLimits.paidVaultBytes,
    );
  });

  test('vaults already above 1 GB can open but cannot grow further', () {
    const oversized = VaultLimits.legacyWebVaultBytes + 4096;

    expect(
      VaultLimits.maxVaultBytesFor(currentVaultSizeBytes: oversized),
      oversized,
    );
  });

  test('free app supports one vault and paid Android supports more', () {
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

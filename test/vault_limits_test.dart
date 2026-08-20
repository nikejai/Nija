import 'package:flutter_test/flutter_test.dart';
import 'package:nija/core/config/vault_limits.dart';

void main() {
  test('free vault limit is 100 MB for new and small vaults', () {
    expect(VaultLimits.freeVaultBytes, 100 * 1024 * 1024);
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

  test('legacy vaults above 100 MB can continue up to 1 GB', () {
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
}

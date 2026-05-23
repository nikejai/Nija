import '../../domain/models/vault.dart';
import '../../domain/models/vault_payload.dart';

class VaultOperationProgress {
  const VaultOperationProgress({
    required this.value,
    required this.message,
  });

  final double value;
  final String message;
}

typedef VaultProgressCallback = void Function(VaultOperationProgress progress);

abstract class VaultService {
  Future<String> readRawVaultFile({
    required String filePath,
  });

  Future<void> writeRawVaultFile({
    required String filePath,
    required String rawContent,
  });

  Future<bool> vaultExists({
    required String filePath,
  });

  Future<Vault> createVault({
    required String filePath,
    required String vaultId,
    required String vaultName,
    required String guardianProfileId,
    required String password,
    required String recoveryPhrase,
    VaultProgressCallback? onProgress,
  });

  Future<Vault> unlockVault({
    required String filePath,
    required String password,
    VaultProgressCallback? onProgress,
  });

  Future<Vault> unlockVaultWithRecoveryPhrase({
    required String filePath,
    required String recoveryPhrase,
    VaultProgressCallback? onProgress,
  });

  Future<void> resetMasterPasswordAfterRecovery({
    required String filePath,
    required String recoveryPhrase,
    required String newPassword,
    VaultProgressCallback? onProgress,
  });

  Future<void> rotateMasterPassword({
    required String filePath,
    required String currentPassword,
    required String newPassword,
    VaultProgressCallback? onProgress,
  });

  Future<void> rotateRecoveryPhrase({
    required String filePath,
    required String currentRecoveryPhrase,
    required String newRecoveryPhrase,
    VaultProgressCallback? onProgress,
  });

  Future<VaultPayload> readVaultPayload({
    required String filePath,
    required String password,
    VaultProgressCallback? onProgress,
  });

  Future<void> persistVaultPayload({
    required String filePath,
    required String password,
    required VaultPayload payload,
    VaultProgressCallback? onProgress,
  });
}

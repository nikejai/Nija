import '../../domain/models/vault.dart';
import '../../domain/models/vault_payload.dart';
import '../../domain/models/vault_transfer_result.dart';

class VaultOperationProgress {
  const VaultOperationProgress({required this.value, required this.message});

  final double value;
  final String message;
}

typedef VaultProgressCallback = void Function(VaultOperationProgress progress);

abstract class VaultService {
  Future<String> readRawVaultFile({required String filePath});

  Future<void> writeRawVaultFile({
    required String filePath,
    required String rawContent,
  });

  Future<bool> vaultExists({required String filePath});

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

  Future<String> persistVaultDocument({
    required String filePath,
    required String password,
    required List<int> bytes,
    required String documentId,
    VaultProgressCallback? onProgress,
  });

  Future<String> persistVaultDocumentStream({
    required String filePath,
    required String password,
    required Stream<List<int>> chunks,
    required int sizeBytes,
    required String documentId,
    VaultProgressCallback? onProgress,
  });

  Future<List<int>> readVaultDocument({
    required String filePath,
    required String password,
    required String sectionName,
    VaultProgressCallback? onProgress,
  });

  Future<int> readVaultSizeBytes({required String filePath});

  Future<void> renameVault({required String filePath, required String label});

  Future<void> markVaultConflictResolved({
    required String filePath,
    required String resolvedVaultVersionId,
  });

  Future<ImportResult> importNijaFile({
    required String filePath,
    required String unlockCredential,
    bool confirmReplace = false,
  });

  Future<ExportResult> exportVault({
    required String vaultId,
    required String destinationPath,
  });

  Future<Map<String, dynamic>> readVaultInternals({required String filePath});
}

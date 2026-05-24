enum ImportStatus {
  imported,
  alreadyUpToDate,
  incomingOlder,
  conflictCreated,
  failed,
}

enum ExportStatus { exported, failed }

class ImportResult {
  const ImportResult({
    required this.status,
    required this.vaultId,
    required this.userSafeMessage,
    this.localRevision,
    this.incomingRevision,
    this.localUpdatedAt,
    this.incomingUpdatedAt,
    this.conflictVaultId,
  });

  final ImportStatus status;
  final String vaultId;
  final int? localRevision;
  final int? incomingRevision;
  final String? localUpdatedAt;
  final String? incomingUpdatedAt;
  final String? conflictVaultId;
  final String userSafeMessage;
}

class ExportResult {
  const ExportResult({
    required this.status,
    required this.vaultId,
    required this.vaultVersionId,
    required this.revision,
    required this.updatedAt,
    required this.destinationPath,
    required this.userSafeMessage,
  });

  final ExportStatus status;
  final String vaultId;
  final String vaultVersionId;
  final int revision;
  final String updatedAt;
  final String destinationPath;
  final String userSafeMessage;
}

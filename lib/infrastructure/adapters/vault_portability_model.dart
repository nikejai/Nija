class ImportedVaultFile {
  const ImportedVaultFile({
    required this.storageId,
    required this.label,
    required this.content,
    this.sourceDescription = '',
  });

  final String storageId;
  final String label;
  final String content;
  final String sourceDescription;
}

class CloudVaultBackupFile {
  const CloudVaultBackupFile({
    required this.storageId,
    required this.label,
    required this.content,
    this.fileName = '',
    this.modifiedAt,
    this.revision = 0,
    this.versionId = '',
    this.updatedAt = '',
    this.driveFileId = '',
    this.listedVaultId = '',
  });

  final String storageId;
  final String label;
  final String content;
  final String fileName;
  final DateTime? modifiedAt;
  final int revision;
  final String versionId;
  final String updatedAt;
  final String driveFileId;
  final String listedVaultId;

  bool get hasContent => content.trim().isNotEmpty;
}

class ImportedVaultFile {
  const ImportedVaultFile({
    required this.storageId,
    required this.label,
    required this.content,
  });

  final String storageId;
  final String label;
  final String content;
}

class CloudVaultBackupFile {
  const CloudVaultBackupFile({
    required this.storageId,
    required this.label,
    required this.content,
  });

  final String storageId;
  final String label;
  final String content;
}

class VaultRegistryEntry {
  const VaultRegistryEntry({
    required this.id,
    required this.vaultId,
    required this.label,
    required this.revision,
    required this.vaultVersionId,
    required this.updatedAt,
    required this.addedAtEpochMs,
    this.lastOpenedAtEpochMs = 0,
    this.isConflict = false,
  });

  final String id;
  final String vaultId;
  final String label;
  final int revision;
  final String vaultVersionId;
  final String updatedAt;
  final int addedAtEpochMs;
  final int lastOpenedAtEpochMs;
  final bool isConflict;

  VaultRegistryEntry copyWith({
    String? label,
    int? revision,
    String? vaultVersionId,
    String? updatedAt,
    int? lastOpenedAtEpochMs,
    bool? isConflict,
  }) {
    return VaultRegistryEntry(
      id: id,
      vaultId: vaultId,
      label: label ?? this.label,
      revision: revision ?? this.revision,
      vaultVersionId: vaultVersionId ?? this.vaultVersionId,
      updatedAt: updatedAt ?? this.updatedAt,
      addedAtEpochMs: addedAtEpochMs,
      lastOpenedAtEpochMs: lastOpenedAtEpochMs ?? this.lastOpenedAtEpochMs,
      isConflict: isConflict ?? this.isConflict,
    );
  }
}

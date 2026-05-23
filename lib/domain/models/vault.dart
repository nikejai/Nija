class Vault {
  const Vault({
    required this.id,
    required this.formatVersion,
    required this.guardianProfileId,
    required this.items,
    required this.notes,
  });

  final String id;
  final int formatVersion;
  final String guardianProfileId;
  final List<String> items;
  final List<String> notes;
}

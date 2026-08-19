class VaultReference {
  const VaultReference({
    required this.id,
    required this.label,
    required this.addedAtEpochMs,
    this.lastOpenedAtEpochMs = 0,
    this.sourceDescription = '',
  });

  final String id;
  final String label;
  final int addedAtEpochMs;
  final int lastOpenedAtEpochMs;
  final String sourceDescription;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'label': label,
    'addedAtEpochMs': addedAtEpochMs,
    'lastOpenedAtEpochMs': lastOpenedAtEpochMs,
    'sourceDescription': sourceDescription,
  };

  factory VaultReference.fromJson(Map<String, dynamic> json) {
    return VaultReference(
      id: json['id']?.toString() ?? '',
      label: json['label']?.toString() ?? '',
      addedAtEpochMs: (json['addedAtEpochMs'] as num?)?.toInt() ?? 0,
      lastOpenedAtEpochMs: (json['lastOpenedAtEpochMs'] as num?)?.toInt() ?? 0,
      sourceDescription: json['sourceDescription']?.toString() ?? '',
    );
  }
}

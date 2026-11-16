class LocalVaultSnapshot {
  const LocalVaultSnapshot({
    required this.id,
    required this.vaultId,
    required this.filePath,
    required this.timestamp,
    required this.sizeBytes,
  });

  final String id;
  final String vaultId;
  final String filePath;
  final DateTime timestamp;
  final int sizeBytes;

  Map<String, dynamic> toJson() => {
        'id': id,
        'vaultId': vaultId,
        'filePath': filePath,
        'timestamp': timestamp.toIso8601String(),
        'sizeBytes': sizeBytes,
      };

  factory LocalVaultSnapshot.fromJson(Map<String, dynamic> json) {
    return LocalVaultSnapshot(
      id: json['id'] as String? ?? '',
      vaultId: json['vaultId'] as String? ?? '',
      filePath: json['filePath'] as String? ?? '',
      timestamp: DateTime.tryParse(json['timestamp'] as String? ?? '') ??
          DateTime.now(),
      sizeBytes: (json['sizeBytes'] as num?)?.toInt() ?? 0,
    );
  }
}

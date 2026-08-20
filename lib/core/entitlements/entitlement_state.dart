class EntitlementState {
  const EntitlementState({
    required this.expandedVaultStorage,
    required this.source,
    required this.lastVerifiedAt,
    this.productId,
  });

  const EntitlementState.free()
    : expandedVaultStorage = false,
      source = 'free',
      lastVerifiedAt = null,
      productId = null;

  final bool expandedVaultStorage;
  final String source;
  final DateTime? lastVerifiedAt;
  final String? productId;

  bool get isPlayVerified => source == 'google_play';

  EntitlementState copyWith({
    bool? expandedVaultStorage,
    String? source,
    DateTime? lastVerifiedAt,
    String? productId,
  }) {
    return EntitlementState(
      expandedVaultStorage: expandedVaultStorage ?? this.expandedVaultStorage,
      source: source ?? this.source,
      lastVerifiedAt: lastVerifiedAt ?? this.lastVerifiedAt,
      productId: productId ?? this.productId,
    );
  }
}

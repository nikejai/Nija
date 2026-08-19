import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'entitlement_service_base.dart';
import 'entitlement_state.dart';

class SecureEntitlementCache implements EntitlementCache {
  SecureEntitlementCache({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  static const _key = 'nija_entitlement_state_v1';

  final FlutterSecureStorage _storage;

  @override
  Future<EntitlementState> read() async {
    try {
      final raw = await _storage.read(key: _key);
      if (raw == null || raw.trim().isEmpty) {
        return const EntitlementState.free();
      }
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        return const EntitlementState.free();
      }
      return EntitlementState(
        expandedVaultStorage: decoded['expandedVaultStorage'] == true,
        source: decoded['source']?.toString() ?? 'free',
        productId: decoded['productId']?.toString(),
        lastVerifiedAt: DateTime.tryParse(
          decoded['lastVerifiedAt']?.toString() ?? '',
        ),
      );
    } catch (_) {
      return const EntitlementState.free();
    }
  }

  @override
  Future<void> write(EntitlementState state) async {
    try {
      await _storage.write(
        key: _key,
        value: jsonEncode({
          'expandedVaultStorage': state.expandedVaultStorage,
          'source': state.source,
          'productId': state.productId,
          'lastVerifiedAt': state.lastVerifiedAt?.toIso8601String(),
        }),
      );
    } catch (_) {}
  }

  @override
  Future<void> clear() async {
    try {
      await _storage.delete(key: _key);
    } catch (_) {}
  }
}

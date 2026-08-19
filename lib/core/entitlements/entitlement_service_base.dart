import 'dart:async';

import 'package:flutter/foundation.dart';

import 'entitlement_state.dart';

class EntitlementProducts {
  EntitlementProducts._();

  static const expandedVaultStorage = 'nija_expanded_vault_lifetime';
}

abstract class EntitlementService extends ChangeNotifier {
  EntitlementState get state;

  bool get canPurchaseExpandedVaultStorage;

  bool get isPurchaseInProgress;

  String? get lastErrorMessage;

  Future<void> initialize();

  Future<void> refresh();

  Future<bool> buyExpandedVaultStorage();

  @mustCallSuper
  @override
  void dispose() {
    super.dispose();
  }
}

abstract class EntitlementCache {
  Future<EntitlementState> read();

  Future<void> write(EntitlementState state);

  Future<void> clear();
}

class MemoryEntitlementCache implements EntitlementCache {
  EntitlementState _state;

  MemoryEntitlementCache([EntitlementState? initial])
    : _state = initial ?? const EntitlementState.free();

  @override
  Future<EntitlementState> read() async => _state;

  @override
  Future<void> write(EntitlementState state) async {
    _state = state;
  }

  @override
  Future<void> clear() async {
    _state = const EntitlementState.free();
  }
}

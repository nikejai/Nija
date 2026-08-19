import 'dart:async';
import 'dart:io';

import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';

import 'entitlement_cache.dart';
import 'entitlement_service_base.dart';
import 'entitlement_state.dart';

class NijaEntitlementService extends EntitlementService {
  NijaEntitlementService({EntitlementCache? cache, InAppPurchase? purchases})
    : _cache = cache ?? SecureEntitlementCache(),
      _purchases = purchases ?? InAppPurchase.instance;

  final EntitlementCache _cache;
  final InAppPurchase _purchases;
  StreamSubscription<List<PurchaseDetails>>? _purchaseSubscription;

  EntitlementState _state = const EntitlementState.free();
  bool _purchaseInProgress = false;
  String? _lastErrorMessage;

  @override
  EntitlementState get state => _state;

  @override
  bool get canPurchaseExpandedVaultStorage =>
      Platform.isAndroid && !_state.expandedVaultStorage;

  @override
  bool get isPurchaseInProgress => _purchaseInProgress;

  @override
  String? get lastErrorMessage => _lastErrorMessage;

  @override
  Future<void> initialize() async {
    _setState(await _cache.read());
    if (!Platform.isAndroid) return;
    _purchaseSubscription ??= _purchases.purchaseStream.listen(
      _handlePurchaseUpdates,
      onError: (Object error) {
        _lastErrorMessage = 'Purchase update failed.';
        notifyListeners();
      },
    );
    await refresh();
  }

  @override
  Future<void> refresh() async {
    _lastErrorMessage = null;
    final cached = await _cache.read();
    _setState(cached);
    if (!Platform.isAndroid) return;
    try {
      if (!await _purchases.isAvailable()) return;
      final addition = _purchases
          .getPlatformAddition<InAppPurchaseAndroidPlatformAddition>();
      final response = await addition.queryPastPurchases();
      if (response.error != null) {
        _lastErrorMessage = 'Could not verify Play purchase.';
        notifyListeners();
        return;
      }
      await _applyPurchases(response.pastPurchases);
    } catch (_) {
      _lastErrorMessage = 'Could not verify Play purchase.';
      notifyListeners();
    }
  }

  @override
  Future<bool> buyExpandedVaultStorage() async {
    if (!Platform.isAndroid) {
      _lastErrorMessage = 'Play purchases are available on Android only.';
      notifyListeners();
      return false;
    }
    if (_purchaseInProgress) return false;
    _purchaseInProgress = true;
    _lastErrorMessage = null;
    notifyListeners();
    try {
      if (!await _purchases.isAvailable()) {
        _lastErrorMessage = 'Google Play Billing is unavailable.';
        return false;
      }
      final response = await _purchases.queryProductDetails({
        EntitlementProducts.expandedVaultStorage,
      });
      if (response.error != null || response.productDetails.isEmpty) {
        _lastErrorMessage =
            'Storage upgrade is not available. Check Play Console setup.';
        return false;
      }
      final details = response.productDetails.firstWhere(
        (item) => item.id == EntitlementProducts.expandedVaultStorage,
        orElse: () => response.productDetails.first,
      );
      return _purchases.buyNonConsumable(
        purchaseParam: PurchaseParam(productDetails: details),
      );
    } catch (_) {
      _lastErrorMessage = 'Could not start Google Play purchase.';
      return false;
    } finally {
      _purchaseInProgress = false;
      notifyListeners();
    }
  }

  Future<void> _handlePurchaseUpdates(List<PurchaseDetails> purchases) async {
    var handledTerminalPurchase = false;
    for (final purchase in purchases) {
      if (purchase.productID != EntitlementProducts.expandedVaultStorage) {
        continue;
      }
      switch (purchase.status) {
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          await _grantExpandedStorageFromPlay(purchase);
          handledTerminalPurchase = true;
        case PurchaseStatus.error:
          _lastErrorMessage =
              purchase.error?.message ?? 'Google Play purchase failed.';
          handledTerminalPurchase = true;
        case PurchaseStatus.pending:
          _lastErrorMessage = 'Google Play purchase is still pending.';
        case PurchaseStatus.canceled:
          _lastErrorMessage = 'Google Play purchase was canceled.';
          handledTerminalPurchase = true;
      }
      if (purchase.pendingCompletePurchase &&
          purchase.status != PurchaseStatus.pending) {
        try {
          await _purchases.completePurchase(purchase);
        } catch (_) {
          _lastErrorMessage = 'Purchase granted, but acknowledgement failed.';
        }
      }
    }
    if (handledTerminalPurchase) {
      _purchaseInProgress = false;
    }
    notifyListeners();
  }

  Future<void> _applyPurchases(List<PurchaseDetails> purchases) async {
    final matching = purchases.where(
      (purchase) =>
          purchase.productID == EntitlementProducts.expandedVaultStorage &&
          (purchase.status == PurchaseStatus.purchased ||
              purchase.status == PurchaseStatus.restored),
    );
    if (matching.isEmpty) {
      final cached = await _cache.read();
      if (cached.expandedVaultStorage) {
        // Keep the locally cached lifetime entitlement for offline starts and
        // transient Play query gaps. A future backend can add revocation.
        _setState(cached);
      }
      return;
    }
    await _grantExpandedStorageFromPlay(matching.first);
  }

  Future<void> _grantExpandedStorageFromPlay(PurchaseDetails purchase) async {
    final next = EntitlementState(
      expandedVaultStorage: true,
      source: 'google_play',
      productId: purchase.productID,
      lastVerifiedAt: DateTime.now().toUtc(),
    );
    await _cache.write(next);
    _setState(next);
  }

  void _setState(EntitlementState next) {
    if (_state.expandedVaultStorage == next.expandedVaultStorage &&
        _state.source == next.source &&
        _state.productId == next.productId &&
        _state.lastVerifiedAt == next.lastVerifiedAt) {
      return;
    }
    _state = next;
    notifyListeners();
  }

  @override
  void dispose() {
    unawaited(_purchaseSubscription?.cancel());
    super.dispose();
  }
}

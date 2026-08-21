import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
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
    _logPlayBilling('initialize platform=${Platform.operatingSystem}');
    _setState(await _cache.read());
    _logPlayBilling(
      'cached entitlement expanded=${_state.expandedVaultStorage} '
      'source=${_state.source}',
    );
    if (!Platform.isAndroid) {
      _logPlayBilling('skip initialize: Play Billing is Android-only');
      return;
    }
    _purchaseSubscription ??= _purchases.purchaseStream.listen(
      _handlePurchaseUpdates,
      onError: (Object error) {
        _logPlayBilling('purchase stream error: $error');
        _lastErrorMessage = 'Purchase update failed.';
        notifyListeners();
      },
    );
    _logPlayBilling('purchase stream subscription ready');
    await refresh();
  }

  @override
  Future<void> refresh() async {
    _logPlayBilling('refresh start');
    _lastErrorMessage = null;
    final cached = await _cache.read();
    _setState(cached);
    if (!Platform.isAndroid) {
      _logPlayBilling('refresh skipped: Play Billing is Android-only');
      return;
    }
    try {
      final available = await _purchases.isAvailable();
      _logPlayBilling('billing available=$available');
      if (!available) return;
      final addition = _purchases
          .getPlatformAddition<InAppPurchaseAndroidPlatformAddition>();
      _logPlayBilling('query past purchases start');
      final response = await addition.queryPastPurchases();
      if (response.error != null) {
        _logPlayBilling(
          'query past purchases error: ${response.error!.code} '
          '${response.error!.message}',
        );
        _lastErrorMessage = 'Could not verify Play purchase.';
        notifyListeners();
        return;
      }
      _logPlayBilling(
        'query past purchases ok count=${response.pastPurchases.length}',
      );
      await _applyPurchases(response.pastPurchases);
    } catch (error) {
      _logPlayBilling('refresh exception: $error');
      _lastErrorMessage = _playBillingUnexpectedErrorMessage(
        error,
        fallback: 'Could not verify Play purchase.',
      );
      notifyListeners();
    }
  }

  @override
  Future<bool> buyExpandedVaultStorage() async {
    _logPlayBilling('buy expanded storage requested');
    if (!Platform.isAndroid) {
      _logPlayBilling('buy rejected: Play Billing is Android-only');
      _lastErrorMessage = 'Play purchases are available on Android only.';
      notifyListeners();
      return false;
    }
    if (_purchaseInProgress) {
      _logPlayBilling('buy ignored: purchase already in progress');
      return false;
    }
    _purchaseInProgress = true;
    _lastErrorMessage = null;
    notifyListeners();
    try {
      final available = await _purchases.isAvailable();
      _logPlayBilling('billing available before buy=$available');
      if (!available) {
        _lastErrorMessage = 'Google Play Billing is unavailable.';
        return false;
      }
      _logPlayBilling(
        'query product details start product=${EntitlementProducts.expandedVaultStorage}',
      );
      final response = await _purchases.queryProductDetails({
        EntitlementProducts.expandedVaultStorage,
      });
      if (response.error != null) {
        _logPlayBilling(
          'query product details error: ${response.error!.code} '
          '${response.error!.message}',
        );
        _lastErrorMessage =
            response.error?.message ??
            'Storage upgrade is not available. Check Play Console setup.';
        return false;
      }
      _logPlayBilling(
        'query product details ok products=${response.productDetails.map((item) => item.id).join(',')} '
        'notFound=${response.notFoundIDs.join(',')}',
      );
      if (response.notFoundIDs.isNotEmpty || response.productDetails.isEmpty) {
        _lastErrorMessage =
            'Storage upgrade product was not found in Google Play. Check product id, active status, tester track, and install source.';
        return false;
      }
      ProductDetails? details;
      for (final item in response.productDetails) {
        if (item.id == EntitlementProducts.expandedVaultStorage) {
          details = item;
          break;
        }
      }
      details ??= response.productDetails.first;
      _logPlayBilling('launch purchase flow product=${details.id}');
      final launched = await _purchases.buyNonConsumable(
        purchaseParam: PurchaseParam(productDetails: details),
      );
      _logPlayBilling('purchase flow launch result=$launched');
      if (!launched) {
        _lastErrorMessage =
            'Google Play rejected the purchase launch. Install from a Play testing track with a license tester account and retry after the product is active.';
      }
      return launched;
    } on PlatformException catch (error) {
      _logPlayBilling(
        'platform exception during buy: ${error.code} ${error.message}',
      );
      _lastErrorMessage =
          error.message ??
          'Could not start Google Play purchase. ${error.code}';
      return false;
    } catch (error) {
      _logPlayBilling('exception during buy: $error');
      _lastErrorMessage = _playBillingUnexpectedErrorMessage(
        error,
        fallback: 'Could not start Google Play purchase.',
      );
      return false;
    } finally {
      _purchaseInProgress = false;
      notifyListeners();
    }
  }

  Future<void> _handlePurchaseUpdates(List<PurchaseDetails> purchases) async {
    _logPlayBilling('purchase update count=${purchases.length}');
    var handledTerminalPurchase = false;
    for (final purchase in purchases) {
      _logPlayBilling(
        'purchase update product=${purchase.productID} '
        'status=${purchase.status.name} '
        'pendingComplete=${purchase.pendingCompletePurchase}',
      );
      if (purchase.productID != EntitlementProducts.expandedVaultStorage) {
        _logPlayBilling('purchase update ignored for unrelated product');
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
          _logPlayBilling(
            'complete purchase start product=${purchase.productID}',
          );
          await _purchases.completePurchase(purchase);
          _logPlayBilling('complete purchase ok product=${purchase.productID}');
        } catch (_) {
          _logPlayBilling(
            'complete purchase failed product=${purchase.productID}',
          );
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
    _logPlayBilling('apply purchases count=${purchases.length}');
    final matching = purchases.where(
      (purchase) =>
          purchase.productID == EntitlementProducts.expandedVaultStorage &&
          (purchase.status == PurchaseStatus.purchased ||
              purchase.status == PurchaseStatus.restored),
    );
    if (matching.isEmpty) {
      _logPlayBilling('no matching purchased/restored entitlement found');
      final cached = await _cache.read();
      if (cached.expandedVaultStorage) {
        // Keep the locally cached lifetime entitlement for offline starts and
        // transient Play query gaps. A future backend can add revocation.
        _logPlayBilling('keeping cached expanded-storage entitlement');
        _setState(cached);
      }
      return;
    }
    await _grantExpandedStorageFromPlay(matching.first);
  }

  Future<void> _grantExpandedStorageFromPlay(PurchaseDetails purchase) async {
    _logPlayBilling(
      'grant expanded storage from Play product=${purchase.productID}',
    );
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

  String _playBillingUnexpectedErrorMessage(
    Object error, {
    required String fallback,
  }) {
    final message = error.toString().trim();
    if (_looksLikeObfuscatedTypeCastError(message)) {
      return 'Google Play returned an unexpected response. Update Google Play Store and Play services, install or update Nija from Google Play, then retry.';
    }
    if (message.isEmpty) return fallback;
    return '$fallback $message';
  }

  bool _looksLikeObfuscatedTypeCastError(String message) {
    final lower = message.toLowerCase();
    return lower.contains('is not a subtype of type') ||
        (lower.contains('type ') && lower.contains('subtype'));
  }

  void _logPlayBilling(String message) {
    if (!kDebugMode) return;
    debugPrint('[NijaEntitlementService][PlayBilling] $message');
  }

  @override
  void dispose() {
    unawaited(_purchaseSubscription?.cancel());
    super.dispose();
  }
}

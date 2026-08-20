import 'entitlement_service_base.dart';
import 'entitlement_state.dart';

class NijaEntitlementService extends EntitlementService {
  NijaEntitlementService({EntitlementCache? cache})
    : _cache = cache ?? MemoryEntitlementCache();

  final EntitlementCache _cache;
  EntitlementState _state = const EntitlementState.free();

  @override
  EntitlementState get state => _state;

  @override
  bool get canPurchaseExpandedVaultStorage => false;

  @override
  bool get isPurchaseInProgress => false;

  @override
  String? get lastErrorMessage => null;

  @override
  Future<void> initialize() async {
    _state = await _cache.read();
    notifyListeners();
  }

  @override
  Future<void> refresh() async {
    _state = await _cache.read();
    notifyListeners();
  }

  @override
  Future<bool> buyExpandedVaultStorage() async => false;
}

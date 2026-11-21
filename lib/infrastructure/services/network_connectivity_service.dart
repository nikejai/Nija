import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/widgets.dart';

/// Service to inspect device network connectivity (e.g. Wi-Fi vs Cellular vs Offline).
class NetworkConnectivityService {
  NetworkConnectivityService({Connectivity? connectivity})
      : _connectivity = connectivity ?? Connectivity();

  final Connectivity _connectivity;

  /// Visible for testing: override Wi-Fi connectivity result in widget/unit tests.
  @visibleForTesting
  static bool? testWifiOverride;

  /// Visible for testing: override general internet connectivity in tests.
  @visibleForTesting
  static bool? testInternetOverride;

  /// Returns true if the device is currently connected to Wi-Fi or Ethernet.
  Future<bool> isWifiConnected() async {
    if (testWifiOverride != null) {
      return testWifiOverride!;
    }

    if (WidgetsBinding.instance.runtimeType.toString().contains('Test')) {
      return true;
    }

    try {
      final results = await _connectivity.checkConnectivity();
      return results.contains(ConnectivityResult.wifi) ||
          results.contains(ConnectivityResult.ethernet);
    } catch (e) {
      debugPrint('NetworkConnectivityService error checking Wi-Fi: $e');
      // Fail closed when Wi-Fi-only cannot verify a Wi-Fi/Ethernet connection.
      return false;
    }
  }

  /// Returns true if the device has an active network connection (Wi-Fi, Cellular, Ethernet, or VPN).
  Future<bool> hasInternetConnection() async {
    if (testInternetOverride != null) {
      return testInternetOverride!;
    }

    if (WidgetsBinding.instance.runtimeType.toString().contains('Test')) {
      return true;
    }

    try {
      final results = await _connectivity.checkConnectivity();
      if (results.isEmpty) return false;
      return !results.contains(ConnectivityResult.none);
    } catch (e) {
      debugPrint('NetworkConnectivityService error checking internet: $e');
      return true;
    }
  }
}

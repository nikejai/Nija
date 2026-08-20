import 'nija_browser_bridge.dart';
import 'pwa_install_service_base.dart';

PwaInstallService createPwaInstallService() => PwaInstallServiceWeb();

class PwaInstallServiceWeb implements PwaInstallService {
  PwaInstallPlatform _parsePlatform(Object? raw) {
    return switch (raw?.toString()) {
      'ios' => PwaInstallPlatform.ios,
      'android' => PwaInstallPlatform.android,
      'desktop' => PwaInstallPlatform.desktop,
      _ => PwaInstallPlatform.unknown,
    };
  }

  @override
  Future<PwaInstallStatus> getStatus() async {
    try {
      final status = nijaPwaStatus();
      return PwaInstallStatus(
        isInstalled: status.isInstalled,
        canPrompt: status.canPrompt,
        requiresManualSteps: status.requiresManualSteps,
        platform: _parsePlatform(status.platform),
      );
    } catch (_) {
      return const PwaInstallStatus(
        isInstalled: false,
        canPrompt: false,
        requiresManualSteps: false,
        platform: PwaInstallPlatform.unknown,
      );
    }
  }

  @override
  Future<PwaInstallPromptOutcome> promptInstall() async {
    try {
      final outcome = await nijaPromptPwaInstall();
      return switch (outcome) {
        'accepted' => PwaInstallPromptOutcome.accepted,
        'dismissed' => PwaInstallPromptOutcome.dismissed,
        _ => PwaInstallPromptOutcome.unavailable,
      };
    } catch (_) {
      return PwaInstallPromptOutcome.unavailable;
    }
  }
}

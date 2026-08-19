enum PwaInstallPlatform { ios, android, desktop, unknown }

enum PwaInstallPromptOutcome { accepted, dismissed, unavailable }

class PwaInstallStatus {
  const PwaInstallStatus({
    required this.isInstalled,
    required this.canPrompt,
    required this.requiresManualSteps,
    required this.platform,
  });

  final bool isInstalled;
  final bool canPrompt;
  final bool requiresManualSteps;
  final PwaInstallPlatform platform;

  bool get showInstallOffer => !isInstalled;

  bool get useHomeScreenLabel =>
      platform == PwaInstallPlatform.ios ||
      platform == PwaInstallPlatform.android;
}

abstract class PwaInstallService {
  Future<PwaInstallStatus> getStatus();

  Future<PwaInstallPromptOutcome> promptInstall();
}

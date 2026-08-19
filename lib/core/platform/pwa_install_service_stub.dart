import 'pwa_install_service_base.dart';

PwaInstallService createPwaInstallService() => _PwaInstallServiceStub();

class _PwaInstallServiceStub implements PwaInstallService {
  @override
  Future<PwaInstallStatus> getStatus() async {
    return const PwaInstallStatus(
      isInstalled: false,
      canPrompt: false,
      requiresManualSteps: false,
      platform: PwaInstallPlatform.unknown,
    );
  }

  @override
  Future<PwaInstallPromptOutcome> promptInstall() async {
    return PwaInstallPromptOutcome.unavailable;
  }
}

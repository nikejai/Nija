import 'package:flutter_test/flutter_test.dart';
import 'package:nija/core/platform/pwa_install_service.dart';

void main() {
  test('stub reports install unavailable on non-web platforms', () async {
    final status = await pwaInstallService.getStatus();
    expect(status.isInstalled, isFalse);
    expect(status.canPrompt, isFalse);
    expect(status.showInstallOffer, isTrue);

    final outcome = await pwaInstallService.promptInstall();
    expect(outcome, PwaInstallPromptOutcome.unavailable);
  });
}

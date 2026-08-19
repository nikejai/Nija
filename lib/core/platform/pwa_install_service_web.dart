// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use, uri_does_not_exist

import 'dart:html' as html;
import 'dart:js_util' as js_util;

import 'pwa_install_service_base.dart';

PwaInstallService createPwaInstallService() => PwaInstallServiceWeb();

class PwaInstallServiceWeb implements PwaInstallService {
  dynamic _bridge() => js_util.getProperty(html.window, 'nijaPwaInstall');

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
    final bridge = _bridge();
    if (bridge == null) {
      return const PwaInstallStatus(
        isInstalled: false,
        canPrompt: false,
        requiresManualSteps: false,
        platform: PwaInstallPlatform.unknown,
      );
    }
    try {
      final installed = js_util.callMethod<bool>(
        bridge,
        'isInstalled',
        const [],
      );
      final canPrompt = js_util.callMethod<bool>(
        bridge,
        'canPromptInstall',
        const [],
      );
      final manual = js_util.callMethod<bool>(
        bridge,
        'requiresManualSteps',
        const [],
      );
      final platform = _parsePlatform(
        js_util.callMethod<Object?>(bridge, 'detectPlatform', const []),
      );
      return PwaInstallStatus(
        isInstalled: installed,
        canPrompt: canPrompt,
        requiresManualSteps: manual,
        platform: platform,
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
    final bridge = _bridge();
    if (bridge == null) return PwaInstallPromptOutcome.unavailable;
    try {
      final result = await js_util.promiseToFuture<Object?>(
        js_util.callMethod(bridge, 'promptInstall', const []),
      );
      if (result == null) return PwaInstallPromptOutcome.unavailable;
      final outcome = js_util.getProperty(result, 'outcome')?.toString();
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

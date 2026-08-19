import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../../core/localization/app_strings.dart';
import '../../../../core/platform/pwa_install_service.dart';

String pwaInstallOfferTitle(PwaInstallStatus status) {
  return status.useHomeScreenLabel
      ? AppStrings.pwaInstallAddToHomeScreen
      : AppStrings.pwaInstallAddToComputer;
}

IconData pwaInstallOfferIcon(PwaInstallStatus status) {
  return status.useHomeScreenLabel
      ? Icons.add_to_home_screen_outlined
      : Icons.install_desktop_outlined;
}

Future<PwaInstallStatus?> handlePwaInstallOfferTap(BuildContext context) async {
  if (!kIsWeb) return null;

  final status = await pwaInstallService.getStatus();
  if (!context.mounted || !status.showInstallOffer) return status;

  if (status.requiresManualSteps) {
    final platform = status.platform == PwaInstallPlatform.ios
        ? PwaInstallPlatform.ios
        : PwaInstallPlatform.desktop;
    await showPwaInstallStepsDialog(context, platform: platform);
    return pwaInstallService.getStatus();
  }

  final outcome = await pwaInstallService.promptInstall();
  if (!context.mounted) return null;
  final messenger = ScaffoldMessenger.of(context)..removeCurrentSnackBar();
  final message = switch (outcome) {
    PwaInstallPromptOutcome.accepted => AppStrings.pwaInstallAccepted,
    PwaInstallPromptOutcome.dismissed => AppStrings.pwaInstallDismissed,
    PwaInstallPromptOutcome.unavailable => AppStrings.pwaInstallUnavailable,
  };
  messenger.showSnackBar(SnackBar(content: Text(message)));
  return pwaInstallService.getStatus();
}

Future<void> showPwaInstallStepsDialog(
  BuildContext context, {
  required PwaInstallPlatform platform,
}) {
  final title = platform == PwaInstallPlatform.ios
      ? AppStrings.pwaInstallIosTitle
      : AppStrings.pwaInstallDesktopSafariTitle;
  final steps = platform == PwaInstallPlatform.ios
      ? AppStrings.pwaInstallIosSteps
      : AppStrings.pwaInstallDesktopSafariSteps;

  return showDialog<void>(
    context: context,
    builder: (dialogContext) {
      final theme = Theme.of(dialogContext);
      final colorScheme = theme.colorScheme;
      return AlertDialog(
        icon: Icon(Icons.install_mobile_outlined, color: colorScheme.primary),
        title: Text(title, textAlign: TextAlign.center),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                AppStrings.pwaInstallStepsIntro,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 16),
              for (var index = 0; index < steps.length; index++) ...[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 24,
                      height: 24,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: colorScheme.primaryContainer,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '${index + 1}',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: colorScheme.onPrimaryContainer,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          steps[index],
                          style: theme.textTheme.bodyMedium?.copyWith(
                            height: 1.4,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                if (index < steps.length - 1) const SizedBox(height: 12),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(AppStrings.pwaInstallStepsDone),
          ),
        ],
      );
    },
  );
}

/// Compact install affordance for entry screens (welcome header, etc.).
class PwaInstallOfferButton extends StatefulWidget {
  const PwaInstallOfferButton({super.key});

  @override
  State<PwaInstallOfferButton> createState() => _PwaInstallOfferButtonState();
}

class _PwaInstallOfferButtonState extends State<PwaInstallOfferButton> {
  PwaInstallStatus? _status;

  @override
  void initState() {
    super.initState();
    if (kIsWeb) {
      _refreshStatus();
    }
  }

  Future<void> _refreshStatus() async {
    final next = await pwaInstallService.getStatus();
    if (!mounted) return;
    setState(() => _status = next);
  }

  Future<void> _handleTap() async {
    final next = await handlePwaInstallOfferTap(context);
    if (!mounted || next == null) return;
    setState(() => _status = next);
  }

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb) return const SizedBox.shrink();

    final status = _status;
    if (status == null || !status.showInstallOffer) {
      return const SizedBox.shrink();
    }

    final label = pwaInstallOfferTitle(status);
    final icon = pwaInstallOfferIcon(status);
    final compact = MediaQuery.sizeOf(context).width < 520;

    if (compact) {
      return IconButton(
        key: const ValueKey('pwa-install-offer-button'),
        tooltip: label,
        onPressed: _handleTap,
        icon: Icon(icon),
      );
    }

    return TextButton.icon(
      key: const ValueKey('pwa-install-offer-button'),
      onPressed: _handleTap,
      icon: Icon(icon, size: 18),
      label: Text(label),
    );
  }
}

import 'package:flutter/material.dart';

import '../../../../app/theme/entry_typography.dart';
import '../../../../core/localization/app_strings.dart';

enum WebBiometricUnavailableReason {
  browserUnsupported,
  platformUnavailable,
  registrationFailed,
  passkeyConflict,
}

Future<bool> showWebBiometricEnableDialog(
  BuildContext context, {
  required Future<void> Function() onConfirm,
  VoidCallback? onUseSessionUnlock,
  VoidCallback? onUnavailableDismissed,
}) {
  return showDialog<bool>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.45),
    builder: (dialogContext) {
      return _WebBiometricEnableDialog(
        onConfirm: onConfirm,
        onShowUnavailable: (reason) async {
          Navigator.of(dialogContext).pop(false);
          if (context.mounted) {
            await showWebBiometricUnavailableDialog(
              context,
              reason: reason,
              onUseSessionUnlock: onUseSessionUnlock,
              onDismissed: onUnavailableDismissed,
            );
          }
        },
      );
    },
  ).then((value) => value ?? false);
}

Future<void> showWebBiometricUnavailableDialog(
  BuildContext context, {
  WebBiometricUnavailableReason reason =
      WebBiometricUnavailableReason.browserUnsupported,
  VoidCallback? onUseSessionUnlock,
  VoidCallback? onDismissed,
}) {
  final title = switch (reason) {
    WebBiometricUnavailableReason.passkeyConflict =>
      AppStrings.webBiometricPasskeyConflictTitle,
    WebBiometricUnavailableReason.registrationFailed =>
      AppStrings.webBiometricRegistrationFailedTitle,
    WebBiometricUnavailableReason.platformUnavailable =>
      AppStrings.webBiometricPlatformUnavailableTitle,
    WebBiometricUnavailableReason.browserUnsupported =>
      AppStrings.webBiometricUnavailableTitle,
  };
  final intro = switch (reason) {
    WebBiometricUnavailableReason.passkeyConflict =>
      AppStrings.webBiometricPasskeyConflictIntro,
    WebBiometricUnavailableReason.registrationFailed =>
      AppStrings.webBiometricRegistrationFailedIntro,
    WebBiometricUnavailableReason.platformUnavailable =>
      AppStrings.webBiometricPlatformUnavailableIntro,
    WebBiometricUnavailableReason.browserUnsupported =>
      AppStrings.webBiometricUnavailableIntro,
  };
  final steps = switch (reason) {
    WebBiometricUnavailableReason.passkeyConflict =>
      AppStrings.webBiometricPasskeyConflictSteps,
    WebBiometricUnavailableReason.registrationFailed =>
      AppStrings.webBiometricRegistrationFailedSteps,
    WebBiometricUnavailableReason.platformUnavailable =>
      AppStrings.webBiometricPlatformUnavailableSteps,
    WebBiometricUnavailableReason.browserUnsupported =>
      AppStrings.webBiometricUnavailableSteps,
  };

  return showDialog<void>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.45),
    builder: (dialogContext) {
      final theme = Theme.of(dialogContext);
      final colorScheme = theme.colorScheme;
      return _NijaThemedDialog(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Icon(Icons.info_outline, color: colorScheme.primary, size: 28),
              const SizedBox(height: 12),
              Text(
                title,
                textAlign: TextAlign.center,
                style: EntryTypography.unlockTitle(colorScheme.onSurface),
              ),
              const SizedBox(height: 12),
              Text(
                intro,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 16),
              for (var index = 0; index < steps.length; index++) ...[
                _StepRow(
                  index: index + 1,
                  label: steps[index],
                  colorScheme: colorScheme,
                  theme: theme,
                ),
                if (index < steps.length - 1) const SizedBox(height: 12),
              ],
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        onDismissed?.call();
                        Navigator.of(dialogContext).pop();
                      },
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(44),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        side: BorderSide(color: colorScheme.outlineVariant),
                      ),
                      child: Text(AppStrings.notNow),
                    ),
                  ),
                  if (onUseSessionUnlock != null) ...[
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton(
                        onPressed: () {
                          onDismissed?.call();
                          onUseSessionUnlock();
                          Navigator.of(dialogContext).pop();
                        },
                        style: FilledButton.styleFrom(
                          backgroundColor: colorScheme.onSurface,
                          foregroundColor: colorScheme.surface,
                          minimumSize: const Size.fromHeight(44),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: Text(
                          AppStrings.webBiometricUseSessionUnlockAction,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      );
    },
  );
}

Future<bool> showWebSessionUnlockEnableDialog(BuildContext context) {
  return showDialog<bool>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.45),
    builder: (dialogContext) {
      final theme = Theme.of(dialogContext);
      final colorScheme = theme.colorScheme;
      return _NijaThemedDialog(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Icon(
                Icons.lock_open_outlined,
                color: colorScheme.primary,
                size: 28,
              ),
              const SizedBox(height: 12),
              Text(
                AppStrings.webSessionUnlockEnableTitle,
                textAlign: TextAlign.center,
                style: EntryTypography.unlockTitle(colorScheme.onSurface),
              ),
              const SizedBox(height: 12),
              Text(
                AppStrings.webSessionUnlockEnableIntro,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 16),
              for (
                var index = 0;
                index < AppStrings.webSessionUnlockEnableSteps.length;
                index++
              ) ...[
                _StepRow(
                  index: index + 1,
                  label: AppStrings.webSessionUnlockEnableSteps[index],
                  colorScheme: colorScheme,
                  theme: theme,
                ),
                if (index < AppStrings.webSessionUnlockEnableSteps.length - 1)
                  const SizedBox(height: 12),
              ],
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(dialogContext).pop(false),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(44),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        side: BorderSide(color: colorScheme.outlineVariant),
                      ),
                      child: Text(AppStrings.notNow),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton(
                      onPressed: () => Navigator.of(dialogContext).pop(true),
                      style: FilledButton.styleFrom(
                        backgroundColor: colorScheme.onSurface,
                        foregroundColor: colorScheme.surface,
                        minimumSize: const Size.fromHeight(44),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: Text(AppStrings.webSessionUnlockEnableConfirm),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    },
  ).then((value) => value ?? false);
}

WebBiometricUnavailableReason? unavailableReasonForError(Object error) {
  final raw = error.toString();
  if (raw.contains('not_allowed') || raw.contains('NotAllowedError')) {
    return WebBiometricUnavailableReason.platformUnavailable;
  }
  if (raw.contains('prf_unavailable')) {
    return WebBiometricUnavailableReason.browserUnsupported;
  }
  if (raw.contains('credential_exists')) {
    return WebBiometricUnavailableReason.passkeyConflict;
  }
  return null;
}

String webBiometricEnableErrorMessage(Object error) {
  final raw = error.toString().trim();
  if (raw.isEmpty) return AppStrings.webBiometricEnableFailed;
  return '${AppStrings.webBiometricEnableFailed}\n\n$raw';
}

class _WebBiometricEnableDialog extends StatefulWidget {
  const _WebBiometricEnableDialog({
    required this.onConfirm,
    required this.onShowUnavailable,
  });

  final Future<void> Function() onConfirm;
  final Future<void> Function(WebBiometricUnavailableReason reason)
  onShowUnavailable;

  @override
  State<_WebBiometricEnableDialog> createState() =>
      _WebBiometricEnableDialogState();
}

class _WebBiometricEnableDialogState extends State<_WebBiometricEnableDialog> {
  var _busy = false;
  String? _errorText;

  Future<void> _handleConfirm() async {
    if (_busy) return;
    _busy = true;
    _errorText = null;
    try {
      await widget.onConfirm();
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (error) {
      final unavailable = unavailableReasonForError(error);
      if (!mounted) return;
      if (unavailable != null) {
        await widget.onShowUnavailable(unavailable);
        return;
      }
      setState(() {
        _busy = false;
        _errorText = webBiometricEnableErrorMessage(error);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return _NijaThemedDialog(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Icon(Icons.fingerprint, color: colorScheme.primary, size: 28),
            const SizedBox(height: 12),
            Text(
              AppStrings.biometricEnableConfirmTitle,
              textAlign: TextAlign.center,
              style: EntryTypography.unlockTitle(colorScheme.onSurface),
            ),
            const SizedBox(height: 12),
            Text(
              AppStrings.webBiometricEnableIntro,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 16),
            for (
              var index = 0;
              index < AppStrings.webBiometricEnableSteps.length;
              index++
            ) ...[
              _StepRow(
                index: index + 1,
                label: AppStrings.webBiometricEnableSteps[index],
                colorScheme: colorScheme,
                theme: theme,
              ),
              if (index < AppStrings.webBiometricEnableSteps.length - 1)
                const SizedBox(height: 12),
            ],
            if (_errorText != null) ...[
              const SizedBox(height: 16),
              Text(
                _errorText!,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.error,
                  height: 1.4,
                ),
              ),
            ],
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _busy
                        ? null
                        : () => Navigator.of(context).pop(false),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(44),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      side: BorderSide(color: colorScheme.outlineVariant),
                    ),
                    child: Text(AppStrings.notNow),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    onPressed: _busy ? null : _handleConfirm,
                    style: FilledButton.styleFrom(
                      backgroundColor: colorScheme.onSurface,
                      foregroundColor: colorScheme.surface,
                      minimumSize: const Size.fromHeight(44),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: _busy
                        ? SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: colorScheme.surface,
                            ),
                          )
                        : Text(AppStrings.webBiometricConfirmTouchId),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _NijaThemedDialog extends StatelessWidget {
  const _NijaThemedDialog({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Dialog(
      backgroundColor: colorScheme.surface,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
          child: child,
        ),
      ),
    );
  }
}

class _StepRow extends StatelessWidget {
  const _StepRow({
    required this.index,
    required this.label,
    required this.colorScheme,
    required this.theme,
  });

  final int index;
  final String label;
  final ColorScheme colorScheme;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Row(
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
            '$index',
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
              label,
              style: theme.textTheme.bodyMedium?.copyWith(height: 1.4),
            ),
          ),
        ),
      ],
    );
  }
}

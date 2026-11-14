import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../app/theme/entry_typography.dart';
import '../../../../core/localization/app_strings.dart';

class NijaPinDialog extends StatelessWidget {
  const NijaPinDialog({super.key, required this.child});

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
          child: IconTheme(
            data: IconThemeData(color: colorScheme.primary),
            child: child,
          ),
        ),
      ),
    );
  }
}

class NijaPinEntryDialog extends StatefulWidget {
  const NijaPinEntryDialog({super.key, required this.title});

  final String title;

  @override
  State<NijaPinEntryDialog> createState() => _NijaPinEntryDialogState();
}

class _NijaPinEntryDialogState extends State<NijaPinEntryDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() => Navigator.of(context).pop(_controller.text.trim());

  @override
  Widget build(BuildContext context) {
    return NijaPinDialog(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Icon(Icons.pin_outlined, size: 28),
          const SizedBox(height: 12),
          NijaPinDialogTitle(widget.title),
          const SizedBox(height: 16),
          TextField(
            key: const ValueKey('app-pin-field'),
            controller: _controller,
            obscureText: true,
            autofocus: true,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(labelText: AppStrings.appPinLabel),
            onSubmitted: (_) => _submit(),
          ),
          const SizedBox(height: 20),
          NijaPinDialogActions(
            primaryLabel: AppStrings.unlock,
            onCancel: () => Navigator.of(context).pop(),
            onPrimary: _submit,
          ),
        ],
      ),
    );
  }
}

class NijaPinSetupDialog extends StatefulWidget {
  const NijaPinSetupDialog({super.key, required this.title});

  final String title;

  @override
  State<NijaPinSetupDialog> createState() => _NijaPinSetupDialogState();
}

class _NijaPinSetupDialogState extends State<NijaPinSetupDialog> {
  final _pinController = TextEditingController();
  final _confirmController = TextEditingController();
  String? _errorText;

  @override
  void dispose() {
    _pinController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  void _submit() {
    final candidate = _pinController.text.trim();
    final confirm = _confirmController.text.trim();
    if (candidate.length < 6 || candidate != confirm) {
      setState(() {
        _errorText = candidate.length < 6
            ? AppStrings.appPinTooShortMessage
            : AppStrings.appPinMismatchMessage;
      });
      return;
    }
    Navigator.of(context).pop(candidate);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return NijaPinDialog(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Icon(Icons.pin_outlined, size: 28),
          const SizedBox(height: 12),
          NijaPinDialogTitle(widget.title),
          const SizedBox(height: 12),
          Text(
            AppStrings.appPinSetupMessage,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const ValueKey('app-pin-new-field'),
            controller: _pinController,
            obscureText: true,
            autofocus: true,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(
              labelText: AppStrings.appPinLabel,
              errorText: _errorText,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const ValueKey('app-pin-confirm-field'),
            controller: _confirmController,
            obscureText: true,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(
              labelText: AppStrings.appPinConfirmLabel,
            ),
            onSubmitted: (_) => _submit(),
          ),
          const SizedBox(height: 20),
          NijaPinDialogActions(
            primaryLabel: AppStrings.enable,
            onCancel: () => Navigator.of(context).pop(),
            onPrimary: _submit,
          ),
        ],
      ),
    );
  }
}

class NijaPinDialogTitle extends StatelessWidget {
  const NijaPinDialogTitle(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Text(
      text,
      textAlign: TextAlign.center,
      style: EntryTypography.unlockTitle(colorScheme.onSurface),
    );
  }
}

class NijaPinDialogActions extends StatelessWidget {
  const NijaPinDialogActions({
    super.key,
    required this.primaryLabel,
    required this.onCancel,
    required this.onPrimary,
  });

  final String primaryLabel;
  final VoidCallback onCancel;
  final VoidCallback onPrimary;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: onCancel,
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(44),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              side: BorderSide(color: colorScheme.outlineVariant),
            ),
            child: Text(AppStrings.cancel),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: FilledButton(
            onPressed: onPrimary,
            style: FilledButton.styleFrom(
              backgroundColor: colorScheme.onSurface,
              foregroundColor: colorScheme.surface,
              minimumSize: const Size.fromHeight(44),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: Text(primaryLabel),
          ),
        ),
      ],
    );
  }
}

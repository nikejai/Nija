import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Whether choice menus and sheets should use a centered dialog instead of a
/// mobile bottom sheet (web and wide viewports).
bool useVaultDialogSurface(BuildContext context) {
  if (kIsWeb) return true;
  return MediaQuery.sizeOf(context).width >= 600;
}

class VaultMenuOption<T> {
  const VaultMenuOption({
    required this.value,
    required this.title,
    this.leading,
    this.trailing,
    this.key,
  });

  final T value;
  final String title;
  final Widget? leading;
  final Widget? trailing;
  final Key? key;
}

Future<T?> showVaultChoiceMenu<T>({
  required BuildContext context,
  String? title,
  required List<VaultMenuOption<T>> options,
}) {
  if (useVaultDialogSurface(context)) {
    return showDialog<T>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: title == null ? null : Text(title),
        contentPadding: title == null
            ? const EdgeInsets.fromLTRB(0, 12, 0, 12)
            : null,
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final option in options)
                ListTile(
                  key: option.key,
                  leading: option.leading,
                  trailing: option.trailing,
                  title: Text(option.title),
                  onTap: () => Navigator.of(dialogContext).pop(option.value),
                ),
            ],
          ),
        ),
      ),
    );
  }

  return showModalBottomSheet<T>(
    context: context,
    builder: (sheetContext) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (title != null)
            ListTile(
              title: Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          for (final option in options)
            ListTile(
              key: option.key,
              leading: option.leading,
              trailing: option.trailing,
              title: Text(option.title),
              onTap: () => Navigator.of(sheetContext).pop(option.value),
            ),
        ],
      ),
    ),
  );
}

Future<T?> showVaultSurfaceSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool scrollControlled = false,
  bool isDismissible = true,
  bool enableDrag = true,
}) {
  if (useVaultDialogSurface(context)) {
    return showDialog<T>(
      context: context,
      barrierDismissible: isDismissible,
      builder: (dialogContext) {
        final maxHeight = MediaQuery.sizeOf(dialogContext).height * 0.85;
        return Dialog(
          insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: 560, maxHeight: maxHeight),
            child: builder(dialogContext),
          ),
        );
      },
    );
  }

  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: scrollControlled,
    isDismissible: isDismissible,
    enableDrag: enableDrag,
    builder: builder,
  );
}

Future<bool?> showVaultConfirmSheet({
  required BuildContext context,
  required String title,
  required String message,
  required String confirmLabel,
  String cancelLabel = 'Cancel',
  bool destructive = false,
  Widget? icon,
}) {
  if (useVaultDialogSurface(context)) {
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: icon,
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(cancelLabel),
          ),
          FilledButton(
            style: destructive
                ? FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFEF4444),
                  )
                : null,
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
  }

  return showModalBottomSheet<bool>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) => SafeArea(
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 10),
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 14),
        decoration: BoxDecoration(
          color: Theme.of(sheetContext).colorScheme.surface,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            icon ??
                const Icon(
                  Icons.delete_outline,
                  size: 34,
                  color: Color(0xFFEF4444),
                ),
            const SizedBox(height: 10),
            Text(
              title,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Theme.of(sheetContext).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: destructive
                      ? const Color(0xFFEF4444)
                      : null,
                ),
                onPressed: () => Navigator.of(sheetContext).pop(true),
                child: Text(confirmLabel),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(sheetContext).pop(false),
              child: Text(cancelLabel),
            ),
          ],
        ),
      ),
    ),
  );
}

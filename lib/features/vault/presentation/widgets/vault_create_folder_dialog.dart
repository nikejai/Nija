import 'package:flutter/material.dart';
import '../../../../domain/models/vault_folder.dart';

Future<VaultFolder?> showCreateVaultFolderDialog(
  BuildContext context, {
  Future<VaultFolder?> Function(String name)? onCreateFolder,
}) async {
  final controller = TextEditingController();
  final theme = Theme.of(context);
  final colorScheme = theme.colorScheme;

  return showDialog<VaultFolder>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Row(
        children: [
          Icon(
            Icons.create_new_folder_outlined,
            color: colorScheme.primary,
            size: 24,
          ),
          const SizedBox(width: 10),
          const Text(
            'New Folder',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
        ],
      ),
      content: TextField(
        key: const ValueKey('create-folder-name-input'),
        controller: controller,
        autofocus: true,
        textCapitalization: TextCapitalization.words,
        decoration: InputDecoration(
          labelText: 'Folder Name',
          hintText: 'e.g. Work, Taxes, Identity',
          prefixIcon: const Icon(Icons.folder_outlined),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        ),
        onSubmitted: (value) async {
          final name = value.trim();
          if (name.isEmpty) return;
          if (onCreateFolder != null) {
            final folder = await onCreateFolder(name);
            if (ctx.mounted) {
              Navigator.of(ctx).pop(folder);
            }
          } else {
            final folder = VaultFolder(
              id: 'folder-${DateTime.now().millisecondsSinceEpoch}',
              name: name,
              createdAt: DateTime.now().toUtc().toIso8601String(),
              updatedAt: DateTime.now().toUtc().toIso8601String(),
            );
            Navigator.of(ctx).pop(folder);
          }
        },
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(null),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: const ValueKey('create-folder-submit-button'),
          style: FilledButton.styleFrom(
            minimumSize: const Size(72, 38),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          onPressed: () async {
            final name = controller.text.trim();
            if (name.isEmpty) return;
            if (onCreateFolder != null) {
              final folder = await onCreateFolder(name);
              if (ctx.mounted) {
                Navigator.of(ctx).pop(folder);
              }
            } else {
              final folder = VaultFolder(
                id: 'folder-${DateTime.now().millisecondsSinceEpoch}',
                name: name,
                createdAt: DateTime.now().toUtc().toIso8601String(),
                updatedAt: DateTime.now().toUtc().toIso8601String(),
              );
              Navigator.of(ctx).pop(folder);
            }
          },
          child: const Text('Create'),
        ),
      ],
    ),
  );
}

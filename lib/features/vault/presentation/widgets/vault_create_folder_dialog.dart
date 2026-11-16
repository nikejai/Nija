import 'package:flutter/material.dart';
import '../../../../domain/models/vault_folder.dart';

Future<VaultFolder?> showCreateVaultFolderDialog(
  BuildContext context, {
  Future<VaultFolder?> Function(String name, {String? parentId})? onCreateFolder,
  String? parentFolderId,
  String? parentFolderName,
}) async {
  final controller = TextEditingController();
  final theme = Theme.of(context);
  final colorScheme = theme.colorScheme;
  final isSubfolder = parentFolderId != null && parentFolderId.isNotEmpty;

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
          Expanded(
            child: Text(
              isSubfolder
                  ? 'New Subfolder in ${parentFolderName ?? "Folder"}'
                  : 'New Folder',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
      content: TextField(
        key: const ValueKey('create-folder-name-input'),
        controller: controller,
        autofocus: true,
        textCapitalization: TextCapitalization.words,
        decoration: InputDecoration(
          labelText: isSubfolder ? 'Subfolder Name' : 'Folder Name',
          hintText: isSubfolder ? 'e.g. Q1, Receipts, Invoices' : 'e.g. Work, Taxes, Identity',
          prefixIcon: const Icon(Icons.folder_outlined),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        ),
        onSubmitted: (value) async {
          final name = value.trim();
          if (name.isEmpty) return;
          if (onCreateFolder != null) {
            final folder = await onCreateFolder(name, parentId: parentFolderId);
            if (ctx.mounted) {
              Navigator.of(ctx).pop(folder);
            }
          } else {
            final folder = VaultFolder(
              id: 'folder-${DateTime.now().millisecondsSinceEpoch}',
              name: name,
              parentId: parentFolderId,
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
              final folder = await onCreateFolder(name, parentId: parentFolderId);
              if (ctx.mounted) {
                Navigator.of(ctx).pop(folder);
              }
            } else {
              final folder = VaultFolder(
                id: 'folder-${DateTime.now().millisecondsSinceEpoch}',
                name: name,
                parentId: parentFolderId,
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

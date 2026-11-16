import 'package:flutter/material.dart';
import '../../../../domain/models/vault_folder.dart';

const List<String> kDefaultFolderColors = [
  '#0381FE', // Blue
  '#7C4DFF', // Purple
  '#1FA968', // Teal
  '#D97706', // Amber
  '#E86A33', // Coral
  '#4B5563', // Charcoal
];

Color parseFolderHexColor(String? hexString, {Color fallback = const Color(0xFF0381FE)}) {
  if (hexString == null || hexString.trim().isEmpty) return fallback;
  try {
    var hex = hexString.trim().replaceFirst('#', '');
    if (hex.length == 6) hex = 'FF$hex';
    return Color(int.parse(hex, radix: 16));
  } catch (_) {
    return fallback;
  }
}

Future<VaultFolder?> showCreateVaultFolderDialog(
  BuildContext context, {
  VaultFolderCreateCallback? onCreateFolder,
  String? parentFolderId,
  String? parentFolderName,
  String? initialName,
  String? initialColor,
  bool isRename = false,
}) async {
  final controller = TextEditingController(text: initialName ?? '');
  final isSubfolder = parentFolderId != null && parentFolderId.isNotEmpty;
  var selectedColorHex = initialColor ?? (isSubfolder ? '#E86A33' : '#0381FE');

  return showDialog<VaultFolder>(
    context: context,
    builder: (ctx) {
      final theme = Theme.of(ctx);
      final colorScheme = theme.colorScheme;

      return StatefulBuilder(
        builder: (context, setState) {
          final currentColor = parseFolderHexColor(selectedColorHex);

          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: currentColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    isRename
                        ? Icons.edit_outlined
                        : (isSubfolder
                            ? Icons.create_new_folder_outlined
                            : Icons.folder_outlined),
                    color: currentColor,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        isRename
                            ? 'Rename Folder'
                            : (isSubfolder
                                ? 'New Subfolder'
                                : 'New Folder'),
                        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (isSubfolder && parentFolderName != null)
                        Text(
                          'Parent: $parentFolderName',
                          style: TextStyle(
                            fontSize: 11,
                            color: colorScheme.primary,
                            fontWeight: FontWeight.w500,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    key: const ValueKey('create-folder-name-input'),
                    controller: controller,
                    autofocus: true,
                    textCapitalization: TextCapitalization.words,
                    decoration: InputDecoration(
                      labelText: isSubfolder ? 'Subfolder Name' : 'Folder Name',
                      hintText: isSubfolder ? 'e.g. Q1, Receipts, Invoices' : 'e.g. Work, Taxes, Identity',
                      prefixIcon: const Icon(Icons.folder_outlined),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                    onSubmitted: (value) async {
                      final name = value.trim();
                      if (name.isEmpty) return;
                      await _handleSubmit(
                        ctx,
                        name: name,
                        parentFolderId: parentFolderId,
                        color: selectedColorHex,
                        onCreateFolder: onCreateFolder,
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Folder color',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: kDefaultFolderColors.map((colorHex) {
                      final dotColor = parseFolderHexColor(colorHex);
                      final isSelected = selectedColorHex.toUpperCase() == colorHex.toUpperCase();

                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            selectedColorHex = colorHex;
                          });
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: dotColor,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isSelected ? colorScheme.onSurface : Colors.transparent,
                              width: 2.5,
                            ),
                            boxShadow: [
                              if (isSelected)
                                BoxShadow(
                                  color: dotColor.withValues(alpha: 0.4),
                                  blurRadius: 6,
                                  spreadRadius: 1,
                                ),
                            ],
                          ),
                          child: isSelected
                              ? const Icon(Icons.check, size: 16, color: Colors.white)
                              : null,
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(null),
                child: const Text('Cancel'),
              ),
              FilledButton(
                key: const ValueKey('create-folder-submit-button'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size(80, 40),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: () async {
                  final name = controller.text.trim();
                  if (name.isEmpty) return;
                  await _handleSubmit(
                    ctx,
                    name: name,
                    parentFolderId: parentFolderId,
                    color: selectedColorHex,
                    onCreateFolder: onCreateFolder,
                  );
                },
                child: Text(isRename ? 'Save' : 'Create'),
              ),
            ],
          );
        },
      );
    },
  );
}

Future<void> _handleSubmit(
  BuildContext ctx, {
  required String name,
  required String? parentFolderId,
  required String color,
  required VaultFolderCreateCallback? onCreateFolder,
}) async {
  if (onCreateFolder != null) {
    VaultFolder? folder;
    try {
      folder = await (onCreateFolder as dynamic)(name, parentId: parentFolderId, color: color) as VaultFolder?;
    } catch (_) {
      try {
        final res = await (onCreateFolder as dynamic)(name, parentId: parentFolderId);
        folder = res as VaultFolder?;
      } catch (_) {
        final res = await (onCreateFolder as dynamic)(name);
        folder = res as VaultFolder?;
      }
    }
    if (ctx.mounted) {
      Navigator.of(ctx).pop(folder);
    }
  } else {
    final folder = VaultFolder(
      id: 'folder-${DateTime.now().millisecondsSinceEpoch}',
      name: name,
      parentId: parentFolderId,
      color: color,
      createdAt: DateTime.now().toUtc().toIso8601String(),
      updatedAt: DateTime.now().toUtc().toIso8601String(),
    );
    Navigator.of(ctx).pop(folder);
  }
}

import 'package:flutter/material.dart';
import '../../../../domain/models/folder_tree_builder.dart';
import '../../../../domain/models/folder_tree_node.dart';
import '../../../../domain/models/vault_folder.dart';
import 'vault_create_folder_dialog.dart';

Future<VaultFolder?> showVaultFolderHierarchySheet(
  BuildContext context, {
  required List<VaultFolder> folders,
  required String selectedFolderId,
  Future<VaultFolder?> Function(String name, {String? parentId})? onCreateFolder,
}) async {
  return showModalBottomSheet<VaultFolder>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => _FolderHierarchySheetContent(
      initialFolders: folders,
      selectedFolderId: selectedFolderId,
      onCreateFolder: onCreateFolder,
    ),
  );
}

class _FolderHierarchySheetContent extends StatefulWidget {
  const _FolderHierarchySheetContent({
    required this.initialFolders,
    required this.selectedFolderId,
    this.onCreateFolder,
  });

  final List<VaultFolder> initialFolders;
  final String selectedFolderId;
  final Future<VaultFolder?> Function(String name, {String? parentId})? onCreateFolder;

  @override
  State<_FolderHierarchySheetContent> createState() =>
      _FolderHierarchySheetContentState();
}

class _FolderHierarchySheetContentState
    extends State<_FolderHierarchySheetContent> {
  late List<VaultFolder> _folders;
  late String _selectedFolderId;
  final Set<String> _expandedFolderIds = <String>{};

  @override
  void initState() {
    super.initState();
    _folders = List<VaultFolder>.from(widget.initialFolders);
    _selectedFolderId = widget.selectedFolderId;

    // Auto-expand parents of currently selected folder
    _autoExpandAncestors();
  }

  void _autoExpandAncestors() {
    final folderMap = {for (final f in _folders) f.id: f};
    var current = folderMap[_selectedFolderId];
    while (current != null && current.parentId != null) {
      _expandedFolderIds.add(current.parentId!);
      current = folderMap[current.parentId];
    }
  }

  Future<void> _createTopLevelFolder() async {
    final newFolder = await showCreateVaultFolderDialog(
      context,
      onCreateFolder: widget.onCreateFolder,
    );
    if (newFolder != null && mounted) {
      setState(() {
        _folders.add(newFolder);
        _selectedFolderId = newFolder.id;
      });
      Navigator.of(context).pop(newFolder);
    }
  }

  Future<void> _showFolderOptions(VaultFolder folder) async {
    await showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                children: [
                  Icon(
                    folder.id == 'default' ? Icons.folder_special : Icons.folder_outlined,
                    color: folder.id == 'default' ? const Color(0xFFF59E0B) : const Color(0xFFEAB308),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      folder.name,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.create_new_folder_outlined),
              title: Text('Create subfolder inside "${folder.name}"'),
              onTap: () async {
                Navigator.of(sheetContext).pop();
                final subfolder = await showCreateVaultFolderDialog(
                  context,
                  parentFolderId: folder.id,
                  parentFolderName: folder.name,
                  onCreateFolder: widget.onCreateFolder,
                );
                if (subfolder != null && mounted) {
                  setState(() {
                    _folders.add(subfolder);
                    _expandedFolderIds.add(folder.id);
                    _selectedFolderId = subfolder.id;
                  });
                  Navigator.of(context).pop(subfolder);
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.check_circle_outline),
              title: const Text('Select this folder'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                Navigator.of(context).pop(folder);
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final tree = FolderTreeBuilder.buildTree(
      folders: _folders.where((f) => f.id != 'default').toList(),
      items: const <Map<String, dynamic>>[],
    );

    final defaultFolder = _folders.firstWhere(
      (f) => f.id == 'default',
      orElse: () => VaultFolder(
        id: 'default',
        name: 'Default',
        icon: 'folder_special',
        createdAt: '',
        updatedAt: '',
      ),
    );

    return DraggableScrollableSheet(
      initialChildSize: 0.65,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) {
        return Column(
          children: [
            // Drag handle
            Container(
              margin: const EdgeInsets.only(top: 10, bottom: 6),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 6, 12, 12),
              child: Row(
                children: [
                  Text(
                    'Select Folder',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      fontSize: 18,
                    ),
                  ),
                  const Spacer(),
                  FilledButton.tonalIcon(
                    key: const ValueKey('hierarchy-create-folder-button'),
                    onPressed: _createTopLevelFolder,
                    icon: const Icon(Icons.create_new_folder_outlined, size: 18),
                    label: const Text('New folder'),
                    style: FilledButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                'Tip: Long-press any folder to create a subfolder inside it.',
                style: TextStyle(
                  fontSize: 12,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            const SizedBox(height: 8),
            const Divider(height: 1),
            // Folder Tree List
            Expanded(
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: [
                  // Default Folder Tile
                  _buildFolderTile(
                    folder: defaultFolder,
                    level: 0,
                    hasChildren: false,
                    isExpanded: false,
                  ),
                  // Hierarchical Folder Nodes
                  for (final node in tree) ..._renderTreeNode(node, 0),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  List<Widget> _renderTreeNode(FolderTreeNode node, int level) {
    final folder = node.folder;
    final hasChildren = node.children.isNotEmpty;
    final isExpanded = _expandedFolderIds.contains(folder.id);

    final widgets = <Widget>[
      _buildFolderTile(
        folder: folder,
        level: level,
        hasChildren: hasChildren,
        isExpanded: isExpanded,
      ),
    ];

    if (isExpanded && hasChildren) {
      for (final child in node.children) {
        widgets.addAll(_renderTreeNode(child, level + 1));
      }
    }

    return widgets;
  }

  Widget _buildFolderTile({
    required VaultFolder folder,
    required int level,
    required bool hasChildren,
    required bool isExpanded,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final isSelected = _selectedFolderId == folder.id;
    final isDefault = folder.id == 'default';

    return Material(
      color: isSelected ? colorScheme.primaryContainer.withValues(alpha: 0.25) : Colors.transparent,
      child: InkWell(
        onTap: () {
          setState(() => _selectedFolderId = folder.id);
          Navigator.of(context).pop(folder);
        },
        onLongPress: () => _showFolderOptions(folder),
        child: Padding(
          padding: EdgeInsets.only(
            left: 16.0 + (level * 22.0),
            right: 16,
            top: 10,
            bottom: 10,
          ),
          child: Row(
          children: [
            if (hasChildren)
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  setState(() {
                    if (isExpanded) {
                      _expandedFolderIds.remove(folder.id);
                    } else {
                      _expandedFolderIds.add(folder.id);
                    }
                  });
                },
                child: Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: Icon(
                    isExpanded ? Icons.keyboard_arrow_down : Icons.keyboard_arrow_right,
                    size: 20,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              )
            else
              const SizedBox(width: 26),
            Icon(
              isDefault
                  ? Icons.folder_special
                  : (folder.parentId != null
                      ? Icons.folder_open_outlined
                      : Icons.folder_outlined),
              size: 22,
              color: isDefault
                  ? const Color(0xFFF59E0B)
                  : (isSelected ? colorScheme.primary : const Color(0xFFEAB308)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                folder.name,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected ? colorScheme.primary : colorScheme.onSurface,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (isSelected)
              Icon(
                Icons.check_circle_rounded,
                size: 20,
                color: colorScheme.primary,
              ),
          ],
        ),
      ),
    ),
  );
}
}

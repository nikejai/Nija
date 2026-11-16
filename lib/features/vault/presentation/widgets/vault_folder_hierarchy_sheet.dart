import 'package:flutter/material.dart';
import '../../../../domain/models/folder_tree_builder.dart';
import '../../../../domain/models/folder_tree_node.dart';
import '../../../../domain/models/vault_folder.dart';
import 'vault_create_folder_dialog.dart';

Color resolveFolderColor(VaultFolder folder, {Color defaultColor = const Color(0xFF0381FE)}) {
  if (folder.id == 'default') return const Color(0xFFF59E0B);
  if (folder.color != null && folder.color!.trim().isNotEmpty) {
    return parseFolderHexColor(folder.color, fallback: defaultColor);
  }
  return defaultColor;
}

Future<VaultFolder?> showVaultFolderHierarchySheet(
  BuildContext context, {
  required List<VaultFolder> folders,
  required String selectedFolderId,
  VaultFolderCreateCallback? onCreateFolder,
}) async {
  return showModalBottomSheet<VaultFolder>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
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
  final VaultFolderCreateCallback? onCreateFolder;

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
    final folderColor = resolveFolderColor(folder);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    await showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: folderColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      folder.id == 'default' ? Icons.folder_special : Icons.folder,
                      color: folderColor,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 12),
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
              leading: Icon(Icons.create_new_folder_outlined, color: colorScheme.primary),
              title: Text('Create subfolder inside "${folder.name}"'),
              onTap: () async {
                Navigator.of(sheetContext).pop();
                final subfolder = await showCreateVaultFolderDialog(
                  context,
                  parentFolderId: folder.id,
                  parentFolderName: folder.name,
                  initialColor: folder.color,
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
            if (folder.id != 'default')
              ListTile(
                leading: Icon(Icons.edit_outlined, color: colorScheme.onSurfaceVariant),
                title: const Text('Rename'),
                onTap: () async {
                  Navigator.of(sheetContext).pop();
                  final renamed = await showCreateVaultFolderDialog(
                    context,
                    initialName: folder.name,
                    initialColor: folder.color,
                    isRename: true,
                    onCreateFolder: widget.onCreateFolder,
                  );
                  if (renamed != null && mounted) {
                    setState(() {
                      final idx = _folders.indexWhere((f) => f.id == folder.id);
                      if (idx != -1) {
                        _folders[idx] = _folders[idx].copyWith(name: renamed.name, color: renamed.color);
                      }
                    });
                  }
                },
              ),
            ListTile(
              leading: Icon(Icons.check_circle_outline, color: colorScheme.primary),
              title: const Text('Select this folder'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                Navigator.of(context).pop(folder);
              },
            ),
            const SizedBox(height: 8),
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
      orElse: () => const VaultFolder(
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
        return Container(
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 16,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: Column(
            children: [
              // One UI Drag Handle
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 10, bottom: 4),
                  width: 38,
                  height: 4,
                  decoration: BoxDecoration(
                    color: colorScheme.outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              // Header: "Select folder" on left, '+' and 'x' on right
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 8, 8),
                child: Row(
                  children: [
                    Text(
                      'Select folder',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        fontSize: 18,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      key: const ValueKey('hierarchy-create-folder-button'),
                      tooltip: 'Create folder',
                      icon: const Icon(Icons.add, size: 22),
                      onPressed: _createTopLevelFolder,
                    ),
                    IconButton(
                      tooltip: 'Close',
                      icon: const Icon(Icons.close, size: 20),
                      onPressed: () => Navigator.of(context).pop(null),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              // Folder Tree List
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  children: [
                    _buildFolderTile(
                      folder: defaultFolder,
                      level: 0,
                      hasChildren: false,
                      isExpanded: false,
                    ),
                    for (final node in tree) ..._renderTreeNode(node, 0),
                  ],
                ),
              ),
              // Subtle Native Gesture Discovery Caption
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                  border: Border(top: BorderSide(color: colorScheme.outlineVariant.withValues(alpha: 0.4))),
                ),
                child: Text(
                  'Tap + to create folder · Touch & hold a folder to add subfolder',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 11.5,
                    color: colorScheme.onSurfaceVariant.withValues(alpha: 0.8),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
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
    final folderColor = resolveFolderColor(folder);

    return Material(
      color: isSelected ? folderColor.withValues(alpha: 0.10) : Colors.transparent,
      child: InkWell(
        onTap: () {
          setState(() => _selectedFolderId = folder.id);
          Navigator.of(context).pop(folder);
        },
        onLongPress: () => _showFolderOptions(folder),
        child: Padding(
          padding: EdgeInsets.only(
            left: 14.0 + (level * 22.0),
            right: 16,
            top: 8,
            bottom: 8,
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
                SizedBox(
                  width: 24,
                  child: level > 0
                      ? Center(
                          child: Text(
                            '└',
                            style: TextStyle(
                              color: colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                              fontSize: 14,
                            ),
                          ),
                        )
                      : null,
                ),
              // Folder icon with tinted container
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: folderColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(
                  isDefault
                      ? Icons.folder_special
                      : (folder.parentId != null
                          ? Icons.folder_open_outlined
                          : Icons.folder),
                  size: 18,
                  color: folderColor,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      folder.name,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                        color: isSelected ? folderColor : colorScheme.onSurface,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      isDefault ? 'Standard folder' : (folder.parentId != null ? 'Subfolder' : 'Folder'),
                      style: TextStyle(
                        fontSize: 11,
                        color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ),
              if (isSelected)
                Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    color: folderColor,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check,
                    size: 14,
                    color: Colors.white,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

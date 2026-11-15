import 'package:flutter/material.dart';

import '../../../../app/theme/entry_typography.dart';
import '../../../../core/config/vault_limits.dart';
import '../../../../domain/models/folder_tree_builder.dart';
import '../../../../domain/models/folder_tree_node.dart';
import '../../../../domain/models/vault_folder.dart';

enum ExplorerViewMode { list, grid, tree }

enum FolderSortOption {
  nameAsc,
  nameDesc,
  dateDesc,
  dateAsc,
  sizeDesc,
  type,
}

IconData defaultIconForType(String type) {
  final normalized = type.toLowerCase();
  if (normalized.contains('note')) return Icons.description_outlined;
  if (normalized.contains('password') || normalized.contains('login')) {
    return Icons.lock_outline;
  }
  if (normalized.contains('card')) return Icons.credit_card_outlined;
  if (normalized.contains('ssh')) return Icons.terminal_outlined;
  if (normalized.contains('api')) return Icons.key_outlined;
  if (normalized.contains('wi-fi') || normalized.contains('wifi')) {
    return Icons.wifi_outlined;
  }
  if (normalized.contains('server') || normalized.contains('database')) {
    return Icons.dns_outlined;
  }
  if (normalized.contains('passport')) return Icons.flight_takeoff_outlined;
  if (normalized.contains('license key')) return Icons.verified_outlined;
  if (normalized.contains('license') || normalized.contains('driver')) {
    return Icons.badge_outlined;
  }
  if (normalized.contains('crypto') ||
      normalized.contains('recovery') ||
      normalized.contains('seed')) {
    return Icons.currency_bitcoin_outlined;
  }
  if (normalized.contains('bank')) return Icons.account_balance_outlined;
  if (normalized.contains('finan')) return Icons.account_balance_wallet_outlined;
  if (normalized.contains('ident')) return Icons.perm_identity_outlined;
  if (normalized.contains('document')) return Icons.folder_outlined;
  if (normalized.contains('health')) return Icons.favorite_outline;
  return Icons.shield_outlined;
}

Color defaultColorForType(String type) {
  final normalized = type.toLowerCase();
  if (normalized.contains('note')) return const Color(0xFFA78BFA);
  if (normalized.contains('password') || normalized.contains('login')) {
    return const Color(0xFF60A5FA);
  }
  if (normalized.contains('card')) return const Color(0xFF38BDF8);
  if (normalized.contains('ssh')) return const Color(0xFF34D399);
  if (normalized.contains('api')) return const Color(0xFFF59E0B);
  if (normalized.contains('wi-fi') || normalized.contains('wifi')) {
    return const Color(0xFF06B6D4);
  }
  if (normalized.contains('server') || normalized.contains('database')) {
    return const Color(0xFF8B5CF6);
  }
  if (normalized.contains('passport')) return const Color(0xFF14B8A6);
  if (normalized.contains('license key')) return const Color(0xFF10B981);
  if (normalized.contains('crypto') ||
      normalized.contains('recovery') ||
      normalized.contains('seed')) {
    return const Color(0xFFF97316);
  }
  if (normalized.contains('bank')) return const Color(0xFFEAB308);
  if (normalized.contains('finan')) return const Color(0xFFFBBF24);
  if (normalized.contains('ident')) return const Color(0xFF34D399);
  if (normalized.contains('document')) return const Color(0xFFFB923C);
  if (normalized.contains('health')) return const Color(0xFFF472B6);
  return const Color(0xFF93C5FD);
}

class VaultFoldersView extends StatefulWidget {
  static const String defaultFolderId = 'default';
  static const String defaultFolderName = 'Default';

  static final VaultFolder defaultFolder = VaultFolder(
    id: defaultFolderId,
    name: defaultFolderName,
    icon: 'folder_special',
    createdAt: DateTime.fromMillisecondsSinceEpoch(0).toUtc().toIso8601String(),
    updatedAt: DateTime.fromMillisecondsSinceEpoch(0).toUtc().toIso8601String(),
  );

  const VaultFoldersView({
    super.key,
    required this.isWide,
    required this.folders,
    required this.items,
    required this.notes,
    required this.onOpenItem,
    required this.onAddItemToFolder,
    required this.onUploadDocumentToFolder,
    required this.onCreateFolder,
    required this.onRenameFolder,
    required this.onMoveFolder,
    required this.onDeleteFolder,
    required this.onMoveItem,
    required this.onCopyItem,
    required this.onDeleteItem,
    this.iconForType,
    this.colorForType,
  });

  final bool isWide;
  final List<VaultFolder> folders;
  final List<Map<String, dynamic>> items;
  final List<Map<String, dynamic>> notes;
  final ValueChanged<Map<String, dynamic>> onOpenItem;
  final void Function(String? folderId) onAddItemToFolder;
  final void Function(String? folderId) onUploadDocumentToFolder;
  final void Function(String name, String? parentId, String? color) onCreateFolder;
  final void Function(String folderId, String newName) onRenameFolder;
  final void Function(String folderId, String? newParentId) onMoveFolder;
  final void Function(String folderId, bool cascade) onDeleteFolder;
  final void Function(Map<String, dynamic> item, String? targetFolderId) onMoveItem;
  final void Function(Map<String, dynamic> item, String? targetFolderId) onCopyItem;
  final ValueChanged<Map<String, dynamic>> onDeleteItem;
  final IconData Function(String type)? iconForType;
  final Color Function(String type)? colorForType;

  @override
  State<VaultFoldersView> createState() => _VaultFoldersViewState();
}

class _VaultFoldersViewState extends State<VaultFoldersView> {
  String? _currentFolderId;
  final List<String?> _backHistory = [];
  final List<String?> _forwardHistory = [];
  ExplorerViewMode _viewMode = ExplorerViewMode.list;
  FolderSortOption _sortOption = FolderSortOption.nameAsc;
  final Set<String> _expandedTreeFolderIds = {};
  String _searchFilter = '';

  late final TextEditingController _searchController;
  late final FocusNode _searchFocusNode;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(text: _searchFilter);
    _searchFocusNode = FocusNode();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final text = _searchController.text;
    if (_searchFilter != text) {
      setState(() {
        _searchFilter = text;
      });
    }
  }

  List<VaultFolder> get _effectiveFolders {
    final hasDefault = widget.folders.any((f) => f.id == VaultFoldersView.defaultFolderId);
    if (!hasDefault) {
      return [VaultFoldersView.defaultFolder, ...widget.folders];
    }
    return widget.folders;
  }

  VaultFolder? get _currentFolder {
    if (_currentFolderId == null) return null;
    return _effectiveFolders.cast<VaultFolder?>().firstWhere(
          (f) => f?.id == _currentFolderId,
          orElse: () => null,
        );
  }

  void _navigateToFolder(String? targetFolderId) {
    if (_currentFolderId == targetFolderId) return;
    setState(() {
      _backHistory.add(_currentFolderId);
      _forwardHistory.clear();
      _currentFolderId = targetFolderId;
      if (targetFolderId != null) {
        _expandedTreeFolderIds.add(targetFolderId);
      }
    });
  }

  void _navigateBack() {
    if (_backHistory.isEmpty) return;
    setState(() {
      _forwardHistory.add(_currentFolderId);
      _currentFolderId = _backHistory.removeLast();
    });
  }

  void _navigateForward() {
    if (_forwardHistory.isEmpty) return;
    setState(() {
      _backHistory.add(_currentFolderId);
      _currentFolderId = _forwardHistory.removeLast();
    });
  }

  void _navigateUp() {
    final current = _currentFolder;
    if (current == null) return;
    _navigateToFolder(current.parentId);
  }

  List<VaultFolder> get _childFolders {
    var list = _effectiveFolders.where((f) {
      if (_currentFolderId == null) {
        return f.isRoot;
      }
      return f.parentId == _currentFolderId;
    }).toList();

    if (_searchFilter.trim().isNotEmpty) {
      final q = _searchFilter.toLowerCase().trim();
      list = list.where((f) => f.name.toLowerCase().contains(q)).toList();
    }

    switch (_sortOption) {
      case FolderSortOption.nameAsc:
        list.sort((a, b) {
          if (a.id == VaultFoldersView.defaultFolderId) return -1;
          if (b.id == VaultFoldersView.defaultFolderId) return 1;
          return a.name.toLowerCase().compareTo(b.name.toLowerCase());
        });
      case FolderSortOption.nameDesc:
        list.sort((a, b) {
          if (a.id == VaultFoldersView.defaultFolderId) return -1;
          if (b.id == VaultFoldersView.defaultFolderId) return 1;
          return b.name.toLowerCase().compareTo(a.name.toLowerCase());
        });
      case FolderSortOption.dateDesc:
        list.sort((a, b) {
          if (a.id == VaultFoldersView.defaultFolderId) return -1;
          if (b.id == VaultFoldersView.defaultFolderId) return 1;
          return b.updatedAt.compareTo(a.updatedAt);
        });
      case FolderSortOption.dateAsc:
        list.sort((a, b) {
          if (a.id == VaultFoldersView.defaultFolderId) return -1;
          if (b.id == VaultFoldersView.defaultFolderId) return 1;
          return a.updatedAt.compareTo(b.updatedAt);
        });
      default:
        list.sort((a, b) {
          if (a.id == VaultFoldersView.defaultFolderId) return -1;
          if (b.id == VaultFoldersView.defaultFolderId) return 1;
          return a.name.toLowerCase().compareTo(b.name.toLowerCase());
        });
    }
    return list;
  }

  List<Map<String, dynamic>> get _currentItems {
    final all = [...widget.items, ...widget.notes];

    // At root directory, items are organized inside the 'Default' folder!
    if (_currentFolderId == null) {
      if (_searchFilter.trim().isEmpty) {
        return const <Map<String, dynamic>>[];
      }
      // If user is searching at root, search matches across all items
      final q = _searchFilter.toLowerCase().trim();
      return all.where((item) {
        final title = (item['title'] ?? '').toString().toLowerCase();
        final type = (item['type'] ?? '').toString().toLowerCase();
        return title.contains(q) || type.contains(q);
      }).toList();
    }

    var list = FolderTreeBuilder.getItemsInFolder(
      folderId: _currentFolderId,
      items: all,
      recursive: false,
    );

    if (_searchFilter.trim().isNotEmpty) {
      final q = _searchFilter.toLowerCase().trim();
      list = list.where((item) {
        final title = (item['title'] ?? '').toString().toLowerCase();
        final type = (item['type'] ?? '').toString().toLowerCase();
        return title.contains(q) || type.contains(q);
      }).toList();
    }

    switch (_sortOption) {
      case FolderSortOption.nameAsc:
        list.sort((a, b) => (a['title'] ?? '').toString().toLowerCase().compareTo((b['title'] ?? '').toString().toLowerCase()));
      case FolderSortOption.nameDesc:
        list.sort((a, b) => (b['title'] ?? '').toString().toLowerCase().compareTo((a['title'] ?? '').toString().toLowerCase()));
      case FolderSortOption.dateDesc:
        list.sort((a, b) => (b['updatedAt'] ?? '').toString().compareTo((a['updatedAt'] ?? '').toString()));
      case FolderSortOption.dateAsc:
        list.sort((a, b) => (a['updatedAt'] ?? '').toString().compareTo((b['updatedAt'] ?? '').toString()));
      case FolderSortOption.sizeDesc:
        list.sort((a, b) {
          final sa = (a['size'] ?? a['sizeBytes'] ?? 0) as num;
          final sb = (b['size'] ?? b['sizeBytes'] ?? 0) as num;
          return sb.compareTo(sa);
        });
      case FolderSortOption.type:
        list.sort((a, b) => (a['type'] ?? 'Item').toString().compareTo((b['type'] ?? 'Item').toString()));
    }

    return list;
  }

  int get _currentTotalSizeBytes {
    var total = 0;
    for (final item in _currentItems) {
      final s = item['size'] ?? item['sizeBytes'];
      if (s is num) total += s.toInt();
    }
    return total;
  }

  @override
  Widget build(BuildContext context) {
    final breadcrumbs = FolderTreeBuilder.resolveBreadcrumbs(
      folderId: _currentFolderId,
      folders: _effectiveFolders,
    );

    return Material(
      color: Colors.transparent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Windows Explorer Header & Breadcrumb Bar
          _buildExplorerHeader(context, breadcrumbs),
          const Divider(height: 1),

          // Explorer Action Bar (Views, Sort, Actions)
          _buildExplorerActionBar(context),
          const Divider(height: 1),

          // Main View Content
          Expanded(
            child: _buildExplorerBody(context),
          ),
        ],
      ),
    );
  }

  Widget _buildExplorerHeader(BuildContext context, List<VaultFolder> breadcrumbs) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final canGoBack = _backHistory.isNotEmpty;
    final canGoForward = _forwardHistory.isNotEmpty;
    final canGoUp = _currentFolderId != null;

    final addressBar = Container(
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            // Root chip
            Material(
              color: Colors.transparent,
              child: InkWell(
                key: const ValueKey('explorer-breadcrumb-root'),
                onTap: () => _navigateToFolder(null),
                borderRadius: BorderRadius.circular(4),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.home_outlined, size: 16, color: colorScheme.primary),
                      const SizedBox(width: 4),
                      Text(
                        'Root',
                        style: TextStyle(
                          fontWeight: _currentFolderId == null ? FontWeight.bold : FontWeight.normal,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            for (final segment in breadcrumbs) ...[
              Icon(Icons.chevron_right, size: 16, color: colorScheme.onSurfaceVariant),
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => _navigateToFolder(segment.id),
                  borderRadius: BorderRadius.circular(4),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    child: Text(
                      segment.name,
                      style: TextStyle(
                        fontWeight: segment.id == _currentFolderId ? FontWeight.bold : FontWeight.normal,
                        fontSize: 13,
                        color: segment.id == _currentFolderId ? colorScheme.primary : colorScheme.onSurface,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );

    final searchField = TextField(
      key: const ValueKey('explorer-search-input'),
      controller: _searchController,
      focusNode: _searchFocusNode,
      decoration: InputDecoration(
        hintText: _currentFolderId == null ? 'Search all folders & items...' : 'Search in this folder...',
        prefixIcon: const Icon(Icons.search, size: 16),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        suffixIcon: _searchFilter.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.clear, size: 14),
                onPressed: () {
                  _searchController.clear();
                  setState(() => _searchFilter = '');
                },
                visualDensity: VisualDensity.compact,
              )
            : null,
      ),
    );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      color: theme.scaffoldBackgroundColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.isWide)
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back, size: 20),
                  onPressed: canGoBack ? _navigateBack : null,
                  tooltip: 'Back',
                  visualDensity: VisualDensity.compact,
                ),
                IconButton(
                  icon: const Icon(Icons.arrow_forward, size: 20),
                  onPressed: canGoForward ? _navigateForward : null,
                  tooltip: 'Forward',
                  visualDensity: VisualDensity.compact,
                ),
                IconButton(
                  icon: const Icon(Icons.arrow_upward, size: 20),
                  onPressed: canGoUp ? _navigateUp : null,
                  tooltip: 'Up to parent folder',
                  visualDensity: VisualDensity.compact,
                ),
                const SizedBox(width: 8),
                Expanded(child: addressBar),
                const SizedBox(width: 8),
                SizedBox(
                  width: 220,
                  height: 38,
                  child: searchField,
                ),
              ],
            )
          else ...[
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back, size: 20),
                  onPressed: canGoBack ? _navigateBack : null,
                  tooltip: 'Back',
                  visualDensity: VisualDensity.compact,
                ),
                IconButton(
                  icon: const Icon(Icons.arrow_forward, size: 20),
                  onPressed: canGoForward ? _navigateForward : null,
                  tooltip: 'Forward',
                  visualDensity: VisualDensity.compact,
                ),
                IconButton(
                  icon: const Icon(Icons.arrow_upward, size: 20),
                  onPressed: canGoUp ? _navigateUp : null,
                  tooltip: 'Up to parent folder',
                  visualDensity: VisualDensity.compact,
                ),
                const SizedBox(width: 4),
                Expanded(child: addressBar),
              ],
            ),
            const SizedBox(height: 6),
            SizedBox(
              height: 38,
              child: searchField,
            ),
          ],
          const SizedBox(height: 6),
          // Metadata metrics subtitle
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Wrap(
              spacing: 8,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  _currentFolder == null ? 'Root Directory' : _currentFolder!.name,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: colorScheme.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _currentFolderId == null
                        ? '${_childFolders.length} folders · ${widget.items.length + widget.notes.length} total items'
                        : '${_childFolders.length} folders · ${_currentItems.length} items'
                            '${_currentTotalSizeBytes > 0 ? " · ${VaultLimits.formatBytes(_currentTotalSizeBytes)}" : ""}',
                    style: EntryTypography.technicalMonospace(
                      fontSize: 11,
                      color: colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExplorerActionBar(BuildContext context) {
    final theme = Theme.of(context);

    final actions = <Widget>[
      FilledButton.icon(
        key: const ValueKey('explorer-new-folder-button'),
        icon: const Icon(Icons.create_new_folder_outlined, size: 16),
        label: const Text('New Folder'),
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, 34),
          visualDensity: VisualDensity.compact,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        ),
        onPressed: _showCreateFolderDialog,
      ),
      const SizedBox(width: 6),
      OutlinedButton.icon(
        key: const ValueKey('explorer-add-item-button'),
        icon: const Icon(Icons.add_circle_outline, size: 16),
        label: const Text('Add Item'),
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 34),
          visualDensity: VisualDensity.compact,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        ),
        onPressed: () => widget.onAddItemToFolder(
          _currentFolderId == VaultFoldersView.defaultFolderId ? null : _currentFolderId,
        ),
      ),
      const SizedBox(width: 6),
      OutlinedButton.icon(
        key: const ValueKey('explorer-upload-file-button'),
        icon: const Icon(Icons.upload_file_outlined, size: 16),
        label: const Text('Upload File'),
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 34),
          visualDensity: VisualDensity.compact,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        ),
        onPressed: () => widget.onUploadDocumentToFolder(
          _currentFolderId == VaultFoldersView.defaultFolderId ? null : _currentFolderId,
        ),
      ),
    ];

    final viewControls = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        PopupMenuButton<FolderSortOption>(
          initialValue: _sortOption,
          tooltip: 'Sort by',
          icon: const Icon(Icons.sort, size: 20),
          onSelected: (option) => setState(() => _sortOption = option),
          itemBuilder: (context) => const [
            PopupMenuItem(value: FolderSortOption.nameAsc, child: Text('Name (A to Z)')),
            PopupMenuItem(value: FolderSortOption.nameDesc, child: Text('Name (Z to A)')),
            PopupMenuItem(value: FolderSortOption.dateDesc, child: Text('Date (Newest first)')),
            PopupMenuItem(value: FolderSortOption.dateAsc, child: Text('Date (Oldest first)')),
            PopupMenuItem(value: FolderSortOption.sizeDesc, child: Text('Size (Largest first)')),
            PopupMenuItem(value: FolderSortOption.type, child: Text('Type')),
          ],
        ),
        const SizedBox(width: 4),
        SegmentedButton<ExplorerViewMode>(
          segments: const [
            ButtonSegment(value: ExplorerViewMode.list, icon: Icon(Icons.view_list, size: 16), tooltip: 'List view'),
            ButtonSegment(value: ExplorerViewMode.grid, icon: Icon(Icons.grid_view, size: 16), tooltip: 'Grid view'),
            ButtonSegment(value: ExplorerViewMode.tree, icon: Icon(Icons.account_tree_outlined, size: 16), tooltip: 'Tree view'),
          ],
          selected: {_viewMode},
          onSelectionChanged: (selected) {
            setState(() => _viewMode = selected.first);
          },
          style: const ButtonStyle(
            visualDensity: VisualDensity.compact,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ),
      ],
    );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      color: theme.scaffoldBackgroundColor,
      child: widget.isWide
          ? Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(mainAxisSize: MainAxisSize.min, children: actions),
                viewControls,
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(children: actions),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [viewControls],
                ),
              ],
            ),
    );
  }

  Widget _buildExplorerBody(BuildContext context) {
    if (_viewMode == ExplorerViewMode.tree) {
      return _buildTreeView(context);
    } else if (_viewMode == ExplorerViewMode.grid) {
      return _buildGridView(context);
    }
    return _buildListView(context);
  }

  // --- 1. LIST VIEW ---
  Widget _buildListView(BuildContext context) {
    final subfolders = _childFolders;
    final items = _currentItems;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (subfolders.isEmpty && items.isEmpty) {
      return _buildEmptyState(context);
    }

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      children: [
        // Table Header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Expanded(
                flex: 4,
                child: Text('Name', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: colorScheme.onSurfaceVariant)),
              ),
              Expanded(
                flex: 2,
                child: Text('Type', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: colorScheme.onSurfaceVariant)),
              ),
              Expanded(
                flex: 2,
                child: Text('Size', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: colorScheme.onSurfaceVariant)),
              ),
              const SizedBox(width: 40),
            ],
          ),
        ),
        const SizedBox(height: 4),

        // Subfolders
        for (final folder in subfolders)
          _buildFolderListRow(context, folder),

        // Items / Files
        for (final item in items)
          _buildItemListRow(context, item),
      ],
    );
  }

  Widget _buildFolderListRow(BuildContext context, VaultFolder folder) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDefault = folder.id == VaultFoldersView.defaultFolderId;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 2),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: colorScheme.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => _navigateToFolder(folder.id),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Expanded(
                flex: 4,
                child: Row(
                  children: [
                    Icon(
                      isDefault ? Icons.folder_special : Icons.folder,
                      color: isDefault ? const Color(0xFFF59E0B) : const Color(0xFFEAB308),
                      size: 22,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        folder.name,
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  isDefault ? 'Default folder' : 'File folder',
                  style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
                ),
              ),
              Expanded(
                flex: 2,
                child: Text('--', style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant)),
              ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, size: 18),
                onSelected: (val) => _handleFolderAction(folder, val),
                itemBuilder: (ctx) => [
                  const PopupMenuItem(value: 'open', child: Text('Open')),
                  if (!isDefault) ...const [
                    PopupMenuItem(value: 'rename', child: Text('Rename')),
                    PopupMenuItem(value: 'move', child: Text('Move to...')),
                    PopupMenuItem(value: 'delete', child: Text('Delete', style: TextStyle(color: Colors.red))),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildItemListRow(BuildContext context, Map<String, dynamic> item) {
    final colorScheme = Theme.of(context).colorScheme;
    final title = (item['title'] ?? 'Untitled').toString();
    final type = (item['type'] ?? 'Item').toString();
    final sizeBytes = item['size'] ?? item['sizeBytes'];
    final sizeLabel = (sizeBytes is num && sizeBytes > 0)
        ? VaultLimits.formatBytes(sizeBytes.toInt())
        : (item['subtitle'] ?? '--').toString();

    final itemIcon = widget.iconForType?.call(type) ?? defaultIconForType(type);
    final itemColor = widget.colorForType?.call(type) ?? defaultColorForType(type);

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 2),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: colorScheme.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => widget.onOpenItem(item),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Expanded(
                flex: 4,
                child: Row(
                  children: [
                    Container(
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(
                        color: itemColor.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Icon(itemIcon, color: itemColor, size: 16),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(type, style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant)),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  sizeLabel,
                  style: EntryTypography.technicalMonospace(fontSize: 11, color: colorScheme.onSurfaceVariant),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, size: 18),
                onSelected: (val) => _handleItemAction(item, val),
                itemBuilder: (ctx) => [
                  const PopupMenuItem(value: 'open', child: Text('Open Details')),
                  const PopupMenuItem(value: 'copy', child: Text('Copy to...')),
                  const PopupMenuItem(value: 'move', child: Text('Move to...')),
                  const PopupMenuItem(value: 'delete', child: Text('Delete', style: TextStyle(color: Colors.red))),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- 2. GRID VIEW ---
  Widget _buildGridView(BuildContext context) {
    final subfolders = _childFolders;
    final items = _currentItems;

    if (subfolders.isEmpty && items.isEmpty) {
      return _buildEmptyState(context);
    }

    final totalCount = subfolders.length + items.length;

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 180,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 0.95,
      ),
      itemCount: totalCount,
      itemBuilder: (context, index) {
        if (index < subfolders.length) {
          final folder = subfolders[index];
          return _buildFolderGridTile(context, folder);
        } else {
          final item = items[index - subfolders.length];
          return _buildItemGridTile(context, item);
        }
      },
    );
  }

  Widget _buildFolderGridTile(BuildContext context, VaultFolder folder) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDefault = folder.id == VaultFoldersView.defaultFolderId;

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: colorScheme.outlineVariant.withValues(alpha: 0.6)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _navigateToFolder(folder.id),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  PopupMenuButton<String>(
                    padding: EdgeInsets.zero,
                    icon: const Icon(Icons.more_horiz, size: 16),
                    onSelected: (val) => _handleFolderAction(folder, val),
                    itemBuilder: (ctx) => [
                      const PopupMenuItem(value: 'open', child: Text('Open')),
                      if (!isDefault) ...const [
                        PopupMenuItem(value: 'rename', child: Text('Rename')),
                        PopupMenuItem(value: 'move', child: Text('Move to...')),
                        PopupMenuItem(value: 'delete', child: Text('Delete', style: TextStyle(color: Colors.red))),
                      ],
                    ],
                  ),
                ],
              ),
              Icon(
                isDefault ? Icons.folder_special : Icons.folder,
                color: isDefault ? const Color(0xFFF59E0B) : const Color(0xFFEAB308),
                size: 48,
              ),
              const SizedBox(height: 8),
              Text(
                folder.name,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 2),
              Text(
                isDefault ? 'Default folder' : 'Folder',
                style: TextStyle(fontSize: 11, color: colorScheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildItemGridTile(BuildContext context, Map<String, dynamic> item) {
    final colorScheme = Theme.of(context).colorScheme;
    final title = (item['title'] ?? 'Untitled').toString();
    final type = (item['type'] ?? 'Item').toString();
    final itemIcon = widget.iconForType?.call(type) ?? defaultIconForType(type);
    final itemColor = widget.colorForType?.call(type) ?? defaultColorForType(type);

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: colorScheme.outlineVariant.withValues(alpha: 0.6)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => widget.onOpenItem(item),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  PopupMenuButton<String>(
                    padding: EdgeInsets.zero,
                    icon: const Icon(Icons.more_horiz, size: 16),
                    onSelected: (val) => _handleItemAction(item, val),
                    itemBuilder: (ctx) => const [
                      PopupMenuItem(value: 'open', child: Text('Open Details')),
                      PopupMenuItem(value: 'copy', child: Text('Copy to...')),
                      PopupMenuItem(value: 'move', child: Text('Move to...')),
                      PopupMenuItem(value: 'delete', child: Text('Delete', style: TextStyle(color: Colors.red))),
                    ],
                  ),
                ],
              ),
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: itemColor.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(itemIcon, color: itemColor, size: 24),
              ),
              const SizedBox(height: 8),
              Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 2),
              Text(
                type,
                style: TextStyle(fontSize: 11, color: colorScheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- 3. TREE VIEW ---
  Widget _buildTreeView(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final tree = FolderTreeBuilder.buildTree(
      folders: _effectiveFolders,
      items: [...widget.items, ...widget.notes],
    );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Left Pane: Folder Tree
        SizedBox(
          width: widget.isWide ? 260 : 160,
          child: Container(
            decoration: BoxDecoration(
              border: Border(right: BorderSide(color: colorScheme.outlineVariant.withValues(alpha: 0.5))),
            ),
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
              children: [
                // Root Tree Entry
                _buildTreeFolderTile(
                  title: 'Root',
                  folderId: null,
                  isSelected: _currentFolderId == null,
                  hasChildren: tree.isNotEmpty,
                  level: 0,
                ),
                for (final node in tree)
                  ..._renderTreeNode(node, 1),
              ],
            ),
          ),
        ),

        // Right Pane: Contents of the active folder
        Expanded(
          child: _buildListView(context),
        ),
      ],
    );
  }

  List<Widget> _renderTreeNode(FolderTreeNode node, int level) {
    final folder = node.folder;
    final isSelected = _currentFolderId == folder.id;
    final isExpanded = _expandedTreeFolderIds.contains(folder.id);
    final hasChildren = node.children.isNotEmpty;

    final widgets = <Widget>[
      _buildTreeFolderTile(
        title: folder.name,
        folderId: folder.id,
        isSelected: isSelected,
        hasChildren: hasChildren,
        level: level,
      ),
    ];

    if (isExpanded && hasChildren) {
      for (final child in node.children) {
        widgets.addAll(_renderTreeNode(child, level + 1));
      }
    }

    return widgets;
  }

  Widget _buildTreeFolderTile({
    required String title,
    required String? folderId,
    required bool isSelected,
    required bool hasChildren,
    required int level,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final isExpanded = folderId != null && _expandedTreeFolderIds.contains(folderId);

    return InkWell(
      onTap: () => _navigateToFolder(folderId),
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: EdgeInsets.only(left: 4.0 + (level * 14.0), right: 6, top: 6, bottom: 6),
        decoration: BoxDecoration(
          color: isSelected ? colorScheme.primary.withValues(alpha: 0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          children: [
            if (hasChildren && folderId != null)
              GestureDetector(
                onTap: () {
                  setState(() {
                    if (isExpanded) {
                      _expandedTreeFolderIds.remove(folderId);
                    } else {
                      _expandedTreeFolderIds.add(folderId);
                    }
                  });
                },
                child: Icon(
                  isExpanded ? Icons.keyboard_arrow_down : Icons.keyboard_arrow_right,
                  size: 16,
                  color: colorScheme.onSurfaceVariant,
                ),
              )
            else
              const SizedBox(width: 16),
            const SizedBox(width: 4),
            Icon(
              isSelected ? Icons.folder_open : Icons.folder,
              size: 18,
              color: const Color(0xFFEAB308),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: isSelected ? colorScheme.primary : colorScheme.onSurface,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- EMPTY STATE ---
  Widget _buildEmptyState(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.folder_open_outlined, size: 64, color: colorScheme.outlineVariant),
            const SizedBox(height: 16),
            Text(
              'This folder is empty',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 6),
            Text(
              'Create a subfolder, add a new credential, or upload encrypted files.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 20),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                FilledButton.icon(
                  icon: const Icon(Icons.create_new_folder_outlined, size: 18),
                  label: const Text('New Folder'),
                  style: FilledButton.styleFrom(minimumSize: const Size(0, 38)),
                  onPressed: _showCreateFolderDialog,
                ),
                OutlinedButton.icon(
                  icon: const Icon(Icons.add_circle_outline, size: 18),
                  label: const Text('Add Item'),
                  style: OutlinedButton.styleFrom(minimumSize: const Size(0, 38)),
                  onPressed: () => widget.onAddItemToFolder(
                    _currentFolderId == VaultFoldersView.defaultFolderId ? null : _currentFolderId,
                  ),
                ),
                OutlinedButton.icon(
                  icon: const Icon(Icons.upload_file_outlined, size: 18),
                  label: const Text('Upload File'),
                  style: OutlinedButton.styleFrom(minimumSize: const Size(0, 38)),
                  onPressed: () => widget.onUploadDocumentToFolder(
                    _currentFolderId == VaultFoldersView.defaultFolderId ? null : _currentFolderId,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // --- ACTIONS & DIALOGS ---
  void _showCreateFolderDialog() {
    final controller = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Create New Folder'),
        content: TextField(
          key: const ValueKey('create-folder-name-input'),
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Folder Name',
            hintText: 'e.g. Work, Taxes, Identity',
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            key: const ValueKey('create-folder-submit-button'),
            style: FilledButton.styleFrom(minimumSize: const Size(64, 38)),
            onPressed: () {
              final name = controller.text.trim();
              if (name.isNotEmpty) {
                widget.onCreateFolder(name, _currentFolderId, null);
                Navigator.pop(ctx);
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  void _handleFolderAction(VaultFolder folder, String action) {
    switch (action) {
      case 'open':
        _navigateToFolder(folder.id);
      case 'rename':
        final controller = TextEditingController(text: folder.name);
        showDialog<void>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Rename Folder'),
            content: TextField(
              controller: controller,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'Folder Name'),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
              FilledButton(
                style: FilledButton.styleFrom(minimumSize: const Size(64, 38)),
                onPressed: () {
                  final name = controller.text.trim();
                  if (name.isNotEmpty) {
                    widget.onRenameFolder(folder.id, name);
                    Navigator.pop(ctx);
                  }
                },
                child: const Text('Save'),
              ),
            ],
          ),
        );
      case 'move':
        _showMoveFolderPicker(folder);
      case 'delete':
        showDialog<void>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text('Delete "${folder.name}"?'),
            content: const Text(
              'Choose whether to keep files (moving them to the parent folder) or delete the folder and all nested files.',
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
              OutlinedButton(
                style: OutlinedButton.styleFrom(minimumSize: const Size(64, 38)),
                onPressed: () {
                  widget.onDeleteFolder(folder.id, false); // Reparent
                  Navigator.pop(ctx);
                },
                child: const Text('Keep Files'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.red,
                  minimumSize: const Size(64, 38),
                ),
                onPressed: () {
                  widget.onDeleteFolder(folder.id, true); // Cascade
                  Navigator.pop(ctx);
                },
                child: const Text('Delete All'),
              ),
            ],
          ),
        );
    }
  }

  void _showMoveFolderPicker(VaultFolder folder) {
    // Collect potential parent folders (excluding itself and its descendants)
    final descendants = FolderTreeBuilder.getDescendantFolderIds(folderId: folder.id, folders: widget.folders);
    final candidates = widget.folders.where((f) => f.id != folder.id && !descendants.contains(f.id)).toList();

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Move "${folder.name}" to...'),
        content: SizedBox(
          width: 320,
          child: ListView(
            shrinkWrap: true,
            children: [
              ListTile(
                leading: const Icon(Icons.home_outlined),
                title: const Text('Root Directory'),
                onTap: () {
                  widget.onMoveFolder(folder.id, null);
                  Navigator.pop(ctx);
                },
              ),
              for (final candidate in candidates)
                ListTile(
                  leading: const Icon(Icons.folder, color: Color(0xFFEAB308)),
                  title: Text(candidate.name),
                  onTap: () {
                    widget.onMoveFolder(folder.id, candidate.id);
                    Navigator.pop(ctx);
                  },
                ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        ],
      ),
    );
  }

  void _handleItemAction(Map<String, dynamic> item, String action) {
    switch (action) {
      case 'open':
        widget.onOpenItem(item);
      case 'move':
        showDialog<void>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text('Move "${item['title'] ?? 'item'}" to...'),
            content: SizedBox(
              width: 320,
              child: ListView(
                shrinkWrap: true,
                children: [
                  ListTile(
                    leading: const Icon(Icons.folder_special, color: Color(0xFFF59E0B)),
                    title: const Text('Default Folder'),
                    subtitle: const Text('Move to default vault location'),
                    onTap: () {
                      widget.onMoveItem(item, null);
                      Navigator.pop(ctx);
                    },
                  ),
                  for (final target in widget.folders.where((f) => f.id != VaultFoldersView.defaultFolderId))
                    ListTile(
                      leading: const Icon(Icons.folder, color: Color(0xFFEAB308)),
                      title: Text(target.name),
                      onTap: () {
                        widget.onMoveItem(item, target.id);
                        Navigator.pop(ctx);
                      },
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ],
          ),
        );
      case 'copy':
        showDialog<void>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text('Copy "${item['title'] ?? 'item'}" to...'),
            content: SizedBox(
              width: 320,
              child: ListView(
                shrinkWrap: true,
                children: [
                  ListTile(
                    leading: const Icon(Icons.folder_special, color: Color(0xFFF59E0B)),
                    title: const Text('Default Folder'),
                    subtitle: const Text('Copy to default vault location'),
                    onTap: () {
                      widget.onCopyItem(item, null);
                      Navigator.pop(ctx);
                    },
                  ),
                  for (final target in widget.folders.where((f) => f.id != VaultFoldersView.defaultFolderId))
                    ListTile(
                      leading: const Icon(Icons.folder, color: Color(0xFFEAB308)),
                      title: Text(target.name),
                      onTap: () {
                        widget.onCopyItem(item, target.id);
                        Navigator.pop(ctx);
                      },
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ],
          ),
        );
      case 'delete':
        showDialog<void>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text('Delete "${item['title'] ?? 'item'}"?'),
            content: const Text('Are you sure you want to delete this encrypted item?'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.red,
                  minimumSize: const Size(64, 38),
                ),
                onPressed: () {
                  widget.onDeleteItem(item);
                  Navigator.pop(ctx);
                },
                child: const Text('Delete'),
              ),
            ],
          ),
        );
    }
  }
}

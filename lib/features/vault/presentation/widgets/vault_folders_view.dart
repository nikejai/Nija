import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../app/theme/entry_typography.dart';
import '../../../../core/config/vault_limits.dart';
import '../../../../domain/models/folder_tree_builder.dart';
import '../../../../domain/models/folder_tree_node.dart';
import '../../../../domain/models/vault_folder.dart';
import 'vault_create_folder_dialog.dart';
import 'vault_folder_hierarchy_sheet.dart';

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
  if (normalized.contains('password') || normalized.contains('login') || normalized.contains('credential')) {
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
  if (normalized.contains('document') || normalized.contains('file') || normalized.contains('pdf')) {
    return Icons.insert_drive_file_outlined;
  }
  if (normalized.contains('health')) return Icons.favorite_outline;
  if (normalized.contains('secure note')) return Icons.sticky_note_2_outlined;
  return Icons.description_outlined;
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
  return const Color(0xFFA78BFA);
}

String resolveItemType(Map<String, dynamic> item) {
  final explicitType = item['type']?.toString().trim();
  if (explicitType != null &&
      explicitType.isNotEmpty &&
      explicitType.toLowerCase() != 'item') {
    return explicitType;
  }
  if (item['delta'] != null || item.containsKey('preview')) {
    return 'Note';
  }
  final tags = item['tags'];
  if (tags is List && tags.map((t) => t.toString().toLowerCase()).contains('note')) {
    return 'Note';
  }
  final fields = item['fields'];
  if (fields is List && fields.isNotEmpty) {
    final fieldLabels = fields.map((f) => (f['label'] ?? f['name'] ?? '').toString().toLowerCase()).toList();
    if (fieldLabels.any((l) => l.contains('card') || l.contains('cvv') || l.contains('expiry') || l.contains('holder'))) {
      return 'Credit Card';
    }
    if (fieldLabels.any((l) => l.contains('password') || l.contains('username') || l.contains('login') || l.contains('email'))) {
      return 'Password';
    }
  }
  return (explicitType != null && explicitType.isNotEmpty && explicitType != 'Item') ? explicitType : 'Note';
}

int resolveItemSizeBytes(Map<String, dynamic> item) {
  final s = item['size'] ?? item['sizeBytes'];
  if (s is num && s > 0) return s.toInt();
  if (item['delta'] != null) {
    try {
      return utf8.encode(jsonEncode(item['delta'])).length;
    } catch (_) {}
  }
  if (item['preview'] != null) {
    return utf8.encode(item['preview'].toString()).length;
  }
  return 0;
}

String resolveItemSizeLabel(Map<String, dynamic> item) {
  final sizeBytes = resolveItemSizeBytes(item);
  if (sizeBytes > 0) {
    return VaultLimits.formatBytes(sizeBytes);
  }
  final sub = (item['subtitle'] ?? '').toString().trim();
  if (sub.isNotEmpty && sub != '--') {
    return sub;
  }
  return '--';
}

String resolveItemDateLabel(Map<String, dynamic> item) {
  final raw = item['updatedAt'] ?? item['updated'] ?? item['createdAt'] ?? item['date'];
  if (raw == null) return '';
  final str = raw.toString().trim();
  if (str.isEmpty || str == '--') return '';
  if (str == 'Now' ||
      str.toLowerCase().contains('ago') ||
      str.toLowerCase().contains('today') ||
      str.toLowerCase().contains('yesterday')) {
    return str;
  }
  try {
    final dt = DateTime.parse(str);
    final local = dt.toLocal();
    final now = DateTime.now();
    final isToday = local.year == now.year && local.month == now.month && local.day == now.day;
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
    final ampm = local.hour >= 12 ? 'PM' : 'AM';
    final minute = local.minute.toString().padLeft(2, '0');
    final timeStr = '$hour:$minute $ampm';
    if (isToday) {
      return 'Today, $timeStr';
    }
    return '${months[local.month - 1]} ${local.day}, ${local.year}';
  } catch (_) {
    return str;
  }
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
    this.onUpdateFolderColor,
    required this.onMoveFolder,
    required this.onDeleteFolder,
    required this.onMoveItem,
    required this.onCopyItem,
    required this.onDeleteItem,
    this.onMoveItems,
    this.onCopyItems,
    this.onDeleteItems,
    this.isDemoPreview = false,
    this.onExitDemoPreview,
    this.onFolderChanged,
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
  final void Function(String folderId, String? color)? onUpdateFolderColor;
  final void Function(String folderId, String? newParentId) onMoveFolder;
  final void Function(String folderId, bool cascade) onDeleteFolder;
  final void Function(Map<String, dynamic> item, String? targetFolderId) onMoveItem;
  final void Function(Map<String, dynamic> item, String? targetFolderId) onCopyItem;
  final ValueChanged<Map<String, dynamic>> onDeleteItem;
  final void Function(List<Map<String, dynamic>> items, String? targetFolderId)? onMoveItems;
  final void Function(List<Map<String, dynamic>> items, String? targetFolderId)? onCopyItems;
  final void Function(List<Map<String, dynamic>> items)? onDeleteItems;
  final bool isDemoPreview;
  final VoidCallback? onExitDemoPreview;
  final ValueChanged<String?>? onFolderChanged;
  final IconData Function(String type)? iconForType;
  final Color Function(String type)? colorForType;

  @override
  State<VaultFoldersView> createState() => _VaultFoldersViewState();
}

class _VaultFoldersViewState extends State<VaultFoldersView> {
  String? _currentFolderId;
  final List<String?> _backHistory = [];
  ExplorerViewMode _viewMode = ExplorerViewMode.list;
  FolderSortOption _sortOption = FolderSortOption.nameAsc;
  final Set<String> _expandedTreeFolderIds = {};
  String _searchFilter = '';
  bool _isSearchExpanded = false;

  final Set<String> _selectedItemIds = {};
  bool _isSelectionModeExplicit = false;
  bool get _isSelectionMode => _isSelectionModeExplicit || _selectedItemIds.isNotEmpty;

  late final TextEditingController _searchController;
  late final FocusNode _searchFocusNode;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(text: _searchFilter);
    _searchFocusNode = FocusNode();
    _searchController.addListener(_onSearchChanged);
    if (_searchFilter.isNotEmpty) {
      _isSearchExpanded = true;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onFolderChanged?.call(_currentFolderId);
    });
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
        if (text.isNotEmpty) {
          _isSearchExpanded = true;
        }
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

  VaultFolder? _folderById(String? folderId) {
    if (folderId == null) return null;
    return _effectiveFolders.cast<VaultFolder?>().firstWhere(
          (f) => f?.id == folderId,
          orElse: () => null,
        );
  }

  String _itemId(Map<String, dynamic> item) {
    final id = item['id'];
    if (id != null && id.toString().isNotEmpty) {
      return id.toString();
    }
    return (item['title'] ?? '').toString();
  }

  List<Map<String, dynamic>> get _selectedItems {
    final all = [...widget.items, ...widget.notes];
    return all.where((i) => _selectedItemIds.contains(_itemId(i))).toList();
  }

  void _toggleItemSelection(Map<String, dynamic> item) {
    final id = _itemId(item);
    setState(() {
      _isSelectionModeExplicit = true;
      if (_selectedItemIds.contains(id)) {
        _selectedItemIds.remove(id);
      } else {
        _selectedItemIds.add(id);
      }
    });
  }

  void _exitSelectionMode() {
    setState(() {
      _selectedItemIds.clear();
      _isSelectionModeExplicit = false;
    });
  }

  void _selectAllItems() {
    final items = _currentItems;
    final allSelected = items.isNotEmpty && items.every((i) => _selectedItemIds.contains(_itemId(i)));
    setState(() {
      if (allSelected) {
        _selectedItemIds.clear();
      } else {
        for (final item in items) {
          _selectedItemIds.add(_itemId(item));
        }
      }
    });
  }

  Future<VaultFolder?> _createFolderCallback(
    String name, {
    String? parentId,
    String? color,
  }) async {
    widget.onCreateFolder(name, parentId, color);
    return VaultFolder(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
      parentId: parentId,
      color: color,
      createdAt: DateTime.now().toIso8601String(),
      updatedAt: DateTime.now().toIso8601String(),
    );
  }

  Future<void> _moveSelectedItems() async {
    final selected = _selectedItems;
    if (selected.isEmpty) return;
    final targetFolder = await showVaultFolderHierarchySheet(
      context,
      folders: widget.folders,
      selectedFolderId: _currentFolderId ?? VaultFoldersView.defaultFolderId,
      onCreateFolder: _createFolderCallback,
      title: 'Move ${selected.length} items to...',
    );
    if (targetFolder == null || !mounted) return;

    _exitSelectionMode();
    final targetId = targetFolder.id == VaultFoldersView.defaultFolderId || targetFolder.id == 'root'
        ? null
        : targetFolder.id;

    if (widget.onMoveItems != null) {
      widget.onMoveItems!(selected, targetId);
    } else {
      for (final item in selected) {
        widget.onMoveItem(item, targetId);
      }
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Moved ${selected.length} items to "${targetFolder.name}".')),
    );
  }

  Future<void> _copySelectedItems() async {
    final selected = _selectedItems;
    if (selected.isEmpty) return;
    final targetFolder = await showVaultFolderHierarchySheet(
      context,
      folders: widget.folders,
      selectedFolderId: _currentFolderId ?? VaultFoldersView.defaultFolderId,
      onCreateFolder: _createFolderCallback,
      title: 'Copy ${selected.length} items to...',
    );
    if (targetFolder == null || !mounted) return;

    _exitSelectionMode();
    final targetId = targetFolder.id == VaultFoldersView.defaultFolderId || targetFolder.id == 'root'
        ? null
        : targetFolder.id;

    if (widget.onCopyItems != null) {
      widget.onCopyItems!(selected, targetId);
    } else {
      for (final item in selected) {
        widget.onCopyItem(item, targetId);
      }
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Copied ${selected.length} items to "${targetFolder.name}".')),
    );
  }

  void _deleteSelectedItems() {
    final selected = _selectedItems;
    if (selected.isEmpty) return;
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete ${selected.length} items?'),
        content: Text(
          selected.length == 1
              ? 'Are you sure you want to delete this encrypted item?'
              : 'Are you sure you want to delete these ${selected.length} encrypted items? This action cannot be undone.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red,
              minimumSize: const Size(64, 38),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              _exitSelectionMode();
              if (widget.onDeleteItems != null) {
                widget.onDeleteItems!(selected);
              } else {
                for (final item in selected) {
                  widget.onDeleteItem(item);
                }
              }
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Deleted ${selected.length} items.')),
              );
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _navigateToFolder(String? targetFolderId) {
    if (_currentFolderId == targetFolderId) return;
    _exitSelectionMode();
    setState(() {
      _backHistory.add(_currentFolderId);
      _currentFolderId = targetFolderId;
      if (targetFolderId != null) {
        _expandedTreeFolderIds.add(targetFolderId);
      }
    });
    widget.onFolderChanged?.call(targetFolderId);
  }

  void _navigateBack() {
    if (_backHistory.isEmpty) return;
    _exitSelectionMode();
    setState(() {
      _currentFolderId = _backHistory.removeLast();
    });
    widget.onFolderChanged?.call(_currentFolderId);
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
          // Demo preview indicator banner
          if (widget.isDemoPreview) _buildDemoBanner(context),

          // Consolidated, space-optimized Explorer Header
          _buildExplorerHeader(context, breadcrumbs),
          const Divider(height: 1),

          // Main View Content
          Expanded(
            child: _buildExplorerBody(context),
          ),
          if (_isSelectionMode && _selectedItemIds.isNotEmpty)
            _buildSelectionBottomBar(context),
        ],
      ),
    );
  }

  Widget _buildSelectionBottomBar(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final count = _selectedItemIds.length;

    return Container(
      key: const ValueKey('explorer-selection-bottom-bar'),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        border: Border(top: BorderSide(color: colorScheme.outlineVariant.withValues(alpha: 0.5))),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                key: const ValueKey('explorer-bottom-move'),
                style: OutlinedButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                ),
                icon: const Icon(Icons.drive_file_move_outlined, size: 18),
                label: Text('Move ($count)'),
                onPressed: _moveSelectedItems,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                key: const ValueKey('explorer-bottom-copy'),
                style: OutlinedButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                ),
                icon: const Icon(Icons.content_copy_outlined, size: 18),
                label: Text('Copy ($count)'),
                onPressed: _copySelectedItems,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: FilledButton.icon(
                key: const ValueKey('explorer-bottom-delete'),
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                ),
                icon: const Icon(Icons.delete_outline, size: 18),
                label: Text('Delete ($count)'),
                onPressed: _deleteSelectedItems,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDemoBanner(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      key: const ValueKey('explorer-demo-preview-banner'),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: colorScheme.secondaryContainer.withValues(alpha: 0.5),
        border: Border(bottom: BorderSide(color: colorScheme.secondary.withValues(alpha: 0.2))),
      ),
      child: Row(
        children: [
          Icon(Icons.visibility_outlined, size: 16, color: colorScheme.secondary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Viewing Demo Folders & Files',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: colorScheme.onSecondaryContainer,
              ),
            ),
          ),
          if (widget.onExitDemoPreview != null)
            TextButton(
              key: const ValueKey('explorer-exit-demo-button'),
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                minimumSize: const Size(0, 28),
              ),
              onPressed: widget.onExitDemoPreview,
              child: const Text('Exit Demo', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            ),
        ],
      ),
    );
  }

  Widget _buildExplorerHeader(BuildContext context, List<VaultFolder> breadcrumbs) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final canGoBack = _backHistory.isNotEmpty;
    final canGoUp = _currentFolderId != null;

    if (_isSelectionMode) {
      final allSelected = _currentItems.isNotEmpty &&
          _currentItems.every((i) => _selectedItemIds.contains(_itemId(i)));
      final count = _selectedItemIds.length;
      return Container(
        key: const ValueKey('explorer-selection-header'),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        color: theme.scaffoldBackgroundColor,
        child: Row(
          children: [
            IconButton(
              key: const ValueKey('explorer-selection-cancel'),
              icon: const Icon(Icons.close, size: 20),
              tooltip: 'Cancel selection',
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              onPressed: _exitSelectionMode,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                count == 0 ? 'Select items' : '$count selected',
                key: const ValueKey('explorer-selection-count'),
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: colorScheme.onSurface,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            IconButton(
              key: const ValueKey('explorer-selection-select-all'),
              icon: Icon(allSelected ? Icons.deselect : Icons.select_all, size: 20),
              tooltip: allSelected ? 'Deselect All' : 'Select All',
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              onPressed: _selectAllItems,
            ),
            const SizedBox(width: 2),
            IconButton(
              key: const ValueKey('explorer-selection-move'),
              icon: const Icon(Icons.drive_file_move_outlined, size: 20),
              tooltip: 'Move selected',
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              onPressed: count == 0 ? null : _moveSelectedItems,
            ),
            const SizedBox(width: 2),
            IconButton(
              key: const ValueKey('explorer-selection-copy'),
              icon: const Icon(Icons.content_copy_outlined, size: 20),
              tooltip: 'Copy selected',
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              onPressed: count == 0 ? null : _copySelectedItems,
            ),
            const SizedBox(width: 2),
            IconButton(
              key: const ValueKey('explorer-selection-delete'),
              icon: Icon(
                Icons.delete_outline,
                size: 20,
                color: count == 0 ? colorScheme.onSurfaceVariant.withValues(alpha: 0.38) : Colors.red,
              ),
              tooltip: 'Delete selected',
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              onPressed: count == 0 ? null : _deleteSelectedItems,
            ),
          ],
        ),
      );
    }

    final sortButton = PopupMenuButton<FolderSortOption>(
      key: const ValueKey('explorer-sort-button'),
      initialValue: _sortOption,
      tooltip: 'Sort by',
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(),
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
    );

    final viewSegmented = SegmentedButton<ExplorerViewMode>(
      showSelectedIcon: false,
      segments: const [
        ButtonSegment(
          value: ExplorerViewMode.list,
          icon: Icon(Icons.view_list, size: 16),
          tooltip: 'List view',
        ),
        ButtonSegment(
          value: ExplorerViewMode.grid,
          icon: Icon(Icons.grid_view, size: 16),
          tooltip: 'Grid view',
        ),
        ButtonSegment(
          value: ExplorerViewMode.tree,
          icon: Icon(Icons.account_tree_outlined, size: 16),
          tooltip: 'Tree view',
        ),
      ],
      selected: {_viewMode},
      onSelectionChanged: (selected) {
        setState(() => _viewMode = selected.first);
      },
      style: const ButtonStyle(
        visualDensity: VisualDensity.compact,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );

    final searchToggleButton = IconButton(
      key: const ValueKey('explorer-search-toggle'),
      tooltip: _isSearchExpanded ? 'Close search' : 'Search folders and items',
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
      icon: AnimatedRotation(
        turns: _isSearchExpanded ? 0.25 : 0.0,
        duration: const Duration(milliseconds: 200),
        child: Icon(
          _isSearchExpanded ? Icons.close : Icons.search,
          size: 20,
          color: _isSearchExpanded || _searchFilter.isNotEmpty
              ? colorScheme.primary
              : colorScheme.onSurfaceVariant,
        ),
      ),
      onPressed: () {
        setState(() {
          _isSearchExpanded = !_isSearchExpanded;
          if (_isSearchExpanded) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) _searchFocusNode.requestFocus();
            });
          } else {
            _searchController.clear();
            _searchFilter = '';
            _searchFocusNode.unfocus();
          }
        });
      },
    );

    final animatedSearchBar = AnimatedSize(
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeInOutCubic,
      child: _isSearchExpanded
          ? Container(
              margin: const EdgeInsets.only(top: 6, bottom: 2),
              height: 38,
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: colorScheme.primary.withValues(alpha: 0.5),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  const SizedBox(width: 10),
                  Icon(
                    Icons.search,
                    size: 16,
                    color: colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      key: const ValueKey('explorer-search-input'),
                      controller: _searchController,
                      focusNode: _searchFocusNode,
                      style: TextStyle(
                        fontSize: 13,
                        color: colorScheme.onSurface,
                        fontWeight: FontWeight.w500,
                      ),
                      decoration: InputDecoration(
                        hintText: _currentFolderId == null
                            ? 'Search all folders & items...'
                            : 'Search in this folder...',
                        hintStyle: TextStyle(
                          fontSize: 13,
                          color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                        ),
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        filled: false,
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(vertical: 8),
                      ),
                    ),
                  ),
                  if (_searchFilter.isNotEmpty)
                    IconButton(
                      key: const ValueKey('explorer-search-clear'),
                      icon: Icon(
                        Icons.cancel,
                        size: 16,
                        color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                      ),
                      tooltip: 'Clear search',
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _searchFilter = '');
                      },
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                    ),
                  IconButton(
                    key: const ValueKey('explorer-search-collapse'),
                    icon: Icon(
                      Icons.keyboard_arrow_up,
                      size: 18,
                      color: colorScheme.onSurfaceVariant,
                    ),
                    tooltip: 'Collapse search',
                    onPressed: () {
                      setState(() {
                        _isSearchExpanded = false;
                        _searchController.clear();
                        _searchFilter = '';
                        _searchFocusNode.unfocus();
                      });
                    },
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                  ),
                  const SizedBox(width: 4),
                ],
              ),
            )
          : const SizedBox.shrink(),
    );

    final navigationButtons = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (canGoBack) ...[
          IconButton(
            icon: const Icon(Icons.arrow_back, size: 18),
            onPressed: _navigateBack,
            tooltip: 'Back',
            visualDensity: VisualDensity.compact,
            padding: const EdgeInsets.all(4),
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
          ),
          const SizedBox(width: 2),
        ],
        if (canGoUp) ...[
          IconButton(
            icon: const Icon(Icons.arrow_upward, size: 18),
            onPressed: _navigateUp,
            tooltip: 'Up to parent folder',
            visualDensity: VisualDensity.compact,
            padding: const EdgeInsets.all(4),
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
          ),
          const SizedBox(width: 2),
        ],
      ],
    );

    final breadcrumbsWidget = SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              key: const ValueKey('explorer-breadcrumb-root'),
              onTap: () => _navigateToFolder(null),
              borderRadius: BorderRadius.circular(4),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.folder_outlined,
                      size: 16,
                      color: _currentFolderId == null ? colorScheme.primary : colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Root Directory',
                      style: TextStyle(
                        fontWeight: _currentFolderId == null ? FontWeight.bold : FontWeight.w500,
                        fontSize: 13,
                        color: _currentFolderId == null ? colorScheme.primary : colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          for (final segment in breadcrumbs) ...[
            Icon(Icons.chevron_right, size: 14, color: colorScheme.onSurfaceVariant),
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => _navigateToFolder(segment.id),
                borderRadius: BorderRadius.circular(4),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  child: Text(
                    segment.name,
                    style: TextStyle(
                      fontWeight: segment.id == _currentFolderId ? FontWeight.bold : FontWeight.w500,
                      fontSize: 13,
                      color: segment.id == _currentFolderId ? colorScheme.primary : colorScheme.onSurface,
                    ),
                  ),
                ),
              ),
            ),
          ],
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: colorScheme.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              _currentFolderId == null
                  ? '${_childFolders.length} folders · ${widget.items.length + widget.notes.length} total items'
                  : '${_childFolders.length} folders · ${_currentItems.length} items'
                      '${_currentTotalSizeBytes > 0 ? " · ${VaultLimits.formatBytes(_currentTotalSizeBytes)}" : ""}',
              style: EntryTypography.technicalMonospace(
                fontSize: 10,
                color: colorScheme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );

    final multiSelectToggle = IconButton(
      key: const ValueKey('explorer-multi-select-toggle'),
      tooltip: 'Select multiple items',
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
      icon: const Icon(Icons.checklist, size: 20),
      onPressed: () {
        setState(() {
          _isSelectionModeExplicit = true;
        });
      },
    );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      color: theme.scaffoldBackgroundColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              navigationButtons,
              Expanded(child: breadcrumbsWidget),
              if (widget.isWide) ...[
                const SizedBox(width: 8),
                searchToggleButton,
                const SizedBox(width: 4),
                sortButton,
                const SizedBox(width: 4),
                multiSelectToggle,
                const SizedBox(width: 6),
                viewSegmented,
              ],
            ],
          ),
          if (!widget.isWide) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                searchToggleButton,
                const SizedBox(width: 4),
                sortButton,
                const SizedBox(width: 4),
                multiSelectToggle,
                const Spacer(),
                viewSegmented,
              ],
            ),
          ],
          animatedSearchBar,
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      children: [
        // Table Header only on wide screens
        if (widget.isWide) ...[
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
        ],

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
    final folderColor = resolveFolderColor(folder);

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
        onLongPress: () => _showFolderActionsBottomSheet(folder),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: widget.isWide
              ? Row(
                  children: [
                    Expanded(
                      flex: 4,
                      child: Row(
                        children: [
                          Icon(
                            isDefault ? Icons.folder_special : Icons.folder,
                            color: folderColor,
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
                )
              : Row(
                  children: [
                    Icon(
                      isDefault ? Icons.folder_special : Icons.folder,
                      color: folderColor,
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            folder.name,
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            isDefault ? 'Default folder' : 'File folder',
                            style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
                          ),
                        ],
                      ),
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
    final type = resolveItemType(item);
    final sizeLabel = resolveItemSizeLabel(item);
    final dateLabel = resolveItemDateLabel(item);

    final itemIcon = widget.iconForType?.call(type) ?? defaultIconForType(type);
    final itemColor = widget.colorForType?.call(type) ?? defaultColorForType(type);

    final folderId = item['folderId']?.toString();
    final folder = (folderId != null && folderId.isNotEmpty && folderId != VaultFoldersView.defaultFolderId)
        ? widget.folders.firstWhere(
            (f) => f.id == folderId,
            orElse: () => VaultFolder(id: folderId, name: folderId, createdAt: '', updatedAt: ''),
          )
        : null;
    final folderName = folder?.name ?? (widget.folders.isNotEmpty ? 'Default' : null);
    final folderColor = folder != null ? resolveFolderColor(folder) : const Color(0xFFF59E0B);

    final subtitleParts = <String>[type];
    if (sizeLabel.isNotEmpty && sizeLabel != '--') subtitleParts.add(sizeLabel);
    if (dateLabel.isNotEmpty) subtitleParts.add(dateLabel);
    final subtitle = subtitleParts.join(' · ');

    final itemId = _itemId(item);
    final isSelected = _selectedItemIds.contains(itemId);

    final selectionIndicator = Padding(
      padding: const EdgeInsets.only(right: 10),
      child: Icon(
        isSelected ? Icons.check_circle : Icons.radio_button_unchecked,
        size: 20,
        color: isSelected ? colorScheme.primary : colorScheme.onSurfaceVariant,
      ),
    );

    return Card(
      key: ValueKey('explorer-item-card-$itemId'),
      margin: const EdgeInsets.symmetric(vertical: 2),
      elevation: 0,
      color: isSelected ? colorScheme.primaryContainer.withValues(alpha: 0.35) : null,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color: isSelected ? colorScheme.primary : colorScheme.outlineVariant.withValues(alpha: 0.5),
          width: isSelected ? 1.5 : 1,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () {
          if (_isSelectionMode) {
            _toggleItemSelection(item);
          } else {
            widget.onOpenItem(item);
          }
        },
        onLongPress: () => _toggleItemSelection(item),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: widget.isWide
              ? Row(
                  children: [
                    if (_isSelectionMode) selectionIndicator,
                    Expanded(
                      flex: 4,
                      child: Row(
                        children: [
                          Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              color: itemColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Icon(itemIcon, color: itemColor, size: 16),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              title,
                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
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
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            folderName == 'Default' ? Icons.folder_special : Icons.folder_outlined,
                            size: 13,
                            color: folderColor,
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              folderName ?? 'Default',
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                                color: folderColor,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(
                        sizeLabel,
                        style: EntryTypography.technicalMonospace(fontSize: 11, color: colorScheme.onSurfaceVariant),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (!_isSelectionMode) ...[
                      IconButton(
                        icon: Icon(Icons.info_outline, size: 18, color: colorScheme.onSurfaceVariant),
                        tooltip: 'Item details',
                        onPressed: () => _showItemInfoBottomSheet(item),
                      ),
                      PopupMenuButton<String>(
                        icon: const Icon(Icons.more_vert, size: 18),
                        onSelected: (val) => _handleItemAction(item, val),
                        itemBuilder: (ctx) => [
                          const PopupMenuItem(value: 'open', child: Text('Open Details')),
                          const PopupMenuItem(value: 'info', child: Text('Item Info')),
                          const PopupMenuItem(value: 'copy', child: Text('Copy to...')),
                          const PopupMenuItem(value: 'move', child: Text('Move to...')),
                          const PopupMenuItem(value: 'delete', child: Text('Delete', style: TextStyle(color: Colors.red))),
                        ],
                      ),
                    ],
                  ],
                )
              : Row(
                  children: [
                    if (_isSelectionMode) selectionIndicator,
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: itemColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(itemIcon, color: itemColor, size: 18),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            title,
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 3),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                margin: const EdgeInsets.only(right: 6),
                                decoration: BoxDecoration(
                                  color: folderColor.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      folderName == 'Default' ? Icons.folder_special : Icons.folder_outlined,
                                      size: 11,
                                      color: folderColor,
                                    ),
                                    const SizedBox(width: 3),
                                    Text(
                                      folderName ?? 'Default',
                                      style: TextStyle(
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.w600,
                                        color: folderColor,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  subtitle,
                                  style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    if (!_isSelectionMode) ...[
                      IconButton(
                        key: ValueKey('item-info-btn-${item['id'] ?? title}'),
                        icon: Icon(Icons.info_outline, size: 18, color: colorScheme.onSurfaceVariant),
                        tooltip: 'Item details',
                        onPressed: () => _showItemInfoBottomSheet(item),
                      ),
                      PopupMenuButton<String>(
                        icon: const Icon(Icons.more_vert, size: 18),
                        onSelected: (val) => _handleItemAction(item, val),
                        itemBuilder: (ctx) => [
                          const PopupMenuItem(value: 'open', child: Text('Open Details')),
                          const PopupMenuItem(value: 'info', child: Text('Item Info')),
                          const PopupMenuItem(value: 'copy', child: Text('Copy to...')),
                          const PopupMenuItem(value: 'move', child: Text('Move to...')),
                          const PopupMenuItem(value: 'delete', child: Text('Delete', style: TextStyle(color: Colors.red))),
                        ],
                      ),
                    ],
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
    final folderColor = resolveFolderColor(folder);

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: colorScheme.outlineVariant.withValues(alpha: 0.6)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _navigateToFolder(folder.id),
        onLongPress: () => _showFolderActionsBottomSheet(folder),
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
                color: folderColor,
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
    final type = resolveItemType(item);
    final sizeLabel = resolveItemSizeLabel(item);
    final itemIcon = widget.iconForType?.call(type) ?? defaultIconForType(type);
    final itemColor = widget.colorForType?.call(type) ?? defaultColorForType(type);

    final folderId = item['folderId']?.toString();
    final folder = (folderId != null && folderId.isNotEmpty && folderId != VaultFoldersView.defaultFolderId)
        ? widget.folders.firstWhere(
            (f) => f.id == folderId,
            orElse: () => VaultFolder(id: folderId, name: folderId, createdAt: '', updatedAt: ''),
          )
        : null;
    final folderName = folder?.name ?? (widget.folders.isNotEmpty ? 'Default' : null);
    final folderColor = folder != null ? resolveFolderColor(folder) : const Color(0xFFF59E0B);

    final itemId = _itemId(item);
    final isSelected = _selectedItemIds.contains(itemId);

    return Card(
      key: ValueKey('explorer-item-grid-$itemId'),
      elevation: 1,
      color: isSelected ? colorScheme.primaryContainer.withValues(alpha: 0.35) : null,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isSelected
              ? colorScheme.primary
              : colorScheme.outlineVariant.withValues(alpha: 0.6),
          width: isSelected ? 2 : 1,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          if (_isSelectionMode) {
            _toggleItemSelection(item);
          } else {
            widget.onOpenItem(item);
          }
        },
        onLongPress: () => _toggleItemSelection(item),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                mainAxisAlignment: _isSelectionMode ? MainAxisAlignment.spaceBetween : MainAxisAlignment.end,
                children: [
                  if (_isSelectionMode)
                    Icon(
                      isSelected ? Icons.check_circle : Icons.radio_button_unchecked,
                      size: 20,
                      color: isSelected ? colorScheme.primary : colorScheme.onSurfaceVariant,
                    ),
                  if (!_isSelectionMode) ...[
                    IconButton(
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      icon: Icon(Icons.info_outline, size: 16, color: colorScheme.onSurfaceVariant),
                      tooltip: 'Item info',
                      onPressed: () => _showItemInfoBottomSheet(item),
                    ),
                    const SizedBox(width: 4),
                    PopupMenuButton<String>(
                      padding: EdgeInsets.zero,
                      icon: const Icon(Icons.more_horiz, size: 16),
                      onSelected: (val) => _handleItemAction(item, val),
                      itemBuilder: (ctx) => const [
                        PopupMenuItem(value: 'open', child: Text('Open Details')),
                        PopupMenuItem(value: 'info', child: Text('Item Info')),
                        PopupMenuItem(value: 'copy', child: Text('Copy to...')),
                        PopupMenuItem(value: 'move', child: Text('Move to...')),
                        PopupMenuItem(value: 'delete', child: Text('Delete', style: TextStyle(color: Colors.red))),
                      ],
                    ),
                  ],
                ],
              ),
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: itemColor.withValues(alpha: 0.12),
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
              Container(
                margin: const EdgeInsets.only(top: 3, bottom: 2),
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                decoration: BoxDecoration(
                  color: folderColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      folderName == 'Default' ? Icons.folder_special : Icons.folder_outlined,
                      size: 10,
                      color: folderColor,
                    ),
                    const SizedBox(width: 3),
                    Flexible(
                      child: Text(
                        folderName ?? 'Default',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: folderColor,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 2),
              Text(
                sizeLabel.isNotEmpty && sizeLabel != '--' ? '$type · $sizeLabel' : type,
                style: TextStyle(fontSize: 11, color: colorScheme.onSurfaceVariant),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
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

    final hasContent = _childFolders.isNotEmpty || _currentItems.isNotEmpty;

    return LayoutBuilder(
      builder: (context, constraints) {
        final totalWidth = constraints.maxWidth;
        // In portrait view, take 25% of the screen space for folder hierarchy
        final treeWidth = widget.isWide ? 280.0 : (totalWidth * 0.25);

        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Left Pane: Folder Tree (Scrollable horizontally and vertically for deep nesting)
            Container(
              key: const ValueKey('explorer-tree-left-pane'),
              width: treeWidth,
              decoration: BoxDecoration(
                border: Border(right: BorderSide(color: colorScheme.outlineVariant.withValues(alpha: 0.5))),
              ),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SizedBox(
                  width: 320,
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
            ),

            // Right Pane: Contents of the active folder (horizontally scrollable in portrait to view all item details)
            Expanded(
              child: LayoutBuilder(
                builder: (context, rightConstraints) {
                  final availableWidth = rightConstraints.maxWidth;
                  final minContentWidth = (widget.isWide || !hasContent)
                      ? availableWidth
                      : math.max(availableWidth, 420.0);

                  return SingleChildScrollView(
                    key: const ValueKey('explorer-tree-right-scroll'),
                    scrollDirection: Axis.horizontal,
                    child: SizedBox(
                      width: minContentWidth,
                      child: _buildListView(context),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
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
    final folder = _folderById(folderId);
    final folderColor = folder != null ? resolveFolderColor(folder) : const Color(0xFFEAB308);

    return InkWell(
      key: ValueKey('explorer-tree-tile-${folderId ?? "root"}'),
      onTap: () => _navigateToFolder(folderId),
      onLongPress: folder != null ? () => _showFolderActionsBottomSheet(folder) : null,
      borderRadius: BorderRadius.circular(6),
      child: Tooltip(
        message: title,
        waitDuration: const Duration(milliseconds: 500),
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
                color: folderColor,
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
              'Tap the + button below to create a folder, add items, or upload files.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }

  // --- ACTIONS & DIALOGS ---
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

  void _showFolderActionsBottomSheet(VaultFolder folder) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDefault = folder.id == VaultFoldersView.defaultFolderId;
    final folderColor = resolveFolderColor(folder);
    final folderItems = FolderTreeBuilder.getItemsInFolder(
      folderId: folder.id,
      items: [...widget.items, ...widget.notes],
      recursive: true,
    );

    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (bottomSheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Drag handle
                Center(
                  child: Container(
                    width: 38,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: colorScheme.outlineVariant.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                // Folder Info Header
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: folderColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          isDefault ? Icons.folder_special : Icons.folder,
                          color: folderColor,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              folder.name,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              isDefault
                                  ? 'Default folder · ${folderItems.length} items'
                                  : 'File folder · ${folderItems.length} items',
                              style: TextStyle(
                                fontSize: 12,
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, size: 20),
                        tooltip: 'Close',
                        onPressed: () => Navigator.pop(bottomSheetContext),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Divider(
                  height: 1,
                  thickness: 1,
                  color: colorScheme.outlineVariant.withValues(alpha: 0.3),
                ),
                const SizedBox(height: 16),
                // Horizontal Action Menus: Move, Create subfolder, Folder color, Rename, Delete
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 1. Move
                      _buildHorizontalActionItem(
                        key: const ValueKey('folder-sheet-action-move'),
                        icon: Icons.drive_file_move_outlined,
                        label: 'Move',
                        enabled: !isDefault,
                        onTap: () {
                          Navigator.pop(bottomSheetContext);
                          _showMoveFolderPicker(folder);
                        },
                      ),
                      const SizedBox(width: 8),
                      // 2. Create subfolder
                      _buildHorizontalActionItem(
                        key: const ValueKey('folder-sheet-action-create-subfolder'),
                        icon: Icons.create_new_folder_outlined,
                        label: 'Create subfolder',
                        enabled: true,
                        onTap: () {
                          Navigator.pop(bottomSheetContext);
                          _showCreateSubfolderDialog(folder);
                        },
                      ),
                      const SizedBox(width: 8),
                      // 3. Folder color
                      _buildHorizontalActionItem(
                        key: const ValueKey('folder-sheet-action-color'),
                        icon: Icons.palette_outlined,
                        label: 'Folder color',
                        enabled: !isDefault,
                        onTap: () {
                          Navigator.pop(bottomSheetContext);
                          _showColorPickerDialog(folder);
                        },
                      ),
                      const SizedBox(width: 8),
                      // 4. Rename
                      _buildHorizontalActionItem(
                        key: const ValueKey('folder-sheet-action-rename'),
                        icon: Icons.edit_outlined,
                        label: 'Rename',
                        enabled: !isDefault,
                        onTap: () {
                          Navigator.pop(bottomSheetContext);
                          _handleFolderAction(folder, 'rename');
                        },
                      ),
                      const SizedBox(width: 8),
                      // 5. Delete
                      _buildHorizontalActionItem(
                        key: const ValueKey('folder-sheet-action-delete'),
                        icon: Icons.delete_outline,
                        label: 'Delete',
                        color: Colors.red,
                        enabled: !isDefault,
                        onTap: () {
                          Navigator.pop(bottomSheetContext);
                          _handleFolderAction(folder, 'delete');
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHorizontalActionItem({
    required Key key,
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color? color,
    bool enabled = true,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final itemColor = color ?? colorScheme.primary;
    final effectiveColor = enabled ? itemColor : colorScheme.onSurfaceVariant.withValues(alpha: 0.38);

    return SizedBox(
      width: 78,
      child: InkWell(
        key: key,
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: effectiveColor.withValues(alpha: enabled ? 0.12 : 0.05),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  size: 22,
                  color: effectiveColor,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: enabled
                      ? (color ?? colorScheme.onSurface)
                      : colorScheme.onSurfaceVariant.withValues(alpha: 0.38),
                  height: 1.2,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showCreateSubfolderDialog(VaultFolder folder) {
    showCreateVaultFolderDialog(
      context,
      parentFolderId: folder.id,
      parentFolderName: folder.name,
      onCreateFolder: (name, {parentId, color}) async {
        widget.onCreateFolder(name, parentId, color);
        return VaultFolder(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          name: name,
          parentId: parentId,
          color: color,
          createdAt: DateTime.now().toIso8601String(),
          updatedAt: DateTime.now().toIso8601String(),
        );
      },
    );
  }

  void _showColorPickerDialog(VaultFolder folder) {
    var selectedHex = folder.color ?? '#0381FE';
    showDialog<void>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dialogCtx, setStateDialog) {
            final theme = Theme.of(dialogCtx);
            final colorScheme = theme.colorScheme;
            final activeColor = parseFolderHexColor(selectedHex);

            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: activeColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.palette_outlined, color: activeColor, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'Folder Color',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                        ),
                        Text(
                          folder.name,
                          style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Select a color tag for this folder:',
                    style: TextStyle(fontSize: 13, color: colorScheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: kDefaultFolderColors.map((colorHex) {
                      final dotColor = parseFolderHexColor(colorHex);
                      final isSelected = selectedHex.toUpperCase() == colorHex.toUpperCase();

                      return GestureDetector(
                        key: ValueKey('color-swatch-$colorHex'),
                        onTap: () {
                          setStateDialog(() {
                            selectedHex = colorHex;
                          });
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: dotColor,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isSelected ? colorScheme.onSurface : Colors.transparent,
                              width: 3,
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
                              ? const Icon(Icons.check, size: 20, color: Colors.white)
                              : null,
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogCtx),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  key: const ValueKey('save-folder-color-button'),
                  onPressed: () {
                    widget.onUpdateFolderColor?.call(folder.id, selectedHex);
                    setState(() {});
                    Navigator.pop(dialogCtx);
                  },
                  child: const Text('Apply'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _showMoveFolderPicker(VaultFolder folder) async {
    final descendants = FolderTreeBuilder.getDescendantFolderIds(folderId: folder.id, folders: widget.folders);
    final excludedIds = {folder.id, ...descendants};

    final targetFolder = await showVaultFolderHierarchySheet(
      context,
      folders: widget.folders,
      selectedFolderId: folder.parentId ?? 'root',
      onCreateFolder: _createFolderCallback,
      title: 'Move "${folder.name}" to...',
      showRootOption: true,
      hideDefaultFolder: true,
      excludedFolderIds: excludedIds,
    );
    if (targetFolder == null || !mounted) return;

    final targetParentId = targetFolder.id == 'root' ? null : targetFolder.id;
    widget.onMoveFolder(folder.id, targetParentId);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Moved "${folder.name}" to "${targetFolder.name}".')),
    );
  }

  void _handleItemAction(Map<String, dynamic> item, String action) async {
    switch (action) {
      case 'open':
        widget.onOpenItem(item);
      case 'info':
        _showItemInfoBottomSheet(item);
      case 'move':
        final targetFolder = await showVaultFolderHierarchySheet(
          context,
          folders: widget.folders,
          selectedFolderId: item['folderId']?.toString() ?? VaultFoldersView.defaultFolderId,
          onCreateFolder: _createFolderCallback,
          title: 'Move "${item['title'] ?? 'item'}" to...',
        );
        if (targetFolder != null && mounted) {
          final targetId = targetFolder.id == VaultFoldersView.defaultFolderId || targetFolder.id == 'root'
              ? null
              : targetFolder.id;
          widget.onMoveItem(item, targetId);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Moved "${item['title'] ?? 'item'}" to "${targetFolder.name}".')),
          );
        }
      case 'copy':
        final targetFolder = await showVaultFolderHierarchySheet(
          context,
          folders: widget.folders,
          selectedFolderId: item['folderId']?.toString() ?? VaultFoldersView.defaultFolderId,
          onCreateFolder: _createFolderCallback,
          title: 'Copy "${item['title'] ?? 'item'}" to...',
        );
        if (targetFolder != null && mounted) {
          final targetId = targetFolder.id == VaultFoldersView.defaultFolderId || targetFolder.id == 'root'
              ? null
              : targetFolder.id;
          widget.onCopyItem(item, targetId);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Copied "${item['title'] ?? 'item'}" to "${targetFolder.name}".')),
          );
        }
      case 'delete':
        await showDialog<void>(
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

  void _showItemInfoBottomSheet(Map<String, dynamic> item) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final title = (item['title'] ?? 'Untitled').toString();
    final type = resolveItemType(item);
    final sizeLabel = resolveItemSizeLabel(item);
    final dateLabel = resolveItemDateLabel(item);
    final itemIcon = widget.iconForType?.call(type) ?? defaultIconForType(type);
    final itemColor = widget.colorForType?.call(type) ?? defaultColorForType(type);

    final folderId = item['folderId']?.toString();
    final folder = _folderById(folderId);
    final folderName = folder?.name ??
        (folderId == null || folderId.isEmpty || folderId == VaultFoldersView.defaultFolderId
            ? VaultFoldersView.defaultFolderName
            : folderId);
    final folderColor = folder != null ? resolveFolderColor(folder) : const Color(0xFFEAB308);

    final tags = (item['tags'] as List<dynamic>? ?? const <dynamic>[])
        .map((t) => t.toString().trim())
        .where((t) => t.isNotEmpty)
        .toList();

    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 38,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: colorScheme.outlineVariant.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: itemColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(itemIcon, color: itemColor, size: 22),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              type,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: itemColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, size: 20),
                        tooltip: 'Close',
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Divider(height: 1, color: colorScheme.outlineVariant.withValues(alpha: 0.3)),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    children: [
                      _buildInfoRow(
                        icon: Icons.category_outlined,
                        label: 'Item Type',
                        value: type,
                        color: itemColor,
                      ),
                      const SizedBox(height: 12),
                      _buildInfoRow(
                        icon: Icons.data_usage_outlined,
                        label: 'Size',
                        value: sizeLabel.isNotEmpty && sizeLabel != '--' ? sizeLabel : 'Text entry',
                      ),
                      const SizedBox(height: 12),
                      _buildInfoRow(
                        icon: Icons.calendar_today_outlined,
                        label: 'Date',
                        value: dateLabel.isNotEmpty ? dateLabel : 'Recent',
                      ),
                      const SizedBox(height: 12),
                      _buildInfoRow(
                        icon: Icons.folder_outlined,
                        label: 'Folder',
                        value: folderName,
                        color: folderColor,
                      ),
                      if (tags.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.label_outline, size: 20, color: colorScheme.onSurfaceVariant),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                children: tags.map((tag) => Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: colorScheme.primary.withValues(alpha: 0.08),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    '#$tag',
                                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: colorScheme.primary),
                                  ),
                                )).toList(),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.drive_file_move_outlined, size: 18),
                          label: const Text('Move'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: () {
                            Navigator.pop(ctx);
                            _handleItemAction(item, 'move');
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton.icon(
                          icon: const Icon(Icons.open_in_new, size: 18),
                          label: const Text('Open'),
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: () {
                            Navigator.pop(ctx);
                            widget.onOpenItem(item);
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
    Color? color,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(icon, size: 20, color: color ?? colorScheme.onSurfaceVariant),
        const SizedBox(width: 14),
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w500,
          ),
        ),
        const Spacer(),
        Flexible(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: color ?? colorScheme.onSurface,
            ),
            textAlign: TextAlign.end,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

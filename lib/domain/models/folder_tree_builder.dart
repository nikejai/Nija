import 'folder_tree_node.dart';
import 'vault_folder.dart';

/// Utilities for building folder trees, resolving breadcrumbs, detecting cycles,
/// and filtering items by folder.
class FolderTreeBuilder {
  FolderTreeBuilder._();

  /// Builds a forest of root [FolderTreeNode]s from flat lists of [folders] and [items].
  /// Detects and prevents circular hierarchy links safely.
  static List<FolderTreeNode> buildTree({
    required List<VaultFolder> folders,
    required List<Map<String, dynamic>> items,
  }) {
    final folderMap = <String, VaultFolder>{
      for (final folder in folders) folder.id: folder,
    };

    final nodeMap = <String, FolderTreeNode>{
      for (final folder in folders)
        folder.id: FolderTreeNode(folder: folder),
    };

    // Associate items to their containing folders
    for (final item in items) {
      final folderId = item['folderId']?.toString();
      if (folderId != null && nodeMap.containsKey(folderId)) {
        nodeMap[folderId]!.items.add(item);
      }
    }

    final rootNodes = <FolderTreeNode>[];

    for (final folder in folders) {
      final node = nodeMap[folder.id]!;
      final parentId = folder.parentId;

      if (parentId == null ||
          parentId.trim().isEmpty ||
          !nodeMap.containsKey(parentId) ||
          _causesCycle(folder.id, parentId, folderMap)) {
        // Top-level / Root node
        rootNodes.add(node);
      } else {
        // Child of another folder
        nodeMap[parentId]!.children.add(node);
      }
    }

    // Sort folders alphabetically at each level
    _sortTree(rootNodes);

    return rootNodes;
  }

  /// Recursively sorts tree nodes by folder name.
  static void _sortTree(List<FolderTreeNode> nodes) {
    nodes.sort((a, b) => a.folder.name.toLowerCase().compareTo(b.folder.name.toLowerCase()));
    for (final node in nodes) {
      if (node.children.isNotEmpty) {
        _sortTree(node.children);
      }
    }
  }

  /// Checks if setting [parentId] as parent of [childId] would create a cycle.
  static bool _causesCycle(
    String childId,
    String parentId,
    Map<String, VaultFolder> folderMap,
  ) {
    if (childId == parentId) return true;
    final visited = <String>{childId};
    var currentId = parentId;

    while (currentId.isNotEmpty) {
      if (visited.contains(currentId)) return true;
      visited.add(currentId);

      final parentFolder = folderMap[currentId];
      if (parentFolder == null || parentFolder.parentId == null) break;
      currentId = parentFolder.parentId!;
    }

    return false;
  }

  /// Returns breadcrumb list of folders from the root ancestor down to [folderId].
  static List<VaultFolder> resolveBreadcrumbs({
    required String? folderId,
    required List<VaultFolder> folders,
  }) {
    if (folderId == null || folderId.trim().isEmpty) {
      return const <VaultFolder>[];
    }

    final folderMap = <String, VaultFolder>{
      for (final folder in folders) folder.id: folder,
    };

    final breadcrumbs = <VaultFolder>[];
    final visited = <String>{};
    var currentId = folderId;

    while (folderMap.containsKey(currentId) && !visited.contains(currentId)) {
      visited.add(currentId);
      final folder = folderMap[currentId]!;
      breadcrumbs.insert(0, folder);

      if (folder.parentId == null || folder.parentId!.trim().isEmpty) break;
      currentId = folder.parentId!;
    }

    return breadcrumbs;
  }

  /// Returns a path string (e.g. `/Work/Invoices/2026`).
  static String resolvePathString({
    required String? folderId,
    required List<VaultFolder> folders,
    String separator = ' / ',
  }) {
    final breadcrumbs = resolveBreadcrumbs(folderId: folderId, folders: folders);
    if (breadcrumbs.isEmpty) return 'Root';
    return breadcrumbs.map((folder) => folder.name).join(separator);
  }

  /// Collects all descendant folder IDs under [folderId] (children, grandchildren, etc.).
  static Set<String> getDescendantFolderIds({
    required String folderId,
    required List<VaultFolder> folders,
  }) {
    final childrenByParent = <String, List<String>>{};
    for (final folder in folders) {
      final pid = folder.parentId;
      if (pid != null && pid.trim().isNotEmpty) {
        childrenByParent.putIfAbsent(pid, () => <String>[]).add(folder.id);
      }
    }

    final descendants = <String>{};
    final queue = <String>[folderId];

    while (queue.isNotEmpty) {
      final current = queue.removeLast();
      final children = childrenByParent[current] ?? const <String>[];
      for (final child in children) {
        if (!descendants.contains(child)) {
          descendants.add(child);
          queue.add(child);
        }
      }
    }

    return descendants;
  }

  /// Filters items located directly within [folderId] (or null for root items),
  /// or recursively if [recursive] is true.
  static List<Map<String, dynamic>> getItemsInFolder({
    required String? folderId,
    required List<Map<String, dynamic>> items,
    bool recursive = false,
    List<VaultFolder> folders = const <VaultFolder>[],
  }) {
    if (folderId == null || folderId.trim().isEmpty) {
      if (!recursive) {
        // Items in root (no folderId or empty folderId)
        return items.where((item) {
          final fid = item['folderId']?.toString().trim();
          return fid == null || fid.isEmpty;
        }).toList();
      }
      return List<Map<String, dynamic>>.from(items);
    }

    final targetFolderIds = <String>{folderId};
    if (recursive) {
      targetFolderIds.addAll(getDescendantFolderIds(folderId: folderId, folders: folders));
    }

    return items.where((item) {
      final fid = item['folderId']?.toString().trim();
      return fid != null && targetFolderIds.contains(fid);
    }).toList();
  }
}

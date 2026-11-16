import 'dart:math';

import '../../domain/models/folder_tree_builder.dart';
import '../../domain/models/vault_folder.dart';

/// Manages folder lifecycle, CRUD operations, hierarchy mutations, and file moves
/// within the vault metadata hub.
class VaultFolderManager {
  const VaultFolderManager();

  static String _newUuidV4() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-'
        '${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-'
        '${hex.substring(16, 20)}-'
        '${hex.substring(20)}';
  }

  /// Creates a new folder under [parentId] (or root if null) and returns the updated folder list.
  List<VaultFolder> createFolder({
    required List<VaultFolder> folders,
    required String name,
    String? parentId,
    String? color,
    String? icon,
    List<String> tags = const <String>[],
    Map<String, dynamic> metadata = const <String, dynamic>{},
    String Function()? idGenerator,
  }) {
    final cleanName = name.trim();
    if (cleanName.isEmpty) {
      throw ArgumentError('Folder name cannot be empty.');
    }

    final now = DateTime.now().toUtc().toIso8601String();
    final id = idGenerator != null ? idGenerator() : _newUuidV4();
    final newFolder = VaultFolder(
      id: id,
      name: cleanName,
      parentId: (parentId != null && parentId.trim().isNotEmpty) ? parentId.trim() : null,
      color: color,
      icon: icon,
      createdAt: now,
      updatedAt: now,
      tags: tags,
      metadata: metadata,
    );

    return [...folders, newFolder];
  }

  /// Renames an existing folder and updates its `updatedAt` timestamp.
  List<VaultFolder> renameFolder({
    required List<VaultFolder> folders,
    required String folderId,
    required String newName,
  }) {
    final cleanName = newName.trim();
    if (cleanName.isEmpty) {
      throw ArgumentError('Folder name cannot be empty.');
    }

    final now = DateTime.now().toUtc().toIso8601String();
    return folders.map((f) {
      if (f.id == folderId) {
        return f.copyWith(name: cleanName, updatedAt: now);
      }
      return f;
    }).toList();
  }

  /// Updates the color of an existing folder and its `updatedAt` timestamp.
  List<VaultFolder> updateFolderColor({
    required List<VaultFolder> folders,
    required String folderId,
    required String? color,
  }) {
    final now = DateTime.now().toUtc().toIso8601String();
    return folders.map((f) {
      if (f.id == folderId) {
        return f.copyWith(color: color, updatedAt: now);
      }
      return f;
    }).toList();
  }

  /// Moves [folderId] to [newParentId]. Throws [ArgumentError] if [newParentId] would cause a cycle.
  List<VaultFolder> moveFolder({
    required List<VaultFolder> folders,
    required String folderId,
    required String? newParentId,
  }) {
    final cleanParent = (newParentId != null && newParentId.trim().isNotEmpty)
        ? newParentId.trim()
        : null;

    if (cleanParent != null) {
      if (cleanParent == folderId) {
        throw ArgumentError('Cannot move a folder into itself.');
      }
      final descendants = FolderTreeBuilder.getDescendantFolderIds(
        folderId: folderId,
        folders: folders,
      );
      if (descendants.contains(cleanParent)) {
        throw ArgumentError('Cannot move a folder into one of its own subfolders.');
      }
    }

    final now = DateTime.now().toUtc().toIso8601String();
    return folders.map((f) {
      if (f.id == folderId) {
        return f.copyWith(
          parentId: cleanParent,
          clearParent: cleanParent == null,
          updatedAt: now,
        );
      }
      return f;
    }).toList();
  }

  /// Deletes a folder.
  /// If [cascade] is true: removes the folder, all its descendant folders, and any items inside them.
  /// If [cascade] is false: removes the folder, but reparents its child folders and items to [folder.parentId].
  ({List<VaultFolder> folders, List<Map<String, dynamic>> items}) deleteFolder({
    required List<VaultFolder> folders,
    required List<Map<String, dynamic>> items,
    required String folderId,
    bool cascade = false,
  }) {
    final targetFolder = folders.cast<VaultFolder?>().firstWhere(
          (f) => f?.id == folderId,
          orElse: () => null,
        );

    if (targetFolder == null) {
      return (folders: folders, items: items);
    }

    if (cascade) {
      final allFolderIdsToDelete = {
        folderId,
        ...FolderTreeBuilder.getDescendantFolderIds(folderId: folderId, folders: folders),
      };

      final updatedFolders = folders
          .where((f) => !allFolderIdsToDelete.contains(f.id))
          .toList();

      final updatedItems = items.where((item) {
        final fid = item['folderId']?.toString();
        return fid == null || !allFolderIdsToDelete.contains(fid);
      }).toList();

      return (folders: updatedFolders, items: updatedItems);
    } else {
      // Reparent children to targetFolder's parent
      final newParentId = targetFolder.parentId;

      final updatedFolders = folders
          .where((f) => f.id != folderId)
          .map((f) {
            if (f.parentId == folderId) {
              return f.copyWith(
                parentId: newParentId,
                clearParent: newParentId == null,
                updatedAt: DateTime.now().toUtc().toIso8601String(),
              );
            }
            return f;
          })
          .toList();

      final updatedItems = items.map((item) {
        if (item['folderId']?.toString() == folderId) {
          final updated = Map<String, dynamic>.from(item);
          if (newParentId != null && newParentId.isNotEmpty) {
            updated['folderId'] = newParentId;
          } else {
            updated.remove('folderId');
          }
          return updated;
        }
        return item;
      }).toList();

      return (folders: updatedFolders, items: updatedItems);
    }
  }

  /// Moves an item or document to [targetFolderId] (null moves to root).
  Map<String, dynamic> moveItemToFolder({
    required Map<String, dynamic> item,
    required String? targetFolderId,
  }) {
    final updated = Map<String, dynamic>.from(item);
    if (targetFolderId != null && targetFolderId.trim().isNotEmpty) {
      updated['folderId'] = targetFolderId.trim();
    } else {
      updated.remove('folderId');
    }
    return updated;
  }

  /// Duplicates an item or document into [targetFolderId] with a fresh UUID.
  Map<String, dynamic> copyItemToFolder({
    required Map<String, dynamic> item,
    required String? targetFolderId,
    String Function()? idGenerator,
  }) {
    final copy = Map<String, dynamic>.from(item);
    copy['id'] = idGenerator != null ? idGenerator() : _newUuidV4();
    if (copy.containsKey('title')) {
      copy['title'] = '${copy['title']} (Copy)';
    }
    if (targetFolderId != null && targetFolderId.trim().isNotEmpty) {
      copy['folderId'] = targetFolderId.trim();
    } else {
      copy.remove('folderId');
    }
    return copy;
  }
}

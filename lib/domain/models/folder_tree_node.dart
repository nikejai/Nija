import 'vault_folder.dart';

/// Represents a folder node in a tree hierarchy with nested children and files/items.
class FolderTreeNode {
  FolderTreeNode({
    required this.folder,
    List<FolderTreeNode>? children,
    List<Map<String, dynamic>>? items,
  })  : children = children ?? <FolderTreeNode>[],
        items = items ?? <Map<String, dynamic>>[];

  final VaultFolder folder;
  final List<FolderTreeNode> children;
  final List<Map<String, dynamic>> items;

  /// Returns the number of direct child subfolders.
  int get subfolderCount => children.length;

  /// Returns the number of direct items in this folder.
  int get directItemCount => items.length;

  /// Returns the total count of items in this folder and all subfolders.
  int get totalItemCount {
    var count = items.length;
    for (final child in children) {
      count += child.totalItemCount;
    }
    return count;
  }

  /// Calculates total size in bytes of all documents and items with size fields.
  int get totalSizeBytes {
    var total = 0;
    for (final item in items) {
      var size = item['size'] ?? item['sizeBytes'] ?? item['documentSizeBytes'];
      if (size == null && item['documents'] is List) {
        var docTotal = 0;
        for (final doc in item['documents'] as List) {
          if (doc is Map) {
            final ds =
                doc['documentSizeBytes'] ?? doc['sizeBytes'] ?? doc['size'];
            if (ds is num) {
              docTotal += ds.toInt();
            } else if (ds is String) {
              docTotal += int.tryParse(ds) ?? 0;
            }
          }
        }
        if (docTotal > 0) size = docTotal;
      }

      if (size is num) {
        total += size.toInt();
      } else if (size is String) {
        total += int.tryParse(size) ?? 0;
      }
    }
    for (final child in children) {
      total += child.totalSizeBytes;
    }
    return total;
  }
}

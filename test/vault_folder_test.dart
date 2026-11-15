import 'package:flutter_test/flutter_test.dart';
import 'package:nija/application/services/vault_folder_manager.dart';
import 'package:nija/domain/models/folder_tree_builder.dart';
import 'package:nija/domain/models/vault_entry_data.dart';
import 'package:nija/domain/models/vault_folder.dart';
import 'package:nija/domain/models/vault_payload.dart';

void main() {
  group('VaultFolder Model', () {
    test('serializes and deserializes correctly', () {
      final folder = VaultFolder(
        id: 'f1',
        name: 'Personal Documents',
        parentId: null,
        color: '#4F46E5',
        icon: 'folder',
        createdAt: '2026-11-15T10:00:00Z',
        updatedAt: '2026-11-15T10:00:00Z',
        tags: const ['personal', 'docs'],
        metadata: const {'starred': true},
      );

      final json = folder.toJson();
      expect(json['id'], 'f1');
      expect(json['name'], 'Personal Documents');
      expect(json['parentId'], isNull);
      expect(json['color'], '#4F46E5');
      expect(json['tags'], ['personal', 'docs']);
      expect(json['metadata']['starred'], true);

      final revived = VaultFolder.fromJson(json);
      expect(revived, equals(folder));
      expect(revived.isRoot, isTrue);
    });

    test('handles nested child folder and copyWith', () {
      final parent = VaultFolder(
        id: 'f1',
        name: 'Work',
        createdAt: '2026-11-15T10:00:00Z',
        updatedAt: '2026-11-15T10:00:00Z',
      );

      final child = VaultFolder(
        id: 'f2',
        name: 'Invoices',
        parentId: 'f1',
        createdAt: '2026-11-15T10:05:00Z',
        updatedAt: '2026-11-15T10:05:00Z',
      );

      expect(child.isRoot, isFalse);
      expect(child.parentId, parent.id);

      final movedToRoot = child.copyWith(clearParent: true);
      expect(movedToRoot.isRoot, isTrue);
      expect(movedToRoot.parentId, isNull);

      final renamed = child.copyWith(name: 'Paid Invoices');
      expect(renamed.name, 'Paid Invoices');
      expect(renamed.parentId, 'f1');
    });
  });

  group('VaultItemData & VaultNoteData with folderId', () {
    test('VaultItemData stores and retrieves folderId', () {
      final item = VaultItemData(
        id: 'item1',
        type: 'Document',
        title: 'Tax_2026.pdf',
        subtitle: 'PDF · 2.4 MB',
        pinned: false,
        folderId: 'f2',
        tags: const ['tax'],
        fields: const [],
      );

      final json = item.toJson();
      expect(json['folderId'], 'f2');

      final revived = VaultItemData.fromJson(json);
      expect(revived.folderId, 'f2');
    });

    test('VaultNoteData stores and retrieves folderId', () {
      final note = VaultNoteData(
        id: 'note1',
        title: 'Meeting Notes',
        preview: 'Discussion notes...',
        pinned: true,
        folderId: 'f1',
        tags: const ['work'],
        delta: const [],
      );

      final json = note.toJson();
      expect(json['folderId'], 'f1');

      final revived = VaultNoteData.fromJson(json);
      expect(revived.folderId, 'f1');
    });
  });

  group('VaultPayload Folders Extension', () {
    test('extracts folders from payload settings and writes back', () {
      final folder = VaultFolder(
        id: 'f1',
        name: 'Finances',
        createdAt: '2026-11-15T10:00:00Z',
        updatedAt: '2026-11-15T10:00:00Z',
      );

      final empty = VaultPayload.empty();
      expect(empty.folders, isEmpty);

      final updated = empty.copyWithFolders([folder]);
      expect(updated.folders.length, 1);
      expect(updated.folders.first.name, 'Finances');
    });
  });

  group('FolderTreeBuilder & FolderTreeNode', () {
    final rootFolder1 = VaultFolder(
      id: 'f1',
      name: 'Work',
      createdAt: '2026-11-15T10:00:00Z',
      updatedAt: '2026-11-15T10:00:00Z',
    );

    final subFolder1 = VaultFolder(
      id: 'f2',
      name: 'Projects',
      parentId: 'f1',
      createdAt: '2026-11-15T10:05:00Z',
      updatedAt: '2026-11-15T10:05:00Z',
    );

    final subFolder2 = VaultFolder(
      id: 'f3',
      name: 'Nija App',
      parentId: 'f2',
      createdAt: '2026-11-15T10:10:00Z',
      updatedAt: '2026-11-15T10:10:00Z',
    );

    final rootFolder2 = VaultFolder(
      id: 'f4',
      name: 'Personal',
      createdAt: '2026-11-15T10:15:00Z',
      updatedAt: '2026-11-15T10:15:00Z',
    );

    final allFolders = [rootFolder1, subFolder1, subFolder2, rootFolder2];

    final sampleItems = [
      {'id': 'item1', 'title': 'Root Item', 'size': 1024},
      {'id': 'item2', 'title': 'Work Doc', 'folderId': 'f1', 'size': 2048},
      {'id': 'item3', 'title': 'Project Spec', 'folderId': 'f2', 'size': 4096},
      {'id': 'item4', 'title': 'App Architecture', 'folderId': 'f3', 'size': 8192},
    ];

    test('builds hierarchy tree correctly with item aggregations', () {
      final tree = FolderTreeBuilder.buildTree(
        folders: allFolders,
        items: sampleItems,
      );

      expect(tree.length, 2); // 'Personal' and 'Work' (sorted alphabetically)
      expect(tree[0].folder.name, 'Personal');
      expect(tree[1].folder.name, 'Work');

      final workNode = tree[1];
      expect(workNode.subfolderCount, 1);
      expect(workNode.directItemCount, 1);
      // Total items = work doc (1) + project spec (1) + app architecture (1) = 3
      expect(workNode.totalItemCount, 3);
      // Total bytes = 2048 + 4096 + 8192 = 14336
      expect(workNode.totalSizeBytes, 14336);

      final projectsNode = workNode.children.first;
      expect(projectsNode.folder.name, 'Projects');
      expect(projectsNode.subfolderCount, 1);
      expect(projectsNode.totalItemCount, 2);

      final nijaAppNode = projectsNode.children.first;
      expect(nijaAppNode.folder.name, 'Nija App');
      expect(nijaAppNode.subfolderCount, 0);
      expect(nijaAppNode.directItemCount, 1);
    });

    test('resolves breadcrumbs path accurately', () {
      final breadcrumbs = FolderTreeBuilder.resolveBreadcrumbs(
        folderId: 'f3',
        folders: allFolders,
      );

      expect(breadcrumbs.map((f) => f.name).toList(), [
        'Work',
        'Projects',
        'Nija App',
      ]);

      final pathString = FolderTreeBuilder.resolvePathString(
        folderId: 'f3',
        folders: allFolders,
      );
      expect(pathString, 'Work / Projects / Nija App');
    });

    test('resolves empty breadcrumbs for root', () {
      final breadcrumbs = FolderTreeBuilder.resolveBreadcrumbs(
        folderId: null,
        folders: allFolders,
      );
      expect(breadcrumbs, isEmpty);

      final pathString = FolderTreeBuilder.resolvePathString(
        folderId: null,
        folders: allFolders,
      );
      expect(pathString, 'Root');
    });

    test('finds all descendant folder IDs to prevent move loops', () {
      final descendantsOfWork = FolderTreeBuilder.getDescendantFolderIds(
        folderId: 'f1',
        folders: allFolders,
      );

      expect(descendantsOfWork, contains('f2'));
      expect(descendantsOfWork, contains('f3'));
      expect(descendantsOfWork, isNot(contains('f4')));
    });

    test('breaks circular hierarchy references safely', () {
      final loopFolderA = VaultFolder(
        id: 'loopA',
        name: 'Loop A',
        parentId: 'loopB',
        createdAt: '2026-11-15T10:00:00Z',
        updatedAt: '2026-11-15T10:00:00Z',
      );
      final loopFolderB = VaultFolder(
        id: 'loopB',
        name: 'Loop B',
        parentId: 'loopA',
        createdAt: '2026-11-15T10:00:00Z',
        updatedAt: '2026-11-15T10:00:00Z',
      );

      final tree = FolderTreeBuilder.buildTree(
        folders: [loopFolderA, loopFolderB],
        items: [],
      );

      // Cycle was safely broken so app does not hang or infinite recurse
      expect(tree.isNotEmpty, isTrue);
    });

    test('filters items in folder directly vs recursively', () {
      final directWorkItems = FolderTreeBuilder.getItemsInFolder(
        folderId: 'f1',
        items: sampleItems,
        recursive: false,
      );
      expect(directWorkItems.length, 1);
      expect(directWorkItems.first['id'], 'item2');

      final recursiveWorkItems = FolderTreeBuilder.getItemsInFolder(
        folderId: 'f1',
        items: sampleItems,
        recursive: true,
        folders: allFolders,
      );
      expect(recursiveWorkItems.length, 3);

      final rootItems = FolderTreeBuilder.getItemsInFolder(
        folderId: null,
        items: sampleItems,
        recursive: false,
      );
      expect(rootItems.length, 1);
      expect(rootItems.first['id'], 'item1');
    });
  });

  group('VaultFolderManager CRUD and Operations', () {
    const manager = VaultFolderManager();

    test('creates and renames folders', () {
      final folders = <VaultFolder>[];
      final created = manager.createFolder(
        folders: folders,
        name: 'Financial',
        color: '#10B981',
      );

      expect(created.length, 1);
      expect(created.first.name, 'Financial');
      expect(created.first.color, '#10B981');

      final renamed = manager.renameFolder(
        folders: created,
        folderId: created.first.id,
        newName: 'Banking & Taxes',
      );

      expect(renamed.first.name, 'Banking & Taxes');
    });

    test('moves folder and blocks circular move', () {
      final f1 = VaultFolder(
        id: 'f1',
        name: 'Work',
        createdAt: '2026-11-15T10:00:00Z',
        updatedAt: '2026-11-15T10:00:00Z',
      );
      final f2 = VaultFolder(
        id: 'f2',
        name: 'Clients',
        parentId: 'f1',
        createdAt: '2026-11-15T10:05:00Z',
        updatedAt: '2026-11-15T10:05:00Z',
      );
      final f3 = VaultFolder(
        id: 'f3',
        name: 'Client Alpha',
        parentId: 'f2',
        createdAt: '2026-11-15T10:10:00Z',
        updatedAt: '2026-11-15T10:10:00Z',
      );

      final folders = [f1, f2, f3];

      // Moving f3 to root
      final movedToRoot = manager.moveFolder(
        folders: folders,
        folderId: 'f3',
        newParentId: null,
      );
      expect(movedToRoot.firstWhere((f) => f.id == 'f3').isRoot, isTrue);

      // Attempting to move f1 into its own subfolder f2 should throw ArgumentError
      expect(
        () => manager.moveFolder(
          folders: folders,
          folderId: 'f1',
          newParentId: 'f2',
        ),
        throwsArgumentError,
      );

      // Attempting to move f1 into itself should throw ArgumentError
      expect(
        () => manager.moveFolder(
          folders: folders,
          folderId: 'f1',
          newParentId: 'f1',
        ),
        throwsArgumentError,
      );
    });

    test('deletes folder with reparenting vs cascade', () {
      final f1 = VaultFolder(
        id: 'f1',
        name: 'Archive',
        createdAt: '2026-11-15T10:00:00Z',
        updatedAt: '2026-11-15T10:00:00Z',
      );
      final f2 = VaultFolder(
        id: 'f2',
        name: '2025',
        parentId: 'f1',
        createdAt: '2026-11-15T10:05:00Z',
        updatedAt: '2026-11-15T10:05:00Z',
      );
      final folders = [f1, f2];
      final items = [
        {'id': 'i1', 'title': 'Old Tax', 'folderId': 'f1'},
        {'id': 'i2', 'title': 'Receipt', 'folderId': 'f2'},
      ];

      // Reparent delete: f1 is deleted, f2 is moved to root (since f1 was root), i1 is moved to root
      final reparentResult = manager.deleteFolder(
        folders: folders,
        items: items,
        folderId: 'f1',
        cascade: false,
      );

      expect(reparentResult.folders.length, 1);
      expect(reparentResult.folders.first.id, 'f2');
      expect(reparentResult.folders.first.parentId, isNull);
      expect(reparentResult.items.firstWhere((i) => i['id'] == 'i1')['folderId'], isNull);

      // Cascade delete: f1 and f2 and all items are deleted
      final cascadeResult = manager.deleteFolder(
        folders: folders,
        items: items,
        folderId: 'f1',
        cascade: true,
      );

      expect(cascadeResult.folders, isEmpty);
      expect(cascadeResult.items, isEmpty);
    });

    test('moves and copies items between folders', () {
      final item = {'id': 'orig-1', 'title': 'W2 Form', 'folderId': 'f1'};

      final moved = manager.moveItemToFolder(
        item: item,
        targetFolderId: 'f2',
      );
      expect(moved['id'], 'orig-1');
      expect(moved['folderId'], 'f2');

      final copied = manager.copyItemToFolder(
        item: item,
        targetFolderId: 'f2',
      );
      expect(copied['id'], isNot('orig-1'));
      expect(copied['title'], 'W2 Form (Copy)');
      expect(copied['folderId'], 'f2');
    });
  });
}

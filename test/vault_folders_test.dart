import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nija/application/services/vault_folder_manager.dart';
import 'package:nija/domain/models/folder_tree_builder.dart';
import 'package:nija/domain/models/vault_entry_data.dart';
import 'package:nija/domain/models/vault_folder.dart';
import 'package:nija/domain/models/vault_payload.dart';
import 'package:nija/features/vault/application/vault_home_demo_data.dart';
import 'package:nija/features/vault/presentation/add_vault_item_screen.dart';
import 'package:nija/features/vault/presentation/document_upload_screen.dart';
import 'package:nija/features/vault/presentation/note_editor_screen.dart';
import 'package:nija/features/vault/presentation/widgets/vault_folders_view.dart';

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

      expect(tree.length, 2);
      expect(tree[0].folder.name, 'Personal');
      expect(tree[1].folder.name, 'Work');

      final workNode = tree[1];
      expect(workNode.subfolderCount, 1);
      expect(workNode.directItemCount, 1);
      expect(workNode.totalItemCount, 3);
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

      final movedToRoot = manager.moveFolder(
        folders: folders,
        folderId: 'f3',
        newParentId: null,
      );
      expect(movedToRoot.firstWhere((f) => f.id == 'f3').isRoot, isTrue);

      expect(
        () => manager.moveFolder(
          folders: folders,
          folderId: 'f1',
          newParentId: 'f2',
        ),
        throwsArgumentError,
      );

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

  group('VaultFoldersView UI & Explorer Operations', () {
    Widget buildTestFoldersView({
      List<VaultFolder> folders = const [],
      List<Map<String, dynamic>> items = const [],
      List<Map<String, dynamic>> notes = const [],
      void Function(String? folderId)? onAddItemToFolder,
      void Function(String? folderId)? onUploadDocumentToFolder,
      void Function(String name, String? parentId, String? color)? onCreateFolder,
      void Function(String id, String newName)? onRenameFolder,
      void Function(String id, bool cascade)? onDeleteFolder,
      void Function(Map<String, dynamic> item, String? targetFolderId)? onMoveItem,
      void Function(Map<String, dynamic> item, String? targetFolderId)? onCopyItem,
    }) {
      String? currentFolderId;
      final createFolderCb = onCreateFolder ?? (_, _, _) {};
      final addItemCb = onAddItemToFolder ?? (_) {};
      final uploadCb = onUploadDocumentToFolder ?? (_) {};

      return StatefulBuilder(
        builder: (context, setState) {
          return MaterialApp(
            home: Builder(
              builder: (ctx) => Scaffold(
                body: VaultFoldersView(
                  isWide: false,
                  folders: folders,
                  items: items,
                  notes: notes,
                  onFolderChanged: (id) => currentFolderId = id,
                  onOpenItem: (_) {},
                  onAddItemToFolder: addItemCb,
                  onUploadDocumentToFolder: uploadCb,
                  onCreateFolder: createFolderCb,
                  onRenameFolder: onRenameFolder ?? (_, _) {},
                  onMoveFolder: (_, _) {},
                  onDeleteFolder: onDeleteFolder ?? (_, _) {},
                  onMoveItem: onMoveItem ?? (_, _) {},
                  onCopyItem: onCopyItem ?? (_, _) {},
                  onDeleteItem: (_) {},
                ),
                floatingActionButton: FloatingActionButton.small(
                  key: const ValueKey('vault-fab'),
                  onPressed: () {
                    showModalBottomSheet<void>(
                      context: ctx,
                      builder: (bCtx) => SafeArea(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            ListTile(
                              key: const ValueKey('explorer-fab-new-folder'),
                              title: const Text('New Folder'),
                              onTap: () {
                                Navigator.pop(bCtx);
                                final controller = TextEditingController();
                                showDialog<void>(
                                  context: ctx,
                                  builder: (dCtx) => AlertDialog(
                                    title: const Text('Create New Folder'),
                                    content: TextField(
                                      key: const ValueKey('create-folder-name-input'),
                                      controller: controller,
                                    ),
                                    actions: [
                                      TextButton(onPressed: () => Navigator.pop(dCtx), child: const Text('Cancel')),
                                      FilledButton(
                                        key: const ValueKey('create-folder-submit-button'),
                                        onPressed: () {
                                          createFolderCb(controller.text.trim(), currentFolderId, null);
                                          Navigator.pop(dCtx);
                                        },
                                        child: const Text('Create'),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                            ListTile(
                              key: const ValueKey('explorer-fab-add-item'),
                              title: const Text('Add Item'),
                              onTap: () {
                                Navigator.pop(bCtx);
                                addItemCb(currentFolderId);
                              },
                            ),
                            ListTile(
                              key: const ValueKey('explorer-fab-upload-file'),
                              title: const Text('Upload File'),
                              onTap: () {
                                Navigator.pop(bCtx);
                                uploadCb(currentFolderId);
                              },
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                  child: const Icon(Icons.add),
                ),
              ),
            ),
          );
        },
      );
    }

    testWidgets('renders root directory header and breadcrumbs', (tester) async {
      await tester.pumpWidget(buildTestFoldersView());
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('explorer-breadcrumb-root')), findsOneWidget);
      expect(find.text('Root Directory'), findsOneWidget);
      expect(find.byKey(const ValueKey('vault-fab')), findsOneWidget);
    });

    testWidgets('creates a new folder via the dialog', (tester) async {
      String? createdName;
      await tester.pumpWidget(buildTestFoldersView(
        onCreateFolder: (name, parentId, color) {
          createdName = name;
        },
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('vault-fab')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('explorer-fab-new-folder')));
      await tester.pumpAndSettle();

      expect(find.text('Create New Folder'), findsOneWidget);
      await tester.enterText(find.byKey(const ValueKey('create-folder-name-input')), 'Financials');
      await tester.tap(find.byKey(const ValueKey('create-folder-submit-button')));
      await tester.pumpAndSettle();

      expect(createdName, 'Financials');
    });

    testWidgets('navigates into folder and updates breadcrumbs', (tester) async {
      final folder1 = VaultFolder(
        id: 'f1',
        name: 'Legal',
        createdAt: '2026-11-15T10:00:00Z',
        updatedAt: '2026-11-15T10:00:00Z',
      );

      await tester.pumpWidget(buildTestFoldersView(folders: [folder1]));
      await tester.pumpAndSettle();

      expect(find.text('Legal'), findsOneWidget);

      await tester.tap(find.text('Legal'));
      await tester.pumpAndSettle();

      expect(find.text('Legal'), findsWidgets);
      expect(find.byTooltip('Up to parent folder'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('explorer-breadcrumb-root')));
      await tester.pumpAndSettle();

      expect(find.text('Root Directory'), findsOneWidget);
    });

    testWidgets('switches between List, Grid, and Tree views', (tester) async {
      final folder1 = VaultFolder(
        id: 'f1',
        name: 'Photos',
        createdAt: '2026-11-15T10:00:00Z',
        updatedAt: '2026-11-15T10:00:00Z',
      );

      await tester.pumpWidget(buildTestFoldersView(folders: [folder1]));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Grid view'));
      await tester.pumpAndSettle();
      expect(find.byType(GridView), findsOneWidget);

      await tester.tap(find.byTooltip('Tree view'));
      await tester.pumpAndSettle();
      expect(find.text('Photos'), findsWidgets);

      await tester.tap(find.byTooltip('List view'));
      await tester.pumpAndSettle();
      expect(find.byType(GridView), findsNothing);
    });

    testWidgets('filters items in folder using explorer search box', (tester) async {
      final folder1 = VaultFolder(
        id: 'f1',
        name: 'Invoices',
        createdAt: '2026-11-15T10:00:00Z',
        updatedAt: '2026-11-15T10:00:00Z',
      );
      final folder2 = VaultFolder(
        id: 'f2',
        name: 'Personal',
        createdAt: '2026-11-15T10:00:00Z',
        updatedAt: '2026-11-15T10:00:00Z',
      );

      await tester.pumpWidget(buildTestFoldersView(folders: [folder1, folder2]));
      await tester.pumpAndSettle();

      expect(find.text('Invoices'), findsOneWidget);
      expect(find.text('Personal'), findsOneWidget);

      await tester.enterText(find.byKey(const ValueKey('explorer-search-input')), 'Invo');
      await tester.pumpAndSettle();

      expect(find.text('Invoices'), findsOneWidget);
      expect(find.text('Personal'), findsNothing);
    });

    testWidgets('renames a folder via popup menu', (tester) async {
      final folder1 = VaultFolder(
        id: 'f1',
        name: 'Drafts',
        createdAt: '2026-11-15T10:00:00Z',
        updatedAt: '2026-11-15T10:00:00Z',
      );

      String? renamedId;
      String? renamedValue;
      await tester.pumpWidget(buildTestFoldersView(
        folders: [folder1],
        onRenameFolder: (id, name) {
          renamedId = id;
          renamedValue = name;
        },
      ));
      await tester.pumpAndSettle();
      expect(find.text('Drafts'), findsOneWidget);

      await tester.tap(
        find.descendant(
          of: find.widgetWithText(Card, 'Drafts'),
          matching: find.byIcon(Icons.more_vert),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Rename'));
      await tester.pumpAndSettle();

      await tester.enterText(find.widgetWithText(TextField, 'Drafts'), 'Published');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(renamedId, 'f1');
      expect(renamedValue, 'Published');
    });

    testWidgets('deletes a folder with cascade choice', (tester) async {
      final folder1 = VaultFolder(
        id: 'f1',
        name: 'Temp',
        createdAt: '2026-11-15T10:00:00Z',
        updatedAt: '2026-11-15T10:00:00Z',
      );

      String? deletedId;
      bool? cascadeOption;
      await tester.pumpWidget(buildTestFoldersView(
        folders: [folder1],
        onDeleteFolder: (id, cascade) {
          deletedId = id;
          cascadeOption = cascade;
        },
      ));
      await tester.pumpAndSettle();
      expect(find.text('Temp'), findsOneWidget);

      await tester.tap(
        find.descendant(
          of: find.widgetWithText(Card, 'Temp'),
          matching: find.byIcon(Icons.more_vert),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Delete All'));
      await tester.pumpAndSettle();

      expect(deletedId, 'f1');
      expect(cascadeOption, isTrue);
    });

    testWidgets('displays Default folder at root and shows unorganized items inside it', (tester) async {
      final unorganizedItem = {
        'id': 'item-default-1',
        'title': 'My Secret Password',
        'type': 'Password',
        'folderId': null,
      };

      await tester.pumpWidget(buildTestFoldersView(
        folders: const [],
        items: [unorganizedItem],
      ));
      await tester.pumpAndSettle();

      // At root, the Default folder is shown
      expect(find.text('Default'), findsOneWidget);
      // Items are grouped inside Default, so not directly in root list
      expect(find.text('My Secret Password'), findsNothing);

      // Navigate into Default folder
      await tester.tap(find.text('Default'));
      await tester.pumpAndSettle();

      // Now inside Default, the item is displayed
      expect(find.text('My Secret Password'), findsOneWidget);
    });

    testWidgets('allows adding item to folder from action bar button', (tester) async {
      String? targetFolderId;
      await tester.pumpWidget(buildTestFoldersView(
        onAddItemToFolder: (fid) => targetFolderId = fid,
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('vault-fab')));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('explorer-fab-add-item')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('explorer-fab-add-item')));
      await tester.pumpAndSettle();

      expect(targetFolderId, isNull);
    });

    testWidgets('allows moving an item to Default folder', (tester) async {
      final itemInCustom = {
        'id': 'item-custom-1',
        'title': 'Database URL',
        'type': 'Server',
        'folderId': 'f1',
      };
      final folder1 = VaultFolder(
        id: 'f1',
        name: 'Infrastructure',
        createdAt: '2026-11-15T10:00:00Z',
        updatedAt: '2026-11-15T10:00:00Z',
      );

      Map<String, dynamic>? movedItem;
      String? targetFolder;

      await tester.pumpWidget(buildTestFoldersView(
        folders: [folder1],
        items: [itemInCustom],
        onMoveItem: (item, target) {
          movedItem = item;
          targetFolder = target;
        },
      ));
      await tester.pumpAndSettle();

      // Open Infrastructure folder
      await tester.tap(find.text('Infrastructure'));
      await tester.pumpAndSettle();
      expect(find.text('Database URL'), findsOneWidget);

      // Tap item actions and select Move to...
      await tester.tap(
        find.descendant(
          of: find.widgetWithText(Card, 'Database URL'),
          matching: find.byIcon(Icons.more_vert),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Move to...'));
      await tester.pumpAndSettle();

      // Choose Default Folder
      expect(find.text('Default Folder'), findsOneWidget);
      await tester.tap(find.text('Default Folder'));
      await tester.pumpAndSettle();

      expect(movedItem?['id'], 'item-custom-1');
      expect(targetFolder, isNull);
    });
  });

  group('Demo PDF and Attachments', () {
    test('VaultHomeDemoData demoPdfBytes is a valid PDF-1.4 file with only text Demo', () {
      final bytes = VaultHomeDemoData.demoPdfBytes;
      expect(bytes, isNotEmpty);
      expect(bytes.length, equals(580));

      final str = latin1.decode(bytes);
      expect(str.startsWith('%PDF-1.4'), isTrue);
      expect(str.contains('(Demo) Tj'), isTrue);
      expect(str.contains('startxref'), isTrue);
      expect(str.contains('%%EOF'), isTrue);

      // Verify "Demo" is the only text drawn in text operators
      final matches = RegExp(r'\((.*?)\)\s*Tj')
          .allMatches(str)
          .map((m) => m.group(1))
          .toList();
      expect(matches, equals(['Demo']));
    });

    test('demo documents and attachments carry valid demo PDF bytes', () {
      final items = VaultHomeDemoData.cloneItems();
      final docs = items.where((i) => i['type'] == 'Documents').toList();
      expect(docs, isNotEmpty);

      for (final doc in docs) {
        expect(doc['documentBytes'], equals(VaultHomeDemoData.demoPdfBytes));
        expect(doc['__documentBytes__'], equals(VaultHomeDemoData.demoPdfBytes));
        expect(doc['documentExtension'], equals('pdf'));
        expect(doc['documentSizeBytes'], equals(VaultHomeDemoData.demoPdfBytes.length));
      }

      // Verify items with attachments
      final itemsWithAttachments = items
          .where((i) => i['attachments'] is List && (i['attachments'] as List).isNotEmpty)
          .toList();
      expect(itemsWithAttachments, isNotEmpty);

      for (final item in itemsWithAttachments) {
        final attachments = item['attachments'] as List;
        for (final att in attachments) {
          expect(att['documentExtension'], equals('pdf'));
          expect(att['documentBytes'], equals(VaultHomeDemoData.demoPdfBytes));
          expect(att['__documentBytes__'], equals(VaultHomeDemoData.demoPdfBytes));
        }
      }
    });
  });

  group('Item Folder Integration & Selection', () {
    final testFolders = [
      VaultFolder(
        id: 'work',
        name: 'Work',
        createdAt: '2026-11-15T00:00:00Z',
        updatedAt: '2026-11-15T00:00:00Z',
      ),
      VaultFolder(
        id: 'personal',
        name: 'Personal',
        createdAt: '2026-11-15T00:00:00Z',
        updatedAt: '2026-11-15T00:00:00Z',
      ),
    ];

    testWidgets('AddVaultItemScreen defaults folder selection to default and saves folderId', (tester) async {
      tester.view.physicalSize = const Size(1000, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      Map<String, dynamic>? savedItem;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () async {
                    savedItem = await Navigator.of(context).push<Map<String, dynamic>>(
                      MaterialPageRoute(
                        builder: (_) => AddVaultItemScreen(
                          fixedType: 'Login',
                          folders: testFolders,
                        ),
                      ),
                    );
                  },
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('item-folder-selector')), findsOneWidget);
      expect(find.text('Default'), findsOneWidget);

      await tester.enterText(find.widgetWithText(TextField, 'Title'), 'GitHub');
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Save'));
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(savedItem, isNotNull);
      expect(savedItem!['title'], 'GitHub');
      expect(savedItem!['folderId'], 'default');
    });

    testWidgets('AddVaultItemScreen pre-selects initialFolderId and allows changing folder', (tester) async {
      tester.view.physicalSize = const Size(1000, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      Map<String, dynamic>? savedItem;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () async {
                    savedItem = await Navigator.of(context).push<Map<String, dynamic>>(
                      MaterialPageRoute(
                        builder: (_) => AddVaultItemScreen(
                          fixedType: 'Login',
                          folders: testFolders,
                          initialFolderId: 'work',
                        ),
                      ),
                    );
                  },
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.text('Work'), findsOneWidget);

      // Change folder to Personal
      await tester.tap(find.byKey(const ValueKey('item-folder-selector')));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Personal').last);
      await tester.pumpAndSettle();

      await tester.enterText(find.widgetWithText(TextField, 'Title'), 'Work Email');
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Save'));
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(savedItem, isNotNull);
      expect(savedItem!['title'], 'Work Email');
      expect(savedItem!['folderId'], 'personal');
    });

    testWidgets('AddVaultItemScreen editing preserves existing folder and defaults legacy item to default', (tester) async {
      tester.view.physicalSize = const Size(1000, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      Map<String, dynamic>? savedItem;

      final existingItem = {
        'id': 'item-101',
        'type': 'Login',
        'title': 'AWS Console',
        'folderId': 'work',
        'fields': [
          {'label': 'Username or email', 'value': 'admin@example.com', 'sensitive': false},
        ],
      };

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () async {
                    savedItem = await Navigator.of(context).push<Map<String, dynamic>>(
                      MaterialPageRoute(
                        builder: (_) => AddVaultItemScreen(
                          initialItem: existingItem,
                          folders: testFolders,
                        ),
                      ),
                    );
                  },
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      // Pre-selected to 'work'
      expect(find.text('Work'), findsOneWidget);

      await tester.ensureVisible(find.text('Save'));
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(savedItem, isNotNull);
      expect(savedItem!['id'], 'item-101');
      expect(savedItem!['folderId'], 'work');
    });

    test('FolderTreeBuilder categorizes legacy items without folderId under default folder', () {
      final legacyItem = {'id': 'i1', 'title': 'Legacy Item'};
      final explicitDefaultItem = {'id': 'i2', 'title': 'Default Item', 'folderId': 'default'};
      final workItem = {'id': 'i3', 'title': 'Work Item', 'folderId': 'work'};

      final allItems = [legacyItem, explicitDefaultItem, workItem];

      final defaultItems = FolderTreeBuilder.getItemsInFolder(
        folderId: 'default',
        items: allItems,
      );
      expect(defaultItems.map((i) => i['id']), containsAll(['i1', 'i2']));
      expect(defaultItems.map((i) => i['id']), isNot(contains('i3')));

      final workItems = FolderTreeBuilder.getItemsInFolder(
        folderId: 'work',
        items: allItems,
      );
      expect(workItems.map((i) => i['id']), equals(['i3']));
    });

    testWidgets('NoteEditorScreen allows folder selection and saves folderId', (tester) async {
      tester.view.physicalSize = const Size(1000, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      Map<String, dynamic>? savedNote;

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: const [
            FlutterQuillLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [Locale('en')],
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () async {
                    savedNote = await Navigator.of(context).push<Map<String, dynamic>>(
                      MaterialPageRoute(
                        builder: (_) => NoteEditorScreen(
                          folders: testFolders,
                          initialFolderId: 'work',
                        ),
                      ),
                    );
                  },
                  child: const Text('Open Note'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Note'));
      await tester.pumpAndSettle();

      // Tap title header button to open animated drawer
      await tester.tap(find.byKey(const ValueKey('note-title-header-button')));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('note-folder-selector')), findsOneWidget);
      expect(find.text('Work'), findsWidgets);

      await tester.enterText(find.byKey(const ValueKey('note-details-title-input')), 'Meeting notes');
      await tester.pumpAndSettle();

      // Change folder to Personal
      await tester.tap(find.byKey(const ValueKey('note-folder-selector')));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Personal').last);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(savedNote, isNotNull);
      expect(savedNote!['title'], 'Meeting notes');
      expect(savedNote!['folderId'], 'personal');
    });

    testWidgets('NoteViewScreen displays folder badge in AppBar', (tester) async {
      final noteWithFolder = {
        'id': 'note-1',
        'title': 'Project Roadmap',
        'preview': 'Q1 roadmap',
        'folderId': 'work',
      };

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: const [
            FlutterQuillLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [Locale('en')],
          home: NoteViewScreen(
            note: noteWithFolder,
            folders: testFolders,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Project Roadmap'), findsOneWidget);
      expect(find.text('Work'), findsOneWidget);
    });

    testWidgets('DocumentUploadScreen has folder selector with regular styling', (tester) async {
      tester.view.physicalSize = const Size(1000, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        MaterialApp(
          home: DocumentUploadScreen(
            currentVaultSizeBytes: 0,
            maxVaultBytes: 100 * 1024 * 1024,
            folders: testFolders,
            initialFolderId: 'work',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('document-folder-selector')), findsOneWidget);
      expect(find.text('Work'), findsOneWidget);
      expect(find.text('Choose documents'), findsOneWidget);
      expect(find.textContaining('per document'), findsOneWidget);
    });

    testWidgets('AddVaultItemScreen allows creating new folder inline via [+] button without dropping operation', (tester) async {
      tester.view.physicalSize = const Size(1000, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      Map<String, dynamic>? savedItem;
      final createdFolders = <VaultFolder>[];

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () async {
                    savedItem = await Navigator.of(context).push<Map<String, dynamic>>(
                      MaterialPageRoute(
                        builder: (_) => AddVaultItemScreen(
                          fixedType: 'Login',
                          folders: testFolders,
                          onCreateFolder: (name, {parentId, color}) async {
                            final folder = VaultFolder(
                              id: 'folder-finances',
                              name: name,
                              createdAt: '2026-11-16T12:00:00Z',
                              updatedAt: '2026-11-16T12:00:00Z',
                            );
                            createdFolders.add(folder);
                            return folder;
                          },
                        ),
                      ),
                    );
                  },
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      // Enter Title
      await tester.enterText(find.widgetWithText(TextField, 'Title'), 'My Bank Login');
      await tester.pumpAndSettle();

      // Tap [+] create folder button next to folder dropdown
      expect(find.byKey(const ValueKey('item-create-folder-button')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('item-create-folder-button')));
      await tester.pumpAndSettle();

      // Folder create dialog appears
      expect(find.text('New Folder'), findsOneWidget);
      expect(find.byKey(const ValueKey('create-folder-name-input')), findsOneWidget);

      await tester.enterText(find.byKey(const ValueKey('create-folder-name-input')), 'Finances');
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('create-folder-submit-button')));
      await tester.pumpAndSettle();

      // Dialog closed, folder was created via callback
      expect(createdFolders.length, 1);
      expect(createdFolders.first.name, 'Finances');

      // The dropdown now automatically displays 'Finances' as selected!
      expect(find.text('Finances'), findsOneWidget);

      // Title is still intact (operation was NOT dropped)
      expect(find.text('My Bank Login'), findsOneWidget);

      await tester.ensureVisible(find.text('Save'));
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(savedItem, isNotNull);
      expect(savedItem!['title'], 'My Bank Login');
      expect(savedItem!['folderId'], 'folder-finances');
    });

    testWidgets('DocumentUploadScreen allows creating new folder inline via [+] button', (tester) async {
      tester.view.physicalSize = const Size(1000, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final createdFolders = <VaultFolder>[];

      await tester.pumpWidget(
        MaterialApp(
          home: DocumentUploadScreen(
            currentVaultSizeBytes: 0,
            maxVaultBytes: 100 * 1024 * 1024,
            folders: testFolders,
            onCreateFolder: (name, {parentId, color}) async {
              final folder = VaultFolder(
                id: 'folder-legal',
                name: name,
                createdAt: '2026-11-16T12:00:00Z',
                updatedAt: '2026-11-16T12:00:00Z',
              );
              createdFolders.add(folder);
              return folder;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('document-create-folder-button')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('document-create-folder-button')));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const ValueKey('create-folder-name-input')), 'Legal');
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('create-folder-submit-button')));
      await tester.pumpAndSettle();

      expect(createdFolders.length, 1);
      expect(createdFolders.first.name, 'Legal');
      expect(find.text('Legal'), findsOneWidget);
    });

    testWidgets('NoteEditorScreen allows creating new folder inline via [+] button in hierarchy sheet', (tester) async {
      tester.view.physicalSize = const Size(1000, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      Map<String, dynamic>? savedNote;
      final createdFolders = <VaultFolder>[];

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: const [
            FlutterQuillLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [Locale('en')],
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () async {
                    savedNote = await Navigator.of(context).push<Map<String, dynamic>>(
                      MaterialPageRoute(
                        builder: (_) => NoteEditorScreen(
                          folders: testFolders,
                          onCreateFolder: (name, {parentId, color}) async {
                            final folder = VaultFolder(
                              id: 'folder-journal',
                              name: name,
                              parentId: parentId,
                              createdAt: '2026-11-16T12:00:00Z',
                              updatedAt: '2026-11-16T12:00:00Z',
                            );
                            createdFolders.add(folder);
                            return folder;
                          },
                        ),
                      ),
                    );
                  },
                  child: const Text('Open Note'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Note'));
      await tester.pumpAndSettle();

      // Tap title header button to open animated drawer
      await tester.tap(find.byKey(const ValueKey('note-title-header-button')));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const ValueKey('note-details-title-input')), 'Daily Journal');
      await tester.pumpAndSettle();

      // Open folder hierarchy sheet
      expect(find.byKey(const ValueKey('note-folder-selector')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('note-folder-selector')));
      await tester.pumpAndSettle();

      // Tap create new folder button in hierarchy sheet
      expect(find.byKey(const ValueKey('hierarchy-create-folder-button')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('hierarchy-create-folder-button')));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const ValueKey('create-folder-name-input')), 'Journal');
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('create-folder-submit-button')));
      await tester.pumpAndSettle();

      expect(createdFolders.length, 1);
      expect(createdFolders.first.name, 'Journal');

      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(savedNote, isNotNull);
      expect(savedNote!['title'], 'Daily Journal');
      expect(savedNote!['folderId'], 'folder-journal');
    });

    testWidgets('NoteEditorScreen allows creating subfolder via long-press in hierarchy sheet', (tester) async {
      tester.view.physicalSize = const Size(1000, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final createdFolders = <VaultFolder>[];

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: const [
            FlutterQuillLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [Locale('en')],
          home: Scaffold(
            body: NoteEditorScreen(
              folders: testFolders,
              onCreateFolder: (name, {parentId, color}) async {
                final folder = VaultFolder(
                  id: 'folder-sub',
                  name: name,
                  parentId: parentId,
                  color: color,
                  createdAt: '2026-11-16T12:00:00Z',
                  updatedAt: '2026-11-16T12:00:00Z',
                );
                createdFolders.add(folder);
                return folder;
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap title header button to open animated drawer
      await tester.tap(find.byKey(const ValueKey('note-title-header-button')));
      await tester.pumpAndSettle();

      // Open folder hierarchy directly from expanded folder pill
      expect(find.byKey(const ValueKey('note-folder-selector')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('note-folder-selector')));
      await tester.pumpAndSettle();

      // Long press on Work folder tile
      await tester.longPress(find.text('Work'));
      await tester.pumpAndSettle();

      // Check option dialog / sheet appeared
      expect(find.text('Create subfolder inside "Work"'), findsOneWidget);
      await tester.tap(find.text('Create subfolder inside "Work"'));
      await tester.pumpAndSettle();

      // Dialog for subfolder
      expect(find.byKey(const ValueKey('create-folder-name-input')), findsOneWidget);
      await tester.enterText(find.byKey(const ValueKey('create-folder-name-input')), 'Projects');
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('create-folder-submit-button')));
      await tester.pumpAndSettle();

      expect(createdFolders.length, 1);
      expect(createdFolders.first.name, 'Projects');
      expect(createdFolders.first.parentId, 'work');
    });
  });
}

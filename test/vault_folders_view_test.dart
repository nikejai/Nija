import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nija/domain/models/vault_folder.dart';
import 'package:nija/features/vault/presentation/vault_app_shell.dart';

void main() {
  Widget buildTestShell({
    List<Map<String, dynamic>> items = const [],
    List<Map<String, dynamic>> notes = const [],
    List<Map<String, dynamic>> folders = const [],
    PersistVaultFolders? onPersistFolders,
  }) {
    return MaterialApp(
      home: VaultAppShell(
        recoveryWords: const [
          'anchor',
          'apple',
          'arrow',
          'atlas',
          'avocado',
          'axis',
          'bacon',
          'badge',
          'baker',
          'balance',
          'banner',
          'bar',
        ],
        initialItems: items,
        initialNotes: notes,
        initialCustomTypeDefinitions: const [],
        initialFolders: folders,
        languageMode: 'en',
        onLanguageModeChanged: (_) {},
        biometricEnabled: false,
        onBiometricChanged: (_) {},
        onPersistVaultData: ({
          required items,
          required notes,
          required customTypeDefinitions,
        }) async {},
        onPersistFolders: onPersistFolders,
        onRotateMasterPassword: ({
          required currentPassword,
          required newPassword,
        }) async {},
        onRotateRecoveryPhrase: ({
          required currentRecoveryPhrase,
          required newRecoveryPhrase,
        }) async {},
        onExportVault: () async {},
        onImportVault: () async {},
        onBackupToCloud: () async {},
        onRestoreFromCloud: () async {},
        onReadCloudBackupAccount: () async => null,
        onChangeCloudBackupAccount: () async => false,
        onLockNow: () {},
      ),
    );
  }

  Future<void> openFoldersTab(WidgetTester tester) async {
    final foldersIcon = find.byIcon(Icons.folder_outlined);
    if (foldersIcon.evaluate().isNotEmpty) {
      await tester.tap(foldersIcon);
    } else {
      await tester.tap(find.byIcon(Icons.folder));
    }
    await tester.pumpAndSettle();
  }

  testWidgets('renders Folders tab in bottom navigation and switches to explorer view', (tester) async {
    await tester.pumpWidget(buildTestShell());
    await tester.pumpAndSettle();

    // Check bottom nav bar has Folders tab
    expect(find.text('Folders'), findsOneWidget);

    // Tap Folders tab
    await openFoldersTab(tester);

    // Verify explorer header and root breadcrumb are shown
    expect(find.byKey(const ValueKey('explorer-breadcrumb-root')), findsOneWidget);
    expect(find.text('Root Directory'), findsOneWidget);
    expect(find.byKey(const ValueKey('explorer-new-folder-button')), findsOneWidget);
    expect(find.byKey(const ValueKey('explorer-upload-file-button')), findsOneWidget);
  });

  testWidgets('creates a new folder via the dialog and persists it', (tester) async {
    List<Map<String, dynamic>>? persistedFolders;

    await tester.pumpWidget(buildTestShell(
      onPersistFolders: (f) async {
        persistedFolders = f;
      },
    ));
    await tester.pumpAndSettle();

    await openFoldersTab(tester);

    // Tap New Folder button
    await tester.tap(find.byKey(const ValueKey('explorer-new-folder-button')));
    await tester.pumpAndSettle();

    // Dialog appears
    expect(find.text('Create New Folder'), findsOneWidget);
    await tester.enterText(find.byKey(const ValueKey('create-folder-name-input')), 'Financials');
    await tester.tap(find.byKey(const ValueKey('create-folder-submit-button')));
    await tester.pumpAndSettle();

    // Folder appears in directory list
    expect(find.text('Financials'), findsOneWidget);
    expect(persistedFolders, isNotNull);
    expect(persistedFolders!.any((f) => f['name'] == 'Financials'), isTrue);
  });

  testWidgets('navigates into folder and updates breadcrumbs', (tester) async {
    final folder1 = VaultFolder(
      id: 'f1',
      name: 'Legal',
      createdAt: '2026-11-15T10:00:00Z',
      updatedAt: '2026-11-15T10:00:00Z',
    );

    await tester.pumpWidget(buildTestShell(folders: [folder1.toJson()]));
    await tester.pumpAndSettle();

    await openFoldersTab(tester);

    // Folder row is visible
    expect(find.text('Legal'), findsOneWidget);

    // Tap on Legal folder to navigate inside
    await tester.tap(find.text('Legal'));
    await tester.pumpAndSettle();

    // Breadcrumb now contains Legal and title updates
    expect(find.text('Legal'), findsWidgets);
    expect(find.byTooltip('Up to parent folder'), findsOneWidget);

    // Tap Root breadcrumb to go back
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

    await tester.pumpWidget(buildTestShell(folders: [folder1.toJson()]));
    await tester.pumpAndSettle();

    await openFoldersTab(tester);

    // Switch to Grid view
    await tester.tap(find.byTooltip('Grid view'));
    await tester.pumpAndSettle();
    expect(find.byType(GridView), findsOneWidget);

    // Switch to Tree view
    await tester.tap(find.byTooltip('Tree view'));
    await tester.pumpAndSettle();
    expect(find.text('Photos'), findsWidgets);

    // Switch back to List view
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

    await tester.pumpWidget(buildTestShell(folders: [folder1.toJson(), folder2.toJson()]));
    await tester.pumpAndSettle();

    await openFoldersTab(tester);

    expect(find.text('Invoices'), findsOneWidget);
    expect(find.text('Personal'), findsOneWidget);

    // Type in search box
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

    List<Map<String, dynamic>>? updatedFolders;
    await tester.pumpWidget(buildTestShell(
      folders: [folder1.toJson()],
      onPersistFolders: (f) async {
        updatedFolders = f;
      },
    ));
    await tester.pumpAndSettle();

    await openFoldersTab(tester);
    expect(find.text('Drafts'), findsOneWidget);

    // Open more menu on folder row
    await tester.tap(find.byIcon(Icons.more_vert).first);
    await tester.pumpAndSettle();

    // Tap Rename
    await tester.tap(find.text('Rename'));
    await tester.pumpAndSettle();

    // Enter new name
    await tester.enterText(find.widgetWithText(TextField, 'Drafts'), 'Published');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.text('Published'), findsOneWidget);
    expect(find.text('Drafts'), findsNothing);
    expect(updatedFolders?.first['name'], 'Published');
  });

  testWidgets('deletes a folder with cascade choice', (tester) async {
    final folder1 = VaultFolder(
      id: 'f1',
      name: 'Temp',
      createdAt: '2026-11-15T10:00:00Z',
      updatedAt: '2026-11-15T10:00:00Z',
    );

    List<Map<String, dynamic>>? updatedFolders;
    await tester.pumpWidget(buildTestShell(
      folders: [folder1.toJson()],
      onPersistFolders: (f) async {
        updatedFolders = f;
      },
    ));
    await tester.pumpAndSettle();

    await openFoldersTab(tester);
    expect(find.text('Temp'), findsOneWidget);

    // Open more menu
    await tester.tap(find.byIcon(Icons.more_vert).first);
    await tester.pumpAndSettle();

    // Tap Delete
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    // Confirm deletion with "Delete All"
    await tester.tap(find.text('Delete All'));
    await tester.pumpAndSettle();

    expect(find.text('Temp'), findsNothing);
    expect(updatedFolders, isEmpty);
  });
}

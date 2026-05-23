import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nija/features/vault/presentation/vault_app_shell.dart';

void main() {
  testWidgets('vault app shell shows primary tabs', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: VaultAppShell(
          recoveryWords: const [
            'anchor',
            'apple',
            'arrow',
            'atlas',
            'beacon',
            'breeze',
            'canyon',
            'cedar',
            'cobalt',
            'ember',
            'harbor',
            'willow',
          ],
          initialItems: const [
            {
              'id': 'item-0',
              'type': 'Login',
              'title': 'Seed item',
              'subtitle': 'seed@example.com',
              'updated': 'Now',
              'fields': [],
            },
          ],
          initialNotes: const [],
          initialCustomTypeDefinitions: const [],
          languageMode: 'en',
          onLanguageModeChanged: (_) {},
          biometricEnabled: false,
          onBiometricChanged: (_) {},
          onPersistVaultData:
              ({
                required items,
                required notes,
                required customTypeDefinitions,
              }) async {},
          onRotateMasterPassword:
              ({required currentPassword, required newPassword}) async {},
          onRotateRecoveryPhrase:
              ({
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
      ),
    );

    expect(find.text('Home'), findsWidgets);
    expect(find.text('Favorites'), findsWidgets);
    expect(find.text('All items'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('Recent'), findsOneWidget);
    expect(find.text('View all'), findsOneWidget);
  });

  testWidgets(
    'vault and notes support type/tag filtering and tag sort option',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: VaultAppShell(
            recoveryWords: const [
              'anchor',
              'apple',
              'arrow',
              'atlas',
              'beacon',
              'breeze',
              'canyon',
              'cedar',
              'cobalt',
              'ember',
              'harbor',
              'willow',
            ],
            initialItems: const [
              {
                'id': 'item-login',
                'type': 'Login',
                'title': 'Mail',
                'subtitle': 'mail@example.com',
                'updated': 'Now',
                'fields': [],
              },
              {
                'id': 'item-card',
                'type': 'Card',
                'title': 'Visa',
                'subtitle': '**** 1234',
                'updated': 'Now',
                'fields': [],
              },
            ],
            initialNotes: const [
              {
                'id': 'note-work',
                'title': 'Meeting',
                'preview': 'Project plan',
                'updated': 'Now',
                'pinned': false,
                'tags': ['work'],
                'delta': [
                  {'insert': 'Project plan\n'},
                ],
              },
              {
                'id': 'note-home',
                'title': 'Groceries',
                'preview': 'Milk',
                'updated': 'Now',
                'pinned': false,
                'tags': ['home'],
                'delta': [
                  {'insert': 'Milk\n'},
                ],
              },
            ],
            initialCustomTypeDefinitions: const [],
            languageMode: 'en',
            onLanguageModeChanged: (_) {},
            biometricEnabled: false,
            onBiometricChanged: (_) {},
            onPersistVaultData:
                ({
                  required items,
                  required notes,
                  required customTypeDefinitions,
                }) async {},
            onRotateMasterPassword:
                ({required currentPassword, required newPassword}) async {},
            onRotateRecoveryPhrase:
                ({
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
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('All types'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('vault-filter-selector')));
      await tester.pumpAndSettle();
      expect(find.text('Card'), findsWidgets);
      await tester.tap(find.text('Card').last);
      await tester.pumpAndSettle();
      expect(find.text('All types'), findsNothing);

      await tester.tap(find.text('Notes'));
      await tester.pumpAndSettle();
      expect(find.text('Sort by'), findsOneWidget);
      expect(find.text('Filter by'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('notes-filter-selector')));
      await tester.pumpAndSettle();
      expect(find.text('#work'), findsWidgets);
      await tester.tap(find.text('#work').last);
      await tester.pumpAndSettle();
      expect(find.text('#work'), findsWidgets);

      await tester.tap(find.byKey(const ValueKey('notes-sort-selector')));
      await tester.pumpAndSettle();
      expect(find.text('Tags'), findsWidgets);
      await tester.tap(find.text('Tags').last);
      await tester.pumpAndSettle();
    },
  );

  testWidgets('notes support long-press pin action and detail delete action', (
    tester,
  ) async {
    final persistedNotes = <List<Map<String, dynamic>>>[];
    await tester.pumpWidget(
      MaterialApp(
        home: VaultAppShell(
          recoveryWords: const [
            'anchor',
            'apple',
            'arrow',
            'atlas',
            'beacon',
            'breeze',
            'canyon',
            'cedar',
            'cobalt',
            'ember',
            'harbor',
            'willow',
          ],
          initialItems: const [],
          initialNotes: const [
            {
              'id': 'note-1',
              'title': 'Trip checklist',
              'preview': 'Pack bags',
              'updated': 'Now',
              'pinned': false,
              'tags': ['trip'],
              'delta': [
                {'insert': 'Pack bags\n'},
              ],
            },
          ],
          initialCustomTypeDefinitions: const [],
          languageMode: 'en',
          onLanguageModeChanged: (_) {},
          biometricEnabled: false,
          onBiometricChanged: (_) {},
          onPersistVaultData:
              ({
                required items,
                required notes,
                required customTypeDefinitions,
              }) async {
                persistedNotes.add(
                  notes
                      .map((entry) => Map<String, dynamic>.from(entry))
                      .toList(),
                );
              },
          onRotateMasterPassword:
              ({required currentPassword, required newPassword}) async {},
          onRotateRecoveryPhrase:
              ({
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
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Notes'));
    await tester.pumpAndSettle();

    await tester.longPress(find.text('Trip checklist'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('note-action-pin')));
    await tester.pumpAndSettle();

    expect(persistedNotes.isNotEmpty, isTrue);
    expect(persistedNotes.last.first['pinned'], isTrue);

    await tester.tap(find.text('Trip checklist'));
    await tester.pumpAndSettle();
    expect(find.text('Edit'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.delete_outline).first);
    await tester.pumpAndSettle();

    expect(find.text('Trip checklist'), findsNothing);
  });

  testWidgets('all items multi-select header/actions and undo flows work', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: VaultAppShell(
          recoveryWords: const [
            'anchor',
            'apple',
            'arrow',
            'atlas',
            'beacon',
            'breeze',
            'canyon',
            'cedar',
            'cobalt',
            'ember',
            'harbor',
            'willow',
          ],
          initialItems: const [
            {
              'id': 'item-1',
              'type': 'Login',
              'title': 'Email',
              'subtitle': 'a@example.com',
              'updated': 'Now',
              'fields': [
                {
                  'label': 'Username',
                  'value': 'a@example.com',
                  'sensitive': false,
                },
              ],
            },
            {
              'id': 'item-2',
              'type': 'Login',
              'title': 'Portal',
              'subtitle': 'p@example.com',
              'updated': 'Now',
              'pinned': false,
              'fields': [
                {
                  'label': 'Password',
                  'value': 'secret-2',
                  'sensitive': true,
                },
              ],
            },
          ],
          initialNotes: const [
            {
              'id': 'note-1',
              'title': 'Trip checklist',
              'preview': 'Pack bags',
              'updated': 'Now',
              'pinned': false,
              'tags': ['trip'],
              'delta': [
                {'insert': 'Pack bags\n'},
              ],
            },
          ],
          initialCustomTypeDefinitions: const [],
          languageMode: 'en',
          onLanguageModeChanged: (_) {},
          biometricEnabled: false,
          onBiometricChanged: (_) {},
          onPersistVaultData:
              ({
                required items,
                required notes,
                required customTypeDefinitions,
              }) async {},
          onRotateMasterPassword:
              ({required currentPassword, required newPassword}) async {},
          onRotateRecoveryPhrase:
              ({
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
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.grid_view_outlined));
    await tester.pumpAndSettle();

    await tester.longPress(find.text('Email'));
    await tester.pumpAndSettle();

    expect(find.text('Cancel'), findsOneWidget);
    expect(find.text('1 Selected'), findsOneWidget);
    expect(find.text('Select all'), findsNothing);
    expect(find.byKey(const ValueKey('selection-action-share')), findsOneWidget);
    expect(find.byKey(const ValueKey('selection-action-move')), findsOneWidget);
    expect(find.byKey(const ValueKey('selection-action-lock')), findsOneWidget);
    expect(find.byKey(const ValueKey('selection-action-delete')), findsOneWidget);
    expect(find.byKey(const ValueKey('selection-action-more')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('selection-action-delete')));
    await tester.pumpAndSettle();
    expect(find.text('Move to Trash?'), findsOneWidget);
    expect(find.textContaining('items will be moved to trash'), findsOneWidget);
    await tester.tap(find.text('Move to Trash'));
    await tester.pumpAndSettle();
    expect(find.text('Email'), findsNothing);
    expect(find.textContaining('items moved to trash'), findsOneWidget);
    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(find.text('Email'), findsOneWidget);

    await tester.longPress(find.text('Email'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('selection-action-more')));
    await tester.pumpAndSettle();
    expect(find.text('Add to Favorites'), findsOneWidget);
    await tester.tap(find.text('Add to Favorites'));
    await tester.pumpAndSettle();
    expect(find.textContaining('added to favorites'), findsOneWidget);
    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(find.text('Email'), findsOneWidget);
  });

  testWidgets('new item follows category -> details -> success flow', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: VaultAppShell(
          recoveryWords: const [
            'anchor',
            'apple',
            'arrow',
            'atlas',
            'beacon',
            'breeze',
            'canyon',
            'cedar',
            'cobalt',
            'ember',
            'harbor',
            'willow',
          ],
          initialItems: const [],
          initialNotes: const [],
          initialCustomTypeDefinitions: const [],
          languageMode: 'en',
          onLanguageModeChanged: (_) {},
          biometricEnabled: false,
          onBiometricChanged: (_) {},
          onPersistVaultData:
              ({
                required items,
                required notes,
                required customTypeDefinitions,
              }) async {},
          onRotateMasterPassword:
              ({required currentPassword, required newPassword}) async {},
          onRotateRecoveryPhrase:
              ({
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
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.add).first);
    await tester.pumpAndSettle();

    expect(find.text('New Item'), findsOneWidget);
    expect(find.text('Login'), findsOneWidget);

    await tester.tap(find.text('Login').first);
    await tester.pumpAndSettle();

    expect(find.text('New Login'), findsOneWidget);
    expect(find.text('Type'), findsNothing);

    await tester.enterText(
      find.widgetWithText(TextField, 'Title'),
      'Home Wi-Fi Password',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.text('Entry saved'), findsOneWidget);
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.grid_view_outlined));
    await tester.pumpAndSettle();
    expect(find.text('Home Wi-Fi Password'), findsOneWidget);
  });

  testWidgets('notes list preview shows rich numbered list markers', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: VaultAppShell(
          recoveryWords: const [
            'anchor',
            'apple',
            'arrow',
            'atlas',
            'beacon',
            'breeze',
            'canyon',
            'cedar',
            'cobalt',
            'ember',
            'harbor',
            'willow',
          ],
          initialItems: const [],
          initialNotes: const [
            {
              'id': 'note-rich-1',
              'title': 'Rich preview',
              'preview': 'fallback preview',
              'updated': 'Now',
              'pinned': false,
              'tags': ['demo'],
              'delta': [
                {'insert': 'Buy milk'},
                {
                  'insert': '\n',
                  'attributes': {'list': 'ordered'},
                },
                {'insert': 'Call mom'},
                {
                  'insert': '\n',
                  'attributes': {'list': 'ordered'},
                },
              ],
            },
          ],
          initialCustomTypeDefinitions: const [],
          languageMode: 'en',
          onLanguageModeChanged: (_) {},
          biometricEnabled: false,
          onBiometricChanged: (_) {},
          onPersistVaultData:
              ({
                required items,
                required notes,
                required customTypeDefinitions,
              }) async {},
          onRotateMasterPassword:
              ({required currentPassword, required newPassword}) async {},
          onRotateRecoveryPhrase:
              ({
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
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Notes'));
    await tester.pumpAndSettle();

    expect(find.textContaining('1. Buy milk'), findsOneWidget);
    expect(find.textContaining('2. Call mom'), findsOneWidget);
  });

  testWidgets('sharing note copies rich-text formatted content', (
    tester,
  ) async {
    String? copiedText;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'Clipboard.setData') {
            copiedText = (call.arguments as Map<dynamic, dynamic>)['text']
                ?.toString();
          }
          return null;
        });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null);
    });

    await tester.pumpWidget(
      MaterialApp(
        home: VaultAppShell(
          recoveryWords: const [
            'anchor',
            'apple',
            'arrow',
            'atlas',
            'beacon',
            'breeze',
            'canyon',
            'cedar',
            'cobalt',
            'ember',
            'harbor',
            'willow',
          ],
          initialItems: const [],
          initialNotes: const [
            {
              'id': 'note-share-1',
              'title': 'Share me',
              'preview': 'fallback preview',
              'updated': 'Now',
              'pinned': false,
              'tags': ['demo'],
              'delta': [
                {'insert': 'Buy milk'},
                {
                  'insert': '\n',
                  'attributes': {'list': 'ordered'},
                },
                {
                  'insert': 'Important',
                  'attributes': {'bold': true},
                },
                {'insert': ' task'},
                {
                  'insert': '\n',
                  'attributes': {'list': 'bullet'},
                },
              ],
            },
          ],
          initialCustomTypeDefinitions: const [],
          languageMode: 'en',
          onLanguageModeChanged: (_) {},
          biometricEnabled: false,
          onBiometricChanged: (_) {},
          onPersistVaultData:
              ({
                required items,
                required notes,
                required customTypeDefinitions,
              }) async {},
          onRotateMasterPassword:
              ({required currentPassword, required newPassword}) async {},
          onRotateRecoveryPhrase:
              ({
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
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Notes'));
    await tester.pumpAndSettle();
    await tester.longPress(find.text('Share me'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('note-action-share')));
    await tester.pumpAndSettle();

    final shared = copiedText ?? '';
    expect(shared, contains('Share me'));
    expect(shared, contains('1. Buy milk'));
    expect(shared, contains('• **Important** task'));
  });

  testWidgets('note quick actions show plain and encrypted share options', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: VaultAppShell(
          recoveryWords: const [
            'anchor',
            'apple',
            'arrow',
            'atlas',
            'beacon',
            'breeze',
            'canyon',
            'cedar',
            'cobalt',
            'ember',
            'harbor',
            'willow',
          ],
          initialItems: const [],
          initialNotes: const [
            {
              'id': 'note-share-menu-1',
              'title': 'Share options',
              'preview': 'preview',
              'updated': 'Now',
              'pinned': false,
              'tags': ['demo'],
              'delta': [
                {'insert': 'Body\n'},
              ],
            },
          ],
          initialCustomTypeDefinitions: const [],
          languageMode: 'en',
          onLanguageModeChanged: (_) {},
          biometricEnabled: false,
          onBiometricChanged: (_) {},
          onPersistVaultData:
              ({
                required items,
                required notes,
                required customTypeDefinitions,
              }) async {},
          onRotateMasterPassword:
              ({required currentPassword, required newPassword}) async {},
          onRotateRecoveryPhrase:
              ({
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
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Notes'));
    await tester.pumpAndSettle();
    await tester.longPress(find.text('Share options'));
    await tester.pumpAndSettle();

    expect(find.text('Share plain text'), findsOneWidget);
    expect(find.text('Share encrypted file'), findsOneWidget);
    expect(find.text('Export encrypted file'), findsOneWidget);
  });

  testWidgets('settings shows encrypted secret import entry point', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: VaultAppShell(
          recoveryWords: const [
            'anchor',
            'apple',
            'arrow',
            'atlas',
            'beacon',
            'breeze',
            'canyon',
            'cedar',
            'cobalt',
            'ember',
            'harbor',
            'willow',
          ],
          initialItems: const [],
          initialNotes: const [],
          initialCustomTypeDefinitions: const [],
          languageMode: 'en',
          onLanguageModeChanged: (_) {},
          biometricEnabled: false,
          onBiometricChanged: (_) {},
          onPersistVaultData:
              ({
                required items,
                required notes,
                required customTypeDefinitions,
              }) async {},
          onRotateMasterPassword:
              ({required currentPassword, required newPassword}) async {},
          onRotateRecoveryPhrase:
              ({
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
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('settings-import-encrypted-secret')),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(
      find.byKey(const ValueKey('settings-import-encrypted-secret')),
      findsOneWidget,
    );
  });

  testWidgets('biometric setting uses slider switch and triggers callback', (
    tester,
  ) async {
    bool? changedTo;
    await tester.pumpWidget(
      MaterialApp(
        home: VaultAppShell(
          recoveryWords: const [
            'anchor',
            'apple',
            'arrow',
            'atlas',
            'beacon',
            'breeze',
            'canyon',
            'cedar',
            'cobalt',
            'ember',
            'harbor',
            'willow',
          ],
          initialItems: const [],
          initialNotes: const [],
          initialCustomTypeDefinitions: const [],
          languageMode: 'en',
          onLanguageModeChanged: (_) {},
          biometricEnabled: false,
          onBiometricChanged: (enabled) => changedTo = enabled,
          onPersistVaultData:
              ({
                required items,
                required notes,
                required customTypeDefinitions,
              }) async {},
          onRotateMasterPassword:
              ({required currentPassword, required newPassword}) async {},
          onRotateRecoveryPhrase:
              ({
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
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();

    final biometricsSwitch = find.byKey(
      const ValueKey('settings-biometrics-switch'),
    );
    expect(biometricsSwitch, findsOneWidget);

    await tester.tap(
      find.descendant(of: biometricsSwitch, matching: find.byType(Switch)),
    );
    await tester.pumpAndSettle();

    expect(changedTo, isTrue);
  });

  testWidgets('active vault name is visible in vault and settings tabs', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: VaultAppShell(
          activeVaultName: 'family-vault.nija',
          recoveryWords: const [
            'anchor',
            'apple',
            'arrow',
            'atlas',
            'beacon',
            'breeze',
            'canyon',
            'cedar',
            'cobalt',
            'ember',
            'harbor',
            'willow',
          ],
          initialItems: const [],
          initialNotes: const [],
          initialCustomTypeDefinitions: const [],
          languageMode: 'en',
          onLanguageModeChanged: (_) {},
          biometricEnabled: false,
          onBiometricChanged: (_) {},
          onPersistVaultData:
              ({
                required items,
                required notes,
                required customTypeDefinitions,
              }) async {},
          onRotateMasterPassword:
              ({required currentPassword, required newPassword}) async {},
          onRotateRecoveryPhrase:
              ({
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
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('family-vault.nija'), findsOneWidget);
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    expect(find.text('family-vault.nija'), findsOneWidget);
  });
}

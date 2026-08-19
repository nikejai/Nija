import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nija/app/theme/app_theme.dart';
import 'package:nija/core/localization/app_strings.dart';
import 'package:nija/features/vault/application/vault_home_demo_data.dart';
import 'package:nija/features/vault/presentation/add_vault_item_screen.dart';
import 'package:nija/features/vault/presentation/vault_app_shell.dart';
import 'package:nija/features/vault/presentation/widgets/vault_entry_list.dart';
import 'package:nija/infrastructure/adapters/secret_share_model.dart';
import 'package:nija/infrastructure/adapters/secret_share_portability_base.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  Future<void> openCategoriesSettings(WidgetTester tester) async {
    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pumpAndSettle();
    final categoriesRow = find.byKey(const ValueKey('settings-categories-row'));
    await tester.scrollUntilVisible(categoriesRow, 200);
    await Scrollable.ensureVisible(
      tester.element(categoriesRow),
      alignment: 0.2,
    );
    await tester.pumpAndSettle();
    await tester.tap(categoriesRow);
    await tester.pumpAndSettle();
  }

  Future<void> pumpUntilFound(
    WidgetTester tester,
    Finder finder, {
    int attempts = 40,
  }) async {
    for (var i = 0; i < attempts; i++) {
      await tester.pump(const Duration(milliseconds: 50));
      if (finder.evaluate().isNotEmpty) return;
    }
    fail('Timed out waiting for $finder');
  }

  Future<void> tapAllItemsTab(WidgetTester tester) async {
    final sidebar = find.byKey(const ValueKey('sidebar-nav-AI'));
    if (sidebar.evaluate().isNotEmpty) {
      await tester.tap(sidebar);
    } else {
      await tester.tap(find.byIcon(Icons.grid_view_outlined));
    }
    await tester.pumpAndSettle();
  }

  testWidgets('new item category list uses themed surfaces in dark mode', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        themeMode: ThemeMode.dark,
        home: const NewItemCategoryScreen(customTypeDefinitions: []),
      ),
    );

    final categoryTile = tester.widget<Material>(
      find.byKey(const ValueKey('new-item-category-item-Login')),
    );

    expect(categoryTile.color, AppTheme.dark().colorScheme.surface);
  });

  testWidgets('wide new item category list is bounded', (tester) async {
    tester.view.physicalSize = const Size(2048, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(home: NewItemCategoryScreen(customTypeDefinitions: [])),
    );

    expect(
      tester
          .getSize(find.byKey(const ValueKey('new-item-category-shell')))
          .width,
      lessThanOrEqualTo(680),
    );
    expect(
      tester
          .getSize(find.byKey(const ValueKey('new-item-category-item-Login')))
          .width,
      lessThanOrEqualTo(648),
    );
  });

  testWidgets('wide saved confirmation uses a constrained dialog', (
    tester,
  ) async {
    AppStrings.setLanguageCode('en');
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    Object? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () async {
              result = await Navigator.of(context).push<Object?>(
                MaterialPageRoute(
                  builder: (_) => NewItemCategoryScreen(
                    customTypeDefinitions: const [],
                    onCreateNote: () async => const {
                      'id': 'note-1',
                      'type': 'Notes',
                      'title': 'Recovery Phrase',
                    },
                  ),
                ),
              );
            },
            child: const Text('Open'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Notes'));
    await tester.pumpAndSettle();

    final dialog = find.byType(Dialog);
    expect(dialog, findsOneWidget);
    expect(find.text('Entry saved'), findsOneWidget);
    expect(
      tester.getSize(find.byKey(const ValueKey('saved-success-content'))).width,
      lessThanOrEqualTo(460),
    );

    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();

    expect(result, isA<Map<String, dynamic>>());
  });

  testWidgets('wide item editor keeps the mobile form at a readable width', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 820);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: AddVaultItemScreen(fixedType: 'Login', customTypeDefinitions: []),
      ),
    );

    expect(
      tester.getSize(find.byType(Card).first).width,
      lessThanOrEqualTo(860),
    );
    expect(find.text('Save'), findsOneWidget);
  });

  testWidgets('custom password-only item does not expose value in subtitle', (
    tester,
  ) async {
    Map<String, dynamic>? savedItem;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () async {
              savedItem = await Navigator.of(context)
                  .push<Map<String, dynamic>>(
                    MaterialPageRoute(
                      builder: (_) => const AddVaultItemScreen(
                        fixedType: 'Door Code',
                        customTypeDefinitions: [
                          {
                            'name': 'Door Code',
                            'fields': [
                              {'key': 'Code', 'valueType': 'password'},
                            ],
                          },
                        ],
                      ),
                    ),
                  );
            },
            child: const Text('Open'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Title'), 'Garage');
    await tester.enterText(find.widgetWithText(TextField, 'Code'), '123456');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(savedItem?['subtitle'], isEmpty);
    expect(savedItem.toString(), isNot(contains("'subtitle': '123456'")));
    final fields = savedItem?['fields'] as List<dynamic>;
    expect(fields.single, containsPair('sensitive', true));
  });

  testWidgets('vault item list hides stored subtitle when it is sensitive', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: VaultEntryList(
          rows: const [
            {
              'kind': 'item',
              'entry': {
                'id': 'item-1',
                'type': 'Custom',
                'title': 'Server',
                'subtitle': 'secret-first',
                'updated': 'Now',
                'fields': [
                  {
                    'label': 'Password',
                    'value': 'secret-first',
                    'sensitive': true,
                  },
                  {
                    'label': 'URL',
                    'value': 'admin.example.com',
                    'sensitive': false,
                  },
                ],
              },
            },
          ],
          adapters: const [VaultItemListEntryAdapter()],
          keyForRow: (row) =>
              (row['entry'] as Map<String, dynamic>)['id'].toString(),
          onTap: (_) {},
        ),
      ),
    );

    expect(find.text('secret-first'), findsNothing);
    expect(find.text('admin.example.com'), findsOneWidget);
  });

  testWidgets('dashboard filter only shows present categories', (tester) async {
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
          ],
          initialNotes: const [],
          initialCustomTypeDefinitions: const [
            {
              'name': 'Vehicle',
              'fields': [
                {'key': 'Plate number', 'valueType': 'text'},
              ],
            },
          ],
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

    await tester.tap(find.byKey(const ValueKey('dashboard-filter-selector')));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(FilterChip, 'Login'), findsOneWidget);
    expect(find.widgetWithText(FilterChip, 'Card'), findsNothing);
    expect(find.widgetWithText(FilterChip, 'Vehicle'), findsNothing);
    expect(find.widgetWithText(FilterChip, 'Notes'), findsOneWidget);
  });

  testWidgets('identity detail shows dynamic ID photos', (tester) async {
    const onePixelPng =
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+/p9sAAAAASUVORK5CYII=';

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
              'id': 'identity-1',
              'type': 'Identity',
              'title': 'Passport',
              'subtitle': 'Ada Lovelace',
              'updated': 'Now',
              'fields': [
                {'label': 'Title', 'value': 'Passport'},
                {'label': 'Full name', 'value': 'Ada Lovelace'},
                {
                  'label': 'Document number',
                  'value': 'P1234567',
                  'sensitive': true,
                },
                {'label': 'Country', 'value': ''},
                {'label': 'Expiry', 'value': ' '},
              ],
              'idPhotos': [
                {
                  'name': 'front.png',
                  'sizeBytes': 68,
                  'bytesBase64': onePixelPng,
                },
                {
                  'name': 'back.png',
                  'sizeBytes': 68,
                  'bytesBase64': onePixelPng,
                },
              ],
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
    await tester.pumpAndSettle();

    await tapAllItemsTab(tester);
    await tester.tap(find.text('Passport'));
    await tester.pumpAndSettle();

    expect(find.text('Copy document number'), findsOneWidget);
    expect(find.text('Copy Password'), findsNothing);
    expect(find.text('TITLE'), findsNothing);
    expect(find.text('COUNTRY'), findsNothing);
    expect(find.text('EXPIRY'), findsNothing);
    expect(find.text('FULL NAME'), findsOneWidget);
    expect(find.text('DOCUMENT NUMBER'), findsOneWidget);
    expect(find.text('ID photos'), findsOneWidget);
    expect(find.text('front.png'), findsOneWidget);
    expect(find.text('back.png'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('identity-photo-row-0')));
    await tester.pumpAndSettle();
    expect(find.text('Choose photo'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('identity-photo-picker-0')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('identity-photo-picker-0')));
    await tester.pumpAndSettle();
    expect(find.byType(InteractiveViewer), findsOneWidget);
    expect(find.widgetWithText(AppBar, 'front.png'), findsOneWidget);
  });

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
            {
              'id': 'item-1',
              'type': 'Bank Account',
              'title': 'Bank',
              'updated': 'Now',
              'fields': [],
            },
            {
              'id': 'item-2',
              'type': 'Passport',
              'title': 'Passport',
              'updated': 'Now',
              'fields': [],
            },
            {
              'id': 'item-3',
              'type': 'Password',
              'title': 'Password',
              'updated': 'Now',
              'fields': [],
            },
            {
              'id': 'item-4',
              'type': 'Card',
              'title': 'Card',
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
    expect(find.text('All Items'), findsAtLeastNWidgets(1));
    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('Recent'), findsOneWidget);
    expect(find.text('View all'), findsOneWidget);
  });

  testWidgets('wide vault shell uses rail/sidebar wireframe', (tester) async {
    tester.view.physicalSize = const Size(1280, 820);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: VaultAppShell(
          activeVaultName: 'personal.nija',
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
            {
              'id': 'item-1',
              'type': 'Bank Account',
              'title': 'Bank',
              'updated': 'Now',
              'fields': [],
            },
            {
              'id': 'item-2',
              'type': 'Passport',
              'title': 'Passport',
              'updated': 'Now',
              'fields': [],
            },
            {
              'id': 'item-3',
              'type': 'Password',
              'title': 'Password',
              'updated': 'Now',
              'fields': [],
            },
            {
              'id': 'item-4',
              'type': 'Card',
              'title': 'Card',
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
    await tester.pumpAndSettle();

    expect(find.text('private archive'), findsOneWidget);
    expect(find.text('Active vault'), findsOneWidget);
    expect(find.text('personal.nija'), findsWidgets);
    expect(find.text('Lock vault'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('desktop-dashboard-stats')),
      findsOneWidget,
    );
    expect(find.text('Total Items'), findsOneWidget);
    expect(find.text('Logins'), findsOneWidget);
    expect(find.text('Card'), findsWidgets);
    expect(find.text('Quick Actions'), findsOneWidget);
    expect(find.text('Recent Items'), findsOneWidget);

    await tapAllItemsTab(tester);

    expect(find.byKey(const ValueKey('wide-all-items-index')), findsOneWidget);
    expect(find.text('NAME'), findsOneWidget);
    expect(find.text('TYPE'), findsOneWidget);
    expect(find.text('FOLDER'), findsOneWidget);
    expect(find.text('UPDATED'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.tune));
    await tester.pumpAndSettle();
    expect(find.byType(Dialog), findsOneWidget);
    expect(find.text('Filters'), findsOneWidget);
  });

  testWidgets('foldable tablet portrait uses expanded vault shell', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(673, 841);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: VaultAppShell(
          activeVaultName: 'tablet.nija',
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
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('sidebar-nav-HM')), findsOneWidget);
    expect(find.text('Active vault'), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);

    await tapAllItemsTab(tester);
    expect(find.byKey(const ValueKey('wide-all-items-index')), findsOneWidget);
  });

  testWidgets('wide homepage offers optional demo dashboard preview', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 820);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    var importCalls = 0;
    var lockCalls = 0;
    var switchCalls = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: VaultAppShell(
          activeVaultName: 'empty.nija',
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
          onImportVault: () async => importCalls++,
          onBackupToCloud: () async {},
          onRestoreFromCloud: () async {},
          onReadCloudBackupAccount: () async => null,
          onChangeCloudBackupAccount: () async => false,
          onLockNow: () => lockCalls++,
          onSwitchVault: () => switchCalls++,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Good '), findsOneWidget);
    expect(find.text('View demo preview'), findsOneWidget);
    expect(find.text('GitHub'), findsNothing);
    expect(
      find.byKey(const ValueKey('desktop-dashboard-stats')),
      findsOneWidget,
    );
    expect(find.text('Total Items'), findsOneWidget);
    expect(find.text('Folders'), findsWidgets);
    expect(find.text('Notes'), findsWidgets);
    expect(find.text('Recovery Phrase'), findsOneWidget);
    expect(find.text('Quick Actions'), findsOneWidget);
    expect(find.text('Import'), findsOneWidget);
    expect(find.text('Switch Vault'), findsWidgets);
    expect(find.text('NIJA VAULT'), findsOneWidget);

    await tester.tap(find.text('View demo preview'));
    await tester.pumpAndSettle();

    expect(
      find.text('Viewing sample data. Your vault has not been changed.'),
      findsOneWidget,
    );
    expect(find.text('Exit demo'), findsOneWidget);
    expect(find.text('Logins'), findsOneWidget);
    expect(find.text('Identities'), findsOneWidget);
    expect(find.text('Documents'), findsWidgets);
    expect(find.text('GitHub'), findsOneWidget);

    await tester.tap(find.text('Exit demo'));
    await tester.pumpAndSettle();

    expect(find.text('GitHub'), findsNothing);
    expect(find.text('View demo preview'), findsOneWidget);
    expect(find.text('Quick Actions'), findsOneWidget);
    expect(find.text('Import'), findsOneWidget);
    expect(find.text('Switch Vault'), findsWidgets);
    expect(find.text('NIJA VAULT'), findsOneWidget);

    await tester.tap(find.text('Import'));
    await tester.pumpAndSettle();
    expect(importCalls, 1);

    await tester.tap(find.text('Switch vault').last);
    await tester.pumpAndSettle();
    expect(switchCalls, 1);
    expect(lockCalls, 0);
  });

  testWidgets('demo preview does not replace real all-items data', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 820);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: VaultAppShell(
          activeVaultName: 'empty.nija',
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

    await tester.tap(find.text('View demo preview'));
    await tester.pumpAndSettle();
    expect(find.text('GitHub'), findsOneWidget);

    await tester.tap(find.text('All Items').first);
    await tester.pumpAndSettle();

    expect(find.text('GitHub'), findsNothing);
    expect(find.text('Demo · sample data'), findsNothing);
    expect(find.text('Recovery Phrase'), findsOneWidget);
  });

  testWidgets('explore demo session shows sample data and opens item details', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 820);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    var exitCalls = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: VaultAppShell(
          activeVaultName: VaultHomeDemoData.vaultName,
          isExploreDemoSession: true,
          onExitExploreDemo: () => exitCalls++,
          cloudBackupFeatureAvailableOverride: false,
          debugInternalsFeatureAvailableOverride: false,
          recoveryWords: VaultHomeDemoData.recoveryWords,
          initialItems: VaultHomeDemoData.cloneItems(),
          initialNotes: VaultHomeDemoData.cloneNotes(),
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
          onLockNow: () => exitCalls++,
          onSwitchVault: () => exitCalls++,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.exploreDemoActiveNotice), findsOneWidget);
    expect(find.text('View demo preview'), findsNothing);
    expect(find.text('Demo · sample data'), findsOneWidget);
    expect(find.text('GitHub'), findsOneWidget);
    expect(find.text('Debug'), findsNothing);

    await tester.tap(find.text('GitHub').first);
    await tester.pumpAndSettle();
    expect(find.text('nitesh@example.com'), findsWidgets);

    await tester.tap(find.byIcon(Icons.arrow_back).first);
    await tester.pumpAndSettle();

    await tester.tap(find.text(AppStrings.exitExploreDemo));
    expect(exitCalls, 1);
  });

  testWidgets('wide homepage does not show demo preview for persisted vault', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: VaultAppShell(
          activeVaultName: 'real.nija',
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
              'id': 'note-recovery-phrase',
              'title': 'Recovery Phrase',
              'preview': 'Recovery phrase (plain copyable text).',
              'updated': 'Now',
              'updatedAt': '2026-08-13T10:00:00Z',
              'pinned': true,
              'tags': ['recovery', 'security'],
              'delta': [
                {'insert': 'anchor apple arrow atlas\n'},
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

    expect(find.text('View demo preview'), findsNothing);
    expect(find.text('GitHub'), findsNothing);
    expect(find.text('Recovery Phrase'), findsOneWidget);
  });

  testWidgets('mobile homepage category tiles route to filtered all items', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: VaultAppShell(
          activeVaultName: 'demo.nija',
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
          initialItems: VaultHomeDemoData.items,
          initialNotes: VaultHomeDemoData.notes,
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

    expect(find.text('Logins'), findsOneWidget);
    expect(find.text('Identities'), findsOneWidget);
    expect(find.text('Documents'), findsOneWidget);
    expect(find.text('Recent'), findsOneWidget);

    await tester.tap(find.text('Logins'));
    await tester.pumpAndSettle();

    expect(find.text('All Items'), findsAtLeastNWidgets(1));
    expect(find.text('GitHub'), findsOneWidget);
    expect(find.text('AWS'), findsOneWidget);
    expect(find.text('Health Insurance'), findsNothing);
  });

  testWidgets('mobile homepage hides categories with no saved entries', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: VaultAppShell(
          activeVaultName: 'personal.nija',
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
              'id': 'login-1',
              'type': 'Login',
              'title': 'Mail',
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
    await tester.pumpAndSettle();

    expect(find.text('Logins'), findsOneWidget);
    expect(find.text('Notes'), findsOneWidget);
    expect(find.text('Identities'), findsNothing);
    expect(find.text('Documents'), findsNothing);
  });

  testWidgets('homepage search clears stale category filters', (tester) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: VaultAppShell(
          activeVaultName: 'demo.nija',
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
          initialItems: VaultHomeDemoData.items,
          initialNotes: VaultHomeDemoData.notes,
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

    await tester.tap(find.text('Logins'));
    await tester.pumpAndSettle();
    expect(find.text('GitHub'), findsOneWidget);
    expect(find.text('AWS'), findsOneWidget);
    expect(find.text('Health Insurance'), findsNothing);

    await tester.tap(find.text('Home'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Passport');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();

    expect(find.text('All Items'), findsAtLeastNWidgets(1));
    expect(find.text('Health Insurance'), findsNothing);
    expect(find.textContaining('Passport'), findsWidgets);
    expect(find.text('GitHub'), findsNothing);
  });

  testWidgets('all items search includes fields folders tags and type', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: VaultAppShell(
          activeVaultName: 'search.nija',
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
              'id': 'item-field',
              'type': 'Login',
              'title': 'Developer Account',
              'subtitle': '',
              'folder': 'Work',
              'updated': 'Now',
              'fields': [
                {'label': 'Website', 'value': 'github.com'},
              ],
            },
            {
              'id': 'item-other',
              'type': 'Card',
              'title': 'Primary Card',
              'subtitle': 'Visa',
              'folder': 'Finance',
              'updated': 'Now',
              'fields': [],
            },
          ],
          initialNotes: const [
            {
              'id': 'note-tagged',
              'title': 'Checklist',
              'preview': 'Private note',
              'updated': 'Now',
              'pinned': false,
              'tags': ['travel'],
              'delta': [
                {'insert': 'Bring passport\n'},
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

    await tester.tap(find.text('All Items').first);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'github.com');
    await tester.pumpAndSettle();
    expect(find.text('Developer Account'), findsOneWidget);
    expect(find.text('Primary Card'), findsNothing);

    await tester.enterText(find.byType(TextField).first, 'travel');
    await tester.pumpAndSettle();
    expect(find.text('Checklist'), findsOneWidget);
    expect(find.text('Developer Account'), findsNothing);
  });

  testWidgets('normal vault items show multiple document attachments', (
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
              'id': 'item-login',
              'type': 'Login',
              'title': 'Work Mail',
              'subtitle': 'mail@example.com',
              'updated': 'Now',
              'fields': [],
              'attachments': [
                {
                  'id': 'attachment-1',
                  'documentFileName': 'contract.txt',
                  'documentExtension': 'txt',
                  'documentSizeBytes': 1024,
                  'documentSection': 'document_attachment_1.manifest.enc',
                  'documentStorage': 'private-section',
                },
                {
                  'id': 'attachment-2',
                  'documentFileName': 'receipt.txt',
                  'documentExtension': 'txt',
                  'documentSizeBytes': 2048,
                  'documentSection': 'document_attachment_2.manifest.enc',
                  'documentStorage': 'private-section',
                },
              ],
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
          onReadVaultDocument: ({required sectionName, onProgress}) async {
            if (sectionName == 'document_attachment_2.manifest.enc') {
              return 'receipt preview\n'.codeUnits;
            }
            return 'contract preview\n'.codeUnits;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('All Items').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Work Mail'));
    await tester.pumpAndSettle();

    expect(find.text('Attachments'), findsOneWidget);
    expect(find.text('Add document'), findsOneWidget);
    expect(find.text('contract.txt'), findsOneWidget);
    expect(find.text('receipt.txt'), findsOneWidget);
    expect(find.textContaining('contract preview'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('attachment-preview-interaction-boundary')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('attachment-preview-fullscreen')),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(const ValueKey('attachment-preview-fullscreen')),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('document-fullscreen-close')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('document-fullscreen-save-copy')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('document-fullscreen-export-encrypted')),
      findsOneWidget,
    );
    expect(find.textContaining('contract preview'), findsWidgets);

    await tester.tap(find.byKey(const ValueKey('document-fullscreen-close')));
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey('item-attachment-attachment-2')),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('receipt preview'), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey('item-attachment-actions-attachment-1')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Open document'), findsOneWidget);
    expect(find.text('Share file'), findsOneWidget);
    expect(find.text('Share encrypted file'), findsOneWidget);
    expect(find.text('Export encrypted file'), findsOneWidget);
    expect(find.text('Save copy'), findsWidgets);
  });

  testWidgets('vault persistence strips runtime attachment picker metadata', (
    tester,
  ) async {
    List<Map<String, dynamic>>? persistedItems;
    final initialItems = [
      {
        'id': 'doc-1',
        'type': 'Documents',
        'title': 'Passport scan',
        'subtitle': 'passport.txt',
        'updated': 'Now',
        'fields': [],
        'documentSection': 'document_doc_1',
        'documentFileName': 'passport.txt',
        'documentExtension': 'txt',
        'documentSizeBytes': 12,
        'attachments': [
          {
            'id': 'attachment-1',
            'documentSection': 'document_attachment_1',
            'documentFileName': 'visa.txt',
            'documentExtension': 'txt',
            'documentSizeBytes': 13,
            '__documentReadStream__': Object(),
          },
        ],
      },
    ];

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
          initialItems: initialItems,
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
              }) async {
                persistedItems = items
                    .map((entry) => Map<String, dynamic>.from(entry))
                    .toList();
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
          onReadVaultDocument: ({required sectionName, onProgress}) async =>
              'document\n'.codeUnits,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tapAllItemsTab(tester);
    await tester.tap(find.byIcon(Icons.more_vert).first);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('document-action-pin')));
    await tester.pumpAndSettle();

    final persistedAttachment =
        (persistedItems!.single['attachments'] as List).single as Map;
    expect(persistedAttachment.containsKey('__documentReadStream__'), isFalse);
  });

  testWidgets('shell init does not auto-persist recovery note', (tester) async {
    var persistCalls = 0;

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
              }) async {
                persistCalls++;
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

    expect(persistCalls, 0);
    expect(find.text('Recovery Phrase'), findsWidgets);
  });

  testWidgets('shell init does not persist when recovery note already seeded', (
    tester,
  ) async {
    var persistCalls = 0;

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
              'id': 'note-recovery-phrase',
              'title': 'Recovery Phrase',
              'preview': 'Recovery phrase (plain copyable text).',
              'updated': 'Now',
              'pinned': true,
              'tags': ['recovery', 'security'],
              'delta': [
                {'insert': 'anchor apple arrow atlas\n'},
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
                persistCalls++;
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

    expect(persistCalls, 0);
    expect(find.text('Recovery Phrase'), findsWidgets);
  });

  testWidgets('vault shows busy overlay while persisting updates', (
    tester,
  ) async {
    final persistCompleter = Completer<void>();
    var persistCalls = 0;

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
              'id': 'doc-1',
              'type': 'Documents',
              'title': 'Passport scan',
              'subtitle': 'passport.txt',
              'updated': 'Now',
              'fields': [],
              'documentSection': 'document_doc_1',
              'documentFileName': 'passport.txt',
              'documentExtension': 'txt',
              'documentSizeBytes': 12,
            },
          ],
          initialNotes: const [
            {
              'id': 'note-recovery-phrase',
              'title': 'Recovery Phrase',
              'preview': 'Recovery phrase (plain copyable text).',
              'updated': 'Now',
              'pinned': true,
              'tags': ['recovery', 'security'],
              'delta': [
                {'insert': 'Recovery phrase\n'},
              ],
              'blocks': [
                {'type': 'heading', 'text': 'Recovery phrase'},
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
              }) {
                persistCalls++;
                return persistCompleter.future;
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
          onReadVaultDocument: ({required sectionName, onProgress}) async =>
              'document\n'.codeUnits,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tapAllItemsTab(tester);
    await tester.tap(find.byIcon(Icons.more_vert).first);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('document-action-pin')));
    await tester.pump();

    expect(find.text('Saving vault updates...'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    persistCompleter.complete();
    await tester.pumpAndSettle();

    expect(find.text('Saving vault updates...'), findsNothing);
  });

  testWidgets(
    'opening an item records lastAccessedAt and updates recent order',
    (tester) async {
      List<Map<String, dynamic>>? persistedItems;
      tester.view.physicalSize = const Size(800, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

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
                'id': 'item-newer',
                'type': 'Login',
                'title': 'Newer item',
                'subtitle': 'newer@example.com',
                'updated': '1d ago',
                'fields': [],
              },
              {
                'id': 'item-older',
                'type': 'Login',
                'title': 'Older item',
                'subtitle': 'older@example.com',
                'updated': '9d ago',
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
                }) async {
                  persistedItems = items
                      .map((entry) => Map<String, dynamic>.from(entry))
                      .toList();
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

      expect(find.text('Older item'), findsOneWidget);

      await tester.tap(find.text('All Items').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Older item'));
      await tester.pumpAndSettle();

      expect(find.text('Last accessed'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();

      final older = persistedItems!.firstWhere(
        (entry) => entry['id'] == 'item-older',
      );
      expect(older['lastAccessedAt'], isNotNull);

      await tester.tap(find.text('Home'));
      await tester.pumpAndSettle();
      expect(find.text('Older item'), findsOneWidget);
      expect(find.text('Newer item'), findsOneWidget);
      expect(find.textContaining('Just now'), findsWidgets);
    },
  );

  testWidgets('custom template manager can create and persist a template', (
    tester,
  ) async {
    List<Map<String, dynamic>>? persistedCustomTypes;

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
              }) async {
                persistedCustomTypes = customTypeDefinitions
                    .map((entry) => Map<String, dynamic>.from(entry))
                    .toList();
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

    await openCategoriesSettings(tester);
    expect(
      find.text('Create reusable item types with your own fields.'),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey('custom-template-add')));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, 'Vehicle');
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Next'));
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Plate number');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save template'));
    await tester.pumpAndSettle();

    expect(find.text('Vehicle'), findsOneWidget);
    expect(find.text('1 fields'), findsOneWidget);

    expect(persistedCustomTypes, isNotNull);
    expect(persistedCustomTypes!.single['name'], 'Vehicle');
  });

  testWidgets('custom template edit page exposes save action', (tester) async {
    List<Map<String, dynamic>>? persistedCustomTypes;

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
          initialCustomTypeDefinitions: const [
            {
              'name': 'Vehicle',
              'description': '',
              'iconKey': 'car',
              'colorKey': 'purple',
              'fields': [
                {'key': 'Plate number', 'valueType': 'text'},
              ],
            },
          ],
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
                persistedCustomTypes = customTypeDefinitions
                    .map((entry) => Map<String, dynamic>.from(entry))
                    .toList();
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

    await openCategoriesSettings(tester);
    await tester.tap(find.byIcon(Icons.edit_outlined));
    await tester.pumpAndSettle();

    expect(find.text('Edit custom template'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('custom-template-fields-save')),
      findsNothing,
    );

    await tester.enterText(find.byType(TextField).first, 'Vehicle Updated');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit fields'));
    await tester.pumpAndSettle();
    expect(find.text('Edit template fields'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('custom-template-fields-save')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('custom-template-fields-save')));
    await tester.pumpAndSettle();

    expect(persistedCustomTypes, isNotNull);
    expect(persistedCustomTypes!.single['name'], 'Vehicle Updated');
  });

  testWidgets('dashboard follows updated custom template details', (
    tester,
  ) async {
    List<Map<String, dynamic>>? persistedItems;

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
              'id': 'item-vehicle',
              'type': 'Vehicle',
              'title': 'Car',
              'subtitle': 'ABC123',
              'updated': 'Now',
              'fields': [],
            },
          ],
          initialNotes: const [],
          initialCustomTypeDefinitions: const [
            {
              'name': 'Vehicle',
              'description': '',
              'iconKey': 'car',
              'colorKey': 'purple',
              'fields': [
                {'key': 'Plate number', 'valueType': 'text'},
              ],
            },
          ],
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
                persistedItems = items
                    .map((entry) => Map<String, dynamic>.from(entry))
                    .toList();
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

    expect(find.text('Vehicle'), findsOneWidget);
    expect(find.byIcon(Icons.directions_car_outlined), findsWidgets);

    await openCategoriesSettings(tester);
    await tester.tap(find.byIcon(Icons.edit_outlined));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Garage');
    await tester.tap(find.text('Add Icon'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Lock'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit fields'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('custom-template-fields-save')));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.shield_outlined));
    await tester.pumpAndSettle();

    expect(find.text('Garage'), findsOneWidget);
    expect(find.text('Vehicle'), findsNothing);
    expect(find.byIcon(Icons.lock_outline), findsWidgets);
    expect(persistedItems, isNotNull);
    expect(persistedItems!.single['type'], 'Garage');
  });

  testWidgets('custom template icon picker shows icon grid', (tester) async {
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

    await openCategoriesSettings(tester);
    await tester.tap(find.byKey(const ValueKey('custom-template-add')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add Icon'));
    await tester.pumpAndSettle();

    expect(find.text('Choose icon'), findsOneWidget);
    expect(find.byType(GridView), findsOneWidget);
    expect(find.text('Lock'), findsOneWidget);

    await tester.tap(find.text('Lock'));
    await tester.pumpAndSettle();
    expect(find.text('Choose icon'), findsNothing);
  });

  testWidgets('custom template category can create a vault item', (
    tester,
  ) async {
    List<Map<String, dynamic>>? persistedItems;

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
          initialCustomTypeDefinitions: const [
            {
              'name': 'Vehicle',
              'description': '',
              'iconKey': 'car',
              'colorKey': 'purple',
              'fields': [
                {'key': 'Plate number', 'valueType': 'text'},
              ],
            },
          ],
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
                persistedItems = items
                    .map((entry) => Map<String, dynamic>.from(entry))
                    .toList();
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

    await tester.tap(find.byIcon(Icons.add).first);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Vehicle');
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.directions_car_outlined), findsOneWidget);
    await tester.tap(find.widgetWithText(ListTile, 'Vehicle'));
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextField, 'Title'), 'Car');
    await tester.enterText(
      find.widgetWithText(TextField, 'Plate number'),
      'ABC123',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();

    expect(persistedItems, isNotNull);
    expect(persistedItems!.single['type'], 'Vehicle');
    expect(persistedItems!.single['title'], 'Car');
  });

  testWidgets(
    'custom template item detail shows template icon and edits item',
    (tester) async {
      List<Map<String, dynamic>>? persistedItems;

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
                'id': 'vehicle-1',
                'type': 'Vehicle',
                'title': 'Car',
                'subtitle': 'ABC123',
                'updated': 'Now',
                'lastAccessedAt': '2026-05-01T00:00:00.000Z',
                'fields': [
                  {
                    'label': 'Plate number',
                    'value': 'ABC123',
                    'sensitive': false,
                  },
                ],
              },
            ],
            initialNotes: const [],
            initialCustomTypeDefinitions: const [
              {
                'name': 'Vehicle',
                'description': '',
                'iconKey': 'car',
                'colorKey': 'orange',
                'fields': [
                  {'key': 'Plate number', 'valueType': 'text'},
                ],
              },
            ],
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
                  persistedItems = items
                      .map((entry) => Map<String, dynamic>.from(entry))
                      .toList();
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

      await tester.tap(find.text('Vehicle'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Car'));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.directions_car_outlined), findsOneWidget);
      await tester.tap(find.byIcon(Icons.edit_outlined));
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextField, 'Title'), 'Truck');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(persistedItems, isNotNull);
      expect(persistedItems!.single['title'], 'Truck');
      expect(persistedItems!.single['lastAccessedAt'], isNotNull);
    },
  );

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

      await tapAllItemsTab(tester);
      expect(find.text('All'), findsWidgets);
      expect(find.text('Card'), findsWidgets);
      await tester.tap(find.text('Card').last);
      await tester.pumpAndSettle();
      expect(find.text('Card'), findsWidgets);

      await tester.tap(find.text('All').last);
      await tester.pumpAndSettle();
      await tapAllItemsTab(tester);
      expect(find.text('work'), findsWidgets);
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

    await tapAllItemsTab(tester);

    await tester.tap(find.byIcon(Icons.more_vert).first);
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
                {'label': 'Password', 'value': 'secret-2', 'sensitive': true},
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

    await tapAllItemsTab(tester);

    await tester.longPress(find.text('Email'));
    await tester.pumpAndSettle();

    expect(find.text('Cancel'), findsOneWidget);
    expect(find.text('1 Selected'), findsOneWidget);
    expect(find.text('Select all'), findsNothing);
    expect(
      find.byKey(const ValueKey('selection-action-favorite')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('selection-action-delete')),
      findsOneWidget,
    );
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
    await tester.tap(find.byKey(const ValueKey('selection-action-favorite')));
    await tester.pumpAndSettle();
    expect(find.textContaining('added to favorites'), findsOneWidget);
    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(find.text('Email'), findsOneWidget);
  });

  testWidgets('new item follows category -> details -> success flow', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

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
    final saveButton = find.widgetWithText(FilledButton, 'Save');
    await tester.scrollUntilVisible(
      saveButton,
      200,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(saveButton);
    await tester.pumpAndSettle();

    expect(find.text('Entry saved'), findsOneWidget);
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();

    await tapAllItemsTab(tester);
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
            {
              'id': 'note-rich-2',
              'title': 'Split attrs preview',
              'preview': 'fallback split preview',
              'updated': 'Now',
              'pinned': false,
              'tags': ['demo'],
              'delta': [
                {
                  'insert': 'First task',
                  'attributes': {'list': 'ordered'},
                },
                {'insert': '\n'},
                {
                  'insert': 'Second task',
                  'attributes': {'list': 'ordered'},
                },
                {'insert': '\n'},
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

    await tapAllItemsTab(tester);

    expect(find.textContaining('1. Buy milk'), findsOneWidget);
    expect(find.textContaining('2. Call mom'), findsOneWidget);
    expect(find.textContaining('1. First task'), findsOneWidget);
    expect(find.textContaining('2. Second task'), findsOneWidget);
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

    await tapAllItemsTab(tester);
    await tester.tap(find.byIcon(Icons.more_vert).first);
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

    await tapAllItemsTab(tester);
    await tester.tap(find.byIcon(Icons.more_vert).first);
    await tester.pumpAndSettle();

    expect(find.text('Share plain text'), findsOneWidget);
    expect(find.text('Share encrypted file'), findsOneWidget);
    expect(find.text('Export encrypted file'), findsOneWidget);
  });

  testWidgets('document preview exposes edit, document list, and save copy', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

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
              'id': 'doc-1',
              'type': 'Documents',
              'title': 'Passport scan',
              'subtitle': 'passport.txt',
              'updated': 'Now',
              'fields': [],
              'documentSection': 'document_doc_1',
              'documentFileName': 'passport.txt',
              'documentExtension': 'txt',
              'documentSizeBytes': 12,
              'attachments': [
                {
                  'id': 'attachment-1',
                  'documentSection': 'document_attachment_1',
                  'documentFileName': 'visa.txt',
                  'documentExtension': 'txt',
                  'documentSizeBytes': 13,
                },
              ],
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
          onReadVaultDocument: ({required sectionName, onProgress}) async =>
              sectionName == 'document_attachment_1'
              ? 'visa document\n'.codeUnits
              : 'passport document\n'.codeUnits,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tapAllItemsTab(tester);
    await tester.tap(find.byIcon(Icons.more_vert).first);
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('document-action-save-copy')),
      findsOneWidget,
    );
    expect(find.text('Save copy'), findsWidgets);

    await tester.tap(find.byKey(const ValueKey('document-action-open')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('document-detail-save-copy')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('document-detail-fullscreen')),
      findsOneWidget,
    );
    expect(find.text('Save copy'), findsOneWidget);
    expect(find.byIcon(Icons.edit_outlined), findsOneWidget);
    expect(find.text('Attachments'), findsNothing);
    expect(find.text('Documents'), findsOneWidget);
    expect(find.text('Add document'), findsOneWidget);
    expect(find.text('passport.txt'), findsOneWidget);
    expect(find.text('visa.txt'), findsOneWidget);

    await tester.tap(find.text('visa.txt'));
    await tester.pumpAndSettle();

    expect(find.textContaining('visa document'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('document-detail-fullscreen')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('document-fullscreen-close')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('document-fullscreen-save-copy')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('document-fullscreen-export-encrypted')),
      findsOneWidget,
    );
    expect(find.textContaining('visa document'), findsWidgets);

    await tester.tap(find.byKey(const ValueKey('document-fullscreen-close')));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.more_horiz));
    await tester.pumpAndSettle();

    expect(find.text('Open document'), findsOneWidget);
    expect(find.text('Share file'), findsOneWidget);
    expect(find.text('Share encrypted file'), findsOneWidget);
    expect(find.text('Export encrypted file'), findsOneWidget);
    expect(find.text('Save copy'), findsWidgets);

    await tester.tapAt(const Offset(20, 20));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.edit_outlined));
    await tester.pumpAndSettle();

    expect(find.text('Edit item'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'Title'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'Description'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'File name'), findsNothing);
    expect(find.widgetWithText(TextField, 'Extension'), findsNothing);
    expect(find.widgetWithText(TextField, 'Size'), findsNothing);
    expect(find.text('passport.txt'), findsOneWidget);
    expect(find.textContaining('Current document'), findsOneWidget);
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

  testWidgets('settings import cancel keeps import row usable', (tester) async {
    final portability = _CancelingSecretSharePortabilityAdapter();
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
          secretSharePortability: portability,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    final importRow = find.byKey(
      const ValueKey('settings-import-encrypted-secret'),
    );
    await tester.scrollUntilVisible(
      importRow,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(importRow);
    await tester.pumpAndSettle();

    expect(portability.importCalls, 1);
    expect(find.text('Import data from a file'), findsOneWidget);
    expect(find.text('Importing data...'), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsNothing);

    await tester.tap(importRow);
    await tester.pumpAndSettle();
    expect(portability.importCalls, 2);
  });

  testWidgets('security encryption settings show sanitized metadata', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

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
          autoLockSeconds: 120,
          onLanguageModeChanged: (_) {},
          biometricEnabled: true,
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
          onReadVaultInternals: () async => {
            'format': 'nija-vault',
            'formatVersion': 2,
            'schemaVersion': 3,
            'storageLayoutVersion': 1,
            'manifestVersion': 1,
            'createdAt': '2026-05-01T00:00:00.000Z',
            'updatedAt': '2026-05-30T00:00:00.000Z',
            'revision': 8,
            'crypto': {
              'guardianProfile': 'owl',
              'kdf': 'Argon2id',
              'kdfMemoryKb': 65536,
              'kdfIterations': 3,
              'kdfParallelism': 2,
              'kdfSaltBytes': 32,
              'recoveryKdfSaltBytes': 32,
              'cipher': 'AES-256-GCM',
              'encryptedRecoveryKeyBytes': 60,
            },
            'encryptedSections': {'payload': 481},
            'workingStore': {
              'root': '/tmp/private-vault',
              'files': {'payload.secret': 481},
            },
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('settings-security-encryption-row')),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('security-encryption-sheet')),
      findsOneWidget,
    );
    expect(find.text('How vault unlock works'), findsOneWidget);
    expect(find.text('Vault crypto metadata'), findsOneWidget);
    expect(find.text('Guardian profile'), findsOneWidget);
    expect(find.text('owl'), findsOneWidget);
    expect(find.text('KDF'), findsOneWidget);
    expect(find.text('Argon2id'), findsOneWidget);
    expect(find.text('Cipher'), findsOneWidget);
    expect(find.text('AES-256-GCM'), findsOneWidget);
    expect(find.text('Recovery key wrapper'), findsOneWidget);
    expect(find.text('Present'), findsOneWidget);
    expect(find.text('Auto-lock'), findsOneWidget);
    expect(find.text('120 sec'), findsWidgets);
    expect(find.text('Change master password'), findsNothing);
    expect(find.text('Manage biometrics'), findsNothing);

    expect(find.text('payload.secret'), findsNothing);
    expect(find.text('/tmp/private-vault'), findsNothing);
    expect(find.text('kdfSaltBytes'), findsNothing);
  });

  testWidgets('debug internals are cached and refreshed explicitly', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(900, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    var readCount = 0;
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
          debugInternalsFeatureAvailableOverride: true,
          onReadVaultInternals: () async {
            readCount++;
            return {
              'format': 'nija-vault',
              'formatVersion': 2,
              'schemaVersion': 3,
              'storageLayoutVersion': 1,
              'manifestVersion': 1,
              'snapshotBytes': 100,
              'workingStoreBytes': 7240,
              'vaultId': 'vault-id',
              'vaultVersionId': 'version-id',
              'revision': readCount,
              'createdAt': '2026-05-01T00:00:00.000Z',
              'updatedAt': '2026-05-30T00:00:00.000Z',
              'lastModifiedByDeviceId': 'device-1',
              'crypto': {'kdf': 'Argon2id', 'cipher': 'AES-256-GCM'},
              'encryptedSections': {
                'items': 42,
                'document_doc.manifest.enc': 100,
                'document_doc_chunk_000000.enc': 200,
                'document_doc_chunk_000001.enc': 50,
              },
              'workingStore': {
                'type': 'memory',
                'root': 'memory://vaults/test',
                'files': {
                  for (var i = 0; i < 120; i++) 'document_doc_chunk_$i.enc': i,
                },
              },
            };
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Debug'), findsNothing);

    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('settings-debug-internals-switch')),
      findsNothing,
    );
    final aboutNijaRow = find.byKey(const ValueKey('settings-about-nija-row'));
    await tester.scrollUntilVisible(
      aboutNijaRow,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    await tester.tap(aboutNijaRow);
    await tester.pump();
    expect(find.textContaining('taps away from debug options.'), findsNothing);

    await tester.tap(aboutNijaRow);
    await tester.pump();
    expect(find.textContaining('taps away from debug options.'), findsNothing);

    await tester.tap(aboutNijaRow);
    await tester.pump();
    expect(find.text('4 taps away from debug options.'), findsOneWidget);

    await tester.tap(aboutNijaRow);
    await tester.pump();
    expect(find.text('4 taps away from debug options.'), findsNothing);
    expect(find.text('3 taps away from debug options.'), findsOneWidget);

    for (var i = 0; i < 3; i++) {
      await tester.tap(aboutNijaRow);
      await tester.pump();
    }
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('settings-debug-internals-switch')),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(const ValueKey('settings-debug-internals-switch')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Debug'), findsOneWidget);

    await tester.tap(find.text('Debug'));
    await pumpUntilFound(tester, find.text('Vault internals'));
    await tester.pumpAndSettle();
    expect(readCount, 1);
    expect(find.text('workingStoreBytes'), findsOneWidget);
    expect(find.text('7240'), findsOneWidget);
    expect(find.text('document manifests'), findsOneWidget);
    expect(find.text('document chunks'), findsOneWidget);
    expect(find.text('document bytes'), findsOneWidget);
    expect(find.text('document doc'), findsOneWidget);
    expect(find.text('document_doc.manifest.enc'), findsNothing);
    expect(find.text('document_doc_chunk_0.enc'), findsNothing);
    expect(
      find.textContaining('more files hidden to keep Debug responsive'),
      findsNothing,
    );

    await tester.tap(find.text('Home'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Debug'));
    await tester.pumpAndSettle();
    expect(readCount, 1);

    await tester.tap(find.byKey(const ValueKey('debug-internals-refresh')));
    await tester.pumpAndSettle();
    expect(readCount, 2);
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

  testWidgets('master password rotation shows password strength', (
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
    await tester.tap(find.text('Master Password'));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('master-password-strength-meter')),
      findsOneWidget,
    );
    expect(find.text('Not started'), findsOneWidget);

    await tester.enterText(find.byType(TextField).at(1), 'short');
    await tester.pumpAndSettle();
    expect(find.text('Weak'), findsOneWidget);

    await tester.enterText(find.byType(TextField).at(1), 'NewStrongPass123!');
    await tester.pumpAndSettle();
    expect(find.text('Strong'), findsOneWidget);
  });

  testWidgets('auto lock setting updates seconds with slider', (tester) async {
    int? changedSeconds;
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
          autoLockSeconds: 300,
          onAutoLockSecondsChanged: (seconds) => changedSeconds = seconds,
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
    await tester.tap(find.byKey(const ValueKey('settings-auto-lock-row')));
    await tester.pumpAndSettle();

    final slider = tester.widget<Slider>(
      find.byKey(const ValueKey('auto-lock-seconds-slider')),
    );
    slider.onChanged!(120);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();

    expect(changedSeconds, 120);
  });

  testWidgets('active vault name is visible in vault and settings tabs', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: VaultAppShell(
          activeVaultName: 'family-vault.nija',
          activeVaultRevision: 12,
          activeVaultVersionId: 'abcdef1234567890',
          activeVaultUpdatedAt: '2026-07-22T12:34:00.000',
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
    expect(find.text('Current version'), findsOneWidget);
    expect(find.text('r12 - abcdef12'), findsOneWidget);
    expect(find.text('Updated 2026-07-22 12:34'), findsOneWidget);
  });

  testWidgets('settings can rename active vault name', (tester) async {
    String? renamedTo;

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
          onRenameVault: (name) async => renamedTo = name,
          onLockNow: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('family-vault.nija'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Vault name'),
      'Personal vault',
    );
    await tester.tap(find.text('Rename'));
    await tester.pumpAndSettle();

    expect(renamedTo, 'Personal vault');
    expect(find.text('Personal vault'), findsOneWidget);
  });

  testWidgets('paid cloud backup shows last backup and backed up version', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'nija_pref_cloud_backup_enabled_v1': true,
      'nija_pref_cloud_backup_last_at_v1': DateTime(
        2026,
        7,
        22,
        9,
        30,
      ).millisecondsSinceEpoch,
      'nija_pref_cloud_backup_revision_v1': 8,
      'nija_pref_cloud_backup_version_id_v1': '1234567890abcdef',
      'nija_pref_cloud_backup_updated_at_v1': '2026-07-22T09:15:00.000',
    });

    await tester.pumpWidget(
      MaterialApp(
        home: VaultAppShell(
          activeVaultRevision: 9,
          activeVaultVersionId: 'fedcba0987654321',
          activeVaultUpdatedAt: '2026-07-22T10:00:00.000',
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
          onReadCloudBackupAccount: () async => 'paid@example.com',
          onChangeCloudBackupAccount: () async => false,
          onLockNow: () {},
          cloudBackupFeatureAvailableOverride: true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();

    expect(find.text('Current version'), findsOneWidget);
    expect(find.text('r9 - fedcba09'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('settings-cloud-backup-last-at')),
      200,
    );
    await tester.pumpAndSettle();
    expect(find.text('Last backup'), findsOneWidget);
    expect(find.text('2026-07-22 09:30'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('settings-cloud-backup-version')),
      200,
    );
    await tester.pumpAndSettle();
    expect(find.text('Backed up version'), findsOneWidget);
    expect(find.text('r8 - 12345678'), findsOneWidget);
    expect(find.text('Vault updated: 2026-07-22 09:15'), findsOneWidget);
  });

  testWidgets('back is blocked while cloud backup is running', (tester) async {
    final backupCompleter = Completer<void>();
    var lockCalls = 0;
    SharedPreferences.setMockInitialValues({
      'nija_pref_cloud_backup_enabled_v1': true,
    });

    await tester.pumpWidget(
      MaterialApp(
        home: VaultAppShell(
          activeVaultRevision: 2,
          activeVaultVersionId: 'abcdef1234567890',
          activeVaultUpdatedAt: '2026-07-22T10:00:00.000',
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
          onBackupToCloud: () => backupCompleter.future,
          onRestoreFromCloud: () async {},
          onReadCloudBackupAccount: () async => 'paid@example.com',
          onChangeCloudBackupAccount: () async => false,
          onLockNow: () => lockCalls++,
          cloudBackupFeatureAvailableOverride: true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    final backupNow = find.byKey(const ValueKey('settings-cloud-backup-now'));
    await tester.scrollUntilVisible(backupNow, 200);
    await tester.pumpAndSettle();

    await tester.tap(backupNow);
    await tester.pump();
    expect(find.text('Cloud backup in progress...'), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pump();

    expect(lockCalls, 0);
    expect(find.text('Settings'), findsOneWidget);
    expect(
      find.text('Please wait for the operation to finish.'),
      findsOneWidget,
    );

    backupCompleter.complete();
    await tester.pumpAndSettle();
    expect(find.text('Cloud backup in progress...'), findsNothing);
  });

  testWidgets('free build shows paid cloud backup gate in settings', (
    tester,
  ) async {
    var cloudAccountReads = 0;
    var backupCalls = 0;
    SharedPreferences.setMockInitialValues({
      'nija_pref_cloud_backup_enabled_v1': true,
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
          onBackupToCloud: () async => backupCalls++,
          onRestoreFromCloud: () async {},
          onReadCloudBackupAccount: () async {
            cloudAccountReads++;
            return 'paid@example.com';
          },
          onChangeCloudBackupAccount: () async => true,
          onLockNow: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(cloudAccountReads, 0);

    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();

    final cloudBackupRow = find.byKey(
      const ValueKey('settings-cloud-backup-switch'),
    );
    await tester.scrollUntilVisible(cloudBackupRow, 200);
    await tester.pumpAndSettle();

    expect(find.text('Cloud Backup'), findsOneWidget);
    expect(find.text('Available in paid version'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('settings-cloud-backup-now')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('settings-cloud-restore-now')),
      findsNothing,
    );

    await tester.tap(cloudBackupRow);
    await tester.pumpAndSettle();
    expect(backupCalls, 0);
    expect(
      find.byKey(const ValueKey('settings-cloud-backup-now')),
      findsNothing,
    );
  });
}

class _CancelingSecretSharePortabilityAdapter
    implements SecretSharePortabilityAdapter {
  int importCalls = 0;

  @override
  Future<bool> exportEncryptedFile({
    required String suggestedName,
    required String content,
  }) async {
    return true;
  }

  @override
  Future<bool> exportPlainFile({
    required String suggestedName,
    required Uint8List bytes,
    required String mimeType,
  }) async {
    return true;
  }

  @override
  Future<ImportedSecretFile?> importEncryptedFile() async {
    importCalls++;
    return null;
  }

  @override
  Future<bool> shareEncryptedFile({
    required String suggestedName,
    required String content,
  }) async {
    return true;
  }
}

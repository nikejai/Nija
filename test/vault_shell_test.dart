import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nija/app/theme/app_theme.dart';
import 'package:nija/features/vault/presentation/add_vault_item_screen.dart';
import 'package:nija/features/vault/presentation/vault_app_shell.dart';
import 'package:nija/features/vault/presentation/widgets/vault_entry_list.dart';

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
          onLongPress: (_) {},
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
                {'label': 'Full name', 'value': 'Ada Lovelace'},
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

    await tester.tap(find.byIcon(Icons.grid_view_outlined));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Passport'));
    await tester.pumpAndSettle();

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

      expect(find.text('No recent items yet.'), findsOneWidget);

      await tester.tap(find.text('All items'));
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
      expect(find.text('Newer item'), findsNothing);
      expect(find.textContaining('Just now'), findsOneWidget);
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

      await tester.tap(find.byIcon(Icons.grid_view_outlined));
      await tester.pumpAndSettle();
      expect(find.text('All'), findsWidgets);
      expect(find.text('Card'), findsWidgets);
      await tester.tap(find.text('Card').last);
      await tester.pumpAndSettle();
      expect(find.text('Card'), findsWidgets);

      await tester.tap(find.text('All').last);
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.grid_view_outlined));
      await tester.pumpAndSettle();
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

    await tester.tap(find.byIcon(Icons.grid_view_outlined));
    await tester.pumpAndSettle();

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

    await tester.tap(find.byIcon(Icons.grid_view_outlined));
    await tester.pumpAndSettle();

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

    await tester.tap(find.byIcon(Icons.grid_view_outlined));
    await tester.pumpAndSettle();

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

    await tester.tap(find.byIcon(Icons.grid_view_outlined));
    await tester.pumpAndSettle();
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

    await tester.tap(find.byIcon(Icons.grid_view_outlined));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.more_vert).first);
    await tester.pumpAndSettle();

    expect(find.text('Share plain text'), findsOneWidget);
    expect(find.text('Share encrypted file'), findsOneWidget);
    expect(find.text('Export encrypted file'), findsOneWidget);
  });

  testWidgets('document preview and actions expose save copy', (tester) async {
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
          onReadVaultDocument: ({required sectionName}) async =>
              'hello world\n'.codeUnits,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.grid_view_outlined));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.more_vert).first);
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('document-action-save-copy')),
      findsOneWidget,
    );
    expect(find.text('Save copy'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('document-action-open')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('document-detail-save-copy')),
      findsOneWidget,
    );
    expect(find.text('Save copy'), findsOneWidget);
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
    expect(find.text('Change master password'), findsOneWidget);

    expect(find.text('payload.secret'), findsNothing);
    expect(find.text('/tmp/private-vault'), findsNothing);
    expect(find.text('kdfSaltBytes'), findsNothing);
  });

  testWidgets('debug internals are cached and refreshed explicitly', (
    tester,
  ) async {
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
          onReadVaultInternals: () async {
            readCount++;
            return {
              'format': 'nija-vault',
              'formatVersion': 2,
              'schemaVersion': 3,
              'storageLayoutVersion': 1,
              'manifestVersion': 1,
              'snapshotBytes': 100,
              'vaultId': 'vault-id',
              'vaultVersionId': 'version-id',
              'revision': readCount,
              'createdAt': '2026-05-01T00:00:00.000Z',
              'updatedAt': '2026-05-30T00:00:00.000Z',
              'lastModifiedByDeviceId': 'device-1',
              'crypto': {'kdf': 'Argon2id', 'cipher': 'AES-256-GCM'},
              'encryptedSections': {'items': 42},
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

    await tester.tap(find.text('Debug'));
    await pumpUntilFound(tester, find.text('Vault internals'));
    await tester.pumpAndSettle();
    expect(readCount, 1);
    final hiddenFilesMessage = find.textContaining(
      'more files hidden to keep Debug responsive',
    );
    await tester.scrollUntilVisible(
      hiddenFilesMessage,
      400,
      scrollable: find.byType(Scrollable).first,
    );
    expect(hiddenFilesMessage, findsOneWidget);

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
}

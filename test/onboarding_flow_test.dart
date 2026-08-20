import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nija/app/theme/app_theme.dart';
import 'package:nija/application/services/default_vault_service.dart';
import 'package:nija/domain/models/vault_reference.dart';
import 'package:nija/core/localization/app_strings.dart';
import 'package:nija/features/onboarding/presentation/onboarding_flow.dart';
import 'package:nija/features/onboarding/presentation/welcome_screen.dart';
import 'package:nija/infrastructure/adapters/crypto_adapter.dart';
import 'package:nija/infrastructure/adapters/in_memory_vault_storage_adapter.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FastTestCryptoAdapter implements CryptoAdapter {
  @override
  Future<List<int>> decrypt({
    required List<int> cipher,
    required List<int> key,
  }) async {
    if (cipher.isEmpty || cipher.first != key.first) {
      throw StateError('Authentication failed.');
    }
    return List<int>.generate(
      cipher.length - 1,
      (index) => cipher[index + 1] ^ key[index % key.length],
    );
  }

  @override
  Future<List<int>> deriveKey({
    required String password,
    required List<int> salt,
    required int memoryKb,
    required int iterations,
    required int parallelism,
  }) async {
    final seed = password.codeUnits.fold<int>(0, (sum, byte) => sum + byte);
    return List<int>.generate(32, (index) => (seed + index) & 0xff);
  }

  @override
  Future<List<int>> encrypt({
    required List<int> plain,
    required List<int> key,
  }) async {
    return <int>[
      key.first,
      ...List<int>.generate(
        plain.length,
        (index) => plain[index] ^ key[index % key.length],
      ),
    ];
  }
}

void main() {
  Future<void> pumpUntilFound(
    WidgetTester tester,
    Finder finder, {
    int attempts = 80,
  }) async {
    for (var i = 0; i < attempts; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      if (finder.evaluate().isNotEmpty) return;
    }
    final texts = tester
        .widgetList<Text>(find.byType(Text))
        .map((widget) => widget.data)
        .whereType<String>()
        .join(' | ');
    fail('Timed out waiting for $finder. Visible text: $texts');
  }

  Future<void> goToUnlockScreen(WidgetTester tester) async {
    final createVault = find.byKey(const ValueKey('entry-create-vault'));
    await tester.ensureVisible(createVault);
    await tester.tap(createVault);
    await pumpUntilFound(tester, find.text('Choose Guardian'));
    await tester.enterText(
      find.widgetWithText(TextField, 'Master password'),
      'StrongPass123',
    );
    await tester.scrollUntilVisible(
      find.widgetWithText(TextField, 'Confirm password'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Confirm password'),
      'StrongPass123',
    );
    await tester.pumpAndSettle();
    final createEncryptedVaultButton = find.byKey(
      const ValueKey('create-encrypted-vault-button'),
    );
    await tester.scrollUntilVisible(
      createEncryptedVaultButton,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(createEncryptedVaultButton);
    await pumpUntilFound(tester, find.text('Recovery phrase'));
    await tester.scrollUntilVisible(
      find.text('I saved my phrase'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('I saved my phrase'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open vault'));
    await tester.pumpAndSettle();
    expect(find.text('Unlock vault'), findsOneWidget);
  }

  testWidgets(
    'first install walkthrough shows pages and continues to welcome',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      tester.view.physicalSize = const Size(430, 932);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          home: OnboardingFlow(
            languageMode: 'en',
            onLanguageModeChanged: (_) {},
            vaultService: DefaultVaultService(
              storageAdapter: InMemoryVaultStorageAdapter(),
              cryptoAdapter: _FastTestCryptoAdapter(),
            ),
            vaultFilePath: 'test.nija',
            firstInstallWalkthroughCompletedOverride: false,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Create or open a vault'), findsOneWidget);
      expect(find.text('Step 1 of 5'), findsOneWidget);

      for (var i = 0; i < 4; i++) {
        await tester.tap(
          find.byKey(const ValueKey('first-install-walkthrough-next')),
        );
        await tester.pumpAndSettle();
      }

      expect(find.text('Back up and recover'), findsOneWidget);
      expect(find.text('Get started'), findsOneWidget);
      await tester.tap(
        find.byKey(const ValueKey('first-install-walkthrough-next')),
      );
      await tester.pumpAndSettle();

      expect(find.text('Create vault'), findsOneWidget);
      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.getBool('nija_first_install_walkthrough_completed_v1'),
        isTrue,
      );
    },
  );

  testWidgets('first install walkthrough uses Nija button theme', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: OnboardingFlow(
          languageMode: 'en',
          onLanguageModeChanged: (_) {},
          vaultService: DefaultVaultService(
            storageAdapter: InMemoryVaultStorageAdapter(),
            cryptoAdapter: _FastTestCryptoAdapter(),
          ),
          vaultFilePath: 'test.nija',
          firstInstallWalkthroughCompletedOverride: false,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final buttonContext = tester.element(
      find.byKey(const ValueKey('first-install-walkthrough-next')),
    );
    final buttonStyle = Theme.of(buttonContext).filledButtonTheme.style;
    final background = buttonStyle?.backgroundColor?.resolve(
      const <WidgetState>{},
    );
    final shape = buttonStyle?.shape?.resolve(const <WidgetState>{});

    expect(background, const Color(0xFF27272A));
    expect(shape, isA<RoundedRectangleBorder>());
    expect(
      (shape! as RoundedRectangleBorder).borderRadius,
      BorderRadius.circular(6),
    );
  });

  testWidgets('first install walkthrough can be skipped', (tester) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: OnboardingFlow(
          languageMode: 'en',
          onLanguageModeChanged: (_) {},
          vaultService: DefaultVaultService(
            storageAdapter: InMemoryVaultStorageAdapter(),
            cryptoAdapter: _FastTestCryptoAdapter(),
          ),
          vaultFilePath: 'test.nija',
          firstInstallWalkthroughCompletedOverride: false,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey('first-install-walkthrough-skip')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Create vault'), findsOneWidget);
    final prefs = await SharedPreferences.getInstance();
    expect(
      prefs.getBool('nija_first_install_walkthrough_completed_v1'),
      isTrue,
    );
  });

  testWidgets('first install walkthrough is hidden after completion override', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: OnboardingFlow(
          languageMode: 'en',
          onLanguageModeChanged: (_) {},
          vaultService: DefaultVaultService(
            storageAdapter: InMemoryVaultStorageAdapter(),
            cryptoAdapter: _FastTestCryptoAdapter(),
          ),
          vaultFilePath: 'test.nija',
          firstInstallWalkthroughCompletedOverride: true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Create or open a vault'), findsNothing);
    expect(find.text('Create vault'), findsOneWidget);
  });

  testWidgets('entry page uses the same grouped vault flow on wide screens', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 760);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: OnboardingFlow(
          languageMode: 'en',
          onLanguageModeChanged: (_) {},
          vaultService: DefaultVaultService(
            storageAdapter: InMemoryVaultStorageAdapter(),
            cryptoAdapter: _FastTestCryptoAdapter(),
          ),
          vaultFilePath: 'test.nija',
          firstInstallWalkthroughCompletedOverride: true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Your private vault'), findsOneWidget);
    expect(find.byKey(const ValueKey('brand-name-nija')), findsWidgets);
    expect(find.text('Nija'), findsWidgets);
    expect(find.text('निज'), findsWidgets);
    expect(find.text('Your digital life, under your control.'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('vault-entry-product-story')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('entry-select-vault')), findsOneWidget);
    expect(find.byKey(const ValueKey('entry-open-vault-file')), findsOneWidget);
    expect(find.byKey(const ValueKey('entry-create-vault')), findsOneWidget);
    expect(find.byKey(const ValueKey('entry-import-data')), findsOneWidget);
    expect(find.byKey(const ValueKey('entry-restore-cloud')), findsOneWidget);
    expect(find.byKey(const ValueKey('entry-theme-toggle')), findsOneWidget);
    expect(
      tester.getSize(find.byKey(const ValueKey('vault-entry-shell'))).width,
      lessThanOrEqualTo(460),
    );
  });

  testWidgets('selecting a known vault uses the full selection page', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 820);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: OnboardingFlow(
          languageMode: 'en',
          onLanguageModeChanged: (_) {},
          vaultService: DefaultVaultService(
            storageAdapter: InMemoryVaultStorageAdapter(),
            cryptoAdapter: _FastTestCryptoAdapter(),
          ),
          vaultFilePath: 'test.nija',
          firstInstallWalkthroughCompletedOverride: true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('entry-select-vault')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('known-vault-selection-screen')),
      findsOneWidget,
    );
    expect(find.text('KNOWN VAULTS'), findsOneWidget);
    expect(find.text('Choose what to open'), findsOneWidget);
    expect(find.text('Select different vault file'), findsOneWidget);
    expect(find.byType(Dialog), findsNothing);
    expect(find.byType(BottomSheet), findsNothing);
  });

  testWidgets('known-vault page renders saved references as cards', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: KnownVaultSelectionScreen(
          knownVaults: const [
            VaultReference(
              id: 'personal-vault.nija',
              label: 'Personal Vault',
              addedAtEpochMs: 100,
              lastOpenedAtEpochMs: 200,
            ),
            VaultReference(
              id: 'family-documents.nija',
              label: 'Family Documents',
              addedAtEpochMs: 90,
              lastOpenedAtEpochMs: 100,
            ),
          ],
          themeMode: ThemeMode.system,
        ),
      ),
    );

    expect(find.text('Personal Vault'), findsOneWidget);
    expect(find.text('Family Documents'), findsOneWidget);
    expect(find.text('Local vault · This device'), findsNWidgets(2));
  });

  testWidgets('known-vault page uses compact reference shell on web', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 820);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: KnownVaultSelectionScreen(
          knownVaults: const [
            VaultReference(
              id: 'personal-vault.nija',
              label: 'Personal Vault',
              addedAtEpochMs: 100,
              lastOpenedAtEpochMs: 200,
            ),
          ],
          themeMode: ThemeMode.system,
        ),
      ),
    );

    final shellSize = tester.getSize(
      find.byKey(const ValueKey('known-vault-shell')),
    );
    final cardSize = tester.getSize(
      find.byKey(const ValueKey('known-vault-card-personal-vault.nija')),
    );

    expect(shellSize.width, lessThanOrEqualTo(460));
    expect(cardSize.height, 86);
    expect(find.text('Choose what to open'), findsOneWidget);
  });

  testWidgets('select different vault file stays on page when picker cancels', (
    tester,
  ) async {
    var importRequested = false;
    await tester.pumpWidget(
      MaterialApp(
        home: KnownVaultSelectionScreen(
          knownVaults: const [
            VaultReference(
              id: 'personal-vault.nija',
              label: 'Personal Vault',
              addedAtEpochMs: 100,
              lastOpenedAtEpochMs: 200,
            ),
          ],
          themeMode: ThemeMode.system,
          onImportFromDevice: () async {
            importRequested = true;
          },
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('known-vault-open-file')));
    await tester.pumpAndSettle();

    expect(importRequested, isTrue);
    expect(
      find.byKey(const ValueKey('known-vault-selection-screen')),
      findsOneWidget,
    );
  });

  testWidgets('known vault selection screen can restore from cloud', (
    tester,
  ) async {
    var cloudRequested = false;
    await tester.pumpWidget(
      MaterialApp(
        home: KnownVaultSelectionScreen(
          knownVaults: const [
            VaultReference(
              id: 'personal-vault.nija',
              label: 'Personal Vault',
              addedAtEpochMs: 100,
              lastOpenedAtEpochMs: 200,
            ),
          ],
          themeMode: ThemeMode.system,
          onImportFromCloud: () async {
            cloudRequested = true;
          },
        ),
      ),
    );

    expect(
      find.byKey(const ValueKey('known-vault-restore-cloud')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('known-vault-restore-cloud')));
    await tester.pumpAndSettle();

    expect(cloudRequested, isTrue);
  });

  testWidgets('welcome recent vaults section opens known vault', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 760);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    VaultReference? selected;
    await tester.pumpWidget(
      MaterialApp(
        home: WelcomeScreen(
          onCreateVault: () {},
          onSelectKnownVault: () {},
          onOpenVaultFile: () {},
          onImportVault: () {},
          onImportVaultFromCloud: () {},
          onExploreDemo: () {},
          recentVaults: const [
            VaultReference(
              id: 'personal-vault.nija',
              label: 'Personal Vault',
              addedAtEpochMs: 100,
              lastOpenedAtEpochMs: 1,
            ),
          ],
          onRecentVaultSelected: (vault) => selected = vault,
        ),
      ),
    );

    expect(
      find.byKey(const ValueKey('entry-recent-vaults-section')),
      findsOneWidget,
    );
    expect(find.text('Personal Vault'), findsOneWidget);
    await tester.ensureVisible(
      find.byKey(const ValueKey('entry-recent-vault-personal-vault.nija')),
    );
    await tester.tap(
      find.byKey(const ValueKey('entry-recent-vault-personal-vault.nija')),
    );
    expect(selected?.id, 'personal-vault.nija');
  });

  testWidgets('mobile entry shows vault actions panel only', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: WelcomeScreen(
          onCreateVault: () {},
          onSelectKnownVault: () {},
          onOpenVaultFile: () {},
          onImportVault: () {},
          onImportVaultFromCloud: () {},
          onExploreDemo: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Your private vault'), findsOneWidget);
    expect(find.byKey(const ValueKey('brand-name-nija')), findsWidgets);
    expect(find.text('Nija'), findsWidgets);
    expect(find.text('निज'), findsWidgets);
    expect(
      find.textContaining('Your data stays local by default'),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('entry-create-vault')), findsOneWidget);
    expect(find.byKey(const ValueKey('entry-explore-demo')), findsOneWidget);
    expect(find.byKey(const ValueKey('entry-restore-cloud')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('vault-entry-product-story')),
      findsNothing,
    );
    expect(find.byKey(const ValueKey('entry-about-nija-toggle')), findsNothing);
  });

  testWidgets('entry actions remain distinct on mobile', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final calls = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        home: WelcomeScreen(
          onCreateVault: () => calls.add('create'),
          onSelectKnownVault: () => calls.add('select'),
          onOpenVaultFile: () => calls.add('open-file'),
          onImportVault: () => calls.add('import'),
          onImportVaultFromCloud: () => calls.add('cloud'),
          onExploreDemo: () => calls.add('explore'),
        ),
      ),
    );

    for (final action in [
      ('entry-select-vault', 'select'),
      ('entry-open-vault-file', 'open-file'),
      ('entry-create-vault', 'create'),
      ('entry-import-data', 'import'),
      ('entry-explore-demo', 'explore'),
      ('entry-restore-cloud', 'cloud'),
    ]) {
      await tester.ensureVisible(find.byKey(ValueKey(action.$1)));
      await tester.tap(find.byKey(ValueKey(action.$1)));
      await tester.pump();
      expect(calls.last, action.$2);
    }
  });

  testWidgets('explore demo opens sample vault without blocking UI', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(1280, 820);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: OnboardingFlow(
          languageMode: 'en',
          onLanguageModeChanged: (_) {},
          vaultService: DefaultVaultService(
            storageAdapter: InMemoryVaultStorageAdapter(),
            cryptoAdapter: _FastTestCryptoAdapter(),
          ),
          vaultFilePath: 'test.nija',
          firstInstallWalkthroughCompletedOverride: true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(
      find.byKey(const ValueKey('entry-explore-demo')),
    );
    await tester.tap(find.byKey(const ValueKey('entry-explore-demo')));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.exploreDemoActiveNotice), findsOneWidget);
    expect(find.text('GitHub'), findsWidgets);
    expect(find.text('Demo · sample data'), findsOneWidget);

    await tester.tap(find.text('GitHub').first);
    await tester.pumpAndSettle();
    expect(find.text('nitesh@example.com'), findsWidgets);
  });

  testWidgets('onboarding moves from welcome to setup', (tester) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: OnboardingFlow(
          languageMode: 'en',
          onLanguageModeChanged: (_) {},
          vaultService: DefaultVaultService(
            storageAdapter: InMemoryVaultStorageAdapter(),
            cryptoAdapter: _FastTestCryptoAdapter(),
          ),
          vaultFilePath: 'test.nija',
        ),
      ),
    );

    expect(find.byKey(const ValueKey('entry-create-vault')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('entry-create-vault')));
    await tester.pumpAndSettle();

    expect(find.text('Choose Guardian'), findsOneWidget);
    expect(
      tester
          .widget<TextField>(
            find.byKey(const ValueKey('setup-vault-name-field')),
          )
          .controller
          ?.text,
      'Nija Vault',
    );
  });

  testWidgets('vault name is optional during onboarding setup', (tester) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: OnboardingFlow(
          languageMode: 'en',
          onLanguageModeChanged: (_) {},
          vaultService: DefaultVaultService(
            storageAdapter: InMemoryVaultStorageAdapter(),
            cryptoAdapter: _FastTestCryptoAdapter(),
          ),
          vaultFilePath: 'test.nija',
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('entry-create-vault')));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('setup-vault-name-field')),
      '',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Master password'),
      'StrongPass123',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Confirm password'),
      'StrongPass123',
    );
    await tester.pumpAndSettle();

    final createEncryptedVaultFinder = find.byKey(
      const ValueKey('create-encrypted-vault-button'),
    );
    await tester.scrollUntilVisible(
      createEncryptedVaultFinder,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    final createEncryptedVaultButton = tester.widget<ElevatedButton>(
      createEncryptedVaultFinder,
    );
    expect(createEncryptedVaultButton.onPressed, isNotNull);
  });

  testWidgets('create encrypted vault moves setup to recovery', (tester) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: OnboardingFlow(
          languageMode: 'en',
          onLanguageModeChanged: (_) {},
          vaultService: DefaultVaultService(
            storageAdapter: InMemoryVaultStorageAdapter(),
            cryptoAdapter: _FastTestCryptoAdapter(),
          ),
          vaultFilePath: 'test.nija',
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('entry-create-vault')));
    await tester.pumpAndSettle();

    expect(find.text('Choose Guardian'), findsOneWidget);

    await tester.enterText(
      find.widgetWithText(TextField, 'Master password'),
      'StrongPass123',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Confirm password'),
      'StrongPass123',
    );
    await tester.pumpAndSettle();

    final createEncryptedVaultButton = find.byKey(
      const ValueKey('create-encrypted-vault-button'),
    );
    await tester.scrollUntilVisible(
      createEncryptedVaultButton,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(createEncryptedVaultButton, findsOneWidget);
    await tester.ensureVisible(createEncryptedVaultButton);
    expect(
      tester.widget<ElevatedButton>(createEncryptedVaultButton).onPressed,
      isNotNull,
    );
    await tester.tap(createEncryptedVaultButton);
    await pumpUntilFound(tester, find.text('Recovery phrase'));

    expect(find.text('Recovery phrase'), findsWidgets);
  });

  testWidgets(
    'unlock screen requires double back to exit and app back opens vault selection',
    (tester) async {
      tester.view.physicalSize = const Size(430, 932);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          home: OnboardingFlow(
            languageMode: 'en',
            onLanguageModeChanged: (_) {},
            vaultService: DefaultVaultService(
              storageAdapter: InMemoryVaultStorageAdapter(),
              cryptoAdapter: _FastTestCryptoAdapter(),
            ),
            vaultFilePath: 'test.nija',
          ),
        ),
      );

      await goToUnlockScreen(tester);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('Press back again to exit.'), findsOneWidget);
      expect(find.text('Unlock vault'), findsOneWidget);

      await tester.enterText(find.byType(TextField).first, 'StrongPass123');
      await tester.tap(find.text('Unlock'));
      await tester.pumpAndSettle();
      expect(find.text('Unlock vault'), findsNothing);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('known-vault-selection-screen')),
        findsOneWidget,
      );

      await tester.tap(
        find.byKey(const ValueKey('known-vault-card-test.nija')),
      );
      await tester.pumpAndSettle();
      expect(find.text('Unlock vault'), findsOneWidget);
    },
  );

  testWidgets('wide unlock screen uses Nija app-themed layout', (tester) async {
    tester.view.physicalSize = const Size(1200, 760);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: OnboardingFlow(
          languageMode: 'en',
          onLanguageModeChanged: (_) {},
          vaultService: DefaultVaultService(
            storageAdapter: InMemoryVaultStorageAdapter(),
            cryptoAdapter: _FastTestCryptoAdapter(),
          ),
          vaultFilePath: 'test.nija',
          firstInstallWalkthroughCompletedOverride: true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('entry-create-vault')));
    await pumpUntilFound(tester, find.text('Choose Guardian'));
    await tester.enterText(
      find.widgetWithText(TextField, 'Master password'),
      'StrongPass123',
    );
    await tester.scrollUntilVisible(
      find.widgetWithText(TextField, 'Confirm password'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Confirm password'),
      'StrongPass123',
    );
    await tester.pumpAndSettle();
    final createEncryptedVaultButton = find.byKey(
      const ValueKey('create-encrypted-vault-button'),
    );
    await tester.scrollUntilVisible(
      createEncryptedVaultButton,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(createEncryptedVaultButton);
    await pumpUntilFound(tester, find.text('Recovery phrase'));
    await tester.scrollUntilVisible(
      find.text('I saved my phrase'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('I saved my phrase'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open vault'));
    await tester.pumpAndSettle();

    expect(find.text('Unlock vault'), findsOneWidget);
    expect(find.text('Protected by Owl Guardian'), findsOneWidget);
    expect(find.byKey(const ValueKey('unlock-password-field')), findsOneWidget);
    expect(find.byKey(const ValueKey('unlock-submit-button')), findsOneWidget);
    expect(find.text('Recover with phrase'), findsOneWidget);
    expect(find.text('Select different vault'), findsOneWidget);
    expect(find.text('Open encrypted secret'), findsOneWidget);
    expect(find.text('Create vault'), findsOneWidget);
    expect(find.text('100% local. 100% yours.'), findsOneWidget);
  });

  testWidgets('wide dashboard switch vault opens known vault selector', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: OnboardingFlow(
          languageMode: 'en',
          onLanguageModeChanged: (_) {},
          vaultService: DefaultVaultService(
            storageAdapter: InMemoryVaultStorageAdapter(),
            cryptoAdapter: _FastTestCryptoAdapter(),
          ),
          vaultFilePath: 'test.nija',
          firstInstallWalkthroughCompletedOverride: true,
        ),
      ),
    );

    await goToUnlockScreen(tester);
    await tester.enterText(find.byType(TextField).first, 'StrongPass123');
    await tester.tap(find.text('Unlock'));
    await pumpUntilFound(tester, find.text('Home'));

    tester.view.physicalSize = const Size(1280, 1000);
    await tester.pumpAndSettle();
    await pumpUntilFound(tester, find.text('Switch vault'));

    await tester.tap(find.text('Switch vault').last);
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('known-vault-selection-screen')),
      findsOneWidget,
    );
    expect(find.text('Choose what to open'), findsOneWidget);
    expect(find.text('Unlock vault'), findsNothing);
  });

  testWidgets('background lock dismisses open sensitive detail routes', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: OnboardingFlow(
          languageMode: 'en',
          onLanguageModeChanged: (_) {},
          autoLockDelay: const Duration(seconds: 10),
          autoLockSeconds: 10,
          vaultService: DefaultVaultService(
            storageAdapter: InMemoryVaultStorageAdapter(),
            cryptoAdapter: _FastTestCryptoAdapter(),
          ),
          vaultFilePath: 'test.nija',
        ),
      ),
    );

    await goToUnlockScreen(tester);
    await tester.enterText(find.byType(TextField).first, 'StrongPass123');
    await tester.tap(find.text('Unlock'));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.grid_view_outlined));
    await tester.pumpAndSettle();
    await pumpUntilFound(tester, find.text('Recovery Phrase'));
    await tester.tap(find.text('Recovery Phrase'));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(AppBar, 'Recovery Phrase'), findsOneWidget);
    expect(find.text('Unlock vault'), findsNothing);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump(const Duration(seconds: 11));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('known-vault-selection-screen')),
      findsOneWidget,
    );
    expect(find.widgetWithText(AppBar, 'Recovery Phrase'), findsNothing);
  });

  testWidgets('unlock screen shows open encrypted secret action', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: OnboardingFlow(
          languageMode: 'en',
          onLanguageModeChanged: (_) {},
          vaultService: DefaultVaultService(
            storageAdapter: InMemoryVaultStorageAdapter(),
            cryptoAdapter: _FastTestCryptoAdapter(),
          ),
          vaultFilePath: 'test.nija',
        ),
      ),
    );

    await goToUnlockScreen(tester);
    expect(find.text('Open encrypted secret'), findsOneWidget);
  });

  testWidgets('pending shared text imports as note after vault unlock', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    var sharedTextConsumed = false;
    const channel = MethodChannel('nija/secret_intent');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          if (call.method == 'consumePendingSharedText' &&
              !sharedTextConsumed) {
            sharedTextConsumed = true;
            return <String, dynamic>{
              'text': 'Remember to rotate keys\nBefore Friday',
              'sourceApplication': 'Test Sender',
              'sourcePackage': 'com.example.sender',
            };
          }
          return null;
        });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    await tester.pumpWidget(
      MaterialApp(
        home: OnboardingFlow(
          languageMode: 'en',
          onLanguageModeChanged: (_) {},
          vaultService: DefaultVaultService(
            storageAdapter: InMemoryVaultStorageAdapter(),
            cryptoAdapter: _FastTestCryptoAdapter(),
          ),
          vaultFilePath: 'test.nija',
        ),
      ),
    );

    await goToUnlockScreen(tester);
    await tester.enterText(find.byType(TextField).first, 'StrongPass123');
    await tester.tap(find.text('Unlock'));
    await pumpUntilFound(
      tester,
      find.textContaining('Shared from Test Sender'),
    );

    expect(sharedTextConsumed, isTrue);
    expect(find.textContaining('Shared from Test Sender'), findsWidgets);

    await tester.tap(find.text('All Items'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Shared from Test Sender'), findsWidgets);
  });

  testWidgets('unlock shows wrong password message for wrong password', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: OnboardingFlow(
          languageMode: 'en',
          onLanguageModeChanged: (_) {},
          vaultService: DefaultVaultService(
            storageAdapter: InMemoryVaultStorageAdapter(),
            cryptoAdapter: _FastTestCryptoAdapter(),
          ),
          vaultFilePath: 'test.nija',
        ),
      ),
    );

    await goToUnlockScreen(tester);
    await tester.enterText(find.byType(TextField).first, 'WrongPass123');
    await tester.tap(find.text('Unlock'));
    await tester.pumpAndSettle();
    expect(find.text('Wrong vault password.'), findsOneWidget);
  });

  testWidgets('unlock screen create vault action opens setup screen', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: OnboardingFlow(
          languageMode: 'en',
          onLanguageModeChanged: (_) {},
          vaultService: DefaultVaultService(
            storageAdapter: InMemoryVaultStorageAdapter(),
            cryptoAdapter: _FastTestCryptoAdapter(),
          ),
          vaultFilePath: 'test.nija',
        ),
      ),
    );

    await goToUnlockScreen(tester);
    await tester.tap(find.text('Create vault').last);
    await tester.pumpAndSettle();
    expect(find.text('Choose Guardian'), findsOneWidget);
  });

  testWidgets(
    'from unlock create vault, back returns to unlock without hanging',
    (tester) async {
      tester.view.physicalSize = const Size(430, 932);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          home: OnboardingFlow(
            languageMode: 'en',
            onLanguageModeChanged: (_) {},
            vaultService: DefaultVaultService(
              storageAdapter: InMemoryVaultStorageAdapter(),
              cryptoAdapter: _FastTestCryptoAdapter(),
            ),
            vaultFilePath: 'test.nija',
          ),
        ),
      );

      await goToUnlockScreen(tester);
      await tester.tap(find.text('Create vault').last);
      await tester.pumpAndSettle();
      expect(find.text('Choose Guardian'), findsOneWidget);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('Unlock vault'), findsOneWidget);
    },
  );

  testWidgets('settings biometric toggle asks for confirmation', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: OnboardingFlow(
          languageMode: 'en',
          onLanguageModeChanged: (_) {},
          vaultService: DefaultVaultService(
            storageAdapter: InMemoryVaultStorageAdapter(),
            cryptoAdapter: _FastTestCryptoAdapter(),
          ),
          vaultFilePath: 'test.nija',
        ),
      ),
    );

    await goToUnlockScreen(tester);
    await tester.enterText(find.byType(TextField).first, 'StrongPass123');
    await tester.tap(find.text('Unlock'));
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

    expect(find.text('Enable biometric unlock?'), findsWidgets);
    await tester.tap(find.text('Not now').last);
    await tester.pumpAndSettle();
  });

  testWidgets('unlock seeds recovery phrase note into durable storage', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final storage = InMemoryVaultStorageAdapter();
    final service = DefaultVaultService(
      storageAdapter: storage,
      cryptoAdapter: _FastTestCryptoAdapter(),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: OnboardingFlow(
          languageMode: 'en',
          onLanguageModeChanged: (_) {},
          vaultService: service,
          vaultFilePath: 'test.nija',
        ),
      ),
    );

    await goToUnlockScreen(tester);
    await tester.enterText(find.byType(TextField).first, 'StrongPass123');
    await tester.tap(find.text('Unlock'));
    await pumpUntilFound(tester, find.text('Home'));

    final reloaded = DefaultVaultService(
      storageAdapter: storage,
      cryptoAdapter: _FastTestCryptoAdapter(),
    );
    await reloaded.unlockVault(
      filePath: 'test.nija',
      password: 'StrongPass123',
    );
    final payload = await reloaded.readVaultPayload(
      filePath: 'test.nija',
      password: 'StrongPass123',
    );

    expect(
      payload.notes.any(
        (note) => note['id']?.toString() == 'note-recovery-phrase',
      ),
      isTrue,
    );
  });

  testWidgets('added items persist across simulated web reload', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final storage = InMemoryVaultStorageAdapter();
    final service = DefaultVaultService(
      storageAdapter: storage,
      cryptoAdapter: _FastTestCryptoAdapter(),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: OnboardingFlow(
          languageMode: 'en',
          onLanguageModeChanged: (_) {},
          vaultService: service,
          vaultFilePath: 'test.nija',
        ),
      ),
    );

    await goToUnlockScreen(tester);
    await tester.enterText(find.byType(TextField).first, 'StrongPass123');
    await tester.tap(find.text('Unlock'));
    await pumpUntilFound(tester, find.text('Add Item').first);

    await tester.tap(find.text('Add Item').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Login'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Title'),
      'Persisted Login',
    );
    await tester.pump();
    await tester.tap(find.text('Save'));
    await pumpUntilFound(tester, find.text('Entry saved'));
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();

    expect(find.text('Persisted Login'), findsWidgets);

    final reloaded = DefaultVaultService(
      storageAdapter: storage,
      cryptoAdapter: _FastTestCryptoAdapter(),
    );
    await reloaded.unlockVault(
      filePath: 'test.nija',
      password: 'StrongPass123',
    );
    final payload = await reloaded.readVaultPayload(
      filePath: 'test.nija',
      password: 'StrongPass123',
    );

    expect(
      payload.items.any(
        (item) => item['title']?.toString() == 'Persisted Login',
      ),
      isTrue,
    );
  });
}

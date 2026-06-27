import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nija/application/services/default_vault_service.dart';
import 'package:nija/features/onboarding/presentation/onboarding_flow.dart';
import 'package:nija/infrastructure/adapters/crypto_adapter.dart';
import 'package:nija/infrastructure/adapters/in_memory_vault_storage_adapter.dart';

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
    await tester.ensureVisible(find.text('Create vault'));
    await tester.tap(find.text('Create vault'));
    await tester.pumpAndSettle();
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
    await tester.tap(createEncryptedVaultButton);
    await pumpUntilFound(tester, find.text('I saved my phrase'));
    await tester.tap(find.text('I saved my phrase'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open vault'));
    await tester.pumpAndSettle();
    expect(find.text('Unlock vault'), findsOneWidget);
  }

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

    expect(find.text('Create vault'), findsOneWidget);
    await tester.ensureVisible(find.text('Create vault'));
    await tester.tap(find.text('Create vault'));
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

    await tester.ensureVisible(find.text('Create vault'));
    await tester.tap(find.text('Create vault'));
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

    await tester.ensureVisible(find.text('Create vault'));
    await tester.tap(find.text('Create vault'));
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
    'unlock screen requires double back to exit and app back returns to unlock',
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
      expect(find.text('Unlock vault'), findsOneWidget);
    },
  );

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

    expect(find.text('Unlock vault'), findsOneWidget);
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
}

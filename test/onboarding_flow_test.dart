import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nija/application/services/default_vault_service.dart';
import 'package:nija/features/onboarding/presentation/onboarding_flow.dart';
import 'package:nija/infrastructure/adapters/in_memory_vault_storage_adapter.dart';
import 'package:nija/infrastructure/adapters/prototype_crypto_adapter.dart';

void main() {
  Future<void> goToUnlockScreen(WidgetTester tester) async {
    await tester.ensureVisible(find.text('Create vault'));
    await tester.tap(find.text('Create vault'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(0), 'StrongPass123');
    await tester.enterText(find.byType(TextField).at(1), 'StrongPass123');
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
    await tester.pumpAndSettle();
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
            cryptoAdapter: PrototypeCryptoAdapter(),
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
            cryptoAdapter: PrototypeCryptoAdapter(),
          ),
          vaultFilePath: 'test.nija',
        ),
      ),
    );

    await tester.ensureVisible(find.text('Create vault'));
    await tester.tap(find.text('Create vault'));
    await tester.pumpAndSettle();

    expect(find.text('Choose Guardian'), findsOneWidget);

    await tester.enterText(find.byType(TextField).at(0), 'StrongPass123');
    await tester.enterText(find.byType(TextField).at(1), 'StrongPass123');
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
    await tester.tap(createEncryptedVaultButton);
    for (var i = 0; i < 60; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      if (find.text('Recovery phrase').evaluate().isNotEmpty) {
        break;
      }
    }

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
              cryptoAdapter: PrototypeCryptoAdapter(),
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
            cryptoAdapter: PrototypeCryptoAdapter(),
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
            cryptoAdapter: PrototypeCryptoAdapter(),
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
            cryptoAdapter: PrototypeCryptoAdapter(),
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
              cryptoAdapter: PrototypeCryptoAdapter(),
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
            cryptoAdapter: PrototypeCryptoAdapter(),
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

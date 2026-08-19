import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:nija/application/services/default_vault_service.dart';
import 'package:nija/core/localization/app_strings.dart';
import 'package:nija/features/onboarding/presentation/onboarding_flow.dart';
import 'package:nija/infrastructure/adapters/in_memory_vault_storage_adapter.dart';
import 'package:nija/infrastructure/adapters/prototype_crypto_adapter.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('lock flow opens themed unlock screen after vault selection', (
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
          vaultFilePath: 'integration-unlock-flow.nija',
          firstInstallWalkthroughCompletedOverride: true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await _createVaultAndOpen(tester);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('known-vault-selection-screen')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('unlock-screen')), findsNothing);

    await tester.tap(
      find.byKey(
        const ValueKey('known-vault-card-integration-unlock-flow.nija'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('unlock-screen')), findsOneWidget);
    expect(find.byKey(const ValueKey('unlock-password-field')), findsOneWidget);
    expect(find.byKey(const ValueKey('unlock-submit-button')), findsOneWidget);
    expect(find.byKey(const ValueKey('unlock-session-button')), findsNothing);
    expect(find.text(AppStrings.unlockVault), findsOneWidget);
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('unlock screen keeps themed layout keys on wide screens', (
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
            cryptoAdapter: PrototypeCryptoAdapter(),
          ),
          vaultFilePath: 'integration-unlock-wide.nija',
          firstInstallWalkthroughCompletedOverride: true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('entry-create-vault')));
    await tester.pumpAndSettle();
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
    await tester.tap(
      find.byKey(const ValueKey('create-encrypted-vault-button')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('I saved my phrase'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open vault'));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('unlock-screen')), findsOneWidget);
    expect(find.byKey(const ValueKey('unlock-theme-toggle')), findsOneWidget);
    expect(find.text(AppStrings.webLocalYours), findsOneWidget);
  });
}

Future<void> _createVaultAndOpen(WidgetTester tester) async {
  await tester.tap(find.text('Create vault'));
  await tester.pumpAndSettle();
  await tester.enterText(find.byType(TextField).at(0), 'StrongPass123');
  await tester.enterText(find.byType(TextField).at(1), 'StrongPass123');
  await tester.pumpAndSettle();
  await tester.scrollUntilVisible(
    find.byKey(const ValueKey('create-encrypted-vault-button')),
    200,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.tap(find.byKey(const ValueKey('create-encrypted-vault-button')));
  await tester.pumpAndSettle();
  await tester.tap(find.text('I saved my phrase'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Open vault'));
  await tester.pumpAndSettle();
  await tester.enterText(
    find.byKey(const ValueKey('unlock-password-field')),
    'StrongPass123',
  );
  await tester.tap(find.byKey(const ValueKey('unlock-submit-button')));
  await tester.pumpAndSettle();
  expect(find.text('Home'), findsWidgets);
}

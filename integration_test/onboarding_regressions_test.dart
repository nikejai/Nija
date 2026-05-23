import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:nija/application/services/default_vault_service.dart';
import 'package:nija/features/onboarding/presentation/onboarding_flow.dart';
import 'package:nija/infrastructure/adapters/in_memory_vault_storage_adapter.dart';
import 'package:nija/infrastructure/adapters/prototype_crypto_adapter.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('unlock shows wrong password message after vault exists', (
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
          vaultFilePath: 'integration-regression.nija',
        ),
      ),
    );

    await _goToUnlockScreen(tester);
    await tester.enterText(find.byType(TextField).first, 'WrongPass123');
    await tester.tap(find.text('Unlock'));
    await tester.pumpAndSettle();
    expect(find.text('Wrong vault password.'), findsOneWidget);
  });
}

Future<void> _goToUnlockScreen(WidgetTester tester) async {
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

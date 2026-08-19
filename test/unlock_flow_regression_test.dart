import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nija/application/services/default_vault_service.dart';
import 'package:nija/core/config/guardian_profiles.dart';
import 'package:nija/core/localization/app_strings.dart';
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
      ...List<int>.generate(plain.length, (index) {
        return plain[index] ^ key[index % key.length];
      }),
    ];
  }

  Future<List<int>> generateRandomBytes(int length) async {
    return List<int>.generate(length, (index) => index & 0xff);
  }
}

void main() {
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
            cryptoAdapter: _FastTestCryptoAdapter(),
          ),
          vaultFilePath: 'integration-unlock-flow.nija',
          firstInstallWalkthroughCompletedOverride: true,
        ),
      ),
    );

    await _goToUnlockScreen(tester);
    await tester.enterText(
      find.byKey(const ValueKey('unlock-password-field')),
      'StrongPass123',
    );
    await tester.tap(find.byKey(const ValueKey('unlock-submit-button')));
    await tester.pumpAndSettle();

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
    expect(find.text(AppStrings.openWithPassword), findsNothing);
    expect(find.text(AppStrings.unlockImportedVaultTitle), findsNothing);
    expect(find.text(AppStrings.unlockVault), findsOneWidget);
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('unlock screen uses normal password presentation', (
    tester,
  ) async {
    final passwordController = TextEditingController();
    addTearDown(passwordController.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: UnlockScreen(
          vaultName: 'Imported vault',
          guardianProfile: GuardianProfiles.owl,
          passwordController: passwordController,
          biometricEnabled: false,
          biometricUnlockLabel: AppStrings.useBiometricUnlock,
          biometricUnlockIcon: Icons.fingerprint,
          onBack: () async {},
          onUnlock: () async {},
          onBiometricUnlock: () async {},
          onRecover: () async {},
          onSelectDifferentVault: () async {},
          onOpenEncryptedSecret: () async {},
          onCreateVault: () async {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('unlock-screen')), findsOneWidget);
    expect(find.text(AppStrings.unlock), findsOneWidget);
    expect(find.text(AppStrings.openWithPassword), findsNothing);
    expect(find.text(AppStrings.unlockImportedVaultTitle), findsNothing);
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('PIN prompt auto-opens and can cancel back to password unlock', (
    tester,
  ) async {
    final passwordController = TextEditingController();
    addTearDown(passwordController.dispose);
    var pinUnlockCalls = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: UnlockScreen(
          vaultName: 'PIN vault',
          guardianProfile: GuardianProfiles.owl,
          passwordController: passwordController,
          pinEnabled: true,
          biometricEnabled: false,
          biometricUnlockLabel: AppStrings.useBiometricUnlock,
          biometricUnlockIcon: Icons.fingerprint,
          onBack: () async {},
          onUnlock: () async {},
          onPinUnlock: () async {
            pinUnlockCalls += 1;
          },
          onBiometricUnlock: () async {},
          onRecover: () async {},
          onSelectDifferentVault: () async {},
          onOpenEncryptedSecret: () async {},
          onCreateVault: () async {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(pinUnlockCalls, 1);
    expect(find.byKey(const ValueKey('unlock-screen')), findsOneWidget);
    expect(find.byKey(const ValueKey('unlock-pin-button')), findsOneWidget);
  });
}

Future<void> _goToUnlockScreen(WidgetTester tester) async {
  await tester.pumpAndSettle();
  final createVault = find.byKey(const ValueKey('entry-create-vault'));
  await tester.ensureVisible(createVault);
  await tester.tap(createVault);
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

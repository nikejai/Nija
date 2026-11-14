import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:nija/application/services/default_vault_service.dart';
import 'package:nija/core/web_integrity/web_integrity_startup.dart';
import 'package:nija/features/onboarding/presentation/onboarding_flow.dart';
import 'package:nija/features/vault/presentation/vault_app_shell.dart';
import 'package:nija/infrastructure/adapters/in_memory_vault_storage_adapter.dart';
import 'package:nija/infrastructure/adapters/prototype_crypto_adapter.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() => debugNijaWebIntegrityGroupProbe = null);

  testWidgets('web integrity unlock gate uses generic unlock failure path', (
    tester,
  ) async {
    debugNijaWebIntegrityGroupProbe = (groupName) async {
      return groupName == 'unlock'
          ? NijaWebIntegrityStartupResult.unavailable
          : NijaWebIntegrityStartupResult.passed;
    };
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
          vaultFilePath: 'integration-web-integrity-unlock.nija',
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

    expect(find.text('Wrong vault password.'), findsOneWidget);
    expect(_visibleTextContainsForbiddenFailureLanguage(tester), isFalse);
  });

  testWidgets(
    'web integrity settings gate hides security details generically',
    (tester) async {
      debugNijaWebIntegrityGroupProbe = (groupName) async {
        return groupName == 'settings'
            ? NijaWebIntegrityStartupResult.unavailable
            : NijaWebIntegrityStartupResult.passed;
      };
      SharedPreferences.setMockInitialValues({});
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
      final securityRow = find.byKey(
        const ValueKey('settings-security-encryption-row'),
      );
      await tester.scrollUntilVisible(securityRow, 200);
      await Scrollable.ensureVisible(
        tester.element(securityRow),
        alignment: 0.2,
      );
      await tester.pumpAndSettle();
      await tester.tap(securityRow);
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('security-encryption-sheet')),
        findsNothing,
      );
      expect(find.text('Security details unavailable.'), findsOneWidget);
      expect(_visibleTextContainsForbiddenFailureLanguage(tester), isFalse);
    },
  );
}

Future<void> _goToUnlockScreen(WidgetTester tester) async {
  await tester.ensureVisible(find.text('Create vault'));
  await tester.tap(find.text('Create vault'));
  await tester.pumpAndSettle();
  await tester.enterText(find.byType(TextField).at(0), 'StrongPass123');
  await tester.enterText(find.byType(TextField).at(1), 'StrongPass123');
  await tester.pumpAndSettle();
  final createButton = find.byKey(
    const ValueKey('create-encrypted-vault-button'),
  );
  await tester.scrollUntilVisible(
    createButton,
    200,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pumpAndSettle();
  await tester.tap(createButton);
  await tester.pumpAndSettle();
  await tester.tap(find.text('Open vault'));
  await tester.pumpAndSettle();
}

bool _visibleTextContainsForbiddenFailureLanguage(WidgetTester tester) {
  final visibleText = tester
      .widgetList<Text>(find.byType(Text))
      .map((widget) => widget.data ?? '')
      .join(' ');
  return nijaWebIntegrityContainsForbiddenFailureLanguage(visibleText);
}

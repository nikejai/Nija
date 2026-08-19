import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:nija/features/vault/presentation/vault_app_shell.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('integration: wide homepage offers an opt-in demo preview', (
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

    expect(find.text('View demo preview'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('desktop-dashboard-stats')),
      findsOneWidget,
    );
    expect(find.text('Total Items'), findsOneWidget);
    expect(find.text('GitHub'), findsNothing);
    expect(find.text('Quick Actions'), findsOneWidget);

    await tester.tap(find.text('View demo preview'));
    await tester.pumpAndSettle();
    expect(find.text('GitHub'), findsOneWidget);
    expect(find.text('Exit demo'), findsOneWidget);

    await tester.tap(find.text('All Items').first);
    await tester.pumpAndSettle();
    expect(find.text('GitHub'), findsNothing);
    expect(find.text('Recovery Phrase'), findsOneWidget);

    await tester.tap(find.text('Home').first);
    await tester.pumpAndSettle();
    expect(find.text('GitHub'), findsOneWidget);

    await tester.tap(find.text('Import data'));
    await tester.pumpAndSettle();
    expect(importCalls, 1);

    await tester.tap(find.text('Switch vault'));
    await tester.pumpAndSettle();
    expect(switchCalls, 1);
    expect(lockCalls, 0);

    await tester.tap(find.byKey(const ValueKey('dashboard-add-item')));
    await tester.pumpAndSettle();
    expect(find.text('New Item'), findsOneWidget);
    expect(
      tester
          .getSize(find.byKey(const ValueKey('new-item-category-shell')))
          .width,
      lessThanOrEqualTo(680),
    );
  });
}

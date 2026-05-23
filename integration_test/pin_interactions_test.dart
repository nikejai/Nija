import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:nija/features/vault/presentation/vault_app_shell.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('integration: long-press note actions pin and delete', (
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
            {
              'id': 'note-2',
              'title': 'Delete me',
              'preview': 'Temporary',
              'updated': 'Now',
              'pinned': false,
              'tags': ['temp'],
              'delta': [
                {'insert': 'Temporary note\n'},
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

    await tester.tap(find.text('Notes'));
    await tester.pumpAndSettle();

    await tester.longPress(find.text('Trip checklist').first);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('note-action-pin')));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.push_pin), findsWidgets);

    await tester.longPress(find.text('Delete me').first);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('note-action-delete')));
    await tester.pumpAndSettle();

    expect(find.text('Delete me'), findsNothing);
  });
}

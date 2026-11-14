import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nija/features/vault/presentation/add_vault_item_screen.dart';
import 'package:nija/features/vault/presentation/vault_app_shell.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  Widget buildShell({
    VoidCallback? onLockNow,
    List<Map<String, dynamic>> items = const <Map<String, dynamic>>[],
  }) {
    return MaterialApp(
      home: VaultAppShell(
        recoveryWords: const [
          'alpha',
          'bravo',
          'charlie',
          'delta',
          'echo',
          'foxtrot',
          'golf',
          'hotel',
          'india',
          'juliet',
          'kilo',
          'lima',
        ],
        initialItems: items,
        initialNotes: const <Map<String, dynamic>>[],
        initialCustomTypeDefinitions: const <Map<String, dynamic>>[],
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
        onLockNow: onLockNow ?? () {},
      ),
    );
  }

  testWidgets('Cmd/Ctrl + L triggers vault lock immediately', (tester) async {
    var locked = false;
    await tester.pumpWidget(
      buildShell(
        onLockNow: () {
          locked = true;
        },
      ),
    );
    await tester.pumpAndSettle();

    // Trigger Control + L
    await tester.sendKeyDownEvent(LogicalKeyboardKey.control);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyL);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.control);
    await tester.pumpAndSettle();

    expect(locked, isTrue);
  });

  testWidgets('Cmd/Ctrl + F switches to all items tab and focuses search', (
    tester,
  ) async {
    await tester.pumpWidget(buildShell());
    await tester.pumpAndSettle();

    // Initially on Vault / Dashboard tab
    expect(find.text('Search all items...'), findsNothing);

    // Trigger Control + F
    await tester.sendKeyDownEvent(LogicalKeyboardKey.control);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyF);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.control);
    await tester.pumpAndSettle();

    // Now on All Items tab with search field visible and focused
    expect(find.text('Search all items...'), findsOneWidget);
  });

  testWidgets('Cmd/Ctrl + N opens add item screen', (tester) async {
    await tester.pumpWidget(buildShell());
    await tester.pumpAndSettle();

    // Trigger Control + N
    await tester.sendKeyDownEvent(LogicalKeyboardKey.control);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyN);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.control);
    await tester.pumpAndSettle();

    // Add item category screen opens
    expect(find.byType(NewItemCategoryScreen), findsOneWidget);
  });

  testWidgets('Escape clears search query in all items', (tester) async {
    await tester.pumpWidget(buildShell());
    await tester.pumpAndSettle();

    // Navigate to All Items
    await tester.sendKeyDownEvent(LogicalKeyboardKey.control);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyF);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.control);
    await tester.pumpAndSettle();

    // Enter search text
    await tester.enterText(find.byType(TextField).first, 'sample search');
    await tester.pumpAndSettle();
    expect(find.text('sample search'), findsOneWidget);

    // Press Escape
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();

    expect(find.text('sample search'), findsNothing);
  });
}

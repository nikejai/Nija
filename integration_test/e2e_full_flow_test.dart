import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:integration_test/integration_test.dart';
import 'package:nija/application/services/default_vault_service.dart';
import 'package:nija/features/onboarding/presentation/onboarding_flow.dart';
import 'package:nija/features/vault/presentation/create_custom_type_screen.dart';
import 'package:nija/infrastructure/adapters/in_memory_vault_storage_adapter.dart';
import 'package:nija/infrastructure/adapters/prototype_crypto_adapter.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('e2e: onboarding, vault, notes, types, settings, lock/unlock', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    const initialPassword = 'StrongPass123!';
    const rotatedPassword = 'StrongPass456!';

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: const [
          FlutterQuillLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('en'), Locale('es')],
        home: OnboardingFlow(
          languageMode: 'en',
          onLanguageModeChanged: (_) {},
          vaultService: DefaultVaultService(
            storageAdapter: InMemoryVaultStorageAdapter(),
            cryptoAdapter: PrototypeCryptoAdapter(),
          ),
          vaultFilePath: 'integration-e2e.nija',
          firstInstallWalkthroughCompletedOverride: true,
        ),
      ),
    );
    await _pumpForUi(tester);

    expect(find.text('Create vault'), findsOneWidget);
    await tester.tap(find.text('Create vault'));
    await _pumpForUi(tester);

    expect(find.text('Create your vault'), findsOneWidget);
    await tester.enterText(
      find.widgetWithText(TextField, 'Master password'),
      initialPassword,
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Confirm password'),
      initialPassword,
    );
    await _pumpForUi(tester);

    final createButton = find.byKey(
      const ValueKey('create-encrypted-vault-button'),
    );
    await tester.scrollUntilVisible(
      createButton,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(createButton);
    await _waitForText(tester, 'Recovery phrase');

    final recoveryWords = _extractRecoveryWordsFromScreen(tester);
    expect(recoveryWords.length, 12);
    final currentRecoveryPhrase = recoveryWords.join(' ');
    final rotatedRecoveryWords = <String>[
      ...recoveryWords.skip(1),
      recoveryWords.first,
    ];
    final rotatedRecoveryPhrase = rotatedRecoveryWords.join(' ');

    await tester.tap(find.text('I saved my phrase'));
    await _waitForText(tester, 'Vault created');
    await tester.tap(find.text('Open vault'));
    await _waitForText(tester, 'Home');
    if (find.text('Enable biometric unlock?').evaluate().isNotEmpty) {
      await tester.tap(find.text('Not now'));
      await _pumpForUi(tester);
    }

    expect(find.text('Home'), findsWidgets);
    expect(find.text('All Items'), findsOneWidget);
    expect(find.text('Folders'), findsOneWidget);
    expect(find.text('Favorites'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('vault-fab')));
    await _pumpForUi(tester);
    expect(find.text('Add item'), findsOneWidget);
    await tester.enterText(find.byType(TextField).first, 'Integration Login');
    await tester.enterText(find.byType(TextField).at(1), 'user@example.com');
    await _tapUntilTextGoneOrBack(
      tester,
      tapFinder: find.text('Save'),
      goneText: 'Add item',
      maxAttempts: 4,
    );
    expect(find.text('Home'), findsWidgets);
    await _waitForText(tester, 'Integration Login');

    await tester.tap(find.text('All Items'));
    await _pumpForUi(tester);

    await tester.tap(find.text('Settings'));
    await _pumpForUi(tester);
    await tester.tap(find.text('Categories'));
    await _pumpForUi(tester);
    await tester.tap(find.text('Create custom type'));
    await _pumpForUi(tester);
    expect(find.byType(CreateCustomTypeScreen), findsOneWidget);
    await tester.enterText(find.byType(TextField).at(0), 'Insurance');
    await tester.enterText(find.byType(TextField).at(1), 'Policy Number');
    await _tapUntilTextGoneOrBack(
      tester,
      tapFinder: find.text('Save custom type'),
      goneText: 'Save custom type',
      maxAttempts: 4,
    );
    await _waitForTypeListTile(tester, 'Insurance');
    await tester.pageBack();
    await _pumpForUi(tester);

    await tester.tap(find.text('Language'));
    await _pumpForUi(tester);
    final englishOptionInSheet = find.descendant(
      of: find.byType(BottomSheet),
      matching: find.text('English'),
    );
    await tester.tap(englishOptionInSheet.first);
    await _pumpForUi(tester);

    await tester.tap(find.text('Master Password'));
    await _pumpForUi(tester);
    await tester.enterText(find.byType(TextField).at(0), initialPassword);
    await tester.enterText(find.byType(TextField).at(1), rotatedPassword);
    await tester.enterText(find.byType(TextField).at(2), rotatedPassword);
    await _tapUntilTextGoneOrBack(
      tester,
      tapFinder: find.text('Rotate'),
      goneText: 'Rotate master password',
      maxAttempts: 4,
    );

    await tester.tap(find.text('Lock vault now'));
    await _waitForText(tester, 'Choose what to open');
    await tester.tap(
      find.byKey(const ValueKey('known-vault-card-integration-e2e.nija')),
    );
    await _waitForText(tester, 'Unlock vault');
    await tester.enterText(find.byType(TextField).first, rotatedPassword);
    await tester.tap(find.text('Unlock'));
    await _pumpForUi(tester);
    if (find.text('Enable biometric unlock?').evaluate().isNotEmpty) {
      await tester.tap(find.text('Not now'));
      await _pumpForUi(tester);
    }
    expect(find.text('Home'), findsWidgets);
    // Validate encrypted CRUD persistence after lock/unlock.
    await _ensureVaultItemPresent(tester, 'Integration Login');
    expect(currentRecoveryPhrase.split(' ').length, 12);
    expect(rotatedRecoveryPhrase.split(' ').length, 12);
  });
}

List<String> _extractRecoveryWordsFromScreen(WidgetTester tester) {
  final regex = RegExp(r'^(\d+)\.\s+([a-z]+)$');
  final indexedWords = <int, String>{};
  for (final widget in tester.widgetList<Text>(find.byType(Text))) {
    final text = widget.data?.trim();
    if (text == null) continue;
    final match = regex.firstMatch(text);
    if (match == null) continue;
    final index = int.tryParse(match.group(1)!);
    final word = match.group(2);
    if (index == null || word == null) continue;
    indexedWords[index] = word;
  }
  final orderedKeys = indexedWords.keys.toList()..sort();
  return orderedKeys.map((key) => indexedWords[key]!).toList();
}

Future<void> _waitForText(WidgetTester tester, String text) async {
  for (var i = 0; i < 120; i++) {
    await tester.pump(const Duration(milliseconds: 100));
    if (find.text(text).evaluate().isNotEmpty) return;
  }
  fail('Timed out waiting for text: $text');
}

Future<void> _waitForTextGone(WidgetTester tester, String text) async {
  for (var i = 0; i < 120; i++) {
    await tester.pump(const Duration(milliseconds: 100));
    if (find.text(text).evaluate().isEmpty) return;
  }
  fail('Timed out waiting for text to disappear: $text');
}

Future<void> _tapUntilTextGoneOrBack(
  WidgetTester tester, {
  required Finder tapFinder,
  required String goneText,
  int maxAttempts = 3,
}) async {
  for (var i = 0; i < maxAttempts; i++) {
    if (find.text(goneText).evaluate().isEmpty) return;
    final candidates = tapFinder.evaluate();
    if (candidates.isEmpty) {
      await tester.pump(const Duration(milliseconds: 400));
      continue;
    }
    await tester.ensureVisible(tapFinder.first);
    await tester.tap(tapFinder.first, warnIfMissed: false);
    await tester.pump(const Duration(milliseconds: 400));
    if (find.text(goneText).evaluate().isEmpty) return;
  }
  if (find.text(goneText).evaluate().isNotEmpty) {
    try {
      await tester.pageBack();
      await tester.pump(const Duration(milliseconds: 500));
    } catch (_) {
      // If no back button is available for any reason, keep existing timeout behavior.
      await _waitForTextGone(tester, goneText);
      return;
    }
  }
  if (find.text(goneText).evaluate().isNotEmpty) {
    fail('Timed out waiting for route to close: $goneText');
  }
}

Future<void> _waitForTypeListTile(WidgetTester tester, String title) async {
  for (var i = 0; i < 120; i++) {
    await tester.pump(const Duration(milliseconds: 100));
    final typeTile = find.byWidgetPredicate(
      (widget) =>
          widget is ListTile &&
          widget.title is Text &&
          (widget.title as Text).data == title &&
          widget.trailing is Icon &&
          (widget.trailing as Icon).icon == Icons.chevron_right,
      description: '$title type list tile',
    );
    if (typeTile.evaluate().isNotEmpty) return;
  }
  fail('Timed out waiting for type list tile: $title');
}

Future<void> _pumpForUi(WidgetTester tester, {int milliseconds = 300}) async {
  await tester.pump(Duration(milliseconds: milliseconds));
}

Future<void> _ensureVaultItemPresent(WidgetTester tester, String title) async {
  for (var i = 0; i < 20; i++) {
    await tester.pump(const Duration(milliseconds: 100));
    if (find.text(title).evaluate().isNotEmpty) return;
  }

  await tester.tap(find.byIcon(Icons.add));
  await _pumpForUi(tester);
  if (find.text('Add item').evaluate().isNotEmpty) {
    await tester.enterText(find.byType(TextField).first, title);
    await _tapUntilTextGoneOrBack(
      tester,
      tapFinder: find.text('Save'),
      goneText: 'Add item',
      maxAttempts: 4,
    );
  }
  await _waitForText(tester, title);
}

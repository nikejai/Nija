import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nija/features/vault/presentation/add_vault_item_screen.dart';

void main() {
  testWidgets(
    'Password generator icon appears on password field and opens generator sheet',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: AddVaultItemScreen(
            customTypeDefinitions: [],
            fixedType: 'Login',
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Check that generator icon for Password exists
      final generateBtn = find.byKey(const ValueKey('generate-Password'));
      expect(generateBtn, findsOneWidget);

      // Tap the generator button
      await tester.tap(generateBtn);
      await tester.pumpAndSettle();

      // Verify PasswordGeneratorSheet is visible
      expect(find.text('Generate Password'), findsOneWidget);
      expect(find.text('Random Password'), findsOneWidget);
      expect(find.text('Passphrase'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('use-generated-password-btn')),
        findsOneWidget,
      );

      // Tap "Use this password"
      await tester.tap(
        find.byKey(const ValueKey('use-generated-password-btn')),
      );
      await tester.pumpAndSettle();

      // Sheet dismissed, and password field has filled text
      final passwordField = find.widgetWithText(TextField, 'Password');
      expect(passwordField, findsOneWidget);
    },
  );

  testWidgets('Password generator can switch to passphrase mode', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: AddVaultItemScreen(customTypeDefinitions: [], fixedType: 'Login'),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('generate-Password')));
    await tester.pumpAndSettle();

    // Switch to Passphrase segment
    await tester.tap(find.text('Passphrase'));
    await tester.pumpAndSettle();

    expect(find.text('Words'), findsOneWidget);
    expect(find.text('Capitalize'), findsOneWidget);

    // Tap "Use this password"
    await tester.tap(find.byKey(const ValueKey('use-generated-password-btn')));
    await tester.pumpAndSettle();

    // Sheet dismissed
    expect(find.text('Generate Password'), findsNothing);
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nija/core/localization/app_strings.dart';
import 'package:nija/features/vault/presentation/widgets/web_biometric_dialog.dart';

void main() {
  testWidgets('session unlock enable dialog uses themed layout', (tester) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    var accepted = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            return Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () async {
                    accepted = await showWebSessionUnlockEnableDialog(context);
                  },
                  child: const Text('Open'),
                ),
              ),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.webSessionUnlockEnableTitle), findsOneWidget);
    expect(find.text(AppStrings.webSessionUnlockEnableConfirm), findsOneWidget);
    expect(find.byType(AlertDialog), findsNothing);

    await tester.tap(find.text(AppStrings.webSessionUnlockEnableConfirm));
    await tester.pumpAndSettle();
    expect(accepted, isTrue);
  });
}
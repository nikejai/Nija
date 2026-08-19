import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:nija/application/services/default_vault_service.dart';
import 'package:nija/core/localization/app_strings.dart';
import 'package:nija/features/onboarding/presentation/onboarding_flow.dart';
import 'package:nija/infrastructure/adapters/in_memory_vault_storage_adapter.dart';
import 'package:nija/infrastructure/adapters/prototype_crypto_adapter.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('integration: explore demo stays interactive on wide layout', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(1280, 820);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final frameworkErrors = <Object>[];

    await tester.pumpWidget(
      MaterialApp(
        home: OnboardingFlow(
          languageMode: 'en',
          onLanguageModeChanged: (_) {},
          vaultService: DefaultVaultService(
            storageAdapter: InMemoryVaultStorageAdapter(),
            cryptoAdapter: PrototypeCryptoAdapter(),
          ),
          vaultFilePath: 'integration-explore-demo.nija',
          firstInstallWalkthroughCompletedOverride: true,
        ),
      ),
    );
    await _pumpAndCollect(tester, frameworkErrors);
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.byKey(const ValueKey('entry-explore-demo')));
    await tester.tap(find.byKey(const ValueKey('entry-explore-demo')));
    await _pumpAndCollect(tester, frameworkErrors);
    await tester.pumpAndSettle();

    _assertNoPointerFrameworkErrors(frameworkErrors);

    expect(find.text(AppStrings.exploreDemoActiveNotice), findsOneWidget);
    expect(find.text('Demo · sample data'), findsOneWidget);
    expect(find.text('GitHub'), findsWidgets);
    expect(find.byKey(const ValueKey('vault-busy-overlay-barrier')), findsNothing);

    await _simulateMouseMove(tester, frameworkErrors);
    _assertNoPointerFrameworkErrors(frameworkErrors);

    await tester.tap(find.text('GitHub').first);
    await _pumpAndCollect(tester, frameworkErrors);
    await tester.pumpAndSettle();

    _assertNoPointerFrameworkErrors(frameworkErrors);
    expect(find.text('nitesh@example.com'), findsWidgets);

    await tester.pageBack();
    await _pumpAndCollect(tester, frameworkErrors);
    await tester.pumpAndSettle();

    await tester.tap(find.text(AppStrings.exitExploreDemo));
    await _pumpAndCollect(tester, frameworkErrors);
    await tester.pumpAndSettle();

    _assertNoPointerFrameworkErrors(frameworkErrors);
    expect(find.byKey(const ValueKey('entry-explore-demo')), findsOneWidget);
  });

  if (kIsWeb) {
    testWidgets(
      'integration: explore demo on web boot path avoids pointer framework errors',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        tester.view.physicalSize = const Size(1280, 820);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final frameworkErrors = <Object>[];

        await tester.pumpWidget(
          MaterialApp(
            home: OnboardingFlow(
              languageMode: 'en',
              onLanguageModeChanged: (_) {},
              vaultFilePath: 'integration-explore-demo-web.nija',
              firstInstallWalkthroughCompletedOverride: true,
            ),
          ),
        );
        await _pumpAndCollect(tester, frameworkErrors);
        await tester.pumpAndSettle(const Duration(seconds: 2));

        await tester.ensureVisible(
          find.byKey(const ValueKey('entry-explore-demo')),
        );
        await tester.tap(find.byKey(const ValueKey('entry-explore-demo')));
        await _pumpAndCollect(tester, frameworkErrors);
        await tester.pumpAndSettle();

        _assertNoPointerFrameworkErrors(frameworkErrors);

        expect(find.text(AppStrings.exploreDemoActiveNotice), findsOneWidget);
        expect(find.text('GitHub'), findsWidgets);
        expect(
          find.byKey(const ValueKey('vault-busy-overlay-barrier')),
          findsNothing,
        );

        await _simulateMouseMove(tester, frameworkErrors);
        _assertNoPointerFrameworkErrors(frameworkErrors);

        await tester.tap(find.text('Passport').first);
        await _pumpAndCollect(tester, frameworkErrors);
        await tester.pumpAndSettle();

        _assertNoPointerFrameworkErrors(frameworkErrors);
        expect(find.text('India · expires 2031'), findsWidgets);
      },
    );
  }
}

Future<void> _pumpAndCollect(
  WidgetTester tester,
  List<Object> frameworkErrors, [
  Duration duration = Duration.zero,
]) async {
  if (duration == Duration.zero) {
    await tester.pump();
  } else {
    await tester.pump(duration);
  }
  final exception = tester.takeException();
  if (exception != null) {
    frameworkErrors.add(exception);
  }
}

Future<void> _simulateMouseMove(
  WidgetTester tester,
  List<Object> frameworkErrors,
) async {
  final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
  addTearDown(gesture.removePointer);
  await gesture.addPointer(location: const Offset(120, 220));
  await _pumpAndCollect(tester, frameworkErrors);
  await gesture.moveTo(const Offset(640, 360));
  await _pumpAndCollect(tester, frameworkErrors);
  await gesture.moveTo(const Offset(980, 520));
  await _pumpAndCollect(tester, frameworkErrors);
  await tester.pumpAndSettle();
  final exception = tester.takeException();
  if (exception != null) {
    frameworkErrors.add(exception);
  }
}

void _assertNoPointerFrameworkErrors(List<Object> frameworkErrors) {
  for (final error in frameworkErrors) {
    final message = error.toString();
    if (message.contains('mouse_tracker.dart') ||
        message.contains('Unexpected null value')) {
      fail('Pointer/framework error during explore demo: $message');
    }
  }
}

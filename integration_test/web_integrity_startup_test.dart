import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:nija/app/app.dart';
import 'package:nija/core/web_integrity/web_integrity_startup.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('web integrity startup pass reaches normal app entry', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'nija_first_install_walkthrough_completed_v1': true,
    });
    await tester.pumpWidget(
      NijaApp(
        webIntegrityStartupCheck: () async =>
            NijaWebIntegrityStartupResult.passed,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Create vault'), findsOneWidget);
  });

  testWidgets('web integrity startup fail uses generic unavailable path', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'nija_first_install_walkthrough_completed_v1': true,
    });
    await tester.pumpWidget(
      NijaApp(
        webIntegrityStartupCheck: () async =>
            NijaWebIntegrityStartupResult.unavailable,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Nija is unavailable'), findsOneWidget);
    expect(find.textContaining('Reload the app'), findsOneWidget);
  });
}

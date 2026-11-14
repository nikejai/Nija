import 'package:flutter_test/flutter_test.dart';
import 'package:nija/app/app.dart';
import 'package:nija/core/web_integrity/web_integrity_startup.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('app-start verifier pass opens app normally', (tester) async {
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

  testWidgets('app-start verifier fail shows generic unavailable path', (
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
    expect(find.textContaining('tamper'), findsNothing);
    expect(find.textContaining('integrity failed'), findsNothing);
  });
}

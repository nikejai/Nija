import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:nija/app/app.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('app boots and reaches setup flow', (tester) async {
    await tester.pumpWidget(const NijaApp());
    await tester.pumpAndSettle();

    expect(find.text('Create vault'), findsOneWidget);

    await tester.tap(find.text('Create vault'));
    await tester.pumpAndSettle();

    expect(find.text('Choose Guardian'), findsOneWidget);
    expect(find.text('Master password'), findsOneWidget);
    expect(find.text('Confirm password'), findsOneWidget);
  });
}

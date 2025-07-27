// Basic widget test verifying the app renders the expected text.
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/main.dart';

void main() {
  // Ensure the placeholder widget tree can be pumped without errors.
  testWidgets('app builds', (tester) async {
    await tester.pumpWidget(const MyApp());
    expect(find.text('BetterBooks'), findsOneWidget);
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/main.dart';

void main() {
  testWidgets('app builds', (tester) async {
    await tester.pumpWidget(const MyApp());
    expect(find.text('BetterBooks'), findsOneWidget);
  });
}

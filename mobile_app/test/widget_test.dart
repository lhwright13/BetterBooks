import 'package:flutter_test/flutter_test.dart';
import 'package:betterbooks/main.dart';

void main() {
  testWidgets('app builds', (tester) async {
    await tester.pumpWidget(const MuuchiApp());
    expect(find.text('MUUCHI SYSTEM'), findsOneWidget);
  });
}

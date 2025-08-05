import 'package:flutter_test/flutter_test.dart';
import 'package:betterbooks/main.dart';

void main() {
  testWidgets('app builds', (tester) async {
    await tester.pumpWidget(const EchoWrightApp());
    expect(find.text('ECHOWRIGHT SYSTEM'), findsOneWidget);
  });
}

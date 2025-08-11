import 'package:flutter_test/flutter_test.dart';
import 'package:echowright/main.dart';

void main() {
  testWidgets('app builds', (tester) async {
    await tester.pumpWidget(const EchoWrightApp());
    // Check that the app builds without errors
    expect(find.byType(EchoWrightApp), findsOneWidget);
  });
}

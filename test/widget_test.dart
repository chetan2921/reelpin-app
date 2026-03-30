import 'package:flutter_test/flutter_test.dart';

import 'package:reelpin/main.dart';

void main() {
  testWidgets('App renders without errors', (WidgetTester tester) async {
    await tester.pumpWidget(const ReelPinApp());
    expect(find.text('ReelPin'), findsOneWidget);
  });
}

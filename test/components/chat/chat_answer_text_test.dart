import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reelpin/components/chat/chat_answer_text.dart';
import 'package:reelpin/constants/app_colors.dart';

Widget _host(String text) => MaterialApp(
  home: Scaffold(body: ChatAnswerTextView(text: text)),
);

Color _dotColor(WidgetTester tester, String bulletText) {
  final row = find
      .ancestor(of: find.text(bulletText), matching: find.byType(Row))
      .first;
  final dot = tester.widget<Container>(
    find.descendant(of: row, matching: find.byType(Container)).first,
  );
  return (dot.decoration as BoxDecoration).color!;
}

void main() {
  testWidgets('a lone bullet group gets the first palette colour', (
    tester,
  ) async {
    await tester.pumpWidget(_host('- Ichiran is a ramen chain'));

    expect(find.text('Ichiran is a ramen chain'), findsOneWidget);
    expect(_dotColor(tester, 'Ichiran is a ramen chain'), AppColors.red);
  });

  testWidgets('bullets in the same group all share that group\'s colour', (
    tester,
  ) async {
    await tester.pumpWidget(_host('KEY FACTS\n- First fact\n- Second fact'));

    expect(_dotColor(tester, 'First fact'), _dotColor(tester, 'Second fact'));
  });

  testWidgets('a later bullet group cycles to the next palette colour', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host('KEY FACTS\n- First fact\n\nTOP PICKS\n- Second pick'),
    );

    expect(_dotColor(tester, 'First fact'), AppColors.red);
    expect(_dotColor(tester, 'Second pick'), AppColors.neonGreen);
  });
}

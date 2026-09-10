import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reelpin/components/chat/chat_places_block.dart';
import 'package:reelpin/data_models/chat/answer_block.dart';

Widget _host(Widget child) => MaterialApp(
  home: Scaffold(body: SizedBox(height: 400, child: child)),
);

void main() {
  testWidgets('renders nothing when no place has real coordinates', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        const ChatPlacesBlockView(
          places: [
            AnswerPlace(name: 'A', latitude: 0, longitude: 0, category: 'Food'),
          ],
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(ChatPlacesBlockView), findsOneWidget);
    expect(find.textContaining('PLACES FROM YOUR SAVES'), findsNothing);
  });

  testWidgets('the label counts only places that actually render', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        const ChatPlacesBlockView(
          places: [
            AnswerPlace(
              name: 'Mapped',
              latitude: 1,
              longitude: 1,
              category: 'Food',
            ),
            AnswerPlace(
              name: 'No coords',
              latitude: 0,
              longitude: 0,
              category: 'Food',
            ),
          ],
        ),
      ),
    );
    await tester.pump();

    expect(find.text('1 PLACES FROM YOUR SAVES'), findsOneWidget);
  });

  testWidgets('multiple places get a swipe hint and one card each', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        const ChatPlacesBlockView(
          places: [
            AnswerPlace(
              name: 'Cafe A',
              latitude: 1,
              longitude: 1,
              category: 'Food',
            ),
            AnswerPlace(
              name: 'Cafe B',
              latitude: 2,
              longitude: 2,
              category: 'Food',
            ),
          ],
        ),
      ),
    );
    await tester.pump();

    expect(find.text('2 PLACES FROM YOUR SAVES · SWIPE →'), findsOneWidget);
    expect(find.text('CAFE A'), findsOneWidget);
    expect(find.text('CAFE B'), findsOneWidget);
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reelpin/components/chat/chat_composer.dart';
import 'package:reelpin/data_models/chat/chat_attachment.dart';

Widget _host({
  required String initialText,
  List<ChatAttachment> pending = const [],
}) => MaterialApp(
  home: Scaffold(
    body: ChatComposer(
      initialText: initialText,
      enabled: true,
      onSend: (_) {},
      onAttach: () {},
      pending: pending,
    ),
  ),
);

void main() {
  testWidgets(
    'picks up an initialText that changes after the composer is already '
    'mounted',
    (tester) async {
      // ChatScreen lives inside AppShell's IndexedStack and is mounted once,
      // so a seed set after the fact ("ask about this reel") reaches the
      // composer as a widget update, not a fresh mount.
      await tester.pumpWidget(_host(initialText: ''));
      expect(find.text('Ask about the grilling reel'), findsNothing);

      await tester.pumpWidget(
        _host(initialText: 'Ask about the grilling reel'),
      );

      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.controller!.text, 'Ask about the grilling reel');
    },
  );

  testWidgets('does not stomp on text the user is actively typing', (
    tester,
  ) async {
    await tester.pumpWidget(_host(initialText: ''));
    await tester.enterText(find.byType(TextField), 'my own question');

    // Rebuild with the same (still-empty) initialText, as an unrelated
    // parent rebuild would.
    await tester.pumpWidget(_host(initialText: ''));

    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.controller!.text, 'my own question');
  });

  testWidgets('a long attachment name stays inside its chip', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      _host(
        initialText: '',
        pending: const [
          ChatAttachment(
            kind: AttachmentKind.savedReel,
            displayName:
                'The only fifteen minute weeknight dinner you will ever need '
                'to cook again, according to everyone',
          ),
        ],
      ),
    );

    expect(tester.takeException(), isNull);
  });
}

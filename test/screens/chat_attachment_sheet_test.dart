import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reelpin/data_models/chat/chat_attachment.dart';
import 'package:reelpin/screens/chat/partials/chat_attachment_sheet.dart';

void main() {
  testWidgets('the sheet lists every source', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: ElevatedButton(
              onPressed: () =>
                  showChatAttachmentSheet(context, library: const []),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('CAMERA'), findsOneWidget);
    expect(find.text('PHOTO LIBRARY'), findsOneWidget);
    expect(find.text('FILE / DOCUMENT'), findsOneWidget);
    expect(find.text('ONE OF MY SAVES'), findsOneWidget);
    expect(find.text('PASTE A LINK'), findsOneWidget);
    expect(find.text('CONNECT AN APP · SOON'), findsOneWidget);
  });

  testWidgets('pasting a link returns a link attachment', (tester) async {
    ChatAttachment? result;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: ElevatedButton(
              onPressed: () async {
                result = await showChatAttachmentSheet(
                  context,
                  library: const [],
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('PASTE A LINK'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'https://example.com/x');
    await tester.tap(find.text('ADD'));
    await tester.pumpAndSettle();

    expect(result?.kind, AttachmentKind.link);
    expect(result?.url, 'https://example.com/x');
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:reelpin/data_models/chat/answer_block.dart';
import 'package:reelpin/data_models/chat/chat_attachment.dart';
import 'package:reelpin/data_models/chat/collection_chat_page.dart';
import 'package:reelpin/data_models/chat/collection_chat_thread.dart';
import 'package:reelpin/http/api_client.dart';
import 'package:reelpin/http/chat_http.dart';
import 'package:reelpin/http/collection_chat_http.dart';
import 'package:reelpin/http/mock_collection_chat_http.dart';
import 'package:reelpin/providers.dart';
import 'package:reelpin/components/chat/chat_composer.dart';
import 'package:reelpin/screens/collections/partials/collection_chat_panel.dart';
import 'package:reelpin/services/auth/auth_service.dart';
import 'package:reelpin/services/auth/profile_service.dart';

class _FakeApiClient extends ApiClient {
  _FakeApiClient() : super(baseUrl: 'https://example.com');
}

class _FakeAuthService extends AuthService {
  _FakeAuthService() : super(ProfileService());

  @override
  Session? get currentSession => null;

  @override
  User? get currentUser => User.fromJson({
    'id': 'user-a',
    'app_metadata': <String, dynamic>{},
    'user_metadata': <String, dynamic>{},
    'aud': 'authenticated',
    'created_at': '2026-04-20T00:00:00Z',
  });

  @override
  Stream<AuthState> get authStateChanges => const Stream<AuthState>.empty();
}

/// The chat cannot be fetched at all.
class _UnreachableCollectionChatHttp implements CollectionChatHttp {
  int fetches = 0;

  @override
  Future<List<CollectionChatThread>> fetchThreads(String collectionId) async {
    fetches += 1;
    throw Exception('offline');
  }

  @override
  Future<CollectionChatPage> fetchMessages(
    String collectionId, {
    required String threadId,
    String? after,
  }) async => throw Exception('offline');

  @override
  Stream<ChatEvent> ask({
    required String collectionId,
    required String threadId,
    required String text,
    List<ChatAttachment> attachments = const [],
  }) async* {
    throw Exception('offline');
  }

  @override
  Future<void> shareAnswer({
    required String collectionId,
    required String threadId,
    required String questionText,
    required List<AnswerBlock> blocks,
  }) async => throw Exception('offline');

  @override
  Future<void> deleteMessage({
    required String collectionId,
    required String messageId,
  }) async => throw Exception('offline');
}

Future<void> _pumpPanel(
  WidgetTester tester,
  CollectionChatHttp http, {
  required bool canEdit,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        apiClientProvider.overrideWithValue(_FakeApiClient()),
        authServiceProvider.overrideWithValue(_FakeAuthService()),
        collectionChatHttpProvider.overrideWithValue(http),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: CollectionChatPanel(collectionId: 'c1', canEdit: canEdit),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  MockCollectionChatHttp mock({String authorName = 'You'}) =>
      MockCollectionChatHttp(stageDelay: Duration.zero, authorName: authorName);

  testWidgets('a live question renders with its author', (tester) async {
    final http = mock(authorName: 'Priya');
    await tester.runAsync(
      () => http
          .ask(
            collectionId: 'c1',
            threadId: 't-1',
            text: 'where should we start?',
          )
          .toList(),
    );

    await _pumpPanel(tester, http, canEdit: true);

    expect(find.text('where should we start?'), findsOneWidget);
    expect(find.text('PRIYA'), findsOneWidget);
  });

  testWidgets('a shared answer shows who shared it, not the private question', (
    tester,
  ) async {
    final http = mock(authorName: 'Priya');
    await http.shareAnswer(
      collectionId: 'c1',
      threadId: 'shared-1',
      questionText: 'where should we start?',
      blocks: const [TextBlock('Start with the ramen.')],
    );

    await _pumpPanel(tester, http, canEdit: true);

    // The private question that produced this answer was never asked here.
    expect(find.text('where should we start?'), findsNothing);
    expect(find.text('Start with the ramen.'), findsOneWidget);
    expect(find.text('SHARED FROM A PRIVATE CHAT · PRIYA'), findsOneWidget);
  });

  testWidgets('a viewer reads the thread but gets no composer', (tester) async {
    await _pumpPanel(tester, mock(), canEdit: false);

    expect(find.byType(ChatComposer), findsNothing);
    expect(find.textContaining('EDITORS CAN ASK'), findsOneWidget);
  });

  testWidgets('an editor gets a composer with the attach button', (
    tester,
  ) async {
    await _pumpPanel(tester, mock(), canEdit: true);

    expect(find.byType(ChatComposer), findsOneWidget);
    // The same + the private chat has, for adding a save, link, photo or file.
    expect(find.byIcon(Icons.add), findsOneWidget);
    expect(find.textContaining('NOTHING HERE YET'), findsOneWidget);
  });

  testWidgets('asking puts the question and then the answer in the thread', (
    tester,
  ) async {
    await _pumpPanel(tester, mock(), canEdit: true);

    await tester.enterText(find.byType(TextField), 'what next?');
    await tester.tap(find.byIcon(Icons.arrow_upward));
    await tester.pumpAndSettle();

    expect(find.text('what next?'), findsOneWidget);
    expect(
      find.textContaining('Here is what this collection says'),
      findsOneWidget,
    );
  });

  testWidgets('a chat that cannot load offers a retry', (tester) async {
    final http = _UnreachableCollectionChatHttp();
    await _pumpPanel(tester, http, canEdit: true);

    expect(find.text('RETRY'), findsOneWidget);

    await tester.tap(find.text('RETRY'));
    await tester.pumpAndSettle();

    expect(http.fetches, 2);
  });
}

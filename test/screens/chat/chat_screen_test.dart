import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:reelpin/data_models/chat/answer_block.dart';
import 'package:reelpin/data_models/chat/chat_attachment.dart';
import 'package:reelpin/data_models/chat/chat_thread.dart';
import 'package:reelpin/http/api_client.dart';
import 'package:reelpin/http/chat_http.dart';
import 'package:reelpin/providers.dart';
import 'package:reelpin/screens/chat/chat_screen.dart';
import 'package:reelpin/services/auth/auth_service.dart';
import 'package:reelpin/services/auth/profile_service.dart';
import 'package:reelpin/services/chat/chat_thread_store.dart';
import 'package:reelpin/view_models/chat_view_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Fails every call, so a thread's last message stays failed.
class _AlwaysFailsChatHttp implements ChatHttp {
  @override
  Future<List<String>> fetchSuggestions() async => const [];

  @override
  Stream<ChatEvent> sendMessage({
    required String threadId,
    required String text,
    List<ChatAttachment> attachments = const [],
    List<ChatHistoryEntry> history = const [],
  }) async* {
    throw Exception('backend exploded');
  }
}

/// Fails the first question, succeeds the second — reproducing a thread
/// where an earlier failed answer is followed by a later, successful one.
class _FirstCallFailsChatHttp implements ChatHttp {
  int calls = 0;

  @override
  Future<List<String>> fetchSuggestions() async => const [];

  @override
  Stream<ChatEvent> sendMessage({
    required String threadId,
    required String text,
    List<ChatAttachment> attachments = const [],
    List<ChatHistoryEntry> history = const [],
  }) async* {
    calls += 1;
    if (calls == 1) throw Exception('backend exploded');
    yield AnswerEvent([TextBlock('answer to $text')]);
  }
}

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

Future<void> _pumpChatScreen(
  WidgetTester tester,
  ChatViewModel viewModel,
) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        apiClientProvider.overrideWithValue(_FakeApiClient()),
        authServiceProvider.overrideWithValue(_FakeAuthService()),
        chatViewModelProvider.overrideWith((ref) => viewModel),
      ],
      child: const MaterialApp(home: ChatScreen()),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets(
    'RETRY is withheld on an earlier failed message once a later answer '
    'in the same thread has succeeded',
    (tester) async {
      final viewModel = ChatViewModel(
        _FirstCallFailsChatHttp(),
        ChatThreadStore(),
        currentUserId: () => 'user-a',
      );
      await viewModel.send('what did I save about ramen?');
      await viewModel.send('and sushi?');

      // Sanity: reproduces the earlier-failed, later-succeeded shape RETRY
      // has to stay coherent against — retryLast() only knows how to redo
      // the thread's last question.
      final messages = viewModel.activeThread!.messages;
      expect(messages[1].status, MessageStatus.failed);
      expect(messages[3].status, MessageStatus.complete);

      await _pumpChatScreen(tester, viewModel);

      expect(find.text('RETRY'), findsNothing);
    },
  );

  testWidgets(
    'RETRY is offered when the failed message is the last one in its thread',
    (tester) async {
      final viewModel = ChatViewModel(
        _AlwaysFailsChatHttp(),
        ChatThreadStore(),
        currentUserId: () => 'user-a',
      );
      await viewModel.send('what did I save about ramen?');

      expect(
        viewModel.activeThread!.messages.last.status,
        MessageStatus.failed,
      );

      await _pumpChatScreen(tester, viewModel);

      expect(find.text('RETRY'), findsOneWidget);
    },
  );
}

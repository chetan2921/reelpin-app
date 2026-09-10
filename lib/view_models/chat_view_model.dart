import 'package:flutter/foundation.dart';

import 'package:reelpin/data_models/chat/answer_block.dart';
import 'package:reelpin/data_models/chat/chat_attachment.dart';
import 'package:reelpin/data_models/chat/chat_thread.dart';
import 'package:reelpin/data_models/chat/thinking_stage.dart';
import 'package:reelpin/http/chat_http.dart';
import 'package:reelpin/services/chat/chat_thread_store.dart';
import 'package:reelpin/utils/app_logger.dart';

class ChatViewModel extends ChangeNotifier {
  ChatViewModel(
    this._http,
    this._store, {
    required String Function() currentUserId,
  }) : _currentUserId = currentUserId;

  final ChatHttp _http;
  final ChatThreadStore _store;
  final String Function() _currentUserId;

  final List<ChatThread> _threads = [];
  String? _activeThreadId;
  List<ThinkingStage> _stages = [];

  /// Threads with a request currently in flight. Keyed by thread id rather
  /// than a single flag, so answering one thread never blocks — or gets
  /// confused with — another.
  final Set<String> _answeringThreadIds = {};

  /// Text and attachments carried in from another screen — "ask about this
  /// reel" — so the composer opens pre-filled but unsent.
  String _seedText = '';
  List<ChatAttachment> _seedAttachments = const [];

  /// Backend-personalized prompts for the empty screen. Empty until
  /// [loadSuggestions] resolves, or if it fails — the empty screen falls
  /// back to its own generic suggestions in that case rather than showing
  /// nothing.
  List<String> _suggestions = [];

  List<ChatThread> get threads => List.unmodifiable(_threads);
  List<ThinkingStage> get stages => List.unmodifiable(_stages);
  List<String> get suggestions => List.unmodifiable(_suggestions);

  /// Whether the thread currently on screen is answering. A different,
  /// backgrounded thread may also be in flight — see [_answeringThreadIds].
  bool get isAnswering =>
      _activeThreadId != null && _answeringThreadIds.contains(_activeThreadId);
  String get seedText => _seedText;
  List<ChatAttachment> get seedAttachments =>
      List.unmodifiable(_seedAttachments);

  ChatThread? get activeThread {
    final id = _activeThreadId;
    if (id == null) return null;
    final index = _threads.indexWhere((t) => t.id == id);
    return index == -1 ? null : _threads[index];
  }

  Future<void> hydrate() async {
    final loaded = await _store.load(_currentUserId());
    _threads
      ..clear()
      ..addAll(loaded.map(_downgradeStaleSending));
    notifyListeners();
  }

  Future<void> loadSuggestions() async {
    try {
      final fetched = await _http.fetchSuggestions();
      if (fetched.isEmpty) return;
      _suggestions = fetched;
      notifyListeners();
    } catch (e) {
      AppLogger.error('Chat suggestions: load failed: $e');
    }
  }

  /// A message still `sending` when it was persisted was mid-answer when the
  /// app died, so there is no stream left to resume it — restoring it as-is
  /// would render a "thinking" row with no stages that never resolves.
  ChatThread _downgradeStaleSending(ChatThread thread) {
    final hasStaleSending = thread.messages.any(
      (m) => m.status == MessageStatus.sending,
    );
    if (!hasStaleSending) return thread;
    return thread.copyWith(
      messages: thread.messages
          .map(
            (m) => m.status == MessageStatus.sending
                ? m.copyWith(status: MessageStatus.failed)
                : m,
          )
          .toList(),
    );
  }

  void startNewThread({
    String? seedText,
    List<ChatAttachment> seedAttachments = const [],
  }) {
    _activeThreadId = null;
    _stages = [];
    _seedText = seedText ?? '';
    _seedAttachments = seedAttachments;
    notifyListeners();
  }

  void openThread(String threadId) {
    _activeThreadId = threadId;
    _stages = [];
    _seedText = '';
    _seedAttachments = const [];
    notifyListeners();
  }

  void consumeSeed() {
    _seedText = '';
    _seedAttachments = const [];
  }

  /// Kept deliberately short. The context window is not what limits this —
  /// six messages is under 1% of it — answer focus is: past about three turns
  /// a follow-up starts drifting toward the first question rather than the
  /// current one.
  static const _maxHistoryMessages = 6;
  static const _maxHistoryChars = 600;

  /// The prior turns to replay, oldest first.
  ///
  /// Only settled messages: a question whose answer failed still counts as
  /// asked, but an answer that never arrived is not context.
  List<ChatHistoryEntry> _historyFrom(List<ChatMessage> messages) {
    final entries = <ChatHistoryEntry>[];
    for (final message in messages) {
      if (message.role == MessageRole.assistant &&
          message.status != MessageStatus.complete) {
        continue;
      }
      final raw = message.role == MessageRole.user
          ? message.text
          : message.blocks.whereType<TextBlock>().map((b) => b.text).join('\n');
      final text = raw.trim();
      if (text.isEmpty) continue;
      entries.add(
        ChatHistoryEntry(
          role: message.role == MessageRole.user ? 'user' : 'assistant',
          text: text.length > _maxHistoryChars
              ? '${text.substring(0, _maxHistoryChars)}…'
              : text,
        ),
      );
    }
    return entries.length <= _maxHistoryMessages
        ? entries
        : entries.sublist(entries.length - _maxHistoryMessages);
  }

  Future<void> send(
    String text, {
    List<ChatAttachment> attachments = const [],
  }) async {
    final question = text.trim();
    if (question.isEmpty) return;

    final now = DateTime.now().toUtc();
    final thread = activeThread ?? _createThread(question, now);
    // Single-flight per thread, not globally — a busy thread must not stop
    // the user from typing into a different, idle one.
    if (_answeringThreadIds.contains(thread.id)) return;

    // Captured before the new pair is appended: history is what came before
    // this question, never the question itself.
    final history = _historyFrom(thread.messages);

    final userMessage = ChatMessage(
      id: 'm-${now.microsecondsSinceEpoch}-u',
      role: MessageRole.user,
      text: question,
      attachments: attachments,
      createdAt: now,
    );
    final pending = ChatMessage(
      id: 'm-${now.microsecondsSinceEpoch}-a',
      role: MessageRole.assistant,
      createdAt: now,
      status: MessageStatus.sending,
    );

    _replaceThread(
      thread.copyWith(
        messages: [...thread.messages, userMessage, pending],
        updatedAt: now,
      ),
    );
    _answeringThreadIds.add(thread.id);
    _stages = [];
    notifyListeners();

    await _consume(thread.id, pending.id, question, attachments, history);
  }

  /// Re-sends the last question. The failed answer is replaced rather than
  /// appended, so a retry does not leave the thread littered with attempts.
  Future<void> retryLast() async {
    final thread = activeThread;
    if (thread == null || _answeringThreadIds.contains(thread.id)) return;

    final lastUserIndex = thread.messages.lastIndexWhere(
      (m) => m.role == MessageRole.user,
    );
    if (lastUserIndex == -1) throw StateError('No question to retry');
    final lastUser = thread.messages[lastUserIndex];
    // Drop everything after the last question — whatever answer it got,
    // complete or failed — so retrying never leaves the old one behind.
    final trimmed = thread.messages.sublist(0, lastUserIndex + 1);
    // Everything before the question being retried, so a retry sends the same
    // context the original attempt did.
    final history = _historyFrom(thread.messages.sublist(0, lastUserIndex));

    final now = DateTime.now().toUtc();
    final pending = ChatMessage(
      id: 'm-${now.microsecondsSinceEpoch}-a',
      role: MessageRole.assistant,
      createdAt: now,
      status: MessageStatus.sending,
    );

    _replaceThread(
      thread.copyWith(messages: [...trimmed, pending], updatedAt: now),
    );
    _answeringThreadIds.add(thread.id);
    _stages = [];
    notifyListeners();

    await _consume(
      thread.id,
      pending.id,
      lastUser.text,
      lastUser.attachments,
      history,
    );
  }

  /// Drives one request to completion against the thread it was started
  /// for — [threadId] — never against whatever happens to be active when
  /// an event arrives. The user may switch threads while this is in flight;
  /// the answer (or failure) must still land on its own thread.
  Future<void> _consume(
    String threadId,
    String pendingId,
    String question,
    List<ChatAttachment> attachments,
    List<ChatHistoryEntry> history,
  ) async {
    try {
      await for (final event in _http.sendMessage(
        threadId: threadId,
        text: question,
        attachments: attachments,
        history: history,
      )) {
        switch (event) {
          case StageEvent(:final stage):
            _applyStage(threadId, stage);
          case AnswerEvent(:final blocks):
            _completeAnswer(threadId, pendingId, blocks);
        }
        notifyListeners();
      }
    } catch (e) {
      AppLogger.error('Chat answer failed: $e');
      _failAnswer(threadId, pendingId);
    } finally {
      _answeringThreadIds.remove(threadId);
      // Stages are transient UI for whatever thread the user is watching.
      // Only clear them here if that is still this request's thread — a
      // backgrounded thread finishing must not touch what is on screen now.
      if (threadId == _activeThreadId) _stages = [];
      notifyListeners();
      await _persist();
    }
  }

  /// Ignored once the thread it belongs to is no longer the one on screen,
  /// so a backgrounded thread's progress never paints itself onto whatever
  /// thread the user switched to.
  void _applyStage(String threadId, ThinkingStage stage) {
    if (threadId != _activeThreadId) return;
    final index = _stages.indexWhere((s) => s.label == stage.label);
    if (index == -1) {
      _stages = [..._stages, stage];
      return;
    }
    final next = [..._stages];
    next[index] = stage;
    _stages = next;
  }

  void _completeAnswer(
    String threadId,
    String pendingId,
    List<AnswerBlock> blocks,
  ) {
    _updateMessage(
      threadId,
      pendingId,
      (message) =>
          message.copyWith(blocks: blocks, status: MessageStatus.complete),
    );
  }

  void _failAnswer(String threadId, String pendingId) {
    _updateMessage(
      threadId,
      pendingId,
      (message) => message.copyWith(status: MessageStatus.failed),
    );
  }

  /// Looks the thread up by id rather than reading [activeThread], so the
  /// update lands correctly whether or not that thread is still on screen.
  void _updateMessage(
    String threadId,
    String messageId,
    ChatMessage Function(ChatMessage) transform,
  ) {
    final index = _threads.indexWhere((t) => t.id == threadId);
    if (index == -1) return;
    final thread = _threads[index];
    _threads[index] = thread.copyWith(
      messages: thread.messages
          .map((m) => m.id == messageId ? transform(m) : m)
          .toList(),
      updatedAt: DateTime.now().toUtc(),
    );
  }

  ChatThread _createThread(String question, DateTime now) {
    final thread = ChatThread(
      id: 't-${now.microsecondsSinceEpoch}',
      title: question,
      createdAt: now,
      updatedAt: now,
    );
    _threads.insert(0, thread);
    _activeThreadId = thread.id;
    return thread;
  }

  void _replaceThread(ChatThread thread) {
    final index = _threads.indexWhere((t) => t.id == thread.id);
    if (index == -1) {
      _threads.insert(0, thread);
      return;
    }
    _threads[index] = thread;
  }

  Future<void> _persist() async {
    try {
      await _store.save(_currentUserId(), _threads);
    } catch (e) {
      AppLogger.error('Chat history not saved: $e');
    }
  }

  void reset() {
    _threads.clear();
    _activeThreadId = null;
    _stages = [];
    _answeringThreadIds.clear();
    _seedText = '';
    _seedAttachments = const [];
    _suggestions = [];
    notifyListeners();
  }
}

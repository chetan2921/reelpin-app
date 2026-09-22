import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:reelpin/data_models/chat/answer_block.dart';
import 'package:reelpin/data_models/chat/chat_attachment.dart';
import 'package:reelpin/data_models/chat/chat_thread.dart';
import 'package:reelpin/data_models/chat/collection_chat_page.dart';
import 'package:reelpin/data_models/chat/collection_chat_thread.dart';
import 'package:reelpin/data_models/chat/thinking_stage.dart';
import 'package:reelpin/http/chat_http.dart';
import 'package:reelpin/http/collection_chat_http.dart';
import 'package:reelpin/services/cache/content_cache.dart';
import 'package:reelpin/utils/app_logger.dart';
import 'package:reelpin/utils/error_message.dart';

/// One collection's shared AI chat: its conversations, and the one open.
///
/// Unlike the private chat — whose threads live on the device — the server is
/// the only authority here, because several people read and write the same
/// threads. So this holds a cache, not a source of truth: what the device last
/// saw, painted at once on open; optimistic rows while a question is in
/// flight, replaced wholesale once the answer lands; and appended to by the
/// poll in between.
class CollectionChatViewModel extends ChangeNotifier {
  CollectionChatViewModel(
    this._http,
    this.collectionId, {
    Duration pollInterval = const Duration(seconds: 8),
    ContentCache? cache,
  }) : _pollInterval = pollInterval,
       _cache = cache ?? ContentCache.instance;

  final CollectionChatHttp _http;
  final String collectionId;
  final Duration _pollInterval;
  final ContentCache _cache;

  final List<CollectionChatThread> _threads = [];
  String? _activeThreadId;
  final List<ChatMessage> _messages = [];
  List<ThinkingStage> _stages = [];
  bool _isAsking = false;
  bool _isLoading = false;
  String? _error;
  Timer? _poll;
  bool _disposed = false;
  bool _hasLoaded = false;

  /// Most recently active first, for the ASK screen's sidebar.
  List<CollectionChatThread> get threads => List.unmodifiable(_threads);

  /// Null on a new, empty conversation — it gets an id with its first
  /// question.
  String? get activeThreadId => _activeThreadId;
  List<ChatMessage> get messages => List.unmodifiable(_messages);
  List<ThinkingStage> get stages => List.unmodifiable(_stages);
  bool get isAsking => _isAsking;
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// Whether there is anything settled to show, from the device or the
  /// server. Before that an empty thread means "not fetched yet", not "nobody
  /// has asked anything" — and the screen must not say the second when it
  /// means the first.
  bool get hasLoaded => _hasLoaded;

  String get _threadsKey => 'collection_chat_threads_$collectionId';
  String _messagesKey(String threadId) =>
      'collection_chat_${collectionId}_$threadId';

  /// Opens on the most recently active conversation, or on a new, empty one
  /// when the collection has none yet.
  ///
  /// What the device last saw is painted first, without waiting on it, and
  /// the network then replaces it — the same cache-then-refresh the PINS tab
  /// and reel detail use, so reopening after a restart shows the old
  /// conversation at once instead of a spinner.
  Future<void> load() async {
    _error = null;
    _isLoading = true;
    _notify();
    var fetched = false;
    unawaited(_hydrateFromCache(() => fetched));
    try {
      final threads = await _http.fetchThreads(collectionId);
      fetched = true;
      _setThreads(threads);
      _activeThreadId ??= threads.isEmpty ? null : threads.first.id;
    } catch (e) {
      _error = userFacingErrorMessage(e);
      _isLoading = false;
      _hasLoaded = true;
      _notify();
      return;
    }
    if (_activeThreadId == null) {
      _isLoading = false;
      _hasLoaded = true;
      _notify();
      return;
    }
    await _loadActiveThread();
  }

  void openThread(String threadId) {
    if (threadId == _activeThreadId) return;
    _activeThreadId = threadId;
    _messages.clear();
    _stages = [];
    _error = null;
    _hasLoaded = false;
    _notify();
    unawaited(_loadActiveThread());
  }

  /// A fresh, empty conversation. It gets its id, and a place in the sidebar,
  /// when its first question is asked — the same way the private chat does.
  void startNewThread() {
    _activeThreadId = null;
    _messages.clear();
    _stages = [];
    _error = null;
    _isLoading = false;
    _hasLoaded = true;
    _notify();
  }

  /// One poll tick: refreshes the sidebar, then appends whatever is newer than
  /// the last message held in the open thread.
  ///
  /// Failures are swallowed. A dropped tick is invisible and self-correcting,
  /// and putting an error on screen for something the user never asked for
  /// would be worse than being briefly out of date. Skipped entirely while a
  /// question is in flight, since the server has already persisted that
  /// question and appending it would show it twice.
  Future<void> pollOnce() async {
    if (_isAsking) return;
    try {
      _setThreads(await _http.fetchThreads(collectionId));
      final threadId = _activeThreadId;
      if (threadId != null) {
        final after = _messages.isEmpty ? null : _messages.last.id;
        final page = await _http.fetchMessages(
          collectionId,
          threadId: threadId,
          after: after,
        );
        if (threadId == _activeThreadId && page.messages.isNotEmpty) {
          final known = _messages.map((m) => m.id).toSet();
          final fresh = page.messages.where((m) => !known.contains(m.id));
          if (fresh.isNotEmpty) {
            _setMessages(threadId, [..._messages, ...fresh]);
          }
        }
      }
      _notify();
    } catch (e) {
      AppLogger.error('Collection chat: poll failed: $e');
    }
  }

  void startPolling() {
    _poll?.cancel();
    _poll = Timer.periodic(_pollInterval, (_) => unawaited(pollOnce()));
  }

  void stopPolling() {
    _poll?.cancel();
    _poll = null;
  }

  Future<void> ask(
    String text, {
    List<ChatAttachment> attachments = const [],
  }) async {
    final question = text.trim();
    if (question.isEmpty || _isAsking) return;

    final now = DateTime.now().toUtc();
    final stamp = now.microsecondsSinceEpoch;
    final threadId = _activeThreadId ?? 't-$stamp';
    if (_activeThreadId == null) {
      _activeThreadId = threadId;
      _threads.insert(
        0,
        CollectionChatThread(
          id: threadId,
          title: question,
          questionCount: 1,
          updatedAt: now,
        ),
      );
    }

    final pendingId = 'local-$stamp-a';
    // Ids prefixed `local-` so they can never collide with the server's, which
    // is what lets the reload below replace this pair instead of doubling it.
    _messages.addAll([
      ChatMessage(
        id: 'local-$stamp-u',
        role: MessageRole.user,
        text: question,
        attachments: attachments,
        createdAt: now,
      ),
      ChatMessage(
        id: pendingId,
        role: MessageRole.assistant,
        createdAt: now,
        status: MessageStatus.sending,
      ),
    ]);
    _isAsking = true;
    _stages = [];
    _error = null;
    _notify();

    try {
      await for (final event in _http.ask(
        collectionId: collectionId,
        threadId: threadId,
        text: question,
        attachments: attachments,
      )) {
        switch (event) {
          case StageEvent(:final stage):
            _applyStage(stage);
          case AnswerEvent(:final blocks):
            _completePending(pendingId, blocks);
        }
        _notify();
      }
      // The server persisted this pair under its own ids, with the author
      // name resolved. Reloading is how the optimistic rows are replaced
      // rather than duplicated by the next poll.
      _isAsking = false;
      await _reloadQuietly(threadId);
    } catch (e) {
      AppLogger.error('Collection chat: ask failed: $e');
      _error = userFacingErrorMessage(e);
      _failPending(pendingId);
    } finally {
      _isAsking = false;
      _stages = [];
      _notify();
    }
  }

  Future<void> _loadActiveThread() async {
    final threadId = _activeThreadId;
    if (threadId == null) return;
    _isLoading = true;
    _notify();
    var fetched = false;
    unawaited(_hydrateMessages(threadId, () => fetched));
    try {
      final page = await _http.fetchMessages(collectionId, threadId: threadId);
      fetched = true;
      if (threadId != _activeThreadId) return;
      _setMessages(threadId, page.messages);
    } catch (e) {
      if (threadId == _activeThreadId) _error = userFacingErrorMessage(e);
    } finally {
      if (threadId == _activeThreadId) {
        _isLoading = false;
        _hasLoaded = true;
      }
      _notify();
    }
  }

  /// Paints the sidebar and the conversation the device last saw. Ignored once
  /// the network has answered, so a slow disk read never lands on top of
  /// fresher data.
  Future<void> _hydrateFromCache(bool Function() fetched) async {
    final cached = await _cache.read(_threadsKey);
    if (cached == null || fetched() || _disposed) return;
    final threads = CollectionChatThread.listFromJson(cached['threads']);
    if (threads.isEmpty) return;
    _threads
      ..clear()
      ..addAll(threads);
    final threadId = _activeThreadId ??= threads.first.id;
    _notify();
    await _hydrateMessages(threadId, () => false);
  }

  Future<void> _hydrateMessages(
    String threadId,
    bool Function() fetched,
  ) async {
    final cached = await _cache.read(_messagesKey(threadId));
    if (cached == null || fetched() || _disposed) return;
    if (threadId != _activeThreadId || _messages.isNotEmpty) return;
    _messages.addAll(CollectionChatPage.fromJson(cached).messages);
    _hasLoaded = true;
    _notify();
  }

  /// Replaces the thread and the sidebar without raising the loading flag —
  /// used after a write, where a spinner over content already on screen is a
  /// regression.
  Future<void> _reloadQuietly(String threadId) async {
    try {
      final page = await _http.fetchMessages(collectionId, threadId: threadId);
      final threads = await _http.fetchThreads(collectionId);
      _setThreads(threads);
      if (threadId == _activeThreadId) _setMessages(threadId, page.messages);
      _notify();
    } catch (e) {
      AppLogger.error('Collection chat: reload failed: $e');
    }
  }

  void _setThreads(List<CollectionChatThread> threads) {
    _threads
      ..clear()
      ..addAll(threads);
    unawaited(
      _cache.write(_threadsKey, {
        'threads': [for (final thread in threads) thread.toJson()],
      }),
    );
  }

  void _setMessages(String threadId, List<ChatMessage> messages) {
    _messages
      ..clear()
      ..addAll(messages);
    unawaited(
      _cache.write(_messagesKey(threadId), {
        'messages': [for (final message in messages) _messageJson(message)],
      }),
    );
  }

  /// [ChatMessage.toJson] is the private chat's storage format, which has no
  /// author or source; a collection's cached messages need both to read back
  /// the way the server sent them.
  static Map<String, dynamic> _messageJson(ChatMessage message) => {
    ...message.toJson(),
    'author_name': message.authorName,
    'source': message.isShared ? 'shared' : 'live',
  };

  void _applyStage(ThinkingStage stage) {
    final index = _stages.indexWhere((s) => s.label == stage.label);
    if (index == -1) {
      _stages = [..._stages, stage];
      return;
    }
    final next = [..._stages];
    next[index] = stage;
    _stages = next;
  }

  void _completePending(String pendingId, List<AnswerBlock> blocks) => _replace(
    pendingId,
    (m) => m.copyWith(blocks: blocks, status: MessageStatus.complete),
  );

  void _failPending(String pendingId) =>
      _replace(pendingId, (m) => m.copyWith(status: MessageStatus.failed));

  void _replace(String id, ChatMessage Function(ChatMessage) transform) {
    final index = _messages.indexWhere((m) => m.id == id);
    if (index == -1) return;
    _messages[index] = transform(_messages[index]);
  }

  /// A poll tick can outlive the screen; notifying a disposed
  /// ChangeNotifier throws.
  void _notify() {
    if (_disposed) return;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    stopPolling();
    super.dispose();
  }
}

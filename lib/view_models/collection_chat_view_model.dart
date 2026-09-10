import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:reelpin/data_models/chat/answer_block.dart';
import 'package:reelpin/data_models/chat/chat_thread.dart';
import 'package:reelpin/data_models/chat/thinking_stage.dart';
import 'package:reelpin/http/chat_http.dart';
import 'package:reelpin/http/collection_chat_http.dart';
import 'package:reelpin/utils/app_logger.dart';
import 'package:reelpin/utils/error_message.dart';

/// One collection's shared AI thread.
///
/// Unlike the private chat — whose threads live on the device — the server is
/// the only authority here, because several people read and write the same
/// thread. So this holds a cache, not a source of truth: optimistic rows
/// while a question is in flight, replaced wholesale once the answer lands,
/// and appended to by the poll in between.
class CollectionChatViewModel extends ChangeNotifier {
  CollectionChatViewModel(
    this._http,
    this.collectionId, {
    Duration pollInterval = const Duration(seconds: 8),
  }) : _pollInterval = pollInterval;

  final CollectionChatHttp _http;
  final String collectionId;
  final Duration _pollInterval;

  final List<ChatMessage> _messages = [];
  List<ThinkingStage> _stages = [];
  bool _isAsking = false;
  bool _isLoading = false;
  String? _error;
  Timer? _poll;
  bool _disposed = false;
  bool _hasLoaded = false;

  List<ChatMessage> get messages => List.unmodifiable(_messages);
  List<ThinkingStage> get stages => List.unmodifiable(_stages);
  bool get isAsking => _isAsking;
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// Whether a load has finished at least once, successfully or not. Before
  /// that an empty thread means "not fetched yet", not "nobody has asked
  /// anything" — and the screen must not say the second when it means the
  /// first.
  bool get hasLoaded => _hasLoaded;

  Future<void> load() async {
    _isLoading = true;
    _error = null;
    _notify();
    try {
      final page = await _http.fetchMessages(collectionId);
      _messages
        ..clear()
        ..addAll(page.messages);
    } catch (e) {
      _error = userFacingErrorMessage(e);
    } finally {
      _isLoading = false;
      _hasLoaded = true;
      _notify();
    }
  }

  /// One poll tick: appends whatever is newer than the last message held.
  ///
  /// Failures are swallowed. A dropped tick is invisible and self-correcting,
  /// and putting an error on screen for something the user never asked for
  /// would be worse than being briefly out of date. Skipped entirely while a
  /// question is in flight, since the server has already persisted that
  /// question and appending it would show it twice.
  Future<void> pollOnce() async {
    if (_isAsking) return;
    try {
      final after = _messages.isEmpty ? null : _messages.last.id;
      final page = await _http.fetchMessages(collectionId, after: after);
      if (page.messages.isEmpty) return;
      final known = _messages.map((m) => m.id).toSet();
      final fresh = page.messages.where((m) => !known.contains(m.id)).toList();
      if (fresh.isEmpty) return;
      _messages.addAll(fresh);
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

  Future<void> ask(String text) async {
    final question = text.trim();
    if (question.isEmpty || _isAsking) return;

    final now = DateTime.now().toUtc();
    final stamp = now.microsecondsSinceEpoch;
    final pendingId = 'local-$stamp-a';
    // Ids prefixed `local-` so they can never collide with the server's, which
    // is what lets the reload below replace this pair instead of doubling it.
    _messages.addAll([
      ChatMessage(
        id: 'local-$stamp-u',
        role: MessageRole.user,
        text: question,
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
        text: question,
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
      await _reloadQuietly();
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

  /// Replaces the thread without raising the loading flag — used after a
  /// write, where a spinner over content already on screen is a regression.
  Future<void> _reloadQuietly() async {
    try {
      final page = await _http.fetchMessages(collectionId);
      _messages
        ..clear()
        ..addAll(page.messages);
      _notify();
    } catch (e) {
      AppLogger.error('Collection chat: reload failed: $e');
    }
  }

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

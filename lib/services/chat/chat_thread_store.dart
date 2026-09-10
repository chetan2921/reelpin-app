import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'package:reelpin/data_models/chat/chat_thread.dart';
import 'package:reelpin/utils/app_logger.dart';

/// Chat history on disk, stamped with the user id that wrote it.
///
/// The stamp lives inside the same envelope as the payload — one key, one
/// write — the same shape `ContentCache` uses and for the same reason: a
/// stamp and payload written as two separate keys can be torn apart by a
/// crash mid-write (backgrounded and killed, disk pressure), leaving a stamp
/// that names the new user over a payload that still holds the previous
/// user's threads. `load` would then trust the stamp and leak that account's
/// conversations into the new one. Keeping them in one key makes that
/// impossible: they always agree, because they are written together.
class ChatThreadStore {
  ChatThreadStore({SharedPreferences? preferences})
    : _preferences = preferences;

  static const _threadsKey = 'chat_threads_v1';

  final SharedPreferences? _preferences;

  Future<SharedPreferences> get _prefs async =>
      _preferences ?? await SharedPreferences.getInstance();

  Future<List<ChatThread>> load(String userId) async {
    final prefs = await _prefs;
    final raw = prefs.getString(_threadsKey);
    if (raw == null || raw.isEmpty) return const [];

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return const [];
      final envelope = Map<String, dynamic>.from(decoded);
      // A payload saved by a different account must never be shown.
      if (envelope['user_id'] != userId) return const [];

      final threads = envelope['threads'];
      if (threads is! List) return const [];
      return threads
          .whereType<Map<String, dynamic>>()
          .map(ChatThread.fromJson)
          .toList();
    } catch (e) {
      // A snapshot we cannot read is worth less than a working history list.
      AppLogger.error('Chat thread snapshot discarded: $e');
      return const [];
    }
  }

  Future<void> save(String userId, List<ChatThread> threads) async {
    final prefs = await _prefs;
    await prefs.setString(
      _threadsKey,
      jsonEncode({
        'user_id': userId,
        'threads': threads.map((t) => t.toJson()).toList(),
      }),
    );
  }

  Future<void> clear() async {
    final prefs = await _prefs;
    await prefs.remove(_threadsKey);
  }
}

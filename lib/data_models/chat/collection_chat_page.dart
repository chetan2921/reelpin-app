import 'package:reelpin/data_models/chat/chat_thread.dart';

/// One slice of a collection's shared thread, oldest first.
///
/// There is no cursor here on purpose: the client polls with `after=<last
/// id>` and appends, so "the next page" is always just "whatever is newer
/// than what I already have".
class CollectionChatPage {
  final List<ChatMessage> messages;

  const CollectionChatPage({this.messages = const []});

  factory CollectionChatPage.fromJson(Map<String, dynamic> json) {
    final raw = json['messages'];
    if (raw is! List) return const CollectionChatPage();
    return CollectionChatPage(
      messages: raw
          .whereType<Map>()
          .map((m) => ChatMessage.fromJson(Map<String, dynamic>.from(m)))
          .toList(),
    );
  }
}

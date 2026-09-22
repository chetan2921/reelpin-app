import 'package:reelpin/data_models/chat/answer_block.dart';
import 'package:reelpin/data_models/chat/chat_attachment.dart';
import 'package:reelpin/data_models/chat/collection_chat_page.dart';
import 'package:reelpin/data_models/chat/collection_chat_thread.dart';
import 'package:reelpin/http/chat_http.dart';

/// The seam between a collection's shared AI chat and whatever answers it.
///
/// A collection holds several conversations (threads), like the private chat
/// does. [ask] returns the same [ChatEvent] stream the private chat consumes,
/// and for the same reason: the backend speaks one SSE protocol for both, so
/// the stream parser and every rendering component are shared rather than
/// duplicated.
abstract interface class CollectionChatHttp {
  /// The collection's conversations, most recently active first.
  Future<List<CollectionChatThread>> fetchThreads(String collectionId);

  /// One thread, oldest first. [after] asks for only what is newer than that
  /// message id — how the poll fetches without refetching the whole log.
  Future<CollectionChatPage> fetchMessages(
    String collectionId, {
    required String threadId,
    String? after,
  });

  Stream<ChatEvent> ask({
    required String collectionId,
    required String threadId,
    required String text,
    List<ChatAttachment> attachments,
  });

  /// Publishes an answer generated in the user's private chat into the
  /// collection, verbatim. No model call happens — the answer already exists.
  Future<void> shareAnswer({
    required String collectionId,
    required String threadId,
    required String questionText,
    required List<AnswerBlock> blocks,
  });

  Future<void> deleteMessage({
    required String collectionId,
    required String messageId,
  });
}

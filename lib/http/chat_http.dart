import 'package:reelpin/data_models/chat/answer_block.dart';
import 'package:reelpin/data_models/chat/chat_attachment.dart';
import 'package:reelpin/data_models/chat/thinking_stage.dart';

/// Everything the assistant emits while answering: progress lines first, then
/// exactly one answer.
sealed class ChatEvent {
  const ChatEvent();
}

class StageEvent extends ChatEvent {
  final ThinkingStage stage;

  const StageEvent(this.stage);
}

class AnswerEvent extends ChatEvent {
  final List<AnswerBlock> blocks;

  const AnswerEvent(this.blocks);
}

/// One prior turn, replayed to the backend so a follow-up — "compare those
/// two", "what about the second one" — can be resolved against what was
/// already said.
///
/// The client is the only thing that can supply this: private threads live on
/// this device and the server has never seen them. Text only, on purpose —
/// the answer's blocks (reel ids, tables, charts) cost tokens and add nothing
/// the model needs to follow a reference.
class ChatHistoryEntry {
  /// `user` or `assistant`, matching the wire vocabulary rather than
  /// [MessageRole], since this only ever exists to be serialised.
  final String role;
  final String text;

  const ChatHistoryEntry({required this.role, required this.text});

  Map<String, dynamic> toJson() => {'role': role, 'text': text};
}

/// The single seam between the chat UI and whatever answers it.
///
/// Deliberately minimal: the backend contract does not exist yet, so there is
/// nothing here to guess wrong. Returning a Stream costs nothing today — the
/// mock emits stages on timers — but means that if the real backend ships
/// server-sent events, no code above this interface changes.
abstract interface class ChatHttp {
  Stream<ChatEvent> sendMessage({
    required String threadId,
    required String text,
    List<ChatAttachment> attachments,
    List<ChatHistoryEntry> history,
  });

  /// Suggested questions for the empty chat screen, personalized to what the
  /// user has actually saved. An empty list means "nothing to suggest" —
  /// callers fall back to their own generic prompts rather than showing
  /// nothing, the same way a dropped block type degrades gracefully.
  Future<List<String>> fetchSuggestions();
}

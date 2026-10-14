import 'package:reelpin/data_models/chat/chat_thread.dart';
import 'package:reelpin/http/api_exception.dart';

/// The status an answer ends in when its request threw [error]. The two daily
/// caps get cards of their own; anything else is a plain failure with RETRY.
MessageStatus statusForChatError(Object error) {
  if (error is ApiException) {
    if (error.isChatQuotaExceeded) return MessageStatus.limitReached;
    if (error.isChatFairUseLimit) return MessageStatus.capReached;
  }
  return MessageStatus.failed;
}

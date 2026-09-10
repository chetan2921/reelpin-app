/// Whether the chat tab exists in this build.
///
/// Defaults to false so a build carrying [MockChatHttp] — which answers with
/// fabricated content — cannot reach the store. Test builds opt in:
/// `tool/reelpin.sh apk-dev --dart-define=CHAT_ENABLED=true`.
const bool chatEnabled = bool.fromEnvironment('CHAT_ENABLED');

# Share intake

How a link shared from another app reaches the server. This file is an
identical copy in both repos at `.claude/contracts/share-intake.md`; change both
together.

| Side | Where the truth lives |
|------|-----------------------|
| server enqueue | reelpin-api `enqueue_reel_processing` in `app/main.py` (`POST /api/v1/processing-jobs/reels`): takes `url` or `raw_payload_text`, plus `collection_ids`; Bearer token or `X-Share-Token` |
| server URL choice | reelpin-api `app/services/display_data.py` (`extract_url_candidates`, `select_primary_url`), then `app/services/source_identity.py` |
| server resolve | reelpin-api `resolve_share` in `app/main.py` (`POST /api/v1/share/resolve`) |
| server share tokens | reelpin-api `POST` and `DELETE /api/v1/share-tokens` in `app/main.py`; check in `app/services/auth.py` (raises `invalid_share_token`) |
| client Android | reelpin-app `android/app/src/main/kotlin/com/chetanjain/reelpin/`: `ShareReceiverActivity.kt`, `ShareEnqueueService.kt`, `ShareIntentParser.kt`, `MainActivity.kt` (method channels) |
| client iOS | reelpin-app `ios/Share Extension/ShareViewController.swift`, `ios/Share Extension/ShareUrlExtractor.swift`, `ios/Runner/AppDelegate.swift` (method channels) |
| client Flutter | reelpin-app `lib/screens/app_shell/app_shell.dart` (drains pending native shares, then resolve and enqueue), `lib/data_models/sharing/pending_share.dart` (reads either platform's pending entry), `lib/services/sharing/share_handoff_service.dart` (mirrors share token, base URL, push token, and collections into native storage), `lib/view_models/session_view_model.dart` (mints the share token) |

## Rule

On Android and iOS a share never goes through Flutter first. Native code posts
straight to the enqueue route with `X-Share-Token`, and only a failed post is
stored as pending for Flutter to drain on the next launch or resume. The native
side branches on the response: 2xx, 400, 401 or 403 with `invalid_share_token`
in the body, and 429. A change to the payload, the token, those status codes, or
the pending-entry shape has to land in Kotlin, Swift, Dart, and the server
together. The method channel names and native storage keys must match across
Dart, Kotlin, and Swift inside reelpin-app.

The two platforms store pending entries differently: Android `{raw_payload_text, collection_ids}`, iOS `{url, collection_ids}`. `PendingShare.fromNative` reads both, plus a bare string from older builds. Until 2026-10-16 the drain read only `raw_payload_text`, so every iOS pending share was dropped.

## Known drift when this was written (2026-10-15; read from code, not run)

- After `invalid_share_token`, native code clears its token but Flutter keeps the old one and pushes it back to native, so the token may never be re-minted.

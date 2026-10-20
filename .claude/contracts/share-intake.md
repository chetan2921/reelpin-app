# Share intake

How a link shared from another app reaches the server. This file is an
identical copy in both repos at `.claude/contracts/share-intake.md`; change both
together.

| Side | Where the truth lives |
|------|-----------------------|
| server native enqueue | reelpin-go `handleNativeShare` in `internal/httpapi/enqueue.go` (`POST /api/v2/native-shares/reels`): takes `raw_payload_text` plus `collection_ids`, requires `X-Share-Token` and `Idempotency-Key`; token check in `internal/httpapi/sharetoken.go` |
| server enqueue | reelpin-api `enqueue_reel_processing` in `app/main.py` (`POST /api/v1/processing-jobs/reels`): takes `url` or `raw_payload_text`, plus `collection_ids`; Bearer token or `X-Share-Token` |
| server URL choice | reelpin-api `app/services/display_data.py` (`extract_url_candidates`, `select_primary_url`), then `app/services/source_identity.py` |
| server resolve | reelpin-api `resolve_share` in `app/main.py` (`POST /api/v1/share/resolve`) |
| server share tokens | reelpin-api `POST` and `DELETE /api/v1/share-tokens` in `app/main.py`; check in `app/services/auth.py` (raises `invalid_share_token`) |
| client Android | reelpin-app `android/app/src/main/kotlin/com/chetanjain/reelpin/`: `ShareReceiverActivity.kt`, `ShareEnqueueService.kt`, `ShareIntentParser.kt`, `MainActivity.kt` (method channels) |
| client iOS | reelpin-app `ios/Share Extension/ShareViewController.swift`, `ios/Share Extension/ShareUrlExtractor.swift`, `ios/Runner/AppDelegate.swift` (method channels) |
| client Flutter | reelpin-app `lib/screens/app_shell/app_shell.dart` (drains pending native shares, then resolve and enqueue), `lib/data_models/sharing/pending_share.dart` (reads either platform's pending entry), `lib/services/sharing/share_handoff_service.dart` (mirrors share token, base URL, push token, and collections into native storage), `lib/view_models/session_view_model.dart` (mints the share token) |

## Rule

On Android and iOS a share never goes through Flutter first. Native code posts
straight to `POST /api/v2/native-shares/reels` with `X-Share-Token` and a new
`Idempotency-Key` per attempt (Android mints it when the job is queued, so a
redelivered job reuses it), and only a failed post is stored as pending for
Flutter to drain on the next launch or resume. The native side branches on the
response: 2xx (`200` reel ready, `202` job queued or already in flight), `401`
with `error.code` `invalid_share_token` or `share_token_required`, and on
Android also `422 validation_error` with `details.field` `url` (unsupported
link) and `429` (`rate_limited` or `active_job_limit`). Neither extension
registers the push token; the app does that with its own session. A change to the payload, the token, those status codes, or
the pending-entry shape has to land in Kotlin, Swift, Dart, and the server
together. The method channel names and native storage keys must match across
Dart, Kotlin, and Swift inside reelpin-app.

The two platforms store pending entries differently: Android `{raw_payload_text, collection_ids}`, iOS `{url, collection_ids}`. `PendingShare.fromNative` reads both, plus a bare string from older builds. The app TikTok branch includes this decoder because its dev baseline still read only `raw_payload_text` and dropped iOS pending shares.

## Known drift when this was written (2026-10-15; read from code, not run)

- After `invalid_share_token`, native code clears its token but Flutter keeps the old one and pushes it back to native, so the token may never be re-minted.

## TikTok intake

Keep HTTP(S) links and caption-plus-link text in the existing payload. Native
parsers do not normalize post identity or require TikTok to be installed.
Resolver coverage includes video/photo, vm/vt and /t short links, share/video,
embed/player, and legacy tiktokv/mobile aliases. Query parameters remain in
native payloads; the server chooses the canonical post identity. The API runs
resolution off the event loop; short expansion uses the existing safe redirect
helper with a 1.5-second budget and a bounded success cache. Slow requests still
use the native pending/retry flow and server deduplication.

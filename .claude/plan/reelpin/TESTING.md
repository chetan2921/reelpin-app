# reelpin testing: reelpin-app

reelpin-api keeps its own `TESTING.md`.

## Run

| What | Command |
|------|---------|
| all Dart tests | `flutter test` |
| one file | `flutter test test/http/api_client_test.dart` |
| the full gate CI runs | `tool/reelpin.sh verify` (format check, `verify_project`, `check_architecture`, `check_assets`, `flutter analyze`, `flutter test`) |
| Android native | `ShareIntentParserTest.kt` under `android/app/src/test/`, run from Android Studio or Gradle |
| iOS native | `RunnerTests` in Xcode (share URL extractor and response classifier) |

Tests need no dart-defines. CI (`validate.yml`) runs the same gate minus
`verify_project` on every PR into `dev` and every push to `dev`.

## Known-good examples

- HTTP with a fake client, including the 401 renew-and-resend: `test/http/api_client_test.dart`
- SSE streaming: `test/http/chat_api_http_test.dart`
- View model with a fake repository or API: `test/view_models/processing_jobs_view_model_test.dart`, `test/view_models/collections_view_model_test.dart`
- Widget test with provider overrides: `test/screens/home/home_filter_sheet_test.dart`, `test/screens/home/home_empty_state_test.dart`
- Repository and disk cache: `test/repositories/reel_repository_cache_test.dart`, `test/services/cache/content_cache_test.dart`

## Strategies that work here

- No mocktail or mockito. Write hand-rolled `_Fake*` classes that extend `ApiClient`, `ReelRepository`, `AuthService`, or `SessionViewModel`, or implement a `*Http` interface.
- `ReelRepository` takes the concrete `ApiClient`, so its fakes must subclass `ApiClient`.
- For raw HTTP use `MockClient` and `MockClient.streaming` from `package:http/testing.dart`.
- `SharedPreferences.setMockInitialValues` for preferences, `ContentCache.forTesting` for the disk cache, `ProviderScope(overrides: [...])` for widget tests, and mocked method channels for native calls.
- `test/` mirrors `lib/`; put a new test at the matching path.

## Inventory

| Area | Unit | Integration | E2E | Notes |
|------|------|-------------|-----|-------|
| `lib/http`, data models, repositories, utils | yes | no | no | fake clients |
| view models | most | no | no | not Entitlements, ReelDetail, Folders |
| components and screens | some | no | no | widget tests with overrides |
| sharing services | partial | no | no | collections sync, links, push registration |
| native share (Kotlin, Swift) | parser and classifier only | no | no | |

## Gaps

- `EntitlementsViewModel`, `ReelDetailViewModel`, `FoldersViewModel`.
- `AppShell`: complete native drain lifecycle, deep-link routing, and resume throttle. PendingShare now has decoder tests, but full native-to-Flutter recovery has no integration test.
- `AuthenticatedShell`: push retry and notification routing.
- `AuthService`, `ProfileService`, `NotificationService`, `LocationService`, `AnalyticsService`, `AppUpdateService`, `PendingDeepLink`, and `ShareHandoffService` beyond the collections sync.
- Screens: auth, profile, paywall, map, discover.
- The native `ShareEnqueueService` and `ShareReceiverActivity` flows and the iOS `ShareViewController` flow.
- No `integration_test/`.

## TikTok checks (2026-10-18)

- `test/constants/source_platforms_test.dart`: registry/artwork, content-type
  nouns, legacy URLs, and lookalike host rejection.
- `test/data_models/sharing/pending_share_test.dart`: Android raw text, iOS URL,
  legacy strings, blank/invalid entries, and retained selected collections.
- Existing home-empty-state, processing-card, and reel-share-card widget tests
  cover TikTok hints/badges and VIDEO/POST/LINK wording, including older photos.
- `tool/reelpin.sh verify` passed all checks and 516 Dart tests. No new package
  was added. `android/gradlew :app:testDebugUnitTest` passed 3 JVM parser tests,
  including the TikTok link-family fixture. Swift RunnerTests passed 8 tests in
  a macOS XCTest bundle built from the actual Foundation extractor/classifier
  and RunnerTests sources, including 14 TikTok raw-share URL cases.
- Swift parser tests do not exercise the iOS share extension UI, App Group,
  network enqueue, APNs, or an installed dev build. Android JVM tests likewise
  do not exercise ShareReceiverActivity/ShareEnqueueService on a phone.
- Remaining device/live acceptance is in IMPLEMENTATION.md. Copied links from
  Notes/browser can test intake without local TikTok; real TikTok sharing and
  backend connectivity are separate checks. No device-cloud result is claimed.

## Dev acceptance checkpoint (2026-10-18)

App PRs 22 and 23 and backend PRs 36, 37, and 38 merged into dev. Backend
readiness/deployment passed. Live testing first exposed About-page false saves
and missing parse_status in detail/job responses; the backend fixes are deployed
and the shared contracts match. No app runtime change was needed for parse_status.

Post-fix live checks: seven unique TikTok jobs failed, four with auth_failure
and three with provider_timeout after three attempts. No TikTok saves were
created. Video transcription, photo cover OCR, search, collection filing, and
completion pushes are still unvalidated because retrieval did not succeed.

A temporary headless Flutter test used the real ApiClient, real HTTP transport,
explicit dev base URL, and the dedicated test account. Both tests passed: all
17 URL shapes resolved as supported TikTok links; the client decoded seven
terminal failures and an empty TikTok feed. Shapes cover video/photo, tracking,
bare HTTP, username-less posts, share, legacy tiktokv/mobile HTML, embed/player,
vm/vt/t short links, and a profile. Short redirects retain their original URL
when TikTok sends them to an About page. This does not mean content was saved.

Local verify passes all 516 Dart tests. A pre-existing collections test cleanup
race failed twice in merged-dev CI with Directory not empty: background cache
writes were still running when teardown deleted their directory. The test-only
cache wrapper now drains pending writes before deletion. All 35 collection
tests and the complete verify gate pass. Production cache code is unchanged.

The initial dev APK runner ran out of disk. Freeing unused temporary-runner
toolchains fixed it: the merged-dev APK workflow passed, as did a local debug
APK built with the explicit dev API override. Hosting is unchanged.

The user stopped the emulator and requested headless checks only. No emulator
or real-device extension/activity test passed. Earlier native unit checks are
Android 3 and Swift 8; real TikTok sharing, UI, and push behavior remain untested.
All 25 original app edits are preserved; main and hosting are unchanged.

<!-- mapped: reelpin-app@dbee86b | paths: .github/workflows/, test/, tool/, android/app/src/test/, ios/RunnerTests/ -->

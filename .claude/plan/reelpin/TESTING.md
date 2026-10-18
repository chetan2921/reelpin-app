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

App PR 22 and backend PR 36 merged into dev. Merged-dev app validation passed.
Backend deployment/readiness passed, but authenticated live link tests exposed
TikTok redirects to About pages and a dropped unparsed flag in job/detail reads.
The backend follow-up restores the existing parse_status contract; the Dart
model already reads and round-trips it, so no app runtime change is needed.
The original user's 25 modified/untracked app files remain untouched. No mobile
device is connected; the native extension/activity-to-worker path is not tested.
The dev APK build and post-fix live results will be recorded when available.

<!-- mapped: reelpin-app@a042be9 | paths: test/, tool/, android/app/src/test/, ios/RunnerTests/ -->

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
- API payloads: `test/fixtures/api_v2/` holds verbatim copies of reelpin-go `api/fixtures/`, read through `ApiV2Fixture` in `test/fixtures/api_v2.dart`. Use them wherever a payload shape matters, and re-copy them when the Go contract moves.
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
| view models | most | no | no | not Entitlements, ReelDetail |
| components and screens | some | no | no | widget tests with overrides |
| sharing services | partial | no | no | collections sync, links, push registration |
| native share (Kotlin, Swift) | parser and classifier only | no | no | |

## Gaps

- `EntitlementsViewModel`, `ReelDetailViewModel`.
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

Before the provider fallback, seven unique TikTok jobs failed, four with auth_failure
and three with provider_timeout after three attempts. No TikTok saves were
created. Video transcription, photo cover OCR, search, collection filing, and
completion pushes were unvalidated at that checkpoint; the successful
retrieval follow-up is recorded below.

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

The backend retrieval follow-up reuses the existing Apify provider for blocked
public posts and unresolved short links. Models, share payloads, polling, and
one-cover photo OCR stay the same. Backend PRs 39 and 40 are deployed to dev;
no app runtime code changes are needed for this fallback.

## Successful headless dev checks (2026-10-19)

Five valid-post processing jobs complete with three unique parsed saves: a
canonical video, a photo, and a newer public vt share. Derived vm and /t variants
of that working share resolve to the same numeric post and saved item. All eight test jobs are terminal: five valid jobs complete, two old short
samples are reported unavailable/private, and one old sample exhausts three
bounded attempts. Failed samples create no false saved content.

The real ApiClient passes URL recognition for all 19 tested shapes, completed
job/detail/feed decoding for the three saves, five legacy/mobile/embed/player
alias dedupe checks, selected-collection filing for video and photo, and short
family dedupe. Deployed v2/locale embed aliases reuse both the existing video
and photo saves. Six real-client headless tests pass. The temporary collection was deleted; valid test saves remain.
The photo has one-cover OCR, and stored video/photo thumbnails return HTTP 200.
The new photo is returned by dev search.

A live polling test overlapped the dev restart and received HTTP 502; its
post-deployment replacement passed. A separate temporary harness initially hit
its default aggregate 30-second limit across sequential real HTTP calls; the
same checks passed with a two-minute test limit. App request timeouts are
unchanged. The full app suite remains 516 passing tests in CI. No emulator was
started; device UI, real TikTok share sheets, and completion push delivery remain
untested. Main, hosting, and all 25 original app edits remain unchanged.

## Account-switch privacy regressions (2026-10-28)

`collections_view_model_test.dart` resets through the actual coordinator provider
and holds list, detail, pagination, cache, and create requests across an account
change. Old responses must not restore content, write cache, or finish the next
account's loading future. The native handoff tests cover sign-out, direct user
switches, and delayed artwork; the session tests hold a share-token mint across
sign-out. The collection picker preference survives clearing its account data.

## Request ownership across account changes (2026-10-28)

`api_client_test.dart` holds account deletion across a user change before its
401 or during renewal. Neither request may replay under the next account.
Malformed token subjects and sign-out also block replay; same-account renewal
and submission idempotency remain covered. Disk-cache tests switch accounts
before a successful response and at cache write time, so old payloads cannot be
stamped with a new owner. A queued-write test checks the original owner stamp
and that a later account write wins. Profile widget tests hold statistics across account
changes and check that already rendered statistics are cleared too.

<!-- mapped: reelpin-app@3ad2d5d plus uncommitted changes | paths: .github/workflows/, test/, tool/, android/app/src/test/, ios/RunnerTests/ -->

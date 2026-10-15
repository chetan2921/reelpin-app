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
- Wiring through the real providers, faking only one HTTP layer with `ProviderContainer(overrides: ...)`: `test/view_models/user_state_coordinator_test.dart`
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
- `AppShell`: deep-link routing, the resume throttle, and the drain loop itself (the entry parsing is tested in `test/data_models/sharing/pending_share_test.dart`). The untested drain is how the iOS pending-share drop went unnoticed.
- `AuthenticatedShell`: push retry and notification routing.
- `AuthService`, `ProfileService`, `NotificationService`, `LocationService`, `AnalyticsService`, `AppUpdateService`, `PendingDeepLink`, and `ShareHandoffService` beyond the collections sync.
- Screens: auth, profile, paywall, map, discover.
- The native `ShareEnqueueService` and `ShareReceiverActivity` flows and the iOS `ShareViewController` flow.
- No `integration_test/`.

<!-- mapped: reelpin-app@8bd45ed | paths: test/, tool/, android/app/src/test/, ios/RunnerTests/ -->

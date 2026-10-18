# reelpin implementation: reelpin-app

This file tracks reelpin-app only; reelpin-api keeps its own. Two people work
here, so every in-flight item names its owner and branch.

## Now

- `dev` @ `05094ba` is version `1.0.17+23`. It carries chat (ASK tab, collection chat threads, the taste suggestions block) behind `CHAT_ENABLED`; the store build on `main` was promoted without chat through `promote/*` cherry-picks. Chat is parked as of 2026-10-15: not shipping, no new work.
- On GitHub but not on `dev`: `feature/paywall` (chetan2921, last commit 2026-10-14) sells Pro through a RevenueCat paywall. It pairs with reelpin-api's `user_entitlements` table, where Pro is granted by hand until this ships.


### TikTok support (dev acceptance 2026-10-18)

Owner: Chetan. App PRs 22 and 23 merged into dev; backend PRs 36, 37, and 38 deployed to dev.
Retrieval follow-up notes/contracts: `codex/tiktok-retrieval-contracts`.
The backend now has an existing-provider Apify fallback for blocked public posts;
its live dev validation is pending. No app runtime change is needed.
Work lives in an isolated checkout; the user's original rate/support changes
are preserved. No main change, hosting change, or production release.
Backend scope and the complete URL matrix are in reelpin-api's implementation
plan and the shared contracts.

Implemented: TikTok registry entry and artwork; platform badges and onboarding/
home hints; VIDEO/POST/LINK wording in saved cards, detail actions, and share
cards; legacy URL fallback; native caption-plus-link parser fixtures; pending
share decoder for Android raw payloads, iOS URLs, and legacy strings, preserving
collection ids. Existing native storage, tokens, request shape, job polling,
models, collections, and push flow stay in place. Photos process only the cover
on the backend; non-post pages save readable public metadata.

Local checks passed: `tool/reelpin.sh verify` including 516 Dart tests, Android
Gradle unit tests (3), and Swift Foundation/XCTest parser/classifier tests (8).
These checks do not establish real-device extension or live TikTok connectivity.
See TESTING.md for covered cases and remaining gaps.

- [x] User confirmed the original dev merges; both PRs are merged.
- [x] Repeat live checks after the backend landing-redirect and unparsed-response fixes. Seven unique jobs reached terminal failure: four auth failures and three exhausted short-link retries; zero saved TikTok items. No false About-page save.
- [x] Run the real Dart API client headlessly against dev: all 17 tested URL shapes accepted, seven failed jobs decoded, and the TikTok feed empty. The user requested no emulator.
- [x] Build Android for dev locally and in CI after freeing unused temporary-runner toolchains. Fix the test-only collection cache teardown race; all 516 app tests pass locally.
- [ ] Run a dev build with the same Mumbai dev API/worker. Share full video/photo,
  vm/vt, /t, share, embed/player, legacy, and page links from Notes/browser.
  Inspect completed saves, summary/transcript, single-cover OCR, stable thumbnail,
  full/short dedupe, collections, platform filtering/search, and push navigation.
  Blocked on successful TikTok retrieval from the existing Mumbai connection.
  Link acceptance alone does not establish successful content ingestion.
- [ ] Exercise slow/offline enqueue, lost responses, relaunch/resume recovery,
  selected collections, and current invalid-token behavior. Inspect small-screen
  layouts with seven platforms and missing-thumbnail/unparsed/failure states.
- [ ] Test native TikTok sharing on real Android and iOS devices remotely when
  available. Verify both apps, network, iOS extension/App Group, and push support
  before choosing a device cloud. This is separate from sharing copied links.
- [ ] Verify open-original behavior separately from stored thumbnail rendering.
  Local TikTok network probes timed out; neither live ingestion nor device
  sharing has passed yet. Backend network access still governs retrieval.
- [ ] Stop at dev validation. Leave main, production config/store releases,
  hosting, and existing dev/main divergence untouched.

## Next

- TikTok is the selected next milestone above, through a feature branch and `dev` only. Production promotion and existing dev/main divergence are outside this task.
- Known defects, none started (read from code, not run). The collection sign-out defect is live in the store build too:
  - Collections survive a sign-out into another account (`AGENTS.md` sharp edge 10).
  - A stale share token survives `invalid_share_token` (`.claude/contracts/share-intake.md`).
  - The backend never sends the plan-limit error codes the app waits for (`.claude/contracts/shared-values.md`).
- Open PRs into `dev` from 2026-08-04, both by XploY04: 9 (`collections`) and 10 (`fix/dev-api-base-url`). Collections reached `dev` another way; whether either PR is still wanted is unclear.

## Done

- 2026-10-18 TikTok app surfaces and pending-share recovery implemented and locally checked on `codex/tiktok-support`; merged into dev; live acceptance in flight.

- 2026-08-18 Collections on `dev` (PR 15), a shared link handled once rather than per recreate (PR 16), then promoted (PR 17).
- 2026-08-22 Collection links open from in-app browsers; instant collection save; stable collection colours.
- 2026-09-02 Firebase Analytics and Crashlytics; map place search by name; the iOS share sheet filled in.
- 2026-09-11 Chat: the Ask Your Saves screen, the ASK tab, the collection chat panel, the SSE client, threads kept on the device.
- 2026-09-22 Collection chat threads as their own ASK screen; share an answer into several collections; drop the card for a share the backend never finishes. `1.0.16+22` promoted without chat (PR 18).
- 2026-09-28 Chat renders the backend's taste-based suggestions block.
- 2026-09-29 Warm collections before they open; renew an expired session and resend on a 401. `1.0.17+23` promoted (PR 19).

<!-- mapped: reelpin-app@dbee86b | paths: .github/workflows/, lib/constants/source_platforms.dart, lib/screens/reel_detail/, lib/components/reels/, lib/screens/home/, lib/screens/onboarding/, lib/data_models/reels/, lib/data_models/sharing/, lib/screens/app_shell/, lib/services/sharing/, lib/http/, android/app/src/, ios/, assets/images/, test/, tool/ -->

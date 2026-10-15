# reelpin implementation: reelpin-app

This file tracks reelpin-app only; reelpin-api keeps its own. Two people work
here, so every in-flight item names its owner and branch.

## Now

- `dev` @ `05094ba` is version `1.0.17+23`. It carries chat (ASK tab, collection chat threads, the taste suggestions block) behind `CHAT_ENABLED`; the store build on `main` was promoted without chat through `promote/*` cherry-picks. Chat is parked as of 2026-10-15: not shipping, no new work.
- On GitHub but not on `dev`: `feature/paywall` (chetan2921, last commit 2026-10-14) sells Pro through a RevenueCat paywall. It pairs with reelpin-api's `user_entitlements` table, where Pro is granted by hand until this ships.

## Next

- No milestone recorded (`SPEC.md`). Because chat stays off `main`, decide how `dev` and `main` reconcile before the next promotion (`AGENTS.md`, "Branches and release").
- Known defects, none started (read from code, not run):
  - A stale share token survives `invalid_share_token` (`.claude/contracts/share-intake.md`).
  - The backend never sends the plan-limit error codes the app waits for (`.claude/contracts/shared-values.md`).
  - TikTok is missing from `lib/constants/source_platforms.dart`.
- Open PRs into `dev` from 2026-08-04, both by XploY04: 9 (`collections`) and 10 (`fix/dev-api-base-url`). Collections reached `dev` another way; whether either PR is still wanted is unclear.

## Done

- 2026-08-18 Collections on `dev` (PR 15), a shared link handled once rather than per recreate (PR 16), then promoted (PR 17).
- 2026-08-22 Collection links open from in-app browsers; instant collection save; stable collection colours.
- 2026-09-02 Firebase Analytics and Crashlytics; map place search by name; the iOS share sheet filled in.
- 2026-09-11 Chat: the Ask Your Saves screen, the ASK tab, the collection chat panel, the SSE client, threads kept on the device.
- 2026-09-22 Collection chat threads as their own ASK screen; share an answer into several collections; drop the card for a share the backend never finishes. `1.0.16+22` promoted without chat (PR 18).
- 2026-09-28 Chat renders the backend's taste-based suggestions block.
- 2026-09-29 Warm collections before they open; renew an expired session and resend on a 401. `1.0.17+23` promoted (PR 19).
- 2026-10-16 iOS shares that fell back to pending are sent again (the drain now reads the extension's `url`), and collections reset when the signed-in user changes. Both bugs were in the store build too; the fixes are on `dev` only.

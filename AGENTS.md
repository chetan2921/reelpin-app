# reelpin-app

Flutter client (Android and iOS) for ReelPin. A user shares a reel, post, or
link into the app; the backend, the separate repo `reelpin-api` (GitHub
`XploY04/reelpin-api`), processes it; the app shows the result as a grid, a map,
search, collections, and, behind a build flag, an AI chat. Everything the two
repos must agree on is in `.claude/contracts/`. `README.md` covers the screens,
local setup, store builds, Firebase, maps, and signing in prose; this file is
what to know on top of it.

Mapped from `codex/tiktok-support` @ `b51cba3`.

## Navigate

Read what the task needs, never the whole tree.

| Need | Read |
|------|------|
| Find a file, class, method, or provider | `.claude/STRUCTURE.md`; grep it before opening whole files |
| Change anything reelpin-api also depends on | `.claude/contracts/` |
| What the product should do | `.claude/plan/reelpin/SPEC.md` |
| Where the work stands, what is next | `.claude/plan/reelpin/IMPLEMENTATION.md` |
| How to test here, good tests to copy | `.claude/plan/reelpin/TESTING.md` |
| Why something is the way it is | `.claude/HISTORY.md`, newest lines last |
| How to do a common Flutter task | the matching skill in `.agent/skills/` (generic, not project-specific) |

## Run

- Config: put `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `API_BASE_URL`, and `MAPS_API_KEY` in the gitignored `assets/config/local.env` (README "Runtime Config"). `lib/env.dart` reads only `--dart-define`s; `tool/reelpin_flutter.sh` turns `local.env` into them.
- Run: `tool/reelpin.sh run-dev` (dev backend) or `tool/reelpin.sh run-production`, plus `-d <device-id>` from `flutter devices`. With no `API_BASE_URL`, debug and profile builds hit dev and release builds hit prod.
- Chat is off unless built with `--dart-define=CHAT_ENABLED=true`; pass it through `tool/reelpin_flutter.sh`, since `tool/reelpin.sh apk-dev` rejects extra arguments. `MOCK_CHAT` and `MOCK_COLLECTIONS` (debug only) swap in fakes.
- Before pushing: `tool/reelpin.sh verify` (format check, project check, architecture and asset checks, analyze, tests). Tests alone: `flutter test`. Details in `.claude/plan/reelpin/TESTING.md`.
- Store builds: `tool/reelpin.sh playstore`, `appstore`, or `stores` build locally into `artifacts/releases/<version>/`; nothing uploads. Bump `version:` in `pubspec.yaml` by hand in its own commit ("Bump the version to X+Y"); the build number must rise for every store upload.

## Where things live

- Startup: `lib/main.dart`, then `lib/bootstrap.dart` (Crashlytics handlers, Firebase init not awaited, launch deep link, theme, Supabase with PKCE, `runApp`), then `lib/reelpin_app.dart` (`MaterialApp`; `SetupRequiredScreen` when the Supabase defines are missing), then `lib/app_entry.dart` (auth gate: splash, onboarding, sign-in, or the signed-in shell).
- `lib/screens/app_shell/`: `authenticated_shell.dart` (user change, push setup and token registration, notification taps) and `app_shell.dart` (tabs in an `IndexedStack`, deep links, draining native pending shares, refresh on resume, first-run prompts).
- `lib/router.dart`: route builders (Navigator 1.0, no route table). `lib/providers.dart`: every Riverpod provider; the HTTP providers all return the one `ApiClient`.
- `lib/screens/<page>/`: one folder per page; widgets only that page uses go in its `partials/`.
- `lib/components/`: widgets shared by more than one screen (chat, collections, common, reels, sharing).
- `lib/view_models/`: `ChangeNotifier` state, plus `user_state_coordinator.dart` (hydrate from disk, reset on user change).
- `lib/repositories/reel_repository.dart`: the only repository (paged reels, search, processing jobs). Other view models call `lib/http/` interfaces directly.
- `lib/http/`: `ApiClient` (every REST call), the `*_http.dart` interfaces, separate SSE clients for chat, and in-memory mocks.
- `lib/data_models/`: `fromJson` classes by area. `lib/services/`: auth, `ContentCache`, chat, notifications, sharing (native handoff, push registration, deep links), analytics, location, app update. `lib/constants/` and `lib/utils/`: theme, flags, pure helpers.
- `lib/constants/source_platforms.dart`: shared platform artwork and nouns, including TikTok VIDEO/POST/LINK and legacy URL labels. `lib/data_models/sharing/pending_share.dart` decodes Android raw payloads, iOS URLs, and legacy pending strings for AppShell.
- Native share intake, a subsystem of its own (`.claude/contracts/share-intake.md`): `android/app/src/main/kotlin/com/chetanjain/reelpin/`, `ios/Share Extension/`, and the method channels in `ios/Runner/AppDelegate.swift`.
- `tool/`: `reelpin.sh` (doctor, verify, run, build), `reelpin_flutter.sh` (`local.env` to dart-defines), and the `check_architecture.dart`, `check_assets.dart`, `verify_project.dart` gates.
- `test/` mirrors `lib/`. `web/`, `macos/`, `linux/`, `windows/` are Flutter defaults; Firebase, push, and native share are skipped off mobile. `play-assets/`: store listing graphics. `docs/`: privacy and delete-account pages, screenshots, the design spec.

## How data moves

Screen, then view model, then `ReelRepository` (reels only) or a `lib/http/`
interface, then `ApiClient`, then reelpin-api. `EntitlementsViewModel.refresh`
is the hub: after entitlements load it reloads Home, map, filters, and Discover.
`ContentCache` keeps first pages on disk for 7 days (entitlements for 24 hours)
and is cleared on sign-out. `ProcessingJobsViewModel` polls the job list while a
job is active and drops the finished reel straight into the grid.
`CollectionsViewModel` warms up to 20 collections after each list load.

## Sharp edges

1. **CI enforces the layers** (`tool/check_architecture.dart`): lower layers never import screens or components, a screen imports only its own `partials/`, and files are named `*_view_model.dart` and `*_http.dart`. Imports must be package imports, and `dart format` is checked on `lib`, `test`, and `tool`.
2. **Chat is parked behind a compile-time flag.** It is not going to the store build and gets no new work (`.claude/plan/reelpin/SPEC.md`); leave the chat code alone unless asked. Without `CHAT_ENABLED` there is no ASK tab and the tab indexes shift (`lib/screens/app_shell/partials/app_shell_controller.dart`), so never hard-code a tab index. `MOCK_CHAT` is not limited to debug builds.
3. **The chat clients bypass `ApiClient`** (`chat_api_http.dart`, `collection_chat_api_http.dart`): no 401 renewal, no `/api/v1` dedupe, their own error text.
4. **Share intake is native on Android and iOS**; Flutter's `receive_sharing_intent` runs only on desktop. A change to the share payload lands in Kotlin, Swift, Dart, and the backend together.
5. The backend reads the user from the token and ignores the many `userId` parameters. Never add `user_id` to a request.
6. `ReelRepository` takes the concrete `ApiClient`, so test fakes subclass `ApiClient`.
7. Dead code, do not extend it: the Folders HTTP, view model, and models; `processReel`, `_waitForProcessingJob`, `processVideo`, `healthCheck`; `ReelDetailViewModel`; the unused `webview_flutter` and `geocoding` dependencies.
8. Firebase is skipped silently when its gitignored config files are missing: no push, no Crashlytics.
9. Switching the API base URL drops the native share token.
10. **Collections survive a sign-out**, on `main` and `dev` alike (read from code, not run). `UserStateCoordinator.reset()` resets every other view model but not `CollectionsViewModel`, and the one root `ProviderScope` is never invalidated. After signing out and into another account without restarting the app, SAVED shows the previous account's collection list (`hydrateFromCache` and `loadCollections` both return early while the old list is in memory) until a pull-to-refresh, an app resume, a share, or a restart. Only the list (names, covers, counts) leaks: opening one of those collections gets a 404 from the backend, which checks membership.
11. Line numbers in docs rot. Name the symbol and look its line up in `.claude/STRUCTURE.md`.

## Branches and release

`README.md` "Branches And Promotion" has the rules: `dev` is the working
branch, `main` is what ships to the stores, never push to `main` directly,
promote with a merge, merge `main` back into `dev` afterwards, never force-push.
A push to `dev` runs `validate.yml` and `build-dev-apk.yml`; a PR into `dev`
runs `validate.yml`. Nothing runs on PRs into `main`.

The history does not match those rules today: `main` was promoted through
`promote/*` branches of cherry-picks that leave chat out, so
`git rev-list --left-right --count origin/main...origin/dev` is `23 44` and the
two trees differ only by chat. Ask before merging `main` into `dev` or
promoting.

## Working rules

- Git: sign commits with `-s`; no AI attribution (`Co-Authored-By` lines or similar) in commits, code, or comments; `git fetch` before committing or pushing; check `git status` before switching branches.
- Changes: read the surrounding code first and match its style; keep diffs minimal; no unrequested refactors or new dependencies; run `tool/reelpin.sh verify` before pushing.
- Writing (docs, comments, commits): no em dashes, straight quotes, plain words, no filler.

## Trust, then update

A context file is true only for the commit it was read from. Before relying on
one, check its footer stamp, the HTML comment on its last line that starts with
`mapped:` and names a sha and the paths it covers:

    git diff --stat <sha>..HEAD -- <paths>

Empty output means it still describes the code. Anything else names the files
to re-read: re-read them, rewrite the context file, and re-stamp it with the
current short sha (`git rev-parse --short HEAD`).

Sweep every stamp at once from the repo root after a pull, merge, or branch
switch:

    grep -rl '<!-- mapped:' AGENTS.md .claude --include='*.md' | while read -r f; do
      line=$(grep -o '<!-- mapped: .* -->' "$f" | tail -1)
      rest=${line#*@};        sha=${rest%% *}
      paths=${line#*paths: }; paths=${paths% -->}
      out=$(git diff --stat "$sha"..HEAD -- $(echo "$paths" | tr ',' ' ') 2>&1)
      if [ -n "$out" ]; then printf '\n=== %s\n%s\n' "$f" "$out"; fi
    done

Every file it prints must be rewritten before it is trusted. The stamp must stay
the last line of its file (the sweep reads the last match). Keep the `tr`:
zsh does not split `${paths//,/ }` into words, so without it every file reads
as clean.

## Update as you go

When a session does the thing on the left, it updates the file on the right
before it ends. Not next session, not when someone notices.

| What happened | What to update |
|---------------|----------------|
| new folder, screen, service, entry point, dependency, dart-define, or command | this `AGENTS.md` |
| class, method, or provider added, removed, or its signature changed | `.claude/STRUCTURE.md`: run `python3 .claude/structure.py > .claude/STRUCTURE.md` |
| either side of a seam moved (an endpoint, request or response field, error code, push key, platform id, plan value, share payload) | the contract in `.claude/contracts/`, then the same edit in reelpin-api's copy |
| a checklist step or milestone landed | `.claude/plan/reelpin/IMPLEMENTATION.md` |
| a test added, or a testing lesson learned | `.claude/plan/reelpin/TESTING.md` |
| a decision that contradicts the spec | `.claude/plan/reelpin/SPEC.md` here and in reelpin-api, or the spec becomes fiction |
| a new seam with reelpin-api appeared | a new file in `.claude/contracts/`, in both repos |
| a folder grew into its own subsystem | give it its own `AGENTS.md` plus a `CLAUDE.md` holding `@AGENTS.md` |

Re-stamp every mapped file you rewrite. A rewritten file with an old stamp is
worse than a stale one, because the sweep will now call it clean.

reelpin-api is a separate repo with its own remote. The contracts and `SPEC.md`
exist as identical copies in both repos. When reelpin-api is checked out on the
same machine, make the matching edit there too; otherwise say plainly in your
final message and in the PR description which reelpin-api file needs it.

## Before the session ends

A session that changed anything: make the updates above, then append one line
to `.claude/HISTORY.md`. A session that only answered questions writes nothing.

`HISTORY.md` takes one line per session, newest last:

    - 2026-10-15 <topic>: <what changed, in one line>. <the consequence someone will trip on, if any>

A decision someone will question later gets a short indented block under its
line: what was chosen, over what, and why. Past 120 lines, fold the oldest half
into one paragraph at the top under `## Before <date>`, keeping decisions and
reasons; never re-fold a folded paragraph. Two people commit here, so
`.gitattributes` merges `HISTORY.md` with `merge=union`: both sides' lines are
kept, so check the order after a merge.

## Compression

Only the work in flight is written out in full. A finished item in
`IMPLEMENTATION.md` becomes one dated line under `## Done`; a past session is
one line in `HISTORY.md`; a folder gets its own file only when it is a real
subsystem; everything else points at where the truth lives instead of restating
it. Re-run the `repo-setup` skill after a large merge or when the sweep prints
more files than you want to fix by hand.

Never write credentials, tokens, keys, or internal URLs into any of these
files. Name the env var or config key instead.

Tracking: committed to this repo, shared with every collaborator.
Layout: per repo; reelpin-api carries its own tree.

<!-- mapped: reelpin-app@b51cba3 | paths: lib/, android/, ios/, tool/, pubspec.yaml, .github/, analysis_options.yaml -->

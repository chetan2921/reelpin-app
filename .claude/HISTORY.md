# History

One line per session that changed something, newest last.

- 2026-10-15 agent-context: mapped the repo with the repo-setup skill into `AGENTS.md` (with `CLAUDE.md` importing it) and `.claude/` (structure index, contracts with reelpin-api, plan, testing). `.agent/skills/` is untouched and referenced from `AGENTS.md`.
  Chose one tree per repo, committed and shared, over a private parent-folder tree, because two people and their agents work across both repos. The contracts and `SPEC.md` are copied into both repos, since neither repo can read the other; the update rules say to change both copies together.
  Chat and the personal context engine design are shelved (user decision, 2026-10-15): not shipping to the stores, no new work. The code stays; `SPEC.md` lists both as out of scope.
- 2026-10-18 tiktok: added platform artwork/copy, legacy URL labels, native parser fixtures, and iOS/Android pending-share decoding on codex/tiktok-support; verify (516 tests), Android (3), and Swift (8) pass, original app edits preserved, dev merge/live tests pending.
- 2026-10-18 dev-acceptance: merged app PRs 22/23 and backend fixes into dev; headless real-client tests accept 17 URL shapes but seven live jobs fail with zero saves; dev APK builds pass, collection test teardown race fixed, 516 local tests pass; all 25 original app edits, main, and hosting preserved, native device checks deferred by user.
- 2026-10-18 tiktok-retrieval: synced provider fallback contract/spec; five valid dev jobs yield three parsed saves, real-client feed/detail, 19 URL shapes including v2 embeds, alias/short dedupe and selected collections pass; no app runtime changes, main/hosting/original edits preserved, real-device checks deferred.
- 2026-10-20 native-share-v2: both share extensions post to `POST /api/v2/native-shares/reels` with `X-Share-Token` and a per-attempt `Idempotency-Key`, read the v2 error envelope, and no longer post the push token. Release builds still point at api.reelpin.in, which serves only v1, so this cannot ship before the production cutover.

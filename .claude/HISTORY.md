# History

One line per session that changed something, newest last.

- 2026-10-15 agent-context: mapped the repo with the repo-setup skill into `AGENTS.md` (with `CLAUDE.md` importing it) and `.claude/` (structure index, contracts with reelpin-api, plan, testing). `.agent/skills/` is untouched and referenced from `AGENTS.md`.
  Chose one tree per repo, committed and shared, over a private parent-folder tree, because two people and their agents work across both repos. The contracts and `SPEC.md` are copied into both repos, since neither repo can read the other; the update rules say to change both copies together.
  Chat and the personal context engine design are shelved (user decision, 2026-10-15): not shipping to the stores, no new work. The code stays; `SPEC.md` lists both as out of scope.
- 2026-10-18 tiktok: added platform artwork/copy, legacy URL labels, native parser fixtures, and iOS/Android pending-share decoding on codex/tiktok-support; verify (516 tests), Android (3), and Swift (8) pass, original app edits preserved, dev merge/live tests pending.
- 2026-10-18 dev-acceptance: merged PR 22 into dev and passed merged-dev validation; synchronized unparsed/redirect contracts after live backend failures, preserved all 25 existing app edits; native device testing and dev APK result pending.

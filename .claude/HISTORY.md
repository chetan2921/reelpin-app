# History

One line per session that changed something, newest last.

- 2026-10-15 agent-context: mapped the repo with the repo-setup skill into `AGENTS.md` (with `CLAUDE.md` importing it) and `.claude/` (structure index, contracts with reelpin-api, plan, testing). `.agent/skills/` is untouched and referenced from `AGENTS.md`.
  Chose one tree per repo, committed and shared, over a private parent-folder tree, because two people and their agents work across both repos. The contracts and `SPEC.md` are copied into both repos, since neither repo can read the other; the update rules say to change both copies together.
  Chat and the personal context engine design are shelved (user decision, 2026-10-15): not shipping to the stores, no new work. The code stays; `SPEC.md` lists both as out of scope.

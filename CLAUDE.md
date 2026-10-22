# CLAUDE.md — Half Unit

@AGENTS.md

The import above loads the shared rules for all agents. Edit rules in `AGENTS.md`, not here.
Only Claude Code–specific notes belong in this file.

## Claude Code notes

- Start each task by reading `PRODUCT.md` and the section of `AGENTS.md` for the area you touch.
- Use plan mode before changing `project.yml`, `Package.swift`, SwiftData models or the Health write path, and wait for approval.
- Prefer `swift test --package-path Packages/HalfUnitCore` for the inner loop; run `xcodebuild` only to confirm a finished change.
- When a task spans several areas, propose splitting it into separate Orca worktrees instead of doing it all in one branch.
- End every task with the summary required by "Definition of done" in `AGENTS.md`.

## Lead workflow (see "Roles and approval" in `AGENTS.md`)

- Claude is the lead and does not write feature code. It dispatches coding tasks to Agy with Orca orchestration (`orca skills get orchestration`), using `--agent antigravity`, `--worktree new-top-level`, `--base-branch origin/main` and `--name agent-<area>-<desc>`.
- Each task spec names target files, the change, constraints, ownership and acceptance (the Definition of done), and tells Agy to read `AGENTS.md` and `PRODUCT.md` first.
- Review before merging: read the full diff, then run `./scripts/lint.sh` and `swift test` (plus the Xcode builds once they exist) in the task worktree. If it fails review, send the fixes to the same dispatch. If it passes, merge into `main` with `--no-ff` and push.
- Claude contacts the project owner only with doubts about product decisions; everything else is settled between Claude and Agy.

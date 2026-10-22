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

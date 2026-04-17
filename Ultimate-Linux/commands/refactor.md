---
name: mm:refactor
description: "Targeted refactoring: rename, extract, restructure. Safety-first with tests before and after."
argument-hint: "[what to refactor and why]"
---

Refactor the specified code. Safety-first.

1. **Confirm tests exist** — if there are no tests covering this code, write them first before touching anything
2. **Plan** — describe the exact change: rename X to Y, extract function Z, move module A to B
3. **Execute** — make the change; use LSP (`mcp__cclsp__rename_symbol`) for renames touching multiple files
4. **Verify** — all tests still pass; no behavior change
5. **Commit** — `refactor: <what changed>`

Rules:

- Refactor is behavior-neutral — if you're also fixing a bug or adding a feature, do it in a separate commit
- For renames touching >10 files, use the `refactor-agent` subagent (isolated worktree)
- Don't "improve" adjacent code that wasn't asked about

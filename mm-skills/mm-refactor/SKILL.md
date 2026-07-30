---
name: mm-refactor
description: "Targeted refactoring: rename, extract, restructure. Safety-first with tests before and after. Use when restructuring code without changing behavior."
argument-hint: "[what to refactor and why]"
---

# /mm-refactor — Safe Refactoring

1. **Confirm tests exist** — if no tests cover this code, write them first
2. **Plan** — describe the exact change: rename X to Y, extract function Z, move module A to B
3. **Execute** — Grep the symbol repo-wide first, read every hit, then Edit. Use `Name` patterns so comments and substrings aren't caught
4. **Verify** — all tests still pass; no behavior change
5. **Commit** — `refactor: <what changed>`

Rules:

- Refactor is behavior-neutral — bug fixes and features go in separate commits
- For renames touching >10 files, use the `refactor-agent` subagent (isolated worktree)
- Don't "improve" adjacent code that wasn't asked about

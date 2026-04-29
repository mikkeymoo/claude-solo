---
name: mm:build
description: "Implement tasks from PLAN.md in dependency order with atomic commits."
---

Read `.planning/PLAN.md` and implement tasks in dependency order.

For each task:

1. Implement the code
2. Run existing tests — fix regressions before moving on
3. Stage only the relevant files (`git add <file>`, never `git add .`)
4. Commit: `feat: <task description>`
5. Report: "✓ Task N — [one-line summary]"

Rules:

- One commit per task, no bundling
- If a task is blocked, stop and explain — don't guess past it
- If something architectural is unclear mid-task, ask before coding
- Never skip tests even if they seem unrelated

After all tasks: "Build complete. Ready to /mm:review?"

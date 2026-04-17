---
name: mm:plan
description: "Create an implementation plan with atomic tasks, dependencies, and test matrix. Writes .planning/PLAN.md."
---

Read `.planning/BRIEF.md` (or ask me to describe the goal if it doesn't exist).

Write `.planning/PLAN.md`:

1. **Architecture** — ASCII diagram of components and data flow
2. **Tasks** — numbered list; each task is one atomic commit with a clear done-condition
3. **Dependencies** — which tasks must precede which (mark parallel-safe tasks)
4. **Test matrix** — what tests are needed (unit / integration / E2E)
5. **Schema/API changes** — list any DB, API, or config changes explicitly
6. **Risk items** — anything that could blow up scope

Task rules:

- No task named "implement X" without naming the exact file/function
- Each task ≤ 4 hours; split anything larger
- Mark tasks that can run in parallel with ‖

End with: "Plan saved. Ready to /mm:build?"

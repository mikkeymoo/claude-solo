---
name: mm-parallel
description: "Execute independent tasks simultaneously in waves. Reads PLAN.md to identify tasks with no dependencies between them."
---

# mm-parallel

Execute independent tasks simultaneously in waves. Reads PLAN.md to identify tasks with no dependencies between them.

## Instructions
Execute independent tasks simultaneously to cut wall-clock time.

Read `.planning/PLAN.md` and identify which tasks have no dependencies between them.

Process:

1. **Analyze** — list all tasks and their dependencies
2. **Wave planning** — group tasks into waves where each wave's tasks are independent:
   ```
   Wave 1: Tasks 1, 2, 3  (no dependencies)
   Wave 2: Tasks 4, 5     (depends on Wave 1)
   Wave 3: Task 6         (depends on Wave 2)
   ```
3. **Execute each wave** — within a wave, use the Task tool to spawn parallel subtasks
4. **Sync after each wave** — confirm all wave tasks succeeded before starting the next
5. **Report** — show completion status for each wave

Rules:
- Only parallelize truly independent tasks — shared state is a bug factory
- If tasks touch the same file, they are NOT independent
- DB schema changes are never parallel — they serialize everything after them
- Always run tests after each wave completes, before starting the next

Wave report format:
```
Wave 1 complete: Task 1 ✓, Task 2 ✓, Task 3 ✓
Wave 2 starting...
```

If a task in a wave fails, stop that wave and fix before continuing.

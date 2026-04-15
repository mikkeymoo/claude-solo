---
name: mm-workflow
description: "Execution mode selector — choose how to run the sprint: hands-off autopilot, parallel waves, strict TDD, or rapid quick mode."
---

# mm-workflow

Execution mode selector — choose how to run the sprint: hands-off autopilot, parallel waves, strict TDD, or rapid quick mode.

## Instructions
Choose how to execute the work. Pick the mode that fits the task.

- `--auto [description]` — full hands-off pipeline: spec → build → QA → validate
- `--parallel` — execute independent tasks simultaneously in waves
- `--tdd` — strict red → green → refactor, no code before failing test
- `--quick [task]` — rapid flow for small changes under 2 hours
- No argument → shows this guide and asks which mode

---

## --auto — Hands-Off Autopilot

Run the full sprint pipeline end-to-end with minimal interruptions.

If no description provided, ask: "What are we building?" — one question, wait for answer.

Execute all 7 stages automatically:
1. **BRIEF** — define scope, write `.planning/BRIEF.md`. Ask: "Proceed?"
2. **PLAN** — create `.planning/PLAN.md` with tasks, architecture, test matrix. Show plan. Ask: "Proceed?"
3. **BUILD** — implement all tasks in dependency order, one atomic commit per task. Report each `✓ Task N done`.
4. **REVIEW** — staff-engineer review. Auto-fix all 🔴 MUST FIX. Show 🟡 and 🔵. Ask: "Fix 🟡 items?"
5. **TEST** — write and run all tests. If coverage < 80%, add tests. Report pass/fail/coverage.
6. **SHIP** — create PR, confirm all tests pass. Ask: "Merge?" before merging.
7. **RETRO** — write `.planning/RETRO-[date].md`.

Pause only at: after BRIEF (scope confirmed), after PLAN (approach confirmed), before SHIP merge. Never pause mid-stage. Make reasonable calls when unclear and note them.

---

## --parallel — Wave Execution

Execute independent tasks simultaneously to cut wall-clock time.

Read `.planning/PLAN.md` and identify tasks with no dependencies between them.

1. **Analyze** — list all tasks and their dependencies
2. **Wave planning** — group into waves where each wave's tasks are fully independent:
   ```
   Wave 1: Tasks 1, 2, 3  (no dependencies)
   Wave 2: Tasks 4, 5     (depends on Wave 1)
   Wave 3: Task 6         (depends on Wave 2)
   ```
3. **Execute each wave** — use Task tool to spawn parallel subtasks within a wave
4. **Sync after each wave** — confirm all tasks succeeded before starting next
5. **Report** — `Wave 1 complete: Task 1 ✓, Task 2 ✓, Task 3 ✓`

Rules: tasks touching the same file are NOT independent. DB schema changes serialize everything after them. If a task in a wave fails, stop the wave and fix before continuing.

---

## --tdd — Strict TDD

No production code before a failing test. Red → green → refactor cycle.

Activate for current task or read `.planning/PLAN.md` for next task.

The cycle — repeat for every unit of work:
1. **RED** — write a test that fails for the right reason. Confirm it fails with a clear message. If it passes immediately, the test is wrong.
2. **GREEN** — write minimum code to make the test pass. No extra logic. Confirm passing.
3. **REFACTOR** — clean up without changing behavior. Run tests: still green.

Rules: one test per cycle, never batch tests then implement. If you can't write a failing test, the requirement is too vague — clarify first. Mocks only for: external APIs, databases in unit tests, system clock.

Report each cycle:
```
🔴 Test: test_name — FAILING (reason)
🟢 Test: test_name — PASSING
♻️  Refactored: [what changed]
```

At the end: run full test suite, report total pass/fail.

---

## --quick — Rapid Small Task

For bug fixes, small features (<2h), config changes, refactors with clear scope. Not for: new systems, DB schema changes, auth, payments.

Four steps — no stopping between them unless blocked:

1. **Clarify** (2 min) — restate what we're doing in one sentence. Is this actually small enough for quick mode? Identify 1-3 files touched.

2. **Plan** (5 min) — list exact changes (file, function, what changes and why). Name tests needed (at minimum: one happy path, one edge case). If it touches >5 files or needs schema change — stop and use full pipeline.

3. **Implement** — make changes, write tests, run tests. Fix any failures before continuing.

4. **Review & commit** — self-review: security? edge cases? cross-platform? Stage specific files (not `git add .`). Commit with `fix:` or `feat:`.

Report: "Done — [one line of what shipped]. Tests: X passed."

If anything surprises you mid-implementation, stop and say so. Don't push through into a mess.

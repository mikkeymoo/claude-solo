---
name: riper
description: "Enforce Research → Innovate → Plan → Execute → Review phase separation. Supports --auto (full pipeline), --plan, --build, --search modes. TRIGGER when user requests a feature, refactor, or fix spanning multiple files or with unclear scope. NOT for one-line fixes or when user says 'quick'."
---

# RIPER — Disciplined Phase Separation

Use this skill when a task is complex enough that rushing to `Edit` first will produce worse code than pausing to think. Each phase has a gate; you cannot advance without satisfying it.

## Phase 1 — RESEARCH

**Goal:** Understand the problem space and current code before proposing anything.

Do:

- Read the relevant code with LSP (`find_references`, `find_definition`) before Grep.
- Map the data flow: where does the input come from, where does the output go, what persists.
- Identify invariants: what must stay true across this change?
- Locate tests that cover the affected behavior.

Do **not**:

- Propose solutions.
- Write code.
- Decide on an approach.

**Gate:** Produce a `## Research findings` block with at least: affected files, current behavior, invariants, existing test coverage. Stop and confirm with the user before Phase 2.

## Phase 2 — INNOVATE

**Goal:** Generate 2–4 distinct approaches. Force yourself past the first idea.

Do:

- List approaches with one-sentence description each.
- For each: pros, cons, blast radius, reversibility.
- Explicitly consider "do nothing" / "smaller scope".

Do **not**:

- Pick a winner yet.
- Start designing any single approach in detail.

**Gate:** Produce a `## Options` table. Ask the user to pick, or state which you recommend and why. Do not advance until acknowledged.

## Phase 3 — PLAN

**Goal:** Convert the chosen approach into atomic, ordered, reversible tasks.

Do:

- Decompose into tasks that each produce one atomic commit.
- Declare dependencies between tasks explicitly.
- For each task: acceptance criteria, test to write/update, files touched.
- Identify the rollback path.

Do **not**:

- Execute anything yet.
- Start a task unless its predecessors are done.

**Gate:** Produce a `## Plan` with numbered tasks and a test matrix. Ask for approval.

## Phase 4 — EXECUTE

**Goal:** Carry out the plan mechanically. No deviations, no scope creep.

Do:

- Work one task at a time; commit after each.
- Run tests after each task; fix before moving on.
- If a task reveals the plan is wrong, STOP — go back to Phase 3 and update the plan. Do not quietly redesign.

Do **not**:

- Combine tasks.
- Add "while I'm in here" improvements.
- Skip tests "because it's obvious".

**Gate:** All tasks committed, test baseline restored.

## Phase 5 — REVIEW

**Goal:** Validate the finished work against the original plan.

Do:

- Diff the final state against the plan — did scope drift?
- Spawn `code-reviewer` subagent on the total diff.
- Run full test suite + typecheck + lint.
- Update docs/CHANGELOG if user-visible.

Do **not**:

- Merge without green review.
- Skip tests under time pressure.

**Gate:** Green CI, green review, docs updated. Done.

## Rules

- You **cannot** skip phases. If the user says "just implement it", remind them this skill was invoked for a reason and offer to switch to quick mode (`/quick`) instead.
- Each phase emits an artifact in `.planning/` (`RESEARCH.md`, `OPTIONS.md`, `PLAN.md`, `REVIEW.md`) so the sprint is inspectable.
- If you're ever unsure which phase you're in, you're in Research.

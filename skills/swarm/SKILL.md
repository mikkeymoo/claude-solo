---
name: swarm
description: "Parallel multi-agent orchestration — break a plan into independent tasks and farm them out to parallel agents in isolated worktrees, then merge results. Use when you want maximum parallelism on a multi-task plan."
argument-hint: "[number of agents (default: 3)] or path to PLAN.md"
---

# /swarm — Parallel Agent Orchestration

Break work into independent tasks and execute them simultaneously across isolated agents.

## How it works

1. **Analyze** — read `.planning/PLAN.md` (or ask for tasks). Identify tasks with no dependencies between them.
2. **Partition** — group tasks into waves of independent work. Tasks touching the same file are NOT independent.
3. **Spawn** — for each task in the current wave, spawn an Agent with `isolation: "worktree"` so each works on its own git branch without conflicts.
4. **Monitor** — run agents in background. Report as each completes.
5. **Merge** — after all agents in a wave complete, merge their worktree branches back into the main branch. Resolve any conflicts.
6. **Next wave** — repeat for dependent tasks that are now unblocked.
7. **Verify** — run full test suite on the merged result.

## Example

```
/swarm 4
```

Reads PLAN.md, finds 8 tasks, groups into:

- Wave 1: Tasks 1, 2, 3, 4 (independent) → 4 parallel agents
- Wave 2: Tasks 5, 6 (depend on Wave 1) → 2 parallel agents
- Wave 3: Tasks 7, 8 (depend on Wave 2) → 2 parallel agents

## Rules

- Max agents per wave: 5 (diminishing returns beyond that)
- Each agent gets: task description, relevant file paths, acceptance criteria
- Agents use `ult-code-reviewer` before committing
- If any agent fails, pause the wave and report before continuing
- DB schema changes serialize — they cannot run in parallel with anything
- Always run `/quality --gate` after all waves complete

## When NOT to use

- Tasks under 3 items (just do them sequentially)
- Tasks that all touch the same files (no parallelism possible)
- Schema migrations (must be sequential)

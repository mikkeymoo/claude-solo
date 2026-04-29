---
name: swarm
description: "Parallel multi-agent orchestration — break a plan into independent tasks and farm them out to parallel agents in isolated worktrees, then merge results. Use when you want maximum parallelism on a multi-task plan."
argument-hint: "[number of agents (default: 3)] or path to PLAN.md, --status, or --results"
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

## --status mode

Monitor real-time progress of running parallel agents:

```
/swarm --status
```

Shows:

1. Active worktrees from `git worktree list`
2. For each worktree: branch name, last commit, recent tool activity from `.claude/logs/session-*.log`
3. Status: Running/Idle/Complete based on log recency

Output example:

```
Wave: 2/3  |  Agents: 3 running, 1 complete

Agent          | Branch              | Last Activity | Status
─────────────────────────────────────────────────────────────
claude-wt-123  | feat/task-1-hooks   | 12s ago       | Running
claude-wt-456  | feat/task-2-skills  | 45s ago       | Running
claude-wt-789  | main (merged)       | 2m ago        | Complete
```

## --results mode

View outcomes after swarm wave completes:

```
/swarm --results
```

Shows:

1. List of merged commits since swarm started (from `.planning/SWARM-LOG.md` or `git log main`)
2. Per-agent summary: task description, files changed, commit messages
3. Overall stats: total tasks, merge success rate

Output example:

```
Wave 1 Results: 5 agents, all merged to main

✓ Task 1 — feat(hooks): add lint-fix hook (2 files)
✓ Task 2 — feat(hooks): add conventional commits (1 file)
✓ Task 3 — feat(hooks): add stop gate (2 files)
✓ Task 4 — feat(hooks): add git-guardrails (3 files)
✓ Task 5 — feat(hooks): add deployment checks (2 files)
```

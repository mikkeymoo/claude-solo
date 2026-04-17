---
name: daily-brief
description: One-shot aggregator that produces a single context block summarizing the current state of work — git status, open PRs, failing tests, recent commits, open TODOs, dependency alerts. TRIGGER when the user says "what's going on", "where did we leave off", "catch me up", "daily brief", or when starting work in a repo you haven't touched today.
---

# Daily Brief — Situation Report in One Block

Produce a single, scannable context block so the user and you both know the lay of the land before any work starts.

## Run these in parallel
```bash
rtk git status
rtk git log --oneline -10
rtk git branch --show-current
rtk gh pr list --limit 5
rtk gh run list --limit 5
```

Plus, in parallel:
- Glob for `.planning/BRIEF.md`, `.planning/PLAN.md`, `.planning/CHECKPOINT.md` — read whichever exist
- Grep for `TODO|FIXME|XXX|HACK` across `src/` — count by file, top 5 files only
- If `package.json` / `pyproject.toml` / `Cargo.toml` changed recently (git log -- <file>), flag it
- If `.env.example` changed in the last 5 commits, flag it (new required var)

## Format
```
# Daily Brief — <date> — <repo name> — <branch>

## Where we left off
<2-3 lines, taken from .planning/CHECKPOINT.md or the most recent commit subject chain>

## Git state
- Branch: <name> (<ahead/behind> origin)
- Uncommitted: <N files> <list top 5>
- Last commit: <sha short> — <subject> — <relative time>

## Open PRs
- #<n> <title> — <status> — <checks> <url>
<or: "None">

## Recent CI runs
- <workflow> — <status> — <relative time>
<top 3 only>

## Tests
<if a recent test log exists in .planning/last-test.log: tail summary; else: "No recent run logged">

## Attention items
- <TODO/FIXME hot spot>  — <file> (<count>)
- <dependency or env change since last brief>
- <any failing check>

## Suggested next action
<one sentence — usually: resume the top task in PLAN.md, or: merge PR #N, or: fix failing check X>
```

## Rules
- **Under 40 lines total.** This is a brief, not a report.
- No raw tool output dumped — summarize every section.
- If a section has nothing useful, omit it — do not write "N/A" padding.
- Prefer `rtk` prefixed commands for every shell call (60–90% token savings).
- Cite file:line only when pointing at something the user should act on.

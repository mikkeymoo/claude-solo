---
name: ci
description: "Check CI/CD status, view failing checks, retry workflows. Use when you want quick CI visibility."
argument-hint: "[--status | --failing | --retry <run-id> | --logs <run-id>]"
---

# /ci — CI/CD Status & Management

Quick CI visibility without leaving the terminal. Four modes:

## --status (default) — Current CI Runs

Show current CI runs for this branch.

1. Get current branch: `git branch --show-current`
2. List runs: `rtk gh run list --branch <branch> --limit 10`
3. Parse and display as table: run-id, name, status, conclusion, created-at
4. Show total count and summary (passed/failed/in-progress)

## --failing — Failing Checks Only

Show only failing checks with log summaries.

1. Check if on a PR branch: `git branch --show-current` and attempt `rtk gh pr checks`
2. If on PR: parse failing checks, show each with status and error summary
3. If not on PR: run `rtk gh run list --status failure --limit 10`
4. For each failure, display: run-id, name, failure reason (from job logs if available)
5. End with: "Found X failing checks. Use `--logs <run-id>` to view full logs."

## --retry <run-id> — Retry a Failed Workflow

Retry a specific failed workflow run.

1. Confirm run exists: `gh run view <run-id>`
2. Execute: `gh run rerun <run-id>`
3. Output: "Requeued run <run-id>. Waiting for CI to start..."
4. Poll status once: `rtk gh run view <run-id>` to confirm requeue accepted

## --logs <run-id> — Stream Logs from a Run

View logs from a specific run.

1. Confirm run exists: `gh run view <run-id>`
2. For failed runs: `gh run view <run-id> --log-failed` (failed jobs only)
3. For all runs: `gh run view <run-id> --log` (full log)
4. Prompt user: "Show (f)ailed jobs only or (a)ll logs?" Default to failed if run status is failure, else all
5. Stream/display logs; at end show summary line: "Run <run-id> status: <status>"

## Error Handling

If `gh` is not installed or not authenticated, output:

```
gh CLI not found — install from: https://cli.github.com and authenticate with: gh auth login
```

If a run-id is not found, output:

```
Run <run-id> not found. Check the ID with: /ci --status
```

## SUCCESS CRITERIA

- `--status` displays latest 10 CI runs with passed/failed/in-progress status
- `--failing` shows only failures with concise error summaries
- `--retry <run-id>` successfully requeues a workflow and confirms acceptance
- `--logs <run-id>` streams logs, respecting failed-only vs. all-logs preference
- All gh commands are wrapped with `rtk` for token efficiency
- Auth/installation errors are clearly communicated
- User can chain modes (e.g., check status, then retry, then view logs)

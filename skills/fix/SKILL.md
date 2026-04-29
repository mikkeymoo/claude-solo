---
name: fix
description: "Debug and fix bugs, errors, and problems. Covers tactical fixes, deep debugging, and universal troubleshooting. Use when something is broken, failing, crashing, throwing errors, or behaving unexpectedly."
argument-hint: "[error message or symptom | --deep | --triage]"
---

# /fix — Debug & Fix

Three modes:

- Default — tactical bug fix (most common)
- `--deep` — systematic hypothesis-driven debugging for hard/intermittent issues
- `--triage` — universal problem triage for any error type

## Default — Tactical Fix

1. **Reproduce** — confirm the bug; get the exact error and stack trace
2. **Locate** — find the failing code path (use LSP find_definition / find_references)
3. **Root cause** — state what's wrong in one sentence before writing any fix
4. **Fix** — minimal change that fixes the root cause; don't fix adjacent things
5. **Verify** — run relevant tests; confirm the error is gone
6. **Commit** — `fix: <what was broken and why>`

If root cause is unclear, add temporary logging and ask the user to run it.

## --deep — Systematic Debugging

For hard or intermittent issues. Don't patch — understand.

1. **Characterize** — what exactly fails? Always? Under what conditions? Since when?
2. **Gather data** — logs, error messages, stack traces; run with verbose output
3. **Hypothesize** — list 2-3 possible root causes, ranked by likelihood
4. **Test hypotheses** — fastest test first; add logging/assertions to isolate
5. **Confirm root cause** — one sentence before any fix
6. **Fix + verify** — minimal fix; no regression

For non-deterministic bugs: instrument with timestamps and retry counts.

## --triage — Universal Troubleshooter

Triage any problem type and route to the right fix strategy.

| Type                | Signals                                        |
| ------------------- | ---------------------------------------------- |
| Build failure       | Compile error, module not found, bundler error |
| Test failure        | Assertion errors, coverage drops               |
| CI failure          | GitHub Actions red, pipeline failed            |
| Runtime error       | Exception/crash, 500 errors                    |
| Type error          | TypeScript/mypy errors                         |
| Dependency conflict | Version mismatch, missing package              |
| Environment issue   | Missing env var, wrong runtime version         |
| Production incident | Live system broken, users affected             |

Announce: "Triaged as: [type]. Investigating..."

For production incidents: capture → reproduce → evidence → root cause → fix → verify → document in `.planning/INCIDENT.md`.

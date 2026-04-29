---
name: fix
description: "Debug and fix bugs, errors, and problems. Covers tactical fixes, deep debugging, and universal troubleshooting. Use when something is broken, failing, crashing, throwing errors, or behaving unexpectedly."
argument-hint: "[error message or symptom | --deep | --triage | --bisect]"
---

# /fix — Debug & Fix

Four modes:

- Default — tactical bug fix (most common)
- `--deep` — systematic hypothesis-driven debugging for hard/intermittent issues
- `--triage` — universal problem triage for any error type
- `--bisect` — find the commit that introduced a regression using git bisect

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

## --bisect — Find Regression Commit

Use when a feature worked in the past but is now broken, and you want to identify exactly which commit introduced the regression.

### Prerequisites

- A test command that reliably reproduces the bug
- The test command must exit with:
  - Exit code 0 when the code is **good** (bug does not exist)
  - Exit code 1 (or non-zero) when the code is **bad** (bug exists)
- A known-good reference: commit hash, tag, or date when the feature worked
- Test command should run fast (ideally under 30 seconds per bisect iteration)

### Process

1. **Get test command** — ask user for a shell command that reproduces the bug
   - Example: `npm test -- --testNamePattern="my failing test"` or `./check_feature.sh`
   - Verify the command works on current HEAD (should fail with non-zero exit)

2. **Find known-good commit** — ask for a commit/tag when the bug didn't exist
   - If unknown, suggest: `git log --oneline -20` to browse history
   - User provides hash, tag, or date (will convert to hash)

3. **Start bisect session**

   ```bash
   git bisect start
   git bisect bad HEAD          # Mark current commit as bad
   git bisect good <ref>        # Mark known-good commit as good
   ```

4. **Auto-bisect**

   ```bash
   git bisect run <test-command>
   ```

   - Git automatically checks out midpoint commits and runs the test
   - Continues until the first bad commit is found
   - Do NOT interrupt; let it run to completion

5. **Report findings**
   - Show the bad commit: `git show <hash>`
   - Extract: author, commit message, diff of the problematic change
   - Document findings in `.planning/BISECT.md`:
     - Bad commit hash and message
     - What changed in that commit
     - Why it likely caused the regression
     - Suggested fix strategy

6. **Clean up**
   ```bash
   git bisect reset
   ```

   - Restores working tree to original HEAD
   - **Always do this**, even if interrupted or on error

### Example

```bash
# Test command that exits 0 when good, 1 when bad
npm test -- --testNamePattern="login feature"

# Known good: git tag v1.5.0 (before regression)
git bisect start
git bisect bad HEAD
git bisect good v1.5.0
git bisect run npm test -- --testNamePattern="login feature"

# Reports first bad commit
# git bisect reset
```

### Safety Notes

- Bisect is non-destructive but leaves you in a detached HEAD state
- Always run `git bisect reset` to return to original HEAD
- If you need to interrupt: `git bisect reset` (never just Ctrl+C and switch branches)
- The test command must be idempotent (safe to run multiple times)
- For slow tests: consider a fast subset (e.g., single test file) as the bisect command

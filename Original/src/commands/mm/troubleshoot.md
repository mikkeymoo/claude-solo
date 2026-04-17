---
name: mm:troubleshoot
description: "Universal debugging — triage any problem (build errors, test failures, CI failures, runtime errors, type errors, dependency conflicts, environment issues, production incidents) and fix it."
argument-hint: "[error message or symptom description]"
---

Universal debugger. Triage any problem, route to the right strategy, fix it.

If no argument given, ask: "What's broken? Paste the error message or describe the symptom."

---

## Step 1 — Triage

Identify the problem type from the error/symptom:

| Type | Signals |
|------|---------|
| **Build failure** | Compile error, module not found, webpack/bundler error |
| **Test failure** | Tests failing, coverage drops, assertion errors |
| **CI failure** | GitHub Actions red, pipeline failed |
| **Runtime error** | Exception/crash in running app, 500 errors |
| **Type error** | TypeScript/mypy errors, type mismatches |
| **Dependency conflict** | Version mismatch, resolution error, missing package |
| **Environment issue** | Missing env var, wrong Node/Python version, config missing |
| **Production incident** | Live system broken, users affected |

Announce: "Triaged as: [type]. Investigating..."

---

## Build failure

```bash
rtk npm run build 2>&1 | head -50   # Node
rtk tsc --noEmit 2>&1 | head -50    # TypeScript
rtk cargo build 2>&1 | head -50     # Rust
rtk python -m build 2>&1 | head -30 # Python
```

Categorize errors: TypeScript type errors → use `type-error-analyzer` agent. Module resolution → check import paths, run `npm install`. Syntax errors → show exact location and fix. If ≤5 errors: apply all fixes, re-run build, verify clean. If >5 errors: show categorized list, fix by category.

---

## Test failure

```bash
rtk pnpm test 2>&1 | tail -80   # Node
rtk python -m pytest -x -q      # Python (stop at first failure)
rtk cargo test 2>&1 | tail -50  # Rust
```

For each failing test: show the assertion, show what was expected vs. actual. Check `rtk git log --oneline -5` — did a recent commit break it? If yes, diff that commit against the failing test. If the test itself is wrong, explain why and fix it. If the code is wrong, fix the code.

---

## CI failure

```bash
rtk gh run list --limit 5
rtk gh run view [run-id] --log-failed
```

Find the failing step. Apply the same fix logic as for build/test failures in the relevant category. Check if the failure is environment-specific (CI has different Node version, missing env var, etc.).

---

## Runtime error / crash

Capture the full stack trace. Then:
1. Identify the exception type and the root line (not the wrapper)
2. Read the file at that line — what could cause this?
3. Form 2-3 hypotheses ranked by likelihood
4. Test the most likely hypothesis first
5. Add a guard or fix at the root cause — not just at the exception handler

Use `root-cause-analyst` agent for complex multi-layer failures.

---

## Type error

Use `type-error-analyzer` agent. Pass the full error output.

For TypeScript:
```bash
rtk pnpm tsc --noEmit 2>&1
```

Common fixes: missing generic type parameter, incorrect interface shape, `undefined` not handled, `as unknown as T` abuse. Fix at the type boundary — don't use `any` or `@ts-ignore` unless there's a documented reason.

---

## Dependency conflict

```bash
npm ls [package] 2>&1 | head -30   # Node: show dependency tree
pip show [package]                  # Python: show installed version
rtk pnpm why [package]             # pnpm: explain why it's installed
```

Identify the conflicting versions. Check if one package requires an older version. Solutions in order: update the requiring package first, then pin a compatible version, then use `overrides`/`resolutions` as last resort.

---

## Environment issue

```bash
node --version && npm --version 2>/dev/null || true
python --version 2>/dev/null || true
cat .env.example 2>/dev/null | grep -v "^#" | grep "="
```

Check: is the required env var set? Is the tool version correct for this project? Does `.env.example` document all required vars? Fix: set the missing var, or document it in `.env.example`.

---

## Production incident

Full incident workflow:

**1. Capture** — symptom, when it started, who/what is affected, blast radius (one user? all users? data loss?)

**2. Reproduce** — can you reproduce locally? If yes: capture exact steps. If no: check logs, error tracking (Sentry/CloudWatch), recent deploys.

**3. Evidence** — error logs, stack traces, deploy diffs, recent metrics. What changed recently? (`rtk git log --since="2 days ago"`)

**4. Root cause** — form 2-3 hypotheses by likelihood. Test most likely first. If wrong, move to next.

**5. Fix** — implement the minimal fix for the root cause. Don't fix other things noticed. If a quick fix is needed before a proper fix, document the temp fix explicitly.

**6. Verify** — confirm the fix resolves the original symptom. Run test suite — no regressions.

**7. Document** — write `.planning/INCIDENT.md`:
```markdown
# Incident Report — [date]
Severity: P1/P2/P3/P4 | Status: RESOLVED

## Summary: [one sentence: what broke and why]
## Timeline: [detected → investigated → root cause → fix → confirmed resolved]
## Root Cause: [what actually caused it]
## Fix Applied: [what changed, commit hash]
## Prevention: [ ] Add monitoring for X  [ ] Add test for Y
```

End with: "Incident documented. Consider adding prevention items to the next /mm:brief."

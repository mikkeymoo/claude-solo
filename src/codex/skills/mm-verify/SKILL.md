# mm-verify

Hard verification gate: lint, typecheck, tests, smoke check, changed files review, and secrets scan. Produces pass/fail evidence report.

## Instructions
Hard verification gate. Run this before /mm:ship to get a pass/fail evidence summary.

This is NOT a code review — it's a mechanical check that everything works. Run all checks, report results, block shipping on failures.

Execute these checks in order:

**1. Lint**
- Run the project linter (eslint, ruff, clippy, etc.)
- Report: pass/fail + count of violations
- If no linter configured: skip and note it

**2. Type check**
- Run typecheck (tsc --noEmit, mypy, cargo check, etc.)
- Report: pass/fail + count of errors

**3. Tests**
- Run the full test suite (pytest, vitest, jest, cargo test, dotnet test)
- Report: pass/fail + X passed / Y failed / Z skipped
- If any test fails, show the failure output

**4. Smoke check**
- If the app has a dev server: start it, confirm it responds (HTTP 200)
- If CLI tool: run --help or a trivial command
- If library: import it successfully
- If none apply: skip

**5. Changed files review**
- List all files changed since the last tag or since PLAN.md was created
- Flag any files that were changed but have no test coverage
- Flag any new dependencies added

**6. Secrets scan**
- Grep for patterns: API keys, passwords, tokens, connection strings in source files
- Check .env is in .gitignore
- Report: clean / X potential secrets found

Write `.planning/VERIFY.md` with results:

```markdown
# Verification Report
Status: PASS | FAIL
Date: [timestamp]

## Results
| Check       | Status | Details          |
|-------------|--------|------------------|
| Lint        | ✅/🔴  | 0 violations     |
| Typecheck   | ✅/🔴  | 0 errors         |
| Tests       | ✅/🔴  | 42 pass / 0 fail |
| Smoke       | ✅/⏭️  | HTTP 200 on /    |
| Files       | ✅/⚠️  | 3 changed, all covered |
| Secrets     | ✅/🔴  | clean            |

## Blocking Issues
[list any failures that must be fixed]

## Warnings
[list any non-blocking concerns]
```

If all pass: "✅ Verification passed. Ready to /ship."
If any fail: "🔴 Verification failed. Fix blocking issues before /ship." — list exactly what to fix.

---
name: mm:verify
description: "Hard verification gate: lint, typecheck, tests, smoke check, changed files review, and secrets scan. Produces pass/fail evidence report."
---

Hard verification gate. Run this before /mm:ship to get a pass/fail evidence summary.

This is NOT a code review — it's a mechanical check that everything works. Run all checks, report results, block shipping on failures.

First, orient yourself:
```bash
rtk git status
rtk git log --oneline -10
```

Execute these checks in order:

**1. Lint**
```bash
# Pick whichever applies:
rtk lint               # ESLint / Biome
rtk pnpm run lint      # npm script
rtk ruff check .       # Python
rtk cargo clippy       # Rust
```
Report: pass/fail + count of violations. If no linter configured: skip and note it.

**2. Type check**
```bash
rtk tsc --noEmit       # TypeScript
rtk mypy .             # Python
rtk cargo check        # Rust
```
Report: pass/fail + count of errors.

**3. Tests**
```bash
rtk vitest run         # Vitest
rtk pnpm test          # npm test script
rtk python -m pytest   # Python
rtk cargo test         # Rust
```
Report: pass/fail + X passed / Y failed / Z skipped. Show failure output.

**4. Smoke check**
- If the app has a dev server: start it, confirm it responds (HTTP 200)
- If CLI tool: run `--help` or a trivial command
- If library: import it successfully
- If none apply: skip

**5. Changed files review**
```bash
rtk git diff --stat HEAD~1
rtk git diff --name-only HEAD~5
```
Flag any files changed but with no test coverage. Flag new dependencies added.

**6. Secrets scan**
```bash
# Scan for common secret patterns:
grep -r "sk-\|api_key\|API_KEY\|password\s*=\|token\s*=" --include="*.ts" --include="*.py" --include="*.js" -l .
# Check .env is gitignored:
cat .gitignore | grep .env
```
Report: clean / X potential secrets found.

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

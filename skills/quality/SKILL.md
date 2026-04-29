---
name: quality
description: "Quality audit and verification — dependency audit, accessibility, database migration, API route testing, and hard verification gate. Use when checking quality, verifying before ship, or auditing deps."
argument-hint: "[--deps | --a11y | --migrate <desc> | --route [method] [endpoint] | --gate | --all (default)]"
---

# /quality — Quality & Verification

- `--deps` — dependency vulnerabilities, outdated packages, license issues
- `--a11y` — WCAG 2.1 AA accessibility audit with auto-fix
- `--migrate <description>` — plan and execute a safe database migration
- `--route [method] [endpoint]` — test an authenticated API route end-to-end
- `--gate` — hard verification gate (lint, typecheck, tests, secrets scan)
- No argument / `--all` — runs `--deps` + `--a11y`

## --deps — Dependency Audit

1. **Vulnerability scan** — CVEs with known fixes
2. **Outdated packages** — anything > 1 major version behind
3. **License audit** — flag GPL/AGPL in commercial projects
4. **Unused dependencies** — packages not imported anywhere

Produce prioritized action plan: Do now (blocking CVEs) → Do this week (major bumps) → Do next sprint (cleanup). Ask before running any installs.

## --a11y — Accessibility Audit

Scope: React/Vue/Angular/HTML. WCAG 2.1 AA.
Auto-fix low-risk issues (missing alt text, aria-labels). Present structural changes for approval.

## --migrate — Database Migration

1. Check current migration state
2. Plan — identify multi-step needs, flag locking risks
3. Write forward + rollback migration
4. Show generated SQL for approval before applying
5. Apply, verify schema, run tests

Never auto-apply a migration that drops data.

## --route — API Route Testing

1. Auth setup — detect auth type, retrieve token
2. Make the request with curl
3. Validate: status code, valid JSON, response time < 500ms, no stack traces
4. Report pass/fail

## --gate — Hard Verification Gate

Run before /ship. Mechanical checks, not a code review.

1. **Lint** — ESLint/Biome/ruff/clippy. Pass/fail + violation count.
2. **Type check** — tsc/mypy/cargo check. Pass/fail + error count.
3. **Tests** — full suite. Pass/fail + counts.
4. **Smoke check** — dev server responds, CLI runs --help, library imports.
5. **Changed files** — flag files changed with no test coverage.
6. **Secrets scan** — scan for hardcoded secrets, verify .env gitignored.

Write `.planning/VERIFY.md` with results table.
If all pass: "✅ Verification passed. Ready to /ship."
If any fail: "🔴 Verification failed." — list what to fix.

## Bundled Script

Run `python skills/quality/complexity_report.py [path]` for code complexity analysis.

Flags:

- `--py-only` / `--js-only` — language filter
- `--threshold N` — custom complexity threshold (default: 10)
- `--top N` — show top N functions (default: 15)
- `--json` — machine-readable JSON output

Reports: cyclomatic complexity, function length, parameter count, nesting depth.
Flags functions exceeding thresholds and identifies file hotspots.
Uses Python AST for `.py` and regex heuristics for JS/TS.

Use this as part of `--gate` or `--all` to surface complexity risks before shipping.

## SUCCESS CRITERIA

- [ ] For `--gate`: All checks (lint, typecheck, tests, secrets, smoke) show explicit pass/fail status
- [ ] Each failing check lists violation count and specific errors, not just "failed"
- [ ] Report includes `.planning/VERIFY.md` with results table summarizing all checks
- [ ] Files with changes but no test coverage are flagged by name with coverage percentage
- [ ] Summary line clearly states "✅ Verification passed. Ready to /ship." OR "🔴 Verification failed." with what must be fixed
- [ ] For `--deps`: Vulnerabilities are prioritized (now, this week, next sprint) with actionable steps
- [ ] For `--route`: Response includes status code, validation results, and timing; no stack traces exposed

## EXAMPLE OUTPUT

```markdown
## Verification Gate Report

### Summary

🔴 Verification failed. 2 checks failed, see details below.

### Results

| Check        | Status     | Details                             |
| ------------ | ---------- | ----------------------------------- |
| Lint         | ✅ PASS    | 0 violations                        |
| Type Check   | 🔴 FAIL    | 3 errors in src/api/routes.ts       |
| Tests        | ✅ PASS    | 142/142 passed (5.2s)               |
| Secrets Scan | ✅ PASS    | No secrets detected                 |
| Smoke Check  | ✅ PASS    | Dev server starts, CLI --help works |
| Coverage     | 🟡 WARNING | 3 files changed with <80% coverage  |

### Failed Checks

#### Type Check: 3 errors

- `src/api/routes.ts:42` — Parameter 'userId' implicitly has type 'any'
- `src/api/routes.ts:156` — Property 'email' does not exist on type 'User'
- `src/types/index.ts:8` — Missing return type annotation on function 'parseConfig'

**Action**: Fix type errors and re-run `tsc`

#### Coverage Warning

Files changed with <80% coverage:

- `src/utils/helpers.ts` — 62% (need 5 more lines covered)
- `src/validators/email.ts` — 71% (need 8 more lines covered)

**Action**: Add tests for uncovered branches or explain why coverage is acceptable.

### Next Steps

1. Fix the 3 TypeScript errors
2. Improve coverage in 2 files or accept coverage gaps
3. Re-run `/quality --gate` to verify
4. Then run `/ship`
```

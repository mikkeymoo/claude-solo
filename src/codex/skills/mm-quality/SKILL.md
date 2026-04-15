---
name: mm-quality
description: "Quality audit suite — dependency vulnerabilities, accessibility audit, database migration, and API route testing."
---

# mm-quality

Quality audit suite — dependency vulnerabilities, accessibility audit, database migration, and API route testing.

## Instructions
Quality audit suite. Default runs dependency audit + accessibility audit. Use flags for targeted work.

- `--deps` — dependency vulnerabilities, outdated packages, license issues
- `--a11y` — WCAG 2.1 AA accessibility audit with auto-fix
- `--migrate <description>` — plan and execute a safe database migration
- `--route [method] [endpoint]` — test an authenticated API route end-to-end
- No argument / `--all` — runs `--deps` + `--a11y`

---

## --deps — Dependency Audit

Delegate to `dependency-auditor` agent for a full report covering:
1. **Vulnerability scan** — CVEs with known fixes
2. **Outdated packages** — anything > 1 major version behind
3. **License audit** — flag GPL/AGPL in commercial projects, unknown licenses
4. **Unused dependencies** — packages in manifest not imported anywhere
5. **Supply chain risks** — unmaintained packages, suspicious new additions

Produce a prioritized action plan:
```markdown
## Dependency Action Plan
### Do now (blocking)
- [ ] upgrade X from 1.2 to 1.4 — CVE-2024-XXXX
### Do this week
- [ ] upgrade Y from 2.0 to 3.0 — major version, check migration guide
### Do next sprint
- [ ] remove Z — unused, confirmed by depcheck
```

Ask before running any installs or updates.

---

## --a11y — Accessibility Audit

Delegate to `accessibility-auditor` agent. Scope: React/Vue/Angular/HTML component files.

1. Scan for ARIA, semantic HTML, keyboard, and color issues (WCAG 2.1 AA)
2. Auto-fix low-risk issues: missing alt text, aria-label on icon buttons, aria-hidden on decorative SVGs
3. Present higher-risk fixes (role changes, structural changes) for approval
4. Report all violations with file:line and fix

Summary:
```markdown
## Accessibility Audit Results
### Auto-fixed
- X issues fixed across Y files
### Needs review
- [structural changes needing approval]
### Remaining violations
| Severity | Count | Top issue |
|----------|-------|-----------|
| Critical | X     | ...       |
```

---

## --migrate <description> — Database Migration

Delegate to `migration-specialist` agent.

Describe the schema change needed, e.g.:
- "Add `verified_at` column to users table"
- "Rename `user_id` to `customer_id` in orders"
- "Remove deprecated `old_status` column"

The agent will:
1. Check current migration state
2. Plan the migration — identify multi-step needs (add nullable → backfill → add constraint), flag locking risks on large tables
3. Write forward + rollback migration
4. Show generated SQL for approval before applying
5. Apply migration, verify schema, run existing tests

Safety rules:
- Never auto-apply a migration that drops data — always ask first
- Always show SQL before applying
- For production: require explicit confirmation

---

## --route [method] [endpoint] — API Route Testing

Test an authenticated API route end-to-end. Usage: `/mm:quality --route GET /api/users`

**1. Auth setup** — detect auth type from codebase (JWT, OAuth, Basic). Retrieve token using env vars (`TEST_USER`, `TEST_PASSWORD`, or `OAUTH_CLIENT_ID`/`OAUTH_CLIENT_SECRET`).

**2. Make the request**
```bash
curl -s -w "\n%{http_code}\n%{time_total}" \
  -H "Authorization: Bearer [token]" \
  -H "Content-Type: application/json" \
  [--data '{}' if POST/PUT/PATCH] \
  http://localhost:3000[endpoint]
```

**3. Validate response**
- Status code matches expected (default: 2xx)
- Response body is valid JSON (if JSON endpoint)
- Response time < 500ms (flag if slower)
- No error messages or stack traces in response body

**4. Report**
```
Testing: [METHOD] [endpoint]
Auth: [type] token obtained ✓
Status: [code] [OK/FAIL]
Response time: [Xms] [OK/SLOW]
Body: [valid JSON / schema check result]
Result: PASS / FAIL — [reason if fail]
```

For batch testing, create `routes.json` with array of `{method, path, auth, expectedStatus}` and pass it as the argument.

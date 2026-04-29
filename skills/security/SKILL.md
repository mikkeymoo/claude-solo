---
name: security
description: "OWASP-based security audit: injection, auth, secrets, API safety, and dependency CVEs. Manual trigger only. Use when explicitly asked for a security review."
---

# /security — Security Audit

Scope: files changed since last tag, or specified path.

1. **Injection** — SQL injection, command injection, path traversal
2. **Auth & Authorization** — all endpoints protected? JWT verified? `alg:none` rejected?
3. **Secrets** — hardcoded keys/tokens/passwords? Secrets in logs or errors?
4. **Input validation** — validated at boundaries? HTML sanitized?
5. **Dependencies** — `npm audit` / `cargo audit` / `pip-audit`; flag CRITICAL/HIGH CVEs
6. **Security headers** — CSP, X-Content-Type-Options, X-Frame-Options

Labels:

- 🔴 CRITICAL — fix immediately, block ship
- 🟡 HIGH — fix before next release
- 🔵 MEDIUM/LOW — backlog

Auto-fix 🔴 CRITICAL findings and commit: `fix(security): <issue>`

## Bundled Script

Run `python skills/security/secrets_scanner.py [path]` for automated secret detection.

Flags:

- `--entropy` — include Shannon entropy analysis for high-entropy strings
- `--strict` — lower thresholds, more findings
- `--json` — machine-readable JSON output

Detects: AWS keys, GitHub/Slack/Stripe/OpenAI/Anthropic tokens, private key headers,
database URLs with passwords, generic API keys/secrets, unignored `.env` files.
Exits with code 1 if CRITICAL findings exist.

Use this script for step 3 (Secrets) of the audit. Review its output before auto-fixing.

## SUCCESS CRITERIA

- [ ] Every finding has: OWASP category, severity (🔴 CRITICAL / 🟡 HIGH / 🔵 MEDIUM / 🔵 LOW), file:line location, and specific vulnerability description
- [ ] CRITICAL findings are listed first and marked for immediate fix before ship
- [ ] All HIGH findings include recommended remediation steps with code examples
- [ ] Summary includes finding count by severity: "X findings (Y critical, Z high, N medium, M low)"
- [ ] No speculative findings — each issue is verified in the actual code, not hypothetical
- [ ] Auto-fixed CRITICAL findings are committed with `fix(security): <category>` message

## EXAMPLE OUTPUT

````markdown
## Security Audit Results

Total findings: 3 (1 critical, 1 high, 1 medium)

### 🔴 CRITICAL

**SQL Injection** (OWASP A03:2021 — Injection)
File: `src/database/queries.ts:87`

```typescript
const user = db.query(`SELECT * FROM users WHERE email = '${email}'`);
```
````

User input is directly interpolated into SQL. Attacker can inject `' OR '1'='1` to bypass authentication.
**Fix**: Use parameterized queries:

```typescript
const user = db.query("SELECT * FROM users WHERE email = ?", [email]);
```

**Auto-fixed**: ✅ Committed as fix(security): SQL injection in user lookup

### 🟡 HIGH

**Hardcoded API Key** (OWASP A02:2021 — Cryptographic Failure)
File: `.env.example:3` (but also found in code)

```
STRIPE_SECRET_KEY=sk_test_4eC39HqLyjWDarht...
```

Secrets should never be in source code or .env.example. Use a secrets manager.
**Fix**: Remove from .env.example, document format with placeholder instead.

### 🔵 MEDIUM

**Missing Security Headers** (OWASP A01:2021 — Broken Access Control)
File: `src/server.ts:12`
No Content-Security-Policy, X-Frame-Options, or X-Content-Type-Options headers set.
**Fix**: Add to middleware:

```typescript
app.use((req, res, next) => {
  res.setHeader("Content-Security-Policy", "default-src 'self'");
  res.setHeader("X-Frame-Options", "DENY");
  res.setHeader("X-Content-Type-Options", "nosniff");
  next();
});
```

```

```

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
5. **Dependencies + CVE Scan** — `npm audit` / `cargo audit` / `pip-audit`; flag CRITICAL/HIGH CVEs
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

## CONFIDENCE SCORING

Rate each finding with a confidence score (0–100):

| Score  | Label    | Meaning                                                        |
| ------ | -------- | -------------------------------------------------------------- |
| 95–100 | Definite | Issue is certain — reproducible, not context-dependent         |
| 75–94  | High     | Very likely an issue, minor context uncertainty                |
| 50–74  | Medium   | Context-dependent — may be intentional or environment-specific |
| <50    | Low      | Flag explicitly — possible false positive, needs human review  |

Format: append `[confidence: N]` to each finding.

Example: `🔴 SQL injection in user_search() — string interpolation in query [confidence: 97]`

For LOW confidence findings (<50): prefix with `⚠️ UNCERTAIN:` and explain what additional context would clarify it.

## CVE Scanning Commands

For step 5 (Dependencies + CVE Scan), use one of these commands based on your project type:

**npm/pnpm projects:**

```bash
npm audit --json 2>/dev/null | python -c "import json,sys; data=json.load(sys.stdin); [print(f'  {k}: {v[\"severity\"]} - {v[\"title\"]}') for k,v in data.get('vulnerabilities',{}).items() if v['severity'] in ['critical','high']]"
```

**Python projects:**

```bash
pip-audit --format=json 2>/dev/null | python -c "import json,sys; [print(f'  {v[\"name\"]} {v[\"version\"]}: {v[\"id\"]} ({v[\"fix_versions\"]})') for v in json.load(sys.stdin).get('dependencies',[]) if v.get('vulns')]"
```

**Rust projects:**

```bash
cargo audit --json 2>/dev/null | python -c "import json,sys; data=json.load(sys.stdin); [print(f'  {v[\"package\"][\"name\"]}: {v[\"advisory\"][\"id\"]} - {v[\"advisory\"][\"title\"]}') for v in data.get('vulnerabilities',{}).get('list',[])]"
```

**If tools not installed:**

- npm audit (built-in with npm/pnpm)
- pip install pip-audit (then: `pip-audit`)
- cargo install cargo-audit (then: `cargo audit`)

## SELF-CHECK

Before returning, grade your response:

- [ ] Every finding has an OWASP category and severity label (🔴 CRITICAL / 🟡 HIGH / 🔵 MEDIUM / 🔵 LOW) — PASS/FAIL
- [ ] Each finding has a file:line location and is verified in actual code, not hypothetical — PASS/FAIL
- [ ] CRITICAL findings are listed first and include specific remediation with code examples — PASS/FAIL
- [ ] Summary includes finding count by severity: "X findings (Y critical, Z high, N medium, M low)" — PASS/FAIL
- [ ] Auto-fixed CRITICAL findings are committed with `fix(security): <category>` message — PASS/FAIL

If any item is FAIL: revise before returning.

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

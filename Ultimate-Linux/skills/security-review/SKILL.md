---
name: security-review
description: Manual-trigger OWASP Top 10 security audit with secrets detection, auth pattern review, and dependency CVE check. TRIGGER ONLY when the user explicitly says "security review", "security audit", "/security-review", or asks to check for vulnerabilities. DO NOT auto-trigger during normal development. Solo-developer aware — no team ceremony, actionable findings only.
---

# Security Review — OWASP + Secrets + Auth + Deps

Run a comprehensive security pass. Output findings with severity, exploitability, and the exact fix. You are auditing for a solo developer — no "escalate to security team" theater. If something is exploitable, show how; if it's defense-in-depth, say so.

## Scope — run in parallel

### 1. Secrets detection (fastest, run first)
```bash
rtk git log --all --pretty=format: --name-only | sort -u > /tmp/all-files.txt
rtk grep -rnE "(api[_-]?key|secret|password|token|bearer|aws_secret|private_key)\s*[:=]\s*['\"][a-zA-Z0-9_\-]{16,}" \
  --include="*.{js,ts,py,rs,go,yaml,yml,json,env,sh}" . \
  | grep -v node_modules | grep -v '.git/' | grep -v '/dist/'
```
Plus: check git history for committed `.env*` files (`git log --all --full-history -- '**/.env*'`).
Plus: entropy check on any string >20 chars that looks base64/hex.

### 2. OWASP Top 10 (2021)
- **A01 Broken Access Control** — find every route/handler; for each: does it check auth? does it check ownership of the resource (user can only access their own data)?
- **A02 Cryptographic Failures** — grep for `md5`, `sha1` used on passwords or tokens; any DIY crypto (XOR, custom hashing); missing TLS (`http://` in non-local configs).
- **A03 Injection** — string interpolation in SQL (`f"SELECT ... {var}"`, `` `SELECT ... ${var}` ``); `exec`/`eval` with user input; `child_process.exec` concatenating input; `innerHTML = userInput`.
- **A04 Insecure Design** — password reset without rate limit; no lockout after N failed logins; no re-auth for sensitive ops.
- **A05 Security Misconfiguration** — CORS `*` in prod; default credentials; verbose error pages; missing security headers (`CSP`, `X-Frame-Options`, `HSTS`).
- **A06 Vulnerable Components** — `pnpm audit`, `pip-audit`, `cargo audit`. Highs and criticals only.
- **A07 ID & Auth Failures** — JWT without expiry/issuer/audience checks; session IDs in URLs; no CSRF on mutating endpoints.
- **A08 Software & Data Integrity** — unsigned webhooks; downloading + executing remote scripts; unpinned CI actions (`actions/checkout@main`).
- **A09 Logging Failures** — passwords/tokens in logs (grep log calls near auth code); no audit log for security events.
- **A10 SSRF** — user-controlled URLs passed to `fetch`/`requests.get` without allowlist.

### 3. Auth-flow review
- Walk every auth-protected route; trace from entry point through middleware.
- Confirm constant-time comparison (`crypto.timingSafeEqual`, `hmac.compare_digest`) for tokens/secrets.
- Confirm password hashing uses `bcrypt`/`argon2`/`scrypt` — never plain `sha256`.
- Check session invalidation on password change.
- Check JWT: signature verified, `exp` checked, `iss` checked, `aud` checked.

### 4. Input validation boundaries
- API routes: parsed through a schema (zod, pydantic, etc.) before hitting business logic?
- File uploads: size cap? extension allowlist? stored outside webroot?
- URL params and query strings: coerced and validated?

## Output format
```
# Security Review — <repo> — <date>

## 🔴 Critical — exploitable, fix before next deploy
<N> finding(s)

### 1. <short title> — <file:line>
**OWASP:** <category>
**Exploit:** <concrete step — e.g. "POST /reset with victim's email + attacker's new_password, no rate limit, <5s to crack OTP">
**Evidence:** <code snippet>
**Fix:**
```<lang>
<exact replacement code>
```

## 🟡 High — exploitable with effort, or serious defense-in-depth gap
...

## 🔵 Medium — defense-in-depth, low exploitability
...

## ✅ Verified safe
- <area> — <what you checked>

## Summary
- Critical: <n>
- High: <n>
- Medium: <n>
- Secrets in history: <n>
- Vulnerable deps (CVSS ≥ 7): <n>
```

## Rules
- Every finding cites `file:line` or a concrete command.
- Never dump a raw grep over `api[_-]?key` — dedupe, filter false positives (env var names, example placeholders).
- For a solo developer: skip "get a second reviewer" recommendations. Skip "inform the security team". Provide the fix, not the process.
- If the audit is clean, say so with what you verified. A short honest report is better than padding.
- Do **not** write fix code directly — produce the diff/snippet and let the developer apply it after reviewing the full report. (Exception: if the user says "fix the criticals automatically", then only criticals, one commit each.)

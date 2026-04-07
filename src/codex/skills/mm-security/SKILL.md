---
name: mm-security
description: "Claude-solo command skill"
---

# mm-security

Claude-solo command skill

## Instructions
---
name: mm:security
description: "Full OWASP-based security audit: injection, auth, secrets exposure, API security, dependency vulnerabilities, and data handling."
---

Full security audit. OWASP-based. Run before any /mm:ship on enterprise or user-facing code.

Scope: the files changed since last tag, or files listed in `.planning/PLAN.md`, or specified path.

Run 8 checks in order:

**1. Injection**
- SQL injection: any string concatenation into queries? Use parameterized queries.
- Command injection: any user input reaching shell commands?
- Path traversal: can a user escape the intended directory with `../`?
- SSTI / XSS: user input rendered without sanitization?

**2. Authentication & Authorization**
- Are all endpoints protected? Any missing auth middleware?
- JWT: is the signature verified? Is `alg: none` rejected?
- Session tokens: generated securely (crypto-random, not guessable)?
- Password hashing: bcrypt/argon2 with sufficient cost factor?
- Is authorization checked at the data layer, not just the route layer?

**3. Secrets & Credentials**
- Scan all changed files for: API keys, passwords, tokens, private keys
- Are secrets in env vars — not hardcoded, not in config files committed to git?
- Do error messages or logs ever expose secrets or stack traces to users?

**4. API Security**
- Rate limiting on auth endpoints? (brute force protection)
- CORS: wildcard origins? Credentials allowed with wildcard?
- Input validation at every API boundary (not just client-side)
- Response: does any endpoint expose more data than the caller needs?

**5. Data Exposure**
- Does any query return `SELECT *` where only specific fields are needed?
- Are internal IDs, user emails, or PII included in responses unnecessarily?
- Are error responses consistent (prevent user enumeration)?

**6. Dependency vulnerabilities**
```bash
# Python
pip-audit  # or: safety check
# Node
npm audit --audit-level=high
```
List any HIGH or CRITICAL findings.

**7. Transport & Storage**
- Is sensitive data encrypted at rest (DB fields, file storage)?
- Are all external calls over HTTPS (no HTTP fallback)?
- Are cookies: `HttpOnly`, `Secure`, `SameSite=Strict`?

**8. Audit logging**
- Are authentication events logged (login, logout, failed attempts)?
- Are admin/privileged actions logged with user ID and timestamp?
- Are logs tamper-evident (append-only, off-system for critical events)?

Output format:
- 🔴 CRITICAL — exploit is possible, fix before ship
- 🟠 HIGH — serious risk, fix this sprint
- 🟡 MEDIUM — should fix, schedule it
- 🔵 LOW — harden when convenient

Auto-fix any 🔴 CRITICAL issues. Present 🟠 HIGH list for decision.

End with: "Security audit complete. [X critical, Y high, Z medium]. Ready to /ship?" only if no CRITICAL remain.

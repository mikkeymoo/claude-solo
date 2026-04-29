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

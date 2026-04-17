---
name: mm:security
description: "OWASP-based security audit: injection, auth, secrets, API safety, and dependency CVEs."
---

Security audit. Scope: files changed since last tag, or files in `.planning/PLAN.md`, or specified path.

Check in order:

1. **Injection** — SQL injection via string concat? Command injection via user input? Path traversal?
2. **Auth & Authorization** — all endpoints protected? JWT signature verified? `alg:none` rejected? Auth at data layer not just route layer?
3. **Secrets** — API keys, tokens, or passwords hardcoded or in committed config? Secrets leaking in logs or error messages?
4. **Input validation** — user input validated at system boundaries? HTML sanitized before render?
5. **Dependencies** — run `npm audit` / `cargo audit` / `pip-audit`; flag CRITICAL and HIGH CVEs
6. **Security headers** — CSP, X-Content-Type-Options, X-Frame-Options present on responses?

Label each finding:

- `🔴 CRITICAL` — fix immediately, block ship
- `🟡 HIGH` — fix before next release
- `🔵 MEDIUM/LOW` — log for backlog

Auto-fix `🔴 CRITICAL` findings and commit: `fix(security): <issue>`

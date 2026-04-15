---
name: mm-security
description: "Full security review: OWASP audit + adversarial attacker-mindset review + enterprise compliance checklist. Run before /mm:ship on any user-facing or enterprise code."
---

# mm-security

Full security review: OWASP audit + adversarial attacker-mindset review + enterprise compliance checklist. Run before /mm:ship on any user-facing or enterprise code.

## Instructions
Comprehensive security review. Runs all three lenses by default — OWASP technical audit, adversarial attacker review, and enterprise compliance checklist.

Use `--owasp`, `--adversarial`, or `--compliance` to run a single lens. Default (`--all`) runs all three.

Scope: files changed since last tag, or files in `.planning/PLAN.md`, or a specified path.

---

## Part 1 — OWASP Technical Audit

**1. Injection** — SQL string concat? User input to shell? Path traversal with `../`? SSTI/XSS without sanitization?

**2. Auth & Authorization** — All endpoints protected? JWT: signature verified, `alg:none` rejected? Sessions crypto-random? Passwords bcrypt/argon2? Auth checked at data layer, not just route?

**3. Secrets & Credentials** — Scan for API keys, passwords, tokens, private keys. Secrets in env vars, not hardcoded or committed config? Do errors/logs expose secrets?

**4. API Security** — Rate limiting on auth endpoints? CORS wildcard origins? Input validated at every API boundary? Responses expose minimum data?

**5. Data Exposure** — `SELECT *` where specific fields suffice? PII in responses unnecessarily? Consistent error responses (prevent user enumeration)?

**6. Dependencies**
```bash
pip-audit              # Python
npm audit --audit-level=high  # Node
```

**7. Transport & Storage** — Sensitive data encrypted at rest? All external calls HTTPS? Cookies: `HttpOnly`, `Secure`, `SameSite=Strict`?

**8. Audit Logging** — Auth events logged (login, logout, failures)? Admin actions logged with user ID + timestamp? Logs tamper-evident?

---

## Part 2 — Adversarial Review

Think like an attacker trying to break this system.

**As a malicious user:** What inputs cause unexpected behavior? Can I access another user's data? Can I bypass auth/payment/validation? Can I escalate privileges? What happens if I replay or flood a request?

**As an insider threat:** What can a low-privilege user do that they shouldn't? What admin action is hard to detect? Are there audit log gaps?

**As an external attacker:** What is exposed without auth? What leaks from errors, headers, or timing? Any callback/redirect endpoints (SSRF, open redirect)? Third-party integrations abusable if compromised?

**As a logic abuser:** Race conditions (check-then-act)? Requests out of order? Numeric overflow/underflow? Pagination or filter parameter abuse?

For each finding:
```
🔴 EXPLOIT: [what I can do]
   Vector: [specific endpoint/input/sequence]
   Impact: [data or capability gained]
   Fix: [specific code change]
```

---

## Part 3 — Compliance Checklist

**Audit Logging** — auth events, authorization failures, data mutations, admin actions logged with actor/timestamp? Structured JSON? Off-application destination? 90-day retention?

**PII & Data Handling** — PII inventory complete? Minimization applied? PII excluded from logs and errors? GDPR deletion + export paths exist?

**Access Control** — least privilege per role? Multi-tenancy isolation (Tenant A cannot see Tenant B)? API tokens scoped, expiring, revocable?

**Secrets Management** — no secrets in code/git history? Rotatable without deploy? Access logged?

**Infrastructure** — DB encrypted at rest + TLS + not public? Backups tested + encrypted + off-region? Prod data never in dev/staging?

**Incident Response** — can you kill a compromised token immediately? Block a user/IP without a deploy?

---

## Output

Severity ratings across all three lenses:
- 🔴 CRITICAL — exploit possible, fix before ship (auto-fixed)
- 🟠 HIGH — serious risk, fix this sprint
- 🟡 MEDIUM — should fix, schedule it
- 🔵 LOW — harden when convenient
- ⚠️ Compliance gap — [what's missing, how to fix]
- 🔴 Compliance blocker — would fail enterprise security review

Auto-fix all 🔴 CRITICAL. Present 🟠 HIGH list for decision.

End with: "Security review complete. [X critical, Y high, Z medium, W compliance gaps]. Ready to /ship?" only if no CRITICAL remain.

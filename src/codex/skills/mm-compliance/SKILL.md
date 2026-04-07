---
name: mm-compliance
description: "Enterprise compliance review — audit logging, PII handling, multi-tenancy isolation, SOC2 surface area, and regulatory checklist."
---

# mm-compliance

Enterprise compliance review — audit logging, PII handling, multi-tenancy isolation, SOC2 surface area, and regulatory checklist.

## Instructions
Enterprise compliance review. Checks audit logging, data handling, PII, and regulatory surface area.

Not a legal opinion — a technical checklist for building software that won't fail an enterprise security review.

Run against the current codebase or `.planning/PLAN.md`:

**1. Audit Logging**
Every enterprise app needs a tamper-evident audit trail:
- [ ] Authentication events: login, logout, failed attempts (with IP, timestamp, user ID)
- [ ] Authorization failures: who tried to access what and was denied
- [ ] Data mutations: who changed what record, when, what was the before/after
- [ ] Admin actions: any privileged operation is logged with actor identity
- [ ] Log format: structured (JSON), not free-text — must be parseable by SIEM
- [ ] Log destination: off-application (not just local file) — DB table or log service
- [ ] Log retention: at least 90 days accessible, 1 year archived

**2. PII & Data Handling**
- [ ] PII inventory: what personal data does the app collect? (name, email, IP, behavioral)
- [ ] PII minimization: is each field actually needed?
- [ ] PII in logs: are emails, names, SSNs, etc. excluded from log lines?
- [ ] PII in error messages: do stack traces or error responses expose personal data?
- [ ] Data deletion: is there a way to delete a user's data? (GDPR right to erasure)
- [ ] Data export: can a user export their own data?

**3. Access Control**
- [ ] Principle of least privilege: does each role have only what it needs?
- [ ] Multi-tenancy isolation: can Tenant A ever see Tenant B's data? (check every query)
- [ ] API tokens: scoped (not god-mode), expiring, revocable
- [ ] Service accounts: no shared credentials, each service has its own identity

**4. Secrets Management**
- [ ] No secrets in code, config files, or git history
- [ ] Secrets rotatable without code deployment
- [ ] Secret access is logged (who accessed what secret, when)

**5. Dependency & Supply Chain**
- [ ] Known CVEs in dependencies? (run audit)
- [ ] Dependencies pinned (lockfile committed)?
- [ ] No abandoned packages (last release >2 years ago for critical deps)?

**6. Infrastructure**
- [ ] Database: encrypted at rest, TLS in transit, not publicly accessible
- [ ] Backups: tested, encrypted, off-region
- [ ] Environments: prod data never in dev/staging

**7. Incident Response**
- [ ] Is there a way to kill a compromised API token immediately?
- [ ] Can you block a user/IP without a code deploy?
- [ ] Do you know where all copies of sensitive data live?

Report format:
- ✅ Compliant
- ⚠️ Gap — [what's missing, how to fix]
- 🔴 Blocker — [would fail enterprise security review, fix before customer demo]

End with: "Compliance posture: [Strong/Adequate/Needs Work]. Top 3 gaps to close first."

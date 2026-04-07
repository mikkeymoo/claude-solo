---
name: mm-incident
description: "Claude-solo command skill"
---

# mm-incident

Claude-solo command skill

## Instructions
---
name: mm:incident
description: "Production incident workflow: capture symptoms, reproduce, gather evidence, root cause analysis, fix, verify, and document."
---

Production incident workflow. Systematic debugging for when something is broken in production.

This is not a code review or a general debugging session — this is triage for a live issue.

**1. Capture**
- What is the symptom? (error message, behavior, impact)
- When did it start? (timestamp, deploy, or change that triggered it)
- Who/what is affected? (all users, specific endpoint, specific data)
- What's the blast radius? (one user? all users? data loss? security?)

**2. Reproduce**
- Can you reproduce locally?
- If yes: capture the exact steps
- If no: check logs, error tracking (Sentry, CloudWatch, etc.), recent deploys

**3. Evidence collection**
- Gather: error logs, stack traces, recent deploy diffs, relevant metrics
- Check: what changed recently? (git log --since, deploy history)
- Note: any recent dependency updates, config changes, or infra changes

**4. Root cause analysis**
- Form 2-3 hypotheses ranked by likelihood
- For each hypothesis: what evidence supports/contradicts it?
- Test the most likely hypothesis first
- If wrong: move to next hypothesis, don't guess

**5. Fix**
- Implement the minimal fix that resolves the root cause
- Do NOT fix other things you notice — stay focused on the incident
- If a quick fix is needed before a proper fix: document the temp fix explicitly

**6. Verify**
- Confirm the fix resolves the original symptom
- Run the test suite — no regressions introduced
- If applicable: verify in staging before production

**7. Document**
Write `.planning/INCIDENT.md`:

```markdown
# Incident Report
Date: [timestamp]
Severity: P1/P2/P3/P4
Status: RESOLVED | MITIGATED | INVESTIGATING

## Summary
[one sentence: what broke and why]

## Timeline
- [time] Issue reported / detected
- [time] Investigation started
- [time] Root cause identified
- [time] Fix deployed
- [time] Confirmed resolved

## Root Cause
[what actually caused the issue]

## Fix Applied
[what was changed, commit hash]

## Prevention
[what would prevent this class of issue in the future]
- [ ] Add monitoring for X
- [ ] Add test for Y
- [ ] Update runbook for Z
```

End with: "Incident documented. Consider adding prevention items to the next /mm:brief."

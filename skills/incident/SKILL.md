---
name: incident
description: "Structure a postmortem from a production incident. Writes .planning/POSTMORTEM-{date}.md. Use after any significant outage or data issue."
argument-hint: "[incident title or description]"
---

# /incident — Incident Postmortem

Structure a postmortem from a production incident in `.planning/POSTMORTEM-{date}.md`.

Use this skill after any significant outage, data loss, or service degradation to document what happened, why it happened, and what prevents recurrence.

## Interactive Conversation

The skill will guide you through:

1. **Gather incident info** — incident title, start time, resolution time, initial impact
2. **Timeline** — reconstruct events: detection → triage → escalation → fix → resolution
3. **Impact** — users affected, features down, total duration, SLA implications
4. **Root cause** — what specifically failed? Proximate cause vs contributing factors
5. **Fix applied** — what stopped the bleeding? Proper fix or temporary workaround?
6. **Prevention** — what would prevent this class of incident? (monitoring, tests, deployment checks, alerting)
7. **Action items** — specific, owner-less tasks (solo dev: just tasks, no owners)

## Output Format

Writes `.planning/POSTMORTEM-{date}.md` with this structure:

```markdown
# Postmortem: {title}

**Date:** {date}  
**Duration:** {start} → {end} ({total hours})  
**Severity:** Critical/High/Medium/Low

## What Happened

{1-paragraph summary: what the user experienced, what broke}

## Timeline

| Time  | Event                             |
| ----- | --------------------------------- |
| HH:MM | Incident detected                 |
| HH:MM | Triage or escalation              |
| HH:MM | Fix deployed / workaround applied |
| HH:MM | Fully resolved                    |

## Root Cause

{clear statement of what broke and why. Distinguish proximate cause (the immediate failure) from contributing factors (poor monitoring, inadequate tests, etc.)}

## Impact

- **Users affected:** {count or description}
- **Features/services down:** {list}
- **Extent:** {percentage of traffic, data loss, etc., if applicable}

## Fix Applied

{what was done to resolve: hotfix, rollback, manual intervention, configuration change, etc. Was it a permanent fix or temporary workaround?}

## Prevention

{what changes prevent recurrence: new monitoring/alerting, test coverage, deployment guards, runbooks, documentation, infrastructure changes}

## Action Items

- [ ] {specific task}
- [ ] {specific task}
```

## Tips

- **Be specific.** "Database slow" is not a root cause. "Connection pool exhaustion due to unshuttered database connections in new feature X" is.
- **Distinguish what and why.** What happened (timeline) vs why it happened (root cause) are different sections.
- **Prevention is about the class of incident.** Don't just write "don't deploy broken code" — write concrete monitoring/test/deployment changes.
- **Action items are unowned.** (Solo dev context: just capture what needs to be done, you'll own it all.)
- **Severity**: Critical = users cannot use service; High = major degradation; Medium = some users affected; Low = minor impact.

End with: "Postmortem written. Ready to review?"

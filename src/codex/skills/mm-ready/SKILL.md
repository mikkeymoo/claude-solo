---
name: mm-ready
description: "Pre-build readiness gate. Verifies brief, plan, environment, and clarity before starting implementation."
---

# mm-ready

Pre-build readiness gate. Verifies brief, plan, environment, and clarity before starting implementation.

## Instructions
Pre-build readiness gate. Verify everything needed to build is actually in place.

Run before /mm:build to catch gaps before they cost time mid-implementation.

Check each pillar:

**1. Brief** — does `.planning/BRIEF.md` exist and contain:
- [ ] What we're building (one sentence)
- [ ] What's out of scope
- [ ] Done criteria (how we know it works)
- [ ] Hard constraints

**2. Plan** — does `.planning/PLAN.md` exist and contain:
- [ ] Numbered task list with time estimates
- [ ] Explicit dependencies between tasks
- [ ] Done criteria per task (specific, testable)
- [ ] Test matrix (what tests, what type)
- [ ] Any schema/API/config changes listed

**3. Environment** — are the tools ready:
- [ ] Required env vars set (check `.env.example` if present)
- [ ] Dependencies installed (`node_modules/`, virtualenv, etc.)
- [ ] Existing tests passing (run them now)

**4. Clarity** — no open questions that would block implementation:
- [ ] All task done-criteria are specific (not "implement X", but "function Y passes test Z")
- [ ] No tasks labeled "TBD" or "figure out later"
- [ ] External dependencies (APIs, DB) accessible

Report as:
```
✅ Brief        — complete
✅ Plan         — 8 tasks, clear dependencies, test matrix present
⚠️  Environment — OPENAI_API_KEY not set in .env
✅ Clarity      — all tasks have specific done criteria

1 issue to fix before /build.
```

If all green: "All clear — ready to /build."
If any red: list exactly what's missing and stop. Don't proceed to build.

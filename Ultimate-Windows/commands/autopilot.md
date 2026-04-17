---
name: mm:autopilot
description: "Full idea-to-ship pipeline in one command. brief → plan → build → review → ship. Use for well-defined features."
argument-hint: "[describe the feature or idea]"
---

Full autonomous pipeline. I'll run each phase and report before moving to the next.

Phases:

1. **Brief** — formalize the idea; ask clarifying questions if the scope is ambiguous
2. **Plan** — write `.planning/PLAN.md` with atomic tasks
3. **Build** — implement tasks in order, one commit each
4. **Review** — code review; auto-fix critical issues
5. **Ship** — final test run, PR, merge

I'll pause between phases and report what was done. If I hit something blocked or ambiguous mid-phase, I'll stop and ask rather than guess.

Use /mm:quick instead for changes under 2 hours.

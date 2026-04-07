---
name: mm:autopilot
description: "Full hands-off sprint pipeline: spec → build → QA → validate. Runs brief through ship with minimal interruptions."
argument-hint: "[brief description of what to build]"
---

Run the full sprint pipeline end-to-end with minimal interruptions.

Usage: `/mm:autopilot [brief description of what to build]`

If no description is provided, ask: "What are we building?" — one question, wait for answer.

Then execute all 7 stages automatically:

1. **BRIEF** — define scope, constraints, success criteria. Write `.planning/BRIEF.md`. Ask: "Proceed?"
2. **PLAN** — create `.planning/PLAN.md` with tasks, architecture, test matrix. Show plan. Ask: "Proceed?"
3. **BUILD** — implement all tasks in dependency order, one atomic commit per task. Report each `✓ Task N done`.
4. **REVIEW** — staff-engineer review. Auto-fix all 🔴 MUST FIX. Show 🟡 and 🔵. Ask: "Fix 🟡 items? (y/n)"
5. **TEST** — write and run all tests. If coverage < 80%, add tests. Report pass/fail/coverage.
6. **SHIP** — create PR, confirm all tests pass. Ask: "Merge?" before merging.
7. **RETRO** — write `.planning/RETRO-[date].md`. Summarize what shipped.

Pause points (always confirm before proceeding):
- After BRIEF: scope confirmed
- After PLAN: approach confirmed
- Before SHIP merge: PR reviewed

Never pause mid-stage. If something is unclear, make a reasonable call and note it.

End with: "Autopilot complete. [one-line summary of what shipped]"

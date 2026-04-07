# mm-plan

Create implementation plan with atomic tasks, dependencies, test matrix, and architecture decisions. Writes .planning/PLAN.md.

## Instructions
Read `.planning/BRIEF.md` (or ask me to describe the feature if it doesn't exist).

Create an implementation plan in `.planning/PLAN.md`:

1. **Architecture** — ASCII diagram of components, data flow, and key decisions
2. **Tasks** — numbered list, each 1-4 hours, with clear "done" criteria
3. **Dependencies** — which tasks must happen before others
4. **Test matrix** — what tests we need (unit, integration, E2E, cross-platform)
5. **Schema changes** — any DB/API/config changes (list them explicitly)
6. **Estimated total** — realistic hours

Rules for tasks:
- Each task = one atomic commit
- No task should be "implement X" without naming the exact file/function
- Mark tasks that can run in parallel

End with: "Ready to /build?"

Read `.planning/PLAN.md` and implement the tasks in dependency order.

For each task:
1. Implement the code
2. Run existing tests — fix any regressions before moving on
3. Stage only the relevant files (not `git add .`)
4. Commit with a clear message: `feat: [task description]`
5. Report: "✓ Task N done — [what was done in one line]"
6. Ask: "Continue to Task N+1?" before moving on

Rules:
- One commit per task — no bundling multiple tasks
- Never skip tests even if they seem unrelated
- If a task is blocked, stop and tell me why — don't guess past it
- If something architectural is unclear, ask before coding

After all tasks: "Build complete. Ready to /review?"

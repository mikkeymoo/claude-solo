# mm-handoff

Create a structured resume packet: status, completed work, blockers, next steps, key decisions, and recommended command for next session.

## Instructions
Create a resume packet so the next session (or next developer) can pick up exactly where you left off.

This replaces /mm:pause with a richer, more structured handoff document.

Write `.planning/HANDOFF.md` with these sections:

**1. Status** (one sentence)
- What are we building and where are we in the pipeline?

**2. Current stage**
- Which sprint stage: brief / plan / build / review / test / ship / retro
- Percent complete within that stage (rough estimate)

**3. What's done**
- Bullet list of completed tasks with commit hashes
- Any merged PRs or shipped artifacts

**4. What's in progress**
- Files currently being edited (with brief context)
- Any half-finished work that needs completion

**5. What's blocked**
- Unresolved decisions or questions
- Missing dependencies, credentials, or access
- Failing tests with suspected cause

**6. Next step**
- The single most important thing to do next
- Be specific: "Implement the `processPayment()` function in `src/billing/handler.ts`"
- Not vague: "Continue working on billing"

**7. Key decisions**
- Architectural or design choices made this session and WHY
- Trade-offs considered and what was chosen

**8. Files to review**
- The 3-7 most important files for this work
- One-line description of each file's role

**9. Recommended command**
- Which /mm: command to run next (e.g., "/mm:build to continue implementation")

Then commit:
```bash
rtk git add .planning/HANDOFF.md && rtk git commit -m "chore: save handoff for next session"
```

Keep the entire document under 500 words. This is for Claude to read at session start, not for human documentation.

End with: "Handoff saved. Run `/mm:resume` in your next session to pick up here."

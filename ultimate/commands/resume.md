---
name: mm:resume
description: "Restore context from a paused session (PAUSE.md, HANDOFF.md, or CHECKPOINT.md) and continue exactly where you left off."
---

Restore context from a previous session and continue exactly where we left off.

Check for resume files in priority order:
1. `.planning/HANDOFF.md` — richest context (from /mm:handoff)
2. `.planning/PAUSE.md` — quick context (from /mm:pause)
3. `.planning/CHECKPOINT.md` — auto-saved before context compaction
4. `.planning/SESSION-END.md` — auto-saved when last session ended

Use the first one found. Then:

1. **Read** the resume file — absorb everything in it
2. **Read** the files listed in "Relevant files" or "Files to review"
3. **Confirm** current state matches what the resume file describes:
   - Check git log for the last few commits
   - Verify the "next task" or "next step" is still accurate
   - Check if any VERIFY.md results exist
4. **Announce** to the user:
   ```
   Resumed: [what we are building]
   Stage: [current stage]
   Last completed: [last done task]
   Next up: [next task]
   Source: [which resume file was used]
   ```
5. **Ask**: "Ready to continue?" — then proceed when confirmed

If no resume file exists, check SESSION-END.md for context about what was last worked on.

If nothing found, ask: "No resume context found. What are we working on?"

Do not start working until the user confirms they are ready.
Restore context from a paused session and continue exactly where we left off.

1. **Read** `.planning/PAUSE.md` — absorb everything in it
2. **Read** the files listed in "Relevant files"
3. **Confirm** current state matches what PAUSE.md describes:
   - Check git log for the last few commits
   - Verify the "next task" is still accurate
4. **Announce** to the user:
   ```
   Resumed: [what we're building]
   Stage: [current stage]
   Last completed: [last done task]
   Next up: [next task]
   ```
5. **Ask**: "Ready to continue?" — then proceed when confirmed

If PAUSE.md doesn't exist, ask: "No pause file found. What are we working on?"

Do not start working until the user confirms they're ready.

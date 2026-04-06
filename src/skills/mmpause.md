Save current session context so you can resume in a fresh window without losing progress.

Write `.planning/PAUSE.md` with:

1. **What we're building** — one sentence
2. **Current stage** — which sprint stage we're in (brief/plan/build/review/test/ship)
3. **Completed tasks** — bullet list of what's done (with commit hashes if available)
4. **Next task** — exactly what to do when resuming (specific file, function, step)
5. **Open questions** — anything unresolved that needs a decision
6. **Relevant files** — the 3-5 files most important to the current work
7. **Key decisions made** — architectural or design choices made this session and why

Then run:
```bash
rtk git add .planning/PAUSE.md && rtk git commit -m "chore: save session pause point"
```

End with:
```
Session paused. To resume: open a fresh Claude Code window and run /mm:resume
```

Keep it under 400 words — this is for Claude to read at session start, not for humans.

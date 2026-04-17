---
name: mm:review
description: "Staff-engineer code review: security, perf, edge cases, error handling. Auto-fixes critical issues."
---

Review all commits since the last tag or since `.planning/PLAN.md` was created.

```bash
git log --oneline -10
git diff HEAD~$(git log --oneline | wc -l | tr -d ' ') --stat
```

Check in order:

1. **Security** — injection, auth bypass, secrets in code, exposed keys
2. **Performance** — N+1 queries, blocking I/O, memory leaks, missing indexes
3. **Edge cases** — empty inputs, null/undefined, large data, concurrent writes
4. **Error handling** — what happens when external calls fail?
5. **Code clarity** — will future-me understand this in 3 months?

Label each finding:

- `🔴 MUST FIX` — auto-fix and commit: `fix: <issue>`
- `🟡 SHOULD FIX` — list and ask which to fix now
- `🔵 CONSIDER` — log for later

End with: "Review complete. Ready to /mm:ship?"

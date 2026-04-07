# mm-review

Staff-engineer code review: security, performance, cross-platform, edge cases, error handling, and code clarity. Auto-fixes critical issues.

## Instructions
Read all commits made during /build (since the last tag or the PLAN.md was created).

Perform a staff-engineer code review. Check:

1. **Security** — injection, auth bypass, secrets in code, exposed API keys
2. **Performance** — N+1 queries, blocking I/O, memory leaks, missing indexes
3. **Cross-platform** — hardcoded paths, Windows-only APIs, line ending issues
4. **Edge cases** — empty inputs, null/undefined, large data, concurrent writes
5. **Error handling** — what happens when external calls fail?
6. **Code clarity** — anything a future-you won't understand in 3 months?

For each issue found:
- Label: `🔴 MUST FIX` / `🟡 SHOULD FIX` / `🔵 CONSIDER`
- Show the file + line
- Show the fix (not just the problem)

Auto-fix all `🔴 MUST FIX` issues and commit them: `fix: [issue description]`
List `🟡 SHOULD FIX` issues and ask which ones I want fixed now.
List `🔵 CONSIDER` for future reference.

End with: "Review done. Ready to /test?"

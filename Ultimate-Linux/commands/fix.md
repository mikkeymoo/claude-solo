---
name: mm:fix
description: "Debug and fix a specific bug or error. Diagnoses root cause before touching code."
argument-hint: "[error message or description of the bug]"
---

Diagnose and fix the bug. Do not guess — find the root cause first.

1. **Reproduce** — confirm the bug is reproducible; get the exact error message and stack trace
2. **Locate** — find the failing code path (use LSP find_definition / find_references)
3. **Root cause** — state what's wrong and why in one sentence before writing any fix
4. **Fix** — make the minimal change that fixes the root cause; don't fix adjacent things
5. **Verify** — run the relevant test(s); confirm the error is gone
6. **Commit** — `fix: <what was broken and why>`

If the root cause is unclear after reading the code, add a temporary `console.error` / `print` and ask me to run it — don't patch symptoms.

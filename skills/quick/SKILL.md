---
name: quick
description: "Rapid flow for small tasks — skips full pipeline. Use for bug fixes, config tweaks, and changes under 2 hours."
argument-hint: "[what to do]"
---

# /quick — Rapid Small Task

Fast path. No ceremony.
Use for: bug fixes, config tweaks, single-file changes.
Don't use for: new systems, schema changes, auth/payments code.

Steps — no stopping unless blocked:

1. **Clarify** — restate the task in one sentence; confirm it's actually small
2. **Locate** — identify the 1-3 files this touches
3. **Implement** — make the change; write the minimal test needed
4. **Commit** — stage explicitly, commit with a clear message

If it grows beyond 5 files or needs a schema change — stop and switch to /riper.

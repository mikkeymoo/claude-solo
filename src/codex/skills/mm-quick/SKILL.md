# mm-quick

Rapid flow for small tasks — skips full pipeline. Use for bug fixes, config changes, and refactors under 2 hours.

## Instructions
Rapid unified flow for small tasks. Skips the full pipeline for changes that don't need it.

Use when: bug fixes, small features (<2h), config changes, refactors with clear scope.
Don't use when: new systems, DB schema changes, anything touching auth or payments.

Four steps — no stopping between them unless blocked:

1. **Clarify** (2 min)
   - Restate what we're doing in one sentence
   - Confirm: is this actually small enough for quick mode?
   - Identify the 1-3 files this touches

2. **Plan** (5 min)
   - List the exact changes: file, function, what changes and why
   - Name the tests needed (at minimum: one happy path, one edge case)
   - If it touches more than 5 files or needs a schema change — stop and use full pipeline

3. **Implement**
   - Make the changes
   - Write the tests
   - Run tests — fix any failures before continuing

4. **Review & commit**
   - Self-review: security? edge cases? cross-platform?
   - Stage specific files (not `git add .`)
   - Commit: `fix:` or `feat:` with clear message

Report at end: "Done — [one line of what shipped]. Tests: X passed."

If anything surprises you mid-implementation (more complex than expected, touches more files),
stop and say so. Don't push through into a mess.

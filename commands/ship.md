---
name: mm:ship
description: "Final test run, PR creation, merge, and post-ship checklist."
---

Prepare and ship the feature.

1. **Final test run** — run all tests; if anything fails, stop
2. **PR** — create a pull request with:
   - What changed (bullet points)
   - Why (link to BRIEF.md or describe the problem)
   - Test plan (what was tested and how)
   - Breaking changes (if any)
3. **Merge** — squash WIP commits into one clean commit if needed
4. **CI** — if CI is configured, confirm it passes
5. **Post-ship** — note any monitoring, feature flags, or follow-up tasks

If no CI: confirm all tests pass locally.

End with: "Shipped."

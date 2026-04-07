---
name: mm-ship
description: "Claude-solo command skill"
---

# mm-ship

Claude-solo command skill

## Instructions
---
name: mm:ship
description: "Prepare and ship: final test run, PR creation, merge, CI verification, and monitoring checklist."
---

Prepare and ship the feature.

1. **Final check** — run all tests one more time. If anything fails, stop and tell me.
2. **PR description** — create a PR with:
   - What changed (bullet points)
   - Why (link to BRIEF.md or describe the problem)
   - Test plan (what was tested, how)
   - Breaking changes (if any)
3. **Merge** — squash into one clean commit if multiple WIP commits exist
4. **Verify** — if CI/CD is configured, confirm it passes
5. **Monitor** — note any error tracking, logging, or monitoring to watch

If no CI/CD: just confirm all tests pass locally on both platforms.

End with: "Shipped. Ready to /retro?"

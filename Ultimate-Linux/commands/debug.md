---
name: mm:debug
description: "Deep debugging session for hard or intermittent issues. Systematic hypothesis-driven approach."
argument-hint: "[symptom or failing behavior]"
---

Systematic debug session. Don't patch — understand.

1. **Characterize** — what exactly fails? Always? Under what conditions? Since when?
2. **Gather data** — read logs, error messages, stack traces; run with verbose output if available
3. **Hypothesize** — list 2-3 possible root causes, ranked by likelihood
4. **Test hypotheses** — fastest test first; add logging/assertions to isolate the failure
5. **Confirm root cause** — state it in one sentence before writing any fix
6. **Fix + verify** — minimal fix; confirm symptom is gone and no regression

If the bug is non-deterministic (race condition, flaky test): instrument with timestamps and retry counts before concluding anything.

If I need to run something locally to gather data, tell me the exact command.

---
name: mm-test
description: "Write and run unit, integration, and E2E tests. Reports coverage, flags gaps, and validates cross-platform compatibility."
---

# mm-test

Write and run unit, integration, and E2E tests. Reports coverage, flags gaps, and validates cross-platform compatibility.

## Instructions
Read `.planning/PLAN.md` (test matrix section) and the current codebase.

Write and run tests:

1. **Unit tests** — for every function with logic (not just getters/setters)
2. **Integration tests** — for API endpoints, DB queries, file I/O
3. **E2E tests** — at least one happy path, one failure path
4. **Cross-platform** — if this tool runs on Windows and Linux, verify both

For each test:
- Write the test first
- Run it — confirm it fails with a clear reason if not implemented
- Confirm it passes after implementation

Report coverage:
- Files with <80% coverage → add tests to reach 80%+
- List any untested code paths that are high-risk

At end: overall pass/fail count, coverage %, any gaps flagged.

End with: "Tests done. Ready to /ship?"

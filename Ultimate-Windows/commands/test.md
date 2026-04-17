---
name: mm:test
description: "Write or improve tests for a file or feature. Covers happy path, edge cases, and failure modes."
argument-hint: "[file or feature to test]"
---

Write tests for the specified file or feature.

1. **Baseline** — run the existing test suite first; note any pre-existing failures
2. **Coverage gaps** — identify: happy path, edge cases, error/failure modes not yet tested
3. **Write tests** — one assertion per test; descriptive names (`should return 401 when token expired`)
4. **Run** — all tests must pass; fix any failures you introduced
5. **Commit** — `test: <what is now tested>`

Rules:

- Test behavior, not implementation — test public API, not private internals
- Only mock external services (HTTP, DB, filesystem) — never mock your own code
- Don't duplicate existing test coverage — check first
- If a test can't meaningfully fail, don't write it

# Test Writing Rules

When writing or modifying tests:

- Tests must test behavior, not implementation — test the public API, not private internals
- Each test must have one clear assertion that can fail for exactly one reason
- Name tests descriptively: `should return 401 when token is expired` not `test_auth_2`
- Don't mock what you own — only mock external services (HTTP, DB, filesystem boundaries)
- Use real data fixtures over magic strings where possible
- Never write tests that always pass — if a test can't fail, delete it
- Clean up all side effects (temp files, DB records, env var mutations) in teardown
- Run the existing test suite before adding new tests to establish a clean baseline
- Prefer integration tests over unit tests for business logic; prefer unit tests for pure functions
- Don't duplicate test coverage that already exists — check first with `rtk grep "describe.*<feature>"`

# Documentation Rules

When updating or creating documentation:

- Update docs in the same commit as the code change — stale docs are worse than no docs
- README must have: what it does, how to install, how to run, how to test, how to contribute
- Don't document the obvious — document the *why*, not the *what*
- API docs must show a working request and response example, not just a schema
- Keep CHANGELOG.md updated with user-visible changes under `[Unreleased]` as work progresses
- If a function/module has non-obvious behavior (side effects, ordering constraints, gotchas), add a comment at the call site or in the docstring
- Link to external docs rather than duplicating them — external docs stay current; copies don't
- When adding a new feature, update the relevant section of the README before shipping
- Don't write `TODO: document this` — either document it now or file a real issue
- Sync CLAUDE.md project instructions whenever the architecture or workflow changes

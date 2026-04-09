---
name: mm:map
description: "Generate a visual map of the codebase: directory structure, key modules, data flow, and entry points. Use at the start of a session to orient before working in an unfamiliar codebase."
---

Generate a codebase map to orient before working on an unfamiliar project.

Run:
```bash
rtk git log --oneline -5
rtk ls src/ 2>/dev/null || rtk ls .
cat package.json 2>/dev/null || cat pyproject.toml 2>/dev/null || cat Cargo.toml 2>/dev/null || true
```

Produce a structured map covering:

**1. Project overview**
- What does this project do? (1-2 sentences from README/package.json description)
- Language(s), framework(s), key dependencies
- Entry points: main file, CLI commands, server start

**2. Directory structure** (meaningful dirs only, skip node_modules/dist)
```
src/
  api/         → HTTP route handlers
  services/    → business logic layer
  models/      → database models / schemas
  utils/       → shared utilities
tests/         → test suite
```

**3. Key data flows**
- How does a request enter and exit? (HTTP lifecycle)
- How is data persisted? (DB layer)
- How are background jobs triggered?

**4. Integration points**
- External services (APIs, DBs, queues, caches)
- Auth mechanism (JWT, sessions, OAuth)
- Notable environment variables

**5. Where to look for...**
- Adding a new API endpoint: [path]
- Adding a new DB model: [path]
- Adding a test: [path and convention]
- Changing configuration: [path]

**6. Gotchas / non-obvious things**
- Anything that would surprise a new contributor
- Known tech debt areas
- Platform-specific code paths

Keep the map scannable — use short bullets and code paths, not prose paragraphs.
Save to `.planning/CODEBASE-MAP.md`.

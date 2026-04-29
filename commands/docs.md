---
name: mm:docs
description: "Generate or update documentation for a file, module, or API. Keeps docs in sync with code."
argument-hint: "[file, module, or API to document]"
---

Write or update documentation for the specified target.

1. **Read the code** — understand what it actually does before writing anything
2. **Identify doc targets**:
   - Public API: document inputs, outputs, side effects, error cases
   - Non-obvious logic: add inline comments explaining _why_, not _what_
   - README: update if the feature changes install/run/test steps
3. **Write** — be honest and short; document for future-self, not a stranger
4. **Sync** — if there's an existing doc that's now stale, update or delete it
5. **Commit** — `docs: <what was documented>`

Rules:

- Don't document the obvious — document the _why_
- API docs must show a working request/response example, not just a schema
- Never write `TODO: document this` — either document it now or don't mention it
- Update docs in the same commit as the code change they describe

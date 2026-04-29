---
name: docs
description: "Generate or update documentation for a file, module, or API. Keeps docs in sync with code. Use when documentation needs writing or updating."
argument-hint: "[file, module, or API to document | --api]"
---

# /docs — Documentation

## Default Mode — Manual Documentation

1. **Read the code** — understand what it actually does before writing anything
2. **Identify doc targets**:
   - Public API: document inputs, outputs, side effects, error cases
   - Non-obvious logic: add inline comments explaining _why_, not _what_
   - README: update if the feature changes install/run/test steps
3. **Write** — honest and short; for future-self, not a stranger
4. **Sync** — if there's a stale doc, update or delete it
5. **Commit** — `docs: <what was documented>`

Rules:

- Don't document the obvious — document the _why_
- API docs must show a working request/response example
- Never write `TODO: document this`
- Update docs in the same commit as the code change

## --api Mode — Generate OpenAPI Spec

Automatically scan API route handlers and generate an OpenAPI 3.0.3 specification.

### Process

1. **Find routes** — scan for handler files:
   - Express: `routes/*.ts`, `routes/*.js`, files matching `router.*`
   - FastAPI: files with `@app.get`, `@app.post`, `@router.get`, etc.
   - Next.js: files in `app/api/**/route.ts` or `pages/api/**/*.ts`

2. **Extract endpoints** — for each handler, extract:
   - HTTP method and path
   - Path parameters (`:id`, `{id}`)
   - Request body type (from Zod/Pydantic/TypeScript types)
   - Response type
   - Auth requirements (middleware usage, comments)

3. **Generate spec** — produce `openapi.yaml` at project root:

   ```yaml
   openapi: 3.0.3
   info:
     title: [from package.json/pyproject.toml]
     version: [from package.json/pyproject.toml]
   paths:
     /endpoint:
       get:
         summary: [extracted from code/comments]
         parameters: [...]
         responses: [...]
   components:
     schemas: [extracted types]
   ```

4. **Output** — write to `openapi.yaml`, display endpoint summary

### Type Resolution

For types you can't fully resolve, use `type: object` with a comment:

```yaml
RequestBody:
  type: object
  # TODO: refine schema — extract from Zod validator / TypeScript interface
```

### Example Output

```
Found 12 endpoints:
  POST   /api/users                 — Create user
  GET    /api/users/{id}            — Get user by ID
  PATCH  /api/users/{id}            — Update user
  DELETE /api/users/{id}            — Delete user
  ...

OpenAPI spec written to openapi.yaml
```

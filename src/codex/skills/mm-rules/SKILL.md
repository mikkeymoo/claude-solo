---
name: mm-rules
description: "Create and manage path-specific Claude rules in .claude/rules/. Rules apply automatically to matching file paths — set different behavior for migrations, tests, frontend code, etc."
---

# mm-rules

Create and manage path-specific Claude rules in .claude/rules/. Rules apply automatically to matching file paths — set different behavior for migrations, tests, frontend code, etc.

## Instructions
Manage path-specific Claude rules for this project.

Path-specific rules in `.claude/rules/` let you set different instructions for different parts of the codebase. For example: stricter review rules for migrations, different patterns for frontend vs backend, no-edit rules for vendor files.

First, detect what exists:
```bash
ls .claude/rules/ 2>/dev/null || echo "no rules directory"
```

Detect which operation the user wants:
- **list** — show active rules and what paths they match
- **create** — create a new rule file interactively
- **edit** — open an existing rule for editing
- **delete** — remove a rule
- **check** — show which rules apply to a specific file path

---

## List active rules

Show all files in `.claude/rules/` with their glob patterns:

```bash
ls -la .claude/rules/*.md 2>/dev/null || echo "No rules files found."
```

For each file, extract and display the glob pattern from its frontmatter (if present) or filename.

Example output:
```
.claude/rules/migrations.md       → src/migrations/**
.claude/rules/tests.md            → **/*.test.ts, **/*.spec.ts
.claude/rules/vendor.md           → vendor/**, node_modules/**
.claude/rules/api-contracts.md    → src/api/**
```

If no rules exist, explain what they are and offer to create one.

---

## Create a new rule

Ask the user:

1. **What paths should this rule apply to?**
   Common patterns:
   - `src/migrations/**` — database migration files
   - `**/*.test.ts` — test files
   - `src/api/**` — API layer
   - `frontend/**` — frontend code
   - `vendor/**` — third-party code (suggest: read-only)
   - Custom glob pattern

2. **What name for this rule file?** (suggest based on path)

3. **What should Claude do differently for these files?**
   - Stricter review (never auto-approve changes)
   - Specific coding patterns to follow
   - Tools to avoid (e.g., never delete from migrations/)
   - Documentation requirements
   - Testing requirements

Then create `.claude/rules/<name>.md`:

```markdown
---
description: Rules for <what these files are>
globs: <glob pattern>
---

<The rules content the user described>
```

Example — migration safety rules:
```markdown
---
description: Database migration rules — never modify or delete existing migrations
globs: src/migrations/**
---

## Migration Rules

- NEVER modify existing migration files — create a new migration instead
- NEVER delete migration files
- Every migration must be reversible (include a down() function)
- Test migrations on a copy of prod data before merging
- Migration filenames must follow: YYYYMMDDHHMMSS_description.ts
```

Write the file and confirm its path.

---

## Edit a rule

List existing rules, ask which to edit.

Read the file, show its current content, ask what to change, then apply the edit.

---

## Delete a rule

List existing rules, ask which to delete. Confirm before deleting.

```bash
rm .claude/rules/<name>.md
```

---

## Check which rules apply to a path

Ask: "Which file path do you want to check?"

Then show all rule files whose glob patterns match that path.

Example:
```
Checking: src/migrations/20260101_add_users.ts

Matching rules:
  ✓ .claude/rules/migrations.md  (glob: src/migrations/**)
  ✓ .claude/rules/typescript.md  (glob: **/*.ts)

Non-matching rules:
  ✗ .claude/rules/tests.md       (glob: **/*.test.ts)
  ✗ .claude/rules/frontend.md    (glob: frontend/**)
```

Use simple glob matching: `**` matches any path segment, `*` matches within a segment.

---

## How glob matching works

Rules in `.claude/rules/` apply when the file Claude is working on matches the glob in the rule's frontmatter:

- `src/migrations/**` — everything under src/migrations/
- `**/*.test.ts` — any TypeScript test file, anywhere
- `src/{api,services}/**` — multiple directories
- `*.md` — Markdown files in the root only
- `**/*.md` — Markdown files anywhere

Rules are loaded lazily — only when Claude opens a matching file. Multiple rules can apply to the same file.

End with: "Rules are active. Claude will apply them automatically when working in matching directories."

---
name: migrate
description: "Plan and execute framework/library migrations with structured verification. Use when upgrading major versions or switching tools."
argument-hint: "[from→to description | --plan | --execute | --verify]"
---

# /migrate — Framework & Library Migrations

Plan and execute migrations safely with structured verification. Three modes handle the full migration lifecycle.

## Three Modes

- `--plan` (default) — Analyze scope, fetch official guides, audit usage, generate migration plan
- `--execute` — Execute migration changes following the plan
- `--verify` — Verify nothing broke: tests, old API usage, build, report

## --plan Mode

Produces a migration plan without changing code.

### Step 1: Identify Scope

Ask: what's being migrated?

- Framework or library name (e.g., ESLint, React, Jest, Express)
- Current version (e.g., v8) and target version (e.g., v9)
- Scope: entire codebase or specific modules?

### Step 2: Fetch Official Migration Guide

Use Context7 MCP to get authoritative docs:

1. Call `mcp__claude_ai_Context7__resolve-library-id` with library name
2. Call `mcp__claude_ai_Context7__query-docs` with a migration-focused query:
   - "migration guide from version X to Y"
   - "breaking changes in version X"
   - "upgrade guide"
3. Extract: breaking changes, new required patterns, deprecated APIs, new dependencies

### Step 3: Audit Current Usage

Find all uses of the old API in the codebase:

- **Imports**: search for old module names, old function exports
- **Function calls**: find all usages of deprecated functions
- **Config files**: `tsconfig.json`, `.eslintrc`, `package.json`, `jest.config.js`, etc.
- **Type usage**: if migrating types (TypeScript versions, etc.)
- **Test fixtures**: old patterns in test files

Use LSP (`find_references`, `find_symbol`) to locate usages across the codebase.

### Step 4: Group Changes by Type

Organize findings into logical change categories:

- **Config changes**: single files, low risk (e.g., `.eslintrc` flat config)
- **API renames**: systematic replacements (e.g., `require()` → `import`, `.on()` → `.addEventListener()`)
- **Removed features**: code that has no replacement (manual review required)
- **New patterns**: how to write new code (hooks vs. class components, async patterns)
- **Dependency updates**: version bumps in `package.json`, new peer dependencies

### Step 5: Estimate Effort & Risk

Count:

- Files affected
- Lines of code to change
- Breaking changes (those requiring manual decisions)
- Test coverage of affected code

Flag high-risk changes: features with no replacement, changes touching business logic.

### Step 6: Write Migration Plan

Write plan to `.planning/MIGRATION-{from}-{to}.md`:

```markdown
# Migration: {Library} {from} → {to}

## Scope

- Files affected: N
- Breaking changes: M
- Estimated effort: X hours
- Risk level: Low/Medium/High

## Breaking Changes

1. [Change 1]: [description]
   - Files: [N files]
   - Manual review: yes/no

## Config Changes

1. [Config file]: [specific changes needed]

## API Changes

| Old API | New API | Files |
| ------- | ------- | ----- |
| foo()   | bar()   | 5     |

## Removed Features

- [Feature]: No direct replacement
  - Manual decision: [what to do]

## Migration Order (lowest-risk first)

1. Update config files
2. Rename X to Y
3. Update types
4. Remove dead code
5. Manual review [high-risk items]

## Test Strategy

- Run tests after each step group
- Focus on: [files with highest coverage]

## Verification Checklist

- [ ] Full test suite passes
- [ ] No old API usage remains
- [ ] Build succeeds
- [ ] No TypeScript/lint errors
```

**Gate:** Review plan with user. Do not proceed to `--execute` until plan is approved.

## --execute Mode

Prerequisites: Run `--plan` first and review `.planning/MIGRATION-*.md`

Execute changes in low-risk-first order:

### Step 1: Config Files First

1. Update configuration files (lowest risk, isolated impact):
   - `.eslintrc` / `eslint.config.js`
   - `tsconfig.json`
   - `package.json` (version pins and dependencies)
   - Framework-specific configs (`jest.config.js`, `next.config.js`, etc.)

2. Test: Run full test suite after config changes
3. Commit: `feat(migrate): update config for {library} v{version}`

### Step 2: Systematic Renames & API Changes

For each API change category:

1. Make changes to all affected files
2. Run tests
3. Commit: `feat(migrate): {description} for {library} v{version}`

Example: `feat(migrate): rename foo() to bar() for express v5`

### Step 3: Handle Removed Features

1. For each removed feature: decide on replacement strategy or deletion
2. Make changes
3. Run tests
4. If tests fail: revert that specific change, flag for manual review

Commit: `feat(migrate): handle {removed feature} removal in {library} v{version}`

### Step 4: Verification

After all changes:

1. Run full test suite
2. Run linter, typecheck
3. Rebuild project
4. Check for any remaining old API usage (grep/search)

If issues found: fix or revert specific changes, commit separately.

### Step 5: Commit One Logical Chunk Per Phase

- One commit per file group or API category
- Commit message pattern: `feat(migrate): {what changed} for {library} v{version}`
- Examples:
  - `feat(migrate): update .eslintrc to flat config for eslint v9`
  - `feat(migrate): rename Jest to Vitest imports`
  - `feat(migrate): update useEffect cleanup patterns for React 19`

If a change group tests fail: revert that commit, investigate root cause, fix, and re-commit.

## --verify Mode

Verify nothing broke after migration. Run this after `--execute`.

### Step 1: Full Test Suite

```bash
npm test     # or your test runner
# or
pytest       # Python
# or
cargo test   # Rust
```

Fail-fast: if any test fails, stop and debug.

### Step 2: Check for Old API Usage

Search the codebase for any remaining references to the old API:

- Use LSP (`find_references`) for known old function/class names
- Grep for old import patterns
- Check for old config keys

Example:

```bash
grep -r "OLD_FUNCTION_NAME" --include="*.ts" --include="*.js"
grep -r "@deprecated" .
```

### Step 3: Build the Project

```bash
npm run build   # or equivalent
# or
cargo build
# or
python -m py_compile ...
```

Ensure zero build errors.

### Step 4: Lint & Typecheck

```bash
npm run lint
npm run type-check   # or tsc
```

Zero errors required.

### Step 5: Generate Verification Report

Write to `.planning/MIGRATION-VERIFY-{from}-{to}.md`:

```markdown
# Migration Verification: {Library} {from} → {to}

## Verification Completed

- [x] Full test suite passed (N tests, 0 failures)
- [x] No old API usage detected
- [x] Build succeeds
- [x] Lint + typecheck pass
- [x] Spot-checked key files: [list files]

## Files Touched

- [List all modified files]

## Status: ✓ COMPLETE

All checks passed. Migration is complete and verified.
```

**Success criteria:** All tests pass, zero remaining old API usage, build succeeds, typecheck/lint pass.

## Examples of Supported Migrations

This skill supports any framework/library migration, including:

- **ESLint v8 → v9**: Flat config, new rule names
- **React**: Class components → hooks, old lifecycle → useEffect, prop-types → TypeScript
- **Jest → Vitest**: Import paths, matcher names, config format
- **Express 4 → 5**: Async error handling, router changes
- **Python 3.9 → 3.12**: f-strings, match statements, new syntax
- **TypeScript 4.x → 5.x**: Type syntax changes, const type parameters
- **Next.js 12 → 14**: App Router migration, API changes
- **Tailwind v2 → v4**: Config changes, new class names
- **Prisma 4 → 5**: Schema syntax, client API changes

## SUCCESS CRITERIA

A migration is **complete** when:

1. ✓ Migration plan created (`.planning/MIGRATION-{from}-{to}.md`)
2. ✓ Plan reviewed and approved
3. ✓ All changes executed with atomic commits
4. ✓ Full test suite passes
5. ✓ Zero old API usage remains in codebase
6. ✓ Build succeeds with no errors
7. ✓ Lint and typecheck pass
8. ✓ Verification report generated (`.planning/MIGRATION-VERIFY-{from}-{to}.md`)
9. ✓ All commits follow the `feat(migrate): ...` pattern

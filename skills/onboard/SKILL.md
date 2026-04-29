---
name: onboard
description: "Generate a comprehensive onboarding guide for this project. Writes .planning/ONBOARDING.md. Use when you need to understand or explain a new codebase."
argument-hint: "[--refresh]"
---

# /onboard — Project Onboarding Guide

Generates a comprehensive onboarding guide for the current project. This guide helps new developers (or future-self) understand the project structure, how to run it, conventions, and common tasks.

## What it produces

Writes `.planning/ONBOARDING.md` with:

### 1. Architecture Overview

- **Project Description** — what does this project do? (1 paragraph, business/domain context)
- **Technology Stack** — languages, frameworks, databases, key libraries
- **Component Architecture** — high-level mermaid diagram (if applicable) or bullet-point architecture

### 2. Key Files & Entry Points

- **Entry points** — `main.ts`, `index.js`, `app.py`, `main.rs`, etc.
- **Critical config files** — `tsconfig.json`, `vite.config.ts`, `next.config.js`, `settings.json`, `.env.example`, etc. and what each controls
- **Where to find:**
  - Routes/API handlers
  - Models/schemas/types
  - Tests (unit, integration, e2e)
  - Build config
  - Utilities/helpers

### 3. How to Run

- **Prerequisites** — Node/Python/Go/Rust version, required tools, system dependencies
- **Setup steps:**
  - Install dependencies (`npm install`, `pip install -r requirements.txt`, `cargo build`, etc.)
  - Copy `.env.example` → `.env` and explain which vars are required
  - Any one-time setup (migrations, seed data, etc.)
- **Start dev server** — exact command(s) to run locally
- **Run tests** — command for unit tests, integration tests, e2e tests if present

### 4. Conventions

- **Commit format** — conventional commits if `.claude/` is present, else infer from recent git log
- **Where new features go** — file/folder structure pattern
- **Naming conventions** — inferred from existing codebase (camelCase, snake_case, PascalCase for classes, etc.)
- **Key abstractions** — any custom patterns, middleware, error handling, logging, etc.

### 5. Common Tasks

- **Add a new API endpoint** — concrete example with file locations and naming
- **Add a new test** — example test structure and how to run them
- **Release a version** — version bumping, changelog, tag command if release process exists
- **Debug common errors** — 2-3 most likely local dev errors and how to fix them

### 6. Useful Links (if detected)

- Links to docs in `docs/` directory
- Links to `.claude/` rules files that are relevant
- Links to CHANGELOG, API docs, deployment guides, etc.

## Flags

### `--refresh`

Regenerate the onboarding guide even if `.planning/ONBOARDING.md` already exists. Use this to update the guide after major code changes.

## How it works

1. **Analyze the repo** — scan root for `package.json`, `pyproject.toml`, `go.mod`, `Cargo.toml`, `README.md`, `.env.example`
2. **Examine code structure** — find entry points, infer architecture from import patterns
3. **Scan git history** — infer commit conventions from recent commits
4. **Read existing docs** — pull in knowledge from README, existing `.planning/` files, `.claude/` rules
5. **Synthesize** — produce a coherent, actionable guide
6. **Write to `.planning/ONBOARDING.md`** — single source of truth for onboarding

## SUCCESS CRITERIA

The generated guide should:

- [ ] Describe what the project does in domain language (not just "API" or "CLI")
- [ ] List tech stack accurately (check `package.json`, `pyproject.toml`, `Cargo.toml`, etc.)
- [ ] Correctly identify entry points (main file, server startup, CLI entrypoint)
- [ ] List all config files and briefly explain what each controls
- [ ] Provide copy-paste-ready setup and run commands
- [ ] Show at least one example of a new feature/endpoint (code location + naming)
- [ ] Explain the test structure with a run command
- [ ] Correctly infer commit message format (conventional commits, other)
- [ ] Be 1–2 pages (500–1000 words) — detailed but scannable
- [ ] Include actionable examples, not vague templates

## Implementation notes

- Use `find_symbol` and `get_symbols_overview` (Serena LSP) to understand code structure
- Prefer reading actual code and config files over guessing
- Look for `README.md`, `.env.example`, CHANGELOG patterns before assuming
- Check `.claude/` rules for context on commit format and conventions
- If the repo is a monorepo, focus on the root project; note if other workspaces exist
- If certain sections can't be determined (e.g., no tests, minimal docs), note briefly and move on
- All output is plain Markdown, readable in any editor

## Post-generation

When the guide is written:

1. Display a summary of what was documented
2. Prompt: "Onboarding guide written to `.planning/ONBOARDING.md`. Review it? (y/n)"
3. If yes, show the generated guide
4. Suggest: "Next: share this with your team or your future-self!"

## Commit message

After generating or updating the guide, the user can commit it with:

```
docs: update project onboarding guide
```

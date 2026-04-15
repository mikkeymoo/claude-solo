---
name: mm-docs
description: "Claude-solo command skill"
---

# mm-docs

Claude-solo command skill

## Instructions
---
name: mm:docs
description: "Documentation suite — sync docs with code, generate onboarding guide, create/update feature dev docs, or compress a doc for LLM consumption."
argument-hint: "[sync | onboard | plan <feature> | update <feature> | distill [file]]"
---

Documentation management. Detect intent from argument or context.

- No argument or `sync` → sync docs with current code
- `onboard` → generate contributor onboarding guide
- `plan <feature>` → create feature dev docs (plan + context + tasks)
- `update <feature>` → refresh existing feature dev docs
- `distill [file]` → compress a doc for LLM consumption

---

## sync — Synchronize docs with code

Run after significant code changes to catch doc/code drift.

Scan each source against the codebase:
- **README.md** — setup steps still work? Listed features accurate?
- **CLAUDE.md** — referenced commands, paths, patterns still exist?
- **API docs** — endpoint signatures match code? Examples valid?
- **.env.example** — lists all required env vars used in code?
- **Code comments** — any @deprecated, TODO, or FIXME referencing completed work?

For each drift found: update the doc to match the code. If the change looks accidental, flag it.

Consistency checks: CLI commands copy-pasteable? Version numbers match lockfile? Links resolve?

Report format:
```
✅ README.md — up to date
🔧 CLAUDE.md — updated 2 stale path references
⚠️  .env.example — missing DATABASE_URL
```

Commit all updates:
```bash
rtk git add -A && rtk git commit -m "docs: sync documentation with current codebase"
```

---

## onboard — Contributor onboarding guide

Inspect the project:
```bash
rtk git log --oneline -10 && rtk ls . && cat README.md 2>/dev/null | head -100
cat package.json 2>/dev/null || cat pyproject.toml 2>/dev/null || true
cat .env.example 2>/dev/null && ls .github/ 2>/dev/null || true
```

Write `docs/ONBOARDING.md` covering:
1. **Prerequisites** — required tools/versions, required accounts/access
2. **Local setup** — step-by-step: clone, install deps, env vars, migrations, dev server
3. **Project structure** — entry point, where new features go, where tests live
4. **Development workflow** — test command, lint command, branch naming, PR process, commit convention
5. **Architecture in 5 bullets** — what it does, structure, key deps, data storage, external services
6. **Where to find things** — table: "I want to add an endpoint → src/routes/"
7. **Common pitfalls** — things that trip up new contributors, non-obvious behavior

---

## plan <feature> — Create feature dev docs

Generate three files for `<feature>`:

**[feature]-plan.md** — executive summary, implementation phases, technical approach, risk assessment, success metrics, task breakdown

**[feature]-context.md** — critical file paths, architectural decisions and rationale, dependencies, integration points, historical trade-offs

**[feature]-tasks.md** — checkbox task list organized by phase, with dependencies, time estimates per task, and acceptance criteria

Save all three to the current directory or `.planning/`.
Present the plan for review. Use `update <feature>` as implementation evolves.

---

## update <feature> — Refresh feature dev docs

Read existing `[feature]-plan.md`, `[feature]-context.md`, and `[feature]-tasks.md`.
Gather recent decisions, file changes, and open questions from the active session.
Mark completed tasks. Append new context and newly discovered follow-up work.
Add "Next Steps" section so future sessions stay anchored after compaction.

---

## distill [file] — Compress for LLM

Default target: `.planning/PLAN.md` if no file given.

This is NOT summarization — every fact, decision, constraint, and relationship must survive. Remove: padding prose, repetitive section intros, human-oriented filler. Preserve: all decisions + rationale, constraints, task names, dependencies, done-criteria, warnings.

Target: ≤40% of original token count.

Write to `.planning/[original-name].distilled.md`.

Report: "Original: ~X tokens → Distilled: ~Y tokens (Z% reduction). All decisions preserved ✓"

If distilled version would be >5K tokens, shard by section with a `_index.md`.

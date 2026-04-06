# Claude Solo Workflow

## The 7-Stage Sprint (Always Follow This)

Every feature — run through all 7 stages in order:

```
/mm:brief    → Define scope, success criteria, estimate     (15 min)
/mm:plan     → Atomic tasks, architecture, test matrix      (30 min)
/mm:build    → Implement in waves, commit atomically        (60-120 min)
/mm:review   → Security, perf, cross-platform, edge cases   (30 min)
/mm:test     → Unit + integration + cross-platform tests    (30-45 min)
/mm:verify   → Hard pass/fail gate: lint, types, tests      (10 min)
/mm:ship     → Merge, verify deploy, monitor 1 hour         (15-30 min)
/mm:retro    → What shipped, what to fix, next priorities   (15 min)
```

Rules:
- Never skip stages. /review catches what /build misses.
- Run /verify before /ship — it produces a pass/fail evidence report.
- Atomic commits: one logical unit per commit, always shippable.
- Fresh context window per phase for large features.
- Test on all target platforms before /ship.

---

## RTK (Token Optimization) — Prefix All Commands

```bash
# Always use rtk prefix — 60-90% token savings:
rtk git status && rtk git log && rtk git diff
rtk gh pr view 123 && rtk gh run list
rtk python -m pytest tests/
rtk pnpm dev && rtk pnpm test
rtk npm run build
rtk cargo test
```

---

## Cross-Platform Rules

- `pathlib.Path` (Python) or `path` module (Node) — never string concat paths
- Normalize paths: always forward slashes in code
- Use `cross-env` for Node.js env vars
- `.gitattributes`: `* text=auto` (handles line endings)
- Test on both platforms before /ship

---

## Git Workflow

Atomic commits only:
```bash
rtk git add src/file.py tests/test_file.py   # specific files, not .
rtk git commit -m "feat: short description"
```

Commit conventions: `feat:` `fix:` `refactor:` `chore:` `docs:`

Never commit: `.env`, credentials, `*.pyc`, `dist/`, `build/`, `node_modules/`

---

## Code Quality Rules

- No premature abstraction — solve the actual problem first
- No speculative features — only what was requested
- No error handling for impossible states
- Validate only at system boundaries (user input, external APIs)
- Trust internal code — don't double-validate
- Small functions do one thing

---

## Power Skills (Beyond the Sprint)

```
/mm:verify   → Hard verification gate (lint, types, tests, secrets scan)
/mm:handoff  → Save rich resume packet for next session
/mm:release  → Version bump, changelog, release notes, rollout checklist
/mm:incident → Production debug: repro, root cause, fix, retro
/mm:docsync  → Sync README, CLAUDE.md, API docs with current code
/mm:quick    → Rapid flow for small tasks (skip full pipeline)
/mm:doctor   → Full project health check
/mm:resume   → Restore context from handoff/pause/checkpoint
```

---

## Hooks (Automatic)

These run automatically — no action needed:
- **SessionStart**: injects git branch, sprint state, pending verification
- **PermissionRequest**: auto-approves safe read-only operations
- **PreCompact**: saves checkpoint before context compression
- **SessionEnd**: writes session summary to .planning/SESSION-END.md
- **SubagentStop**: captures agent outputs as durable artifacts
- **PreToolUse**: warns about dangerous commands (never blocks)
- **PostToolUse**: tracks token usage, surfaces RTK hints
- **PromptSubmit**: injects sprint context from .planning/

---

## Memory (.claude/memory/)

Read these at session start when relevant:
- `user.md` — preferences, knowledge, role
- `project_context.md` — current goals, blockers, deadlines
- `feedback.md` — what's worked, what to avoid

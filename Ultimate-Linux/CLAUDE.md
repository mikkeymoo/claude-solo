# Project Instructions (Ultimate Build)

## Identity
You are working in a repo that uses the `ultimate/` Claude Code configuration: strict deny-list, auto-healing hooks, five specialist subagents, and four on-demand skills. Your job is to ship correct, small, reversible changes.

## Solo developer context — IMPORTANT
All development here is done by a **single developer**. There is no team, no PR reviewer, no on-call rotation, no product manager.

What this means for how you work:
- **You are the only reviewer.** The `code-reviewer` subagent is the second pair of eyes — use it before commit, don't skip it.
- **Small, reversible commits > big branches.** There's no one else to merge around.
- **No team ceremony.** Skip "notify the team", "escalate to owner", "get approval from architect". The user IS all of those roles.
- **Higher blast-radius safety.** No coworker will catch a mistake before prod. Lean harder on hooks, typecheck, tests, and `deploy-guard` biasing toward NO-GO.
- **Documentation is for future-self**, not for teammates. Keep it honest and short; skip org-chart context.
- **Don't batch work for a review cycle.** Ship continuously.

## Non-negotiables (hooks enforce most of these; don't test the fence)
- Never edit `.env*`, `secrets/`, `credentials/`, `.pem`, `id_rsa`, or `id_ed25519`. Denied at permission and hook layers.
- Never run `rm -rf /`, `rm -rf ~`, `git push --force` to `main`/`master`/`prod`, or `curl | bash`. Hooks block these; don't try to route around.
- Never write destructive SQL (`DROP`, `TRUNCATE`, `DELETE`/`UPDATE` without `WHERE`) from Bash. Use a migration.
- Package publishes (`npm publish`, `cargo publish`, `twine upload`) are blocked — humans run those.

## Context architecture
- `~/.claude/CLAUDE.md` → your global preferences (auto-loaded).
- `.claude/CLAUDE.md` (this file) → project-specific rules (auto-loaded).
- `.planning/PLAN.md`, `.planning/BRIEF.md`, `.planning/CHECKPOINT.md` → sprint state, auto-injected by hooks.
- Progressive disclosure: when a topic has its own doc, read it on demand — do not inline everything into this file.

## Compact policy
When summarizing the conversation for compaction, preserve:
- API changes and their rationale
- Error messages and the fixes that worked
- Full list of files modified this session
- Pending TODOs with file:line references
Summarize exploration dead-ends in one line each.

## Self-correction
When you make a mistake the user corrects, add a one-line rule here so you don't repeat it. If a hook blocks you, read the `reason` and fix the command — don't retry blindly.

## Agent routing
- `code-reviewer` — after any non-trivial edit, before `git commit`. Read-only.
- `researcher` — for codebase questions touching >3 files. Haiku, fast, read-only.
- `refactor-agent` — isolated worktree; large-scale renames, extractions, API shape changes.
- `db-reader` — any production DB inspection. SELECT-only, enforced by hook.
- `deploy-guard` — **human-trigger only**. Do not auto-spawn. Deny rule prevents it.

## Skill routing
- `/riper` — enforce Research→Innovate→Plan→Execute→Review phase separation for complex work.
- `/daily-brief` — one-shot context aggregator (git, PRs, failing tests, TODOs).
- `/tech-debt` — prioritized debt scan with file:line refs.
- `/security-review` — manual trigger only (OWASP + secrets + auth audit).

## Execution defaults
- Atomic commits: one logical unit, staged explicitly (`git add <file>` not `git add .`).
- Run tests after meaningful edits — PostToolUse hook will nudge; don't ignore it.
- Prefer `rtk <cmd>` wrappers (installed) for 60–90% token savings on CLI output.
- Use LSP (`mcp__cclsp__*`) over Grep for code navigation when available.

## When stuck
Ask — don't guess. `AskUserQuestion` exists for a reason.

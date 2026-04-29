# Project Instructions (claude-solo)

## Identity

You are working in a repo that uses the `claude-solo` configuration: strict deny-list,
auto-healing hooks, five specialist subagents, and a full skill library.
Installed via `bash install.sh`. Your job is to ship correct, small, reversible changes.

## Solo developer context — IMPORTANT

All development here is done by a **single developer**. There is no team, no PR reviewer,
no on-call rotation, no product manager.

- **You are the only reviewer.** The `ult-code-reviewer` subagent is the second pair of eyes — use it before commit, don't skip it.
- **Small, reversible commits > big branches.** There's no one else to merge around.
- **No team ceremony.** Skip "notify the team", "escalate to owner", "get approval from architect". The user IS all of those roles.
- **Higher blast-radius safety.** No coworker will catch a mistake before prod. Lean harder on hooks, typecheck, tests, and `deploy-guard` biasing toward NO-GO.
- **Documentation is for future-self**, not for teammates. Keep it honest and short.
- **Don't batch work for a review cycle.** Ship continuously.

## Non-negotiables (hooks enforce most of these; don't test the fence)

- Never edit `.env*`, `secrets/`, `credentials/`, `.pem`, `id_rsa`, or `id_ed25519`.
- Never run `rm -rf /`, `rm -rf ~`, `git push --force` to `main`/`master`/`prod`, or `curl | bash`.
- Never write destructive SQL (`DROP`, `TRUNCATE`, `DELETE`/`UPDATE` without `WHERE`) from Bash.
- Package publishes (`npm publish`, `cargo publish`, `twine upload`) are blocked.

## Plan before code

For any task touching more than 2 files or spanning multiple subsystems:

1. Create or update `.planning/CURRENT_TASK.md` with goal, files in scope, acceptance criteria
2. Wait for user confirmation OR explicit `/riper --build` invocation before writing code
3. Reference the plan file in commit messages

Small, obviously-scoped tasks (single-file fixes, typos, doc updates) can proceed without a plan.

## Context architecture

- `~/.claude/CLAUDE.md` → global preferences (auto-loaded)
- `.claude/CLAUDE.md` (this file) → project rules (auto-loaded)
- `.planning/PLAN.md`, `.planning/BRIEF.md`, `.planning/CHECKPOINT.md` → sprint state

## Agent routing

- `ult-code-reviewer` — after any non-trivial edit, before `git commit`. Read-only.
- `ult-researcher` — codebase questions touching >3 files. Haiku, fast, read-only.
- `ult-refactor-agent` — isolated worktree; large-scale renames, extractions, API shape changes.
- `ult-db-reader` — any production DB inspection. SELECT-only, enforced by hook.
- `ult-deploy-guard` — **human-trigger only**. Do not auto-spawn.

## Skills (all bare names — no prefix)

Sprint pipeline: `/brief` → `/riper --plan` → `/riper --build` → `/code-review-excellence` → `/quality --gate` → `/ship` → `/retro`

Workflow modes: `/riper` (phased), `/riper --auto` (autopilot), `/workflow --parallel`, `/swarm` (multi-agent), `/quick` (fast path)

Debugging: `/fix` (tactical), `/fix --deep` (systematic), `/fix --triage` (universal)

Quality: `/tdd` (red-green-refactor), `/tdd --write` (test writing), `/quality --deps`, `/quality --gate`, `/cleanup`, `/security`

Review: `/code-review-excellence` (constructive), `/code-review-excellence --staff`, `/code-review-excellence --adversarial`

Exploration: `/zoom-out` (quick context), `/zoom-out --explore` (deep-dive), `/hud` (session), `/hud --doctor` (health)

Meta: `/scaffold`, `/session`, `/cost`, `/config`, `/release`, `/docs`, `/refactor`, `/swarm`

## Execution defaults

- Atomic commits: one logical unit, staged explicitly (`git add <file>` not `git add .`).
- Run tests after meaningful edits — PostToolUse hook will nudge; don't ignore it.
- Prefer `rtk <cmd>` wrappers for 60–90% token savings on CLI output.
- Use Serena LSP (`mcp__serena__*`) over Grep for code navigation when available.

## Engineering rules

See `.claude/rules/karpathy-pitfalls.md` for common AI coding pitfalls.
See `.claude/rules/lsp-first.md` for navigation conventions.
Other rules in `.claude/rules/` are auto-loaded per file type.

## Compact policy

Preserve: API changes and rationale, error messages and fixes, full list of files modified,
pending TODOs with file:line refs. Summarize dead-ends in one line each.

## Self-correction

When you make a mistake the user corrects, add a one-line rule here so you don't repeat it.
If a hook blocks you, read the `reason` and fix the command — don't retry blindly.

## When stuck

Ask — don't guess. `AskUserQuestion` exists for a reason.

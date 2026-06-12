# Project Instructions (claude-solo)

## Identity

You are working in a repo that uses the `claude-solo` configuration: strict deny-list,
auto-healing hooks, five specialist subagents, and a full skill library.
Installed via `bash install.sh`. Your job is to ship correct, small, reversible changes.

## Solo developer context — IMPORTANT

All development here is done by a **single developer**. There is no team, no PR reviewer,
no on-call rotation, no product manager.

- **You are the only reviewer.** The `code-reviewer` subagent is the second pair of eyes — use it before commit, don't skip it.
- **Small, reversible commits > big branches.** There's no one else to merge around.
- **No team ceremony.** Skip "notify the team", "escalate to owner", "get approval from architect". The user IS all of those roles.
- **Higher blast-radius safety.** No coworker will catch a mistake before prod. Lean harder on hooks, typecheck, tests, and `deploy-guard` biasing toward NO-GO.
- **Documentation is for future-self**, not for teammates. Keep it honest and short.
- **Don't batch work for a review cycle.** Ship continuously.

## Safety (the deny-list was removed — these are now conventions, not fences)

The permission deny-list and the catastrophic-command hook block were removed at
the user's request. With `defaultMode: bypassPermissions` and an empty `deny`
array, **nothing is blocked** — the items below are judgment guidelines, not
enforced barriers. Use care; there is no longer a safety net.

- Avoid editing `.env*`, `secrets/`, `credentials/`, `.pem`, `id_rsa`, `id_ed25519` unless intended.
- Avoid `rm -rf /`, `rm -rf ~`, `git push --force` to shared branches, and `curl | bash` from untrusted sources.
- Avoid destructive SQL (`DROP`, `TRUNCATE`, `DELETE`/`UPDATE` without `WHERE`) from Bash — use a migration.
- Package publishes (`npm publish`, `cargo publish`, `twine upload`) are humans' job.
- To restore enforcement, add `deny` entries to `settings.json` and a catastrophic-pattern check to `hooks/permission-request.js`.

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

- `code-reviewer` — after any non-trivial edit, before `git commit`. Read-only.
- `researcher` — codebase questions touching >3 files. Haiku, fast, read-only.
- `refactor-agent` — isolated worktree; large-scale renames, extractions, API shape changes.
- `db-reader` — any production DB inspection. SELECT-only, enforced by hook.
- `deploy-guard` — **human-trigger only**. Do not auto-spawn.

## Skills (all bare names — no prefix)

Sprint pipeline: `/brief` → `/riper --plan` → `/riper --build` → `/code-review-excellence` → `/quality --gate` → `/ship` → `/retro`

Workflow modes: `/riper` (phased), `/riper --auto` (autopilot), `/workflow --parallel`, `/swarm` (multi-agent), `/quick` (fast path)

Debugging: `/fix` (tactical), `/fix --deep` (systematic), `/fix --triage` (universal), `/fix --bisect` (git bisect regression finder)

Quality: `/tdd` (red-green-refactor), `/tdd --write` (test writing), `/test-gen` (generate tests for existing code), `/quality --deps`, `/quality --gate`, `/cleanup`, `/security` (OWASP + CVE scan), `/perf` (performance profiling)

Review: `/code-review-excellence` (constructive), `/code-review-excellence --staff`, `/code-review-excellence --adversarial`, `/api-design` (REST API review/design)

Exploration: `/zoom-out` (quick context), `/zoom-out --explore` (deep-dive), `/hud` (session), `/hud --doctor` (health), `/onboard` (generate project onboarding guide)

Dependencies: `/deps` (audit/upgrade/clean deps), `/deps --audit`, `/deps --clean`, `/changelog` (generate from conventional commits), `/ci` (CI status/retry)

Incident response: `/incident` (structured postmortem Q&A), `/migrate` (migration assistant: `--plan`, `--execute`, `--verify`)

Meta: `/scaffold` (new: `--react`, `--next`, `--fastapi`, `--express` templates), `/sketch` (rapid prototype), `/session`, `/cost` (`--trend` for week-over-week comparison), `/config`, `/release`, `/docs` (`--api` for OpenAPI spec generation), `/refactor`, `/swarm` (`--status`, `--results` modes), `/cleanup` (`--aggressive` for maximum dead code removal)

## Execution defaults

- Atomic commits: one logical unit, staged explicitly (`git add <file>` not `git add .`).
- **Pushing to `main` is always allowed without asking.** After committing, push to `origin/main` directly — no confirmation needed, no feature branch required. (Solo repo; the deny-list was removed, so even `git push --force` is no longer blocked — use care.)
- Run tests after meaningful edits — PostToolUse hook will nudge; don't ignore it.
- `rtk` (Rust Token Killer) auto-rewrites simple Bash commands via the `rtk-rewrite.sh` PreToolUse hook — no need to prefix `rtk` yourself (it's a no-op if rtk isn't installed). 60–90% token savings on CLI output.
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

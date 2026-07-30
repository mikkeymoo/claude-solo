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
2. Wait for user confirmation OR explicit `/mm-riper --build` invocation before writing code
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

## Skills (all `/mm-` prefixed — standalone skills)

Sprint pipeline: `/mm-brief` → `/mm-riper --plan` → `/mm-riper --build` → `/mm-code-review-excellence` → `/mm-quality --gate` → `/mm-ship` → `/mm-retro`

Workflow modes: `/mm-riper` (phased), `/mm-riper --auto` (autopilot), `/mm-workflow --parallel`, `/mm-swarm` (multi-agent), `/mm-quick` (fast path)

Debugging: `/mm-fix` (tactical), `/mm-fix --deep` (systematic), `/mm-fix --triage` (universal), `/mm-fix --bisect` (git bisect regression finder)

Quality: `/mm-tdd` (red-green-refactor), `/mm-tdd --write` (test writing), `/mm-test-gen` (generate tests for existing code), `/mm-quality --deps`, `/mm-quality --gate`, `/mm-cleanup`, `/mm-security` (OWASP + CVE scan), `/mm-perf` (performance profiling)

Review: `/mm-code-review-excellence` (constructive), `/mm-code-review-excellence --staff`, `/mm-code-review-excellence --adversarial`, `/mm-api-design` (REST API review/design)

Exploration: `/mm-zoom-out` (quick context), `/mm-zoom-out --explore` (deep-dive), `/mm-hud` (session), `/mm-hud --doctor` (health), `/mm-onboard` (generate project onboarding guide)

Dependencies: `/mm-deps` (audit/upgrade/clean deps), `/mm-deps --audit`, `/mm-deps --clean`, `/mm-changelog` (generate from conventional commits), `/mm-ci` (CI status/retry)

Incident response: `/mm-incident` (structured postmortem Q&A), `/mm-migrate` (migration assistant: `--plan`, `--execute`, `--verify`)

Meta: `/mm-scaffold` (new: `--react`, `--next`, `--fastapi`, `--express` templates), `/mm-sketch` (rapid prototype), `/mm-session`, `/mm-cost` (`--trend` for week-over-week comparison), `/mm-config`, `/mm-release`, `/mm-docs` (`--api` for OpenAPI spec generation), `/mm-refactor`, `/mm-swarm` (`--status`, `--results` modes), `/mm-cleanup` (`--aggressive` for maximum dead code removal)

## Execution defaults

- Atomic commits: one logical unit, staged explicitly (`git add <file>` not `git add .`).
- **Pushing to `main` is always allowed without asking.** After committing, push to `origin/main` directly — no confirmation needed, no feature branch required. (Solo repo; the deny-list was removed, so even `git push --force` is no longer blocked — use care.)
- Run tests after meaningful edits — PostToolUse hook will nudge; don't ignore it.
- `rtk` (Rust Token Killer) auto-rewrites simple Bash commands via the `rtk-rewrite.sh` PreToolUse hook — no need to prefix `rtk` yourself (it's a no-op if rtk isn't installed). 60–90% token savings on CLI output.
- Use Grep/Glob for code navigation. Scope with `glob`/`type`, start with `files_with_matches`, then re-run with `content` on the hits.

## Engineering rules

See `.claude/rules/karpathy-pitfalls.md` for common AI coding pitfalls.
Other rules in `.claude/rules/` are auto-loaded per file type.

## Compact policy

Preserve: API changes and rationale, error messages and fixes, full list of files modified,
pending TODOs with file:line refs. Summarize dead-ends in one line each.

## Self-correction

When you make a mistake the user corrects, add a one-line rule here so you don't repeat it.
If a hook blocks you, read the `reason` and fix the command — don't retry blindly.

## When stuck

Ask — don't guess. `AskUserQuestion` exists for a reason.

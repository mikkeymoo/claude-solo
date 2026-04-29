# claude-solo

Claude Code configuration for solo developers. One flat repo, one installer, no variant selection.

## Quickstart

```bash
# Install (merge — coexists with existing config)
bash install.sh

# Fresh install (replaces existing config, backup taken automatically)
bash install.sh --fresh

# Dry run (preview without changing anything)
bash install.sh --dry-run

# Add project override to current directory
bash install.sh --project

# Uninstall
bash install.sh --uninstall

# Check prerequisites only
bash install.sh --verify
```

**Requirements:** `bash` (Git Bash on Windows), `jq`

**Auto-installed by the installer (if not present):** `claude-code-cache-fix` (npm)

## What gets installed

```
~/.claude/
  scripts/           18 lifecycle scripts (bash + node)
  hooks/             21 JS hooks (PreToolUse, PostToolUse, Stop, SubagentStart/Stop)
  agents/            5 specialist subagents (ult-* prefix)
  skills/            47 skills (bare /name invocation)
  rules/             10 engineering rules (auto-loaded)
  settings.json      Wired hooks, permissions, env vars
  CLAUDE.md          Working style + agent/skill routing
  statusline.sh      One Dark Pro compact statusline
```

## Hooks (25 entries across 6 events)

| Event         | Hook                            | Purpose                                                        |
| ------------- | ------------------------------- | -------------------------------------------------------------- |
| SessionStart  | `bootstrap-windows-encoding.sh` | Set UTF-8 env vars before anything runs                        |
| SessionStart  | `cost-summary.sh`               | Today's token/cost summary (throttled 5min)                    |
| SessionStart  | `quota-warmup-warn.sh`          | 5h quota window visibility                                     |
| SessionStart  | `session-hud.sh`                | Branch, sprint, recent files, TODO count (throttled 10min)     |
| SessionStart  | `session-start-context.sh`      | Git + sprint state injected into model context                 |
| SessionStart  | `morae-context.sh`              | eDiscovery reminders when CWD matches known patterns           |
| SessionStart  | `update-check.sh`               | Daily update notice (network-failure-tolerant)                 |
| PreToolUse    | `validate-readonly-query.sh`    | Block write SQL from db-reader subagent                        |
| PreToolUse    | `pre-tool-use.js`               | Conventional commits enforcement + danger warnings             |
| PreToolUse    | `validate-utf8-source.sh`       | Block mojibake before it corrupts files                        |
| PreToolUse    | `large-file.js`                 | Warn on Write >500 lines or >50KB (advisory)                   |
| PreToolUse    | `gitignore-check.js`            | Warn on writes to gitignored paths (advisory)                  |
| PreToolUse    | `enforce-lsp-navigation.sh`     | Nudge: prefer LSP over Grep for code symbols                   |
| PostToolUse   | `post-format-and-heal.sh`       | Auto-format + LSP diagnostics after edits                      |
| PostToolUse   | `lint-fix.js`                   | Auto lint-then-fix: runs eslint/ruff/clippy, exits 2 on error  |
| PostToolUse   | `compress-lsp-output.sh`        | Trim verbose Serena MCP output                                 |
| PostToolUse   | `morae-powerbi-validate.sh`     | Power BI brand/JSON validation (opt-in via env var)            |
| PostToolUse   | `dashboard-agent.js`            | Post tool lifecycle events to local dashboard on :9876         |
| PostToolUse   | `test-fix.js`                   | Run tests after edits, exit 2 on failure (opt-in: AUTO_TEST=1) |
| PostToolUse   | `commit-msg.js`                 | Suggest conventional commit message from staged diff           |
| PostToolUse   | `latency-track.js`              | Track per-tool timing, alert if >30s (advisory)                |
| PreCompact    | `pre-compact-checkpoint.sh`     | Save checkpoint before context compaction                      |
| Stop          | `stop-gate.js`                  | Block stop if dirty tree, TODO markers, or tests fail          |
| SubagentStart | `dashboard-agent.js`            | Post subagent lifecycle events to dashboard                    |
| SubagentStop  | `dashboard-agent.js`            | Post subagent lifecycle events to dashboard                    |

## Specialist subagents

Installed with `ult-` prefix (invoke via `Agent` tool or `/agents`):

| Agent                | Purpose                                       |
| -------------------- | --------------------------------------------- |
| `ult-code-reviewer`  | Staff-engineer review, Opus, 3-pass           |
| `ult-researcher`     | Codebase questions >3 files, Haiku, read-only |
| `ult-refactor-agent` | Isolated worktree for large-scale changes     |
| `ult-db-reader`      | SELECT-only DB inspector (hook-enforced)      |
| `ult-deploy-guard`   | Pre-deploy checklist (human-trigger only)     |

## Skills (bare `/name`)

```
Sprint pipeline
  /brief              Capture idea → .planning/BRIEF.md
  /riper --plan       Expand brief → PLAN.md with atomic tasks
  /riper --build      Execute tasks from PLAN.md
  /code-review-excellence  Run code-reviewer before commit
  /quality --gate     Hard pass/fail gate (lint, types, tests)
  /ship               Merge + deploy + monitor
  /retro              Sprint retrospective

Observability
  /cost               Token/cost analysis from JSONL logs
  /cost --trend       Week-over-week comparison + 7-day bar chart
  /hud                Session HUD with token chart
  /session            Save/restore context

Workflow
  /riper              Phased development (Research→Plan→Execute→Review)
  /riper --auto       Full autopilot pipeline
  /workflow           Execution mode selector
  /swarm              Parallel multi-agent orchestration
  /swarm --status     Inspect active worktrees
  /swarm --results    List merged wave outcomes
  /quick              Rapid flow for small tasks

Quality & security
  /tdd                Red-green-refactor TDD loop
  /test-gen           Generate tests for existing code
  /quality --deps     Dependency audit
  /cleanup            Dead code + duplication removal
  /cleanup --aggressive  Maximum removal with diff table + confirmation
  /security           OWASP + CVE scan (manual trigger only)
  /perf               Performance profiling (--quick, --deep, --db)

Debug
  /fix                Tactical bug fix
  /fix --deep         Systematic debugging
  /fix --triage       Universal troubleshooting
  /fix --bisect       Git bisect regression finder

Review & design
  /api-design         REST API review/design (--review, --design, --breaking)
  /code-review-excellence --staff        Staff-engineer review
  /code-review-excellence --adversarial  Adversarial review

Dependencies & CI
  /deps               Audit/upgrade/clean deps (npm/pip/cargo)
  /changelog          Generate Keep a Changelog output from git log
  /ci                 CI status, failing checks, retry, logs

Incident response
  /incident           Guided postmortem Q&A → .planning/POSTMORTEM.md
  /migrate            Migration assistant (--plan, --execute, --verify)

DX & tooling
  /hud --doctor       Project health check
  /onboard            Generate project onboarding guide
  /sketch             Rapid prototype (--api, --cli, --ui, --script)
  /scaffold           New project starter (--react, --next, --fastapi, --express)
  /config             Manage rules, schedule, CI
  /docs               Docs sync and onboarding
  /docs --api         Generate OpenAPI 3.0 spec from route handlers
  /release            Changelog + version bump + tag
  /refactor           Targeted refactoring
  /zoom-out           Higher-level perspective
  /write-a-skill      Scaffold a new skill
  /lsp-status         Diagnose LSP server registration

eDiscovery / Morae
  /relativity-sql     Relativity SQL bundle + PS wrappers
```

## Windows encoding

Fixes `charmap` codec errors and `settings.json` mojibake — two common Windows bugs.

One-shot fix (run once from PowerShell, no installer needed):

```powershell
powershell -ExecutionPolicy Bypass -File scripts/Setup-WindowsEncoding.ps1
```

## Cost optimization

The installer handles all three automatically:

1. **cache-fix proxy** — fixes the 5m→1h cache TTL regression in CC v2.1.81+. Auto-installed via `npm install -g claude-code-cache-fix`; `ANTHROPIC_BASE_URL=http://127.0.0.1:9801` patched into `settings.json`.
2. **Session hygiene** — keep sessions long, use checkpoints, prefer LSP over Grep.
3. **`/cost --trend`** — week-over-week token/cost comparison to spot regressions early.

## Install modes

| Flag          | Behavior                                                             |
| ------------- | -------------------------------------------------------------------- |
| (none)        | Merge — coexists with existing config, agents prefixed `ult-`        |
| `--fresh`     | Replace — overwrites config, backup taken automatically              |
| `--project`   | Project override — adds `.claude/settings.json` to current directory |
| `--dry-run`   | Preview only — no files changed                                      |
| `--verify`    | Check prerequisites only                                             |
| `--uninstall` | Remove installed files using manifest                                |

## Changelog

See [CHANGELOG.md](CHANGELOG.md).

Current: **v0.8.0** (2026-04-29) — 47 skills, 21 hooks, observability dashboard, auto lint-fix, confidence scoring

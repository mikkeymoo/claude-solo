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
  scripts/           17 lifecycle hook scripts
  agents/            5 specialist subagents (ult-* prefix)
  skills/            37 skills (bare /name invocation)
  rules/             10 engineering rules (auto-loaded)
  settings.json      Wired hooks, permissions, env vars
  CLAUDE.md          Working style + agent/skill routing
  statusline.sh      One Dark Pro compact statusline
  COST-OPTIMIZATION.md  Cache TTL fix + lean-ctx notes
```

## Hooks (14 entries across 4 events)

| Event        | Hook                            | Purpose                                                    |
| ------------ | ------------------------------- | ---------------------------------------------------------- |
| SessionStart | `start-cache-proxy.sh`          | Start claude-code-cache-fix proxy on :9801 (runs first)    |
| SessionStart | `bootstrap-windows-encoding.sh` | Set UTF-8 env vars before anything runs                    |
| SessionStart | `cost-summary.sh`               | Today's token/cost summary (throttled 5min)                |
| SessionStart | `quota-warmup-warn.sh`          | 5h quota window visibility                                 |
| SessionStart | `session-hud.sh`                | Branch, sprint, recent files, TODO count (throttled 10min) |
| SessionStart | `session-start-context.sh`      | Git + sprint state injected into model context             |
| SessionStart | `morae-context.sh`              | eDiscovery reminders when CWD matches known patterns       |
| SessionStart | `update-check.sh`               | Daily update notice (network-failure-tolerant)             |
| PreToolUse   | `validate-readonly-query.sh`    | Block write SQL from db-reader subagent                    |
| PreToolUse   | `validate-utf8-source.sh`       | Block mojibake before it corrupts files                    |
| PreToolUse   | `enforce-lsp-navigation.sh`     | Nudge: prefer LSP over Grep for code symbols               |
| PostToolUse  | `post-format-and-heal.sh`       | Auto-format + LSP diagnostics after edits                  |
| PostToolUse  | `compress-lsp-output.sh`        | Trim verbose Serena MCP output                             |
| PostToolUse  | `morae-powerbi-validate.sh`     | Power BI brand/JSON validation (opt-in via env var)        |
| PreCompact   | `pre-compact-checkpoint.sh`     | Save checkpoint before context compaction                  |

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
  /hud                Session HUD with token chart
  /session            Save/restore context

Workflow
  /riper              Phased development (Research→Plan→Execute→Review)
  /riper --auto       Full autopilot pipeline
  /workflow           Execution mode selector
  /swarm              Parallel multi-agent orchestration
  /quick              Rapid flow for small tasks

Quality & security
  /tdd                Red-green-refactor TDD loop
  /quality --deps     Dependency audit
  /cleanup            Dead code + duplication removal
  /security           OWASP audit (manual trigger only)

Debug
  /fix                Tactical bug fix
  /fix --deep         Systematic debugging
  /fix --triage       Universal troubleshooting

DX & tooling
  /hud --doctor       Project health check
  /scaffold           Scaffold Python/PS/SQL starter
  /config             Manage rules, schedule, CI
  /docs               Docs sync, onboarding, distill
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

1. **cache-fix proxy** — fixes the 5m→1h cache TTL regression in CC v2.1.81+. Auto-installed via `npm install -g claude-code-cache-fix`; proxy starts each session via `start-cache-proxy.sh` hook; `ANTHROPIC_BASE_URL=http://127.0.0.1:9801` patched into `settings.json`.
2. **Session hygiene** — keep sessions long, use checkpoints, prefer LSP over Grep.

See `COST-OPTIMIZATION.md` (installed to `~/.claude/`) for full guide.

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

Current: **v0.5.0** (2026-04-29) — skills consolidation: 37 skills replace commands+skills, bare `/name` invocation

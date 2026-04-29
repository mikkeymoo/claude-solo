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
  commands/          30 slash commands (/mm:name)
  skills/            25 skills (/mm:name)
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

## Commands & skills (`/mm:name`)

```
Planning & execution
  /mm:brief           Capture idea → .planning/BRIEF.md
  /mm:plan            Expand brief → PLAN.md with atomic tasks
  /mm:build           Execute tasks from PLAN.md
  /mm:review          Run code-reviewer before commit
  /mm:retro           Sprint retrospective
  /mm:verify          Hard pass/fail gate (lint, types, tests)
  /mm:ship            Merge + deploy + monitor

Observability
  /mm:cost            Token/cost analysis from JSONL logs
  /mm:hud             Full session HUD with token chart
  /mm:daily-brief     One-shot context aggregator
  /mm:session         Save/restore context

Quality & security
  /mm:riper           Enforce Research→Plan→Execute phases
  /mm:security-review OWASP audit (manual trigger only)
  /mm:tech-debt       Prioritized debt scan with file:line refs
  /mm:quality         Code quality audit
  /mm:cleanup         Code cleanup

DX & tooling
  /mm:doctor          Project health check
  /mm:scaffold        Scaffold Python/PS/SQL starter
  /mm:config          Manage rules, schedule, CI
  /mm:workflow        Execution modes (--auto, --parallel, --tdd)
  /mm:search          Deep research + explain + estimate
  /mm:docs            Docs sync, onboarding, distill
  /mm:release         Changelog + version bump + tag

LSP & skills
  /mm:lsp-status      Diagnose LSP server registration
  /mm:skill-from-template  Scaffold a new skill

eDiscovery / Morae
  /mm:nuix-binary-store    Prudential binary store audit
  /mm:relativity-sql       Relativity SQL bundle + PS wrappers
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

Current: **v0.4.4** (2026-04-29) — removed notifications (BurntToast/toast); --fresh now wipes all managed dirs

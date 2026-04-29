# claude-solo

Claude Code configuration for solo developers. Three variants, one installer.

## Variants

| Variant              | Target             | What it adds                                                                                               |
| -------------------- | ------------------ | ---------------------------------------------------------------------------------------------------------- |
| **Original**         | Any platform       | Classic claude-solo setup — prompts, basic hooks                                                           |
| **Ultimate-Linux**   | Linux / macOS      | 5 specialist subagents, 18 commands, 4 skills, 13 lifecycle hooks                                          |
| **Ultimate-Windows** | Windows / Git Bash | Everything in Ultimate-Linux plus Windows encoding hardening, cost observability, eDiscovery domain skills |

## Quickstart

```bash
# Interactive install (recommended)
bash install.sh

# Direct install — Ultimate-Windows
bash install.sh --windows

# Fresh install (replaces existing config, backup taken automatically)
bash install.sh --windows --fresh

# Dry run (preview without changing anything)
bash install.sh --windows --dry-run

# Add project override to current directory
bash install.sh --windows --project

# Uninstall
bash install.sh --uninstall --windows
```

Requirements: `bash` (Git Bash on Windows), `jq`, `node`

## Ultimate-Windows highlights

### Windows encoding hardening (v0.3.0)

Fixes `charmap` codec errors and `settings.json` mojibake corruption — two reproducible bugs
on Windows that silently drop hook configs or corrupt Python output.

```bash
# One-shot fix (run once from PowerShell, no installer needed):
powershell -ExecutionPolicy Bypass -File Ultimate-Windows/scripts/Setup-WindowsEncoding.ps1
```

What the installer adds to `settings.json`:

- `PYTHONIOENCODING=utf-8` — prevents `charmap` errors in Python tool output
- `PYTHONUTF8=1` — enables Python's UTF-8 mode globally
- `CLAUDE_CODE_USE_POWERSHELL_TOOL=1` — enables native PowerShell tool support

### Cost & cache observability (v0.3.0)

SessionStart banner shows token usage summary on every session start:

```
[bootstrap] Windows UTF-8 encoding active
[cost] today: 142k reads, 38k 5m-writes, 12k 1h-writes (78% hit) ~$1.84
[quota] 5h window started 14:32 (2h 12m ago), 87k tokens used
--- session context ---
  git: main  |  dirty: 2  |  vs origin: +0 -0
```

Run `/mm:cost` for a full breakdown with per-project stats and optimization suggestions.

See `Ultimate-Windows/COST-OPTIMIZATION.md` for the cache TTL regression fix (CC v2.1.81+)
and `lean-ctx` integration notes.

### Lifecycle hooks (13 events)

| Event        | Hook                            | Purpose                                                    |
| ------------ | ------------------------------- | ---------------------------------------------------------- |
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
| PostToolUse  | `morae-powerbi-validate.sh`     | Power BI brand/JSON validation (opt-in)                    |
| Notification | `notify-desktop.sh`             | BurntToast → MessageBox → terminal bell                    |
| PreCompact   | `pre-compact-checkpoint.sh`     | Save checkpoint before context compaction                  |

### Specialist subagents

All installed with `ult-` prefix in merge mode:

- `ult-code-reviewer` — staff-engineer review (Opus, 3-pass)
- `ult-researcher` — codebase questions >3 files (Haiku, fast, read-only)
- `ult-refactor-agent` — isolated worktree for large-scale changes
- `ult-db-reader` — SELECT-only DB inspector (hook-enforced)
- `ult-deploy-guard` — pre-deploy checklist (human-trigger only)

### Commands & skills

```
/mm:brief         Capture idea → .planning/BRIEF.md
/mm:plan          Expand brief → PLAN.md with atomic tasks
/mm:build         Execute tasks from PLAN.md
/mm:review        Run code-reviewer before commit
/mm:cost          Token/cost analysis from JSONL logs
/mm:skill-from-template  Scaffold a new skill
/lsp-status       Diagnose LSP server registration
/hud              Full session HUD with token chart
/riper            Enforce Research→Plan→Execute phase separation
/daily-brief      One-shot context aggregator
/tech-debt        Prioritized debt scan
/security-review  OWASP audit (manual trigger only)
```

### Domain skills (Morae / eDiscovery)

- `/nuix-binary-store` — three-phase Prudential binary store audit (Phase 1 scan, Phase 2 MD5 extraction, Phase 3 orphan detection)
- `/relativity-sql` — verified SQL bundle with PowerShell wrappers and Power BI output formatters

## Cost optimization

Claude Code costs vary 4-20x depending on session patterns. Key levers:

1. **cache-fix-wrapper** — fixes 5m TTL regression in CC v2.1.81+: https://github.com/cnighswonger/claude-code-cache-fix
2. **lean-ctx** — file-read caching at ~13 tokens/re-read: `cargo install lean-ctx`
3. **Session hygiene** — keep sessions long, use checkpoints, prefer LSP over Grep

See `Ultimate-Windows/COST-OPTIMIZATION.md` for full guide.

## Install modes

| Flag          | Behavior                                                             |
| ------------- | -------------------------------------------------------------------- |
| (none)        | Merge — coexists with existing config, agents prefixed `ult-`        |
| `--fresh`     | Replace — overwrites config, backup taken automatically              |
| `--project`   | Project override — adds `.claude/settings.json` to current directory |
| `--dry-run`   | Preview only — no files changed                                      |
| `--verify`    | Check prerequisites only                                             |
| `--uninstall` | Remove installed variant using manifest                              |

## Changelog

See [CHANGELOG.md](CHANGELOG.md).

Current: **v0.3.0** (2026-04-29) — Windows encoding hardening, cost observability, LSP enforcement, HUD, domain skills

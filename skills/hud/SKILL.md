---
name: hud
description: "Session HUD (default), project health check (--doctor), codebase map (--map), or pre-build gate (--ready). Use for 'you are here' view or project diagnostics."
---

# /hud — Session HUD

Full-featured heads-up display. ASCII only, no images.

## What it produces

### Section 1: Git & Sprint State

```
Branch:  main (+2 ahead, 0 behind)
Dirty:   3 files modified
Sprint:  Phase 2 — cost observability hooks
Last CP: 2026-04-29T14:30:00Z
```

### Section 2: Token Usage (today, from JSONL)

```
Token usage today
  Cache reads  [========          ] 142k  (78%)
  5m writes    [===               ]  38k  (21%)
  Direct input [=                 ]   8k   (4%)
  Output       [====              ]  24k

  Cache hit ratio: 78%  |  Est. cost: $1.84
```

Use ASCII bar charts. Bar width = 20 chars. Scale bars relative to largest value.

### Section 3: Recent Tool Distribution (last 50 tool calls from JSONL)

```
Recent tool calls (last 50)
  Read          18  [==================]
  Grep           9  [=========         ]
  Edit           8  [========          ]
  Bash           7  [=======           ]
  Agent          5  [=====             ]
  other          3  [===               ]
```

### Section 4: Active Hooks

List all hooks registered in `~/.claude/settings.json`:

```
Active hooks
  SessionStart  bootstrap-windows-encoding.sh
  SessionStart  cost-summary.sh
  SessionStart  quota-warmup-warn.sh
  SessionStart  session-hud.sh
  SessionStart  morae-context.sh
  PreToolUse    validate-readonly-query.sh      (matcher: Bash)
  PreToolUse    validate-utf8-source.sh         (matcher: Edit|Write|MultiEdit)
  PreToolUse    enforce-lsp-navigation.sh       (matcher: Grep|Glob)
  PostToolUse   post-format-and-heal.sh         (matcher: Edit|Write|MultiEdit)
  PostToolUse   compress-lsp-output.sh          (matcher: mcp__serena__.*)
  PostToolUse   morae-powerbi-validate.sh       (matcher: Edit|Write|MultiEdit) [gated: MORAE_POWERBI_VALIDATION=1]
  Notification  notify-desktop.sh
  PreCompact    pre-compact-checkpoint.sh
```

### Section 5: Open TODOs

Show first 5 unchecked items from `.planning/TODO.md` or repo-root `TODO.md`.

## Helper script

Run `python ~/.claude/skills/hud/hud_report.py` for token usage and tool distribution sections. Flags: `--tokens` (tokens only), `--tools` (tools only). No flag = both.

## Implementation notes

- Parse JSONL from `~/.claude/projects/**/*.jsonl` using jq
- Parse hooks list from `~/.claude/settings.json`
- Git info from `git status`, `git log`, `git rev-list`
- All output is plain text, no ANSI colors (renders in any context)
- Width-aware: detect `$COLUMNS` env var, default 80

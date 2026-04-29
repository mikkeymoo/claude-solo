---
name: mm:lsp-status
description: Show registered LSP MCP servers, active language servers, and run a sample query against each. Use when diagnosing LSP availability or why the Grep/Glob LSP nudge fires but no results appear.
---

# /lsp-status — LSP Server Status

Diagnose which LSP/MCP servers are registered and working.

## What it does

1. **Reads** `~/.claude/settings.json` and `~/.claude/mcp.json` to list all registered MCP servers
2. **Filters** for LSP-capable servers (serena, cclsp, or any key matching `*lsp*`)
3. **Runs a sample query** against each available LSP tool:
   - For Serena: `mcp__serena__get_symbols_overview` on current directory
   - For cclsp: `mcp__cclsp__find_symbol` with a simple pattern
4. **Reports** which servers responded and which timed out or errored
5. **Diagnoses** common issues:
   - Server registered but not started → suggest restarting Claude Code
   - Server started but query failed → show raw error
   - No LSP servers found → suggest installing Serena MCP

## Output format

```
LSP Status Report
-----------------
Registered MCP servers (LSP-capable):
  [OK]   serena    — mcp__serena__* tools available
  [NONE] cclsp     — not registered in settings.json

Sample query results:
  serena / get_symbols_overview → 12 symbols found in current directory

Diagnosis: LSP navigation is available. The Grep/Glob nudge hook will suggest
  mcp__serena__find_symbol for code-symbol searches.

To disable the nudge: remove enforce-lsp-navigation.sh from PreToolUse hooks in settings.json
```

## When to use

- After installing Serena or cclsp to verify it's working
- When LSP nudge fires in Grep/Glob but you get no results
- When diagnosing why code navigation seems to be using Grep instead of LSP
- After updating Claude Code to check LSP tools still respond

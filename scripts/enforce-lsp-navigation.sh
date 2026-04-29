#!/usr/bin/env bash
# enforce-lsp-navigation.sh — PreToolUse hook for Grep|Glob
# Nudges agent to prefer LSP symbol tools when search looks like a code-symbol query.
# Does NOT block (exit 0 always). Advisory hint only.

set -euo pipefail

input="$(cat)"

# Extract the search pattern from Grep or Glob tool input
pattern="$(printf '%s' "$input" | jq -r '.tool_input.pattern // .tool_input.query // ""' 2>/dev/null || true)"
tool_name="$(printf '%s' "$input" | jq -r '.tool_name // ""' 2>/dev/null || true)"

[[ -z "$pattern" ]] && exit 0

# Check if an LSP-capable MCP server is registered in settings.json
CLAUDE_HOME="${HOME}/.claude"
settings_file="${CLAUDE_HOME}/settings.json"
has_lsp=0
if [[ -f "$settings_file" ]]; then
  # Look for serena or cclsp MCP server keys in settings
  if jq -e '(.mcpServers // {}) | keys[] | select(test("serena|cclsp"; "i"))' "$settings_file" >/dev/null 2>&1; then
    has_lsp=1
  fi
fi

# Also check MCP config file
mcp_config="${CLAUDE_HOME}/mcp.json"
if [[ -f "$mcp_config" ]]; then
  if jq -e '(.mcpServers // {}) | keys[] | select(test("serena|cclsp"; "i"))' "$mcp_config" >/dev/null 2>&1; then
    has_lsp=1
  fi
fi

[[ $has_lsp -eq 0 ]] && exit 0

# Heuristics: does the pattern look like a code-symbol search?
# Positive signals: code syntax markers
is_code_symbol=0
code_patterns=(
  '\bdef \w'
  '\bclass \w'
  '\bfunction \w'
  '\bconst \w+\s*='
  '\blet \w+\s*='
  '\bvar \w+\s*='
  '\bfn \w'
  '\bpub fn'
  '\bimport \w'
  '\bexport (default |const |function |class )'
  '\b[A-Z][A-Za-z]+\('    # PascalCase function call
  '\b[a-z][A-Za-z]+\('    # camelCase function call
  '^[A-Z][A-Za-z0-9]+$'   # pure PascalCase symbol (class/type name)
)

for cp in "${code_patterns[@]}"; do
  if printf '%s' "$pattern" | grep -qP "$cp" 2>/dev/null; then
    is_code_symbol=1
    break
  fi
done

# Negative signals: prose (multi-word plain text, no parens/braces)
if printf '%s' "$pattern" | grep -qP '^[a-z ]{10,}$' 2>/dev/null; then
  is_code_symbol=0
fi

[[ $is_code_symbol -eq 0 ]] && exit 0

# Emit nudge as additionalContext (non-blocking)
printf '{"decision":"approve","reason":"[lsp-hint] For code symbol searches, prefer mcp__serena__find_symbol or mcp__serena__find_referencing_symbols over Grep/Glob. They use LSP and return structured results at ~20%% the token cost. Only fall back to Grep when LSP returns no results or you need full-text search."}\n'

exit 0

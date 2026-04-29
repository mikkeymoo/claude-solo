#!/usr/bin/env bash
# compress-lsp-output.sh — PostToolUse hook for mcp__serena__* tools.
#
# Rewrites overly verbose LSP output before it lands in the agent's context.
# Inspired by lean-ctx (https://github.com/yvgude/lean-ctx) — lean-ctx handles
# shell output; this hook does the LSP/MCP equivalent.
#
# Mechanism: PostToolUse + MCP tools support `hookSpecificOutput.updatedMCPToolOutput`
# to replace the tool's response. This is documented in the Claude Code hooks spec.
#
# Compression strategies by tool:
#   find_referencing_symbols  → keep top 30 refs verbatim, summarize rest
#   find_symbol               → cap at 50 matches
#   get_symbols_overview      → cap at 80 symbols per response
#
# Everything else passes through untouched. Never silently drops info — always
# includes a "compressed: original N → kept M" line so the agent knows to ask
# for more if needed.

set -euo pipefail
exec 2>/dev/null

INPUT=$(cat)
TOOL=$(echo "$INPUT" | jq -r '.tool_name // ""')

# Only operate on serena tools; pass through everything else
case "$TOOL" in
  mcp__serena__*) ;;
  *) exit 0 ;;
esac

# Extract the MCP tool response
RAW=$(echo "$INPUT" | jq -c '.tool_response // empty')
[[ -z "$RAW" || "$RAW" == "null" ]] && exit 0

# Helper to emit the rewrite and exit
emit_compressed() {
  local compressed="$1"
  jq -nc --argjson out "$compressed" \
    '{hookSpecificOutput:{hookEventName:"PostToolUse",updatedMCPToolOutput:$out}}'
  exit 0
}

# ---------------------------------------------------------------------------
# find_referencing_symbols — cap at 30 full refs, summarize remainder
# ---------------------------------------------------------------------------
if [[ "$TOOL" == "mcp__serena__find_referencing_symbols" ]]; then
  TOTAL=$(echo "$RAW" | jq -r '
    if type=="array" then length
    elif (.content // empty | type)=="array" then (.content | length)
    elif (.result // empty | type)=="string" then (.result | split("\n") | length)
    else 0 end')

  if [[ "$TOTAL" -gt 30 ]]; then
    COMPRESSED=$(echo "$RAW" | jq --argjson max 30 '
      if type=="array" then
        {kept: .[:$max], note: ("compressed: kept first \($max) of \(length) references")}
      elif (.content // empty | type)=="array" then
        .content = .content[:$max] + [{type:"text",text:("… (truncated \((.content|length) - $max) more references)")}]
      else . end')
    emit_compressed "$COMPRESSED"
  fi
fi

# ---------------------------------------------------------------------------
# find_symbol — cap at 50
# ---------------------------------------------------------------------------
if [[ "$TOOL" == "mcp__serena__find_symbol" ]]; then
  TOTAL=$(echo "$RAW" | jq -r '
    if type=="array" then length
    elif (.content // empty | type)=="array" then (.content | length)
    elif (.result // empty | type)=="string" then (.result | split("\n") | length)
    else 0 end')
  if [[ "$TOTAL" -gt 50 ]]; then
    COMPRESSED=$(echo "$RAW" | jq --argjson max 50 '
      if type=="array" then .[:$max] + [{note:"symbols truncated; refine query for more precision"}]
      elif (.content // empty | type)=="array" then .content = .content[:$max] + [{type:"text",text:"… (truncated; refine query)"}]
      else . end')
    emit_compressed "$COMPRESSED"
  fi
fi

# ---------------------------------------------------------------------------
# get_symbols_overview — cap at 80 symbols per response
# ---------------------------------------------------------------------------
if [[ "$TOOL" == "mcp__serena__get_symbols_overview" ]]; then
  TOTAL=$(echo "$RAW" | jq -r '
    if type=="array" then length
    elif (.content // empty | type)=="array" then (.content | length)
    elif (.result // empty | type)=="string" then (.result | split("\n") | length)
    else 0 end')
  if [[ "$TOTAL" -gt 80 ]]; then
    COMPRESSED=$(echo "$RAW" | jq --argjson max 80 '
      if type=="array" then .[:$max] + [{note:"overview truncated at \($max) symbols"}]
      elif (.content // empty | type)=="array" then .content = .content[:$max] + [{type:"text",text:"… (truncated; use depth=0 or restrict to specific file)"}]
      else . end')
    emit_compressed "$COMPRESSED"
  fi
fi

exit 0

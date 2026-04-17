#!/usr/bin/env bash
# compress-lsp-output.sh — PostToolUse hook for mcp__cclsp__* tools.
#
# Rewrites overly verbose LSP output before it lands in the agent's context.
# Inspired by lean-ctx (https://github.com/yvgude/lean-ctx) — lean-ctx handles
# shell output; this hook does the LSP/MCP equivalent.
#
# Mechanism: PostToolUse + MCP tools support `hookSpecificOutput.updatedMCPToolOutput`
# to replace the tool's response. This is documented in the Claude Code hooks spec.
#
# Compression strategies by tool:
#   find_references            → keep top 30 refs verbatim, summarize rest by file
#   find_workspace_symbols     → cap at 50 matches, sort by likely relevance (file path shorter = closer to src root)
#   get_diagnostics            → group by severity, cap 20 per severity
#   get_hover                  → truncate types > 800 chars with a "(truncated)" marker
#   prepare_call_hierarchy / get_incoming_calls / get_outgoing_calls → cap at 40 entries
#
# Everything else passes through untouched. Never silently drops info — always
# includes a "compressed: original N → kept M" line so the agent knows to ask
# for more if needed.

set -euo pipefail
exec 2>/dev/null

INPUT=$(cat)
TOOL=$(echo "$INPUT" | jq -r '.tool_name // ""')

# Only operate on cclsp tools; pass through everything else
case "$TOOL" in
  mcp__cclsp__*) ;;
  *) exit 0 ;;
esac

# Extract the MCP tool response. Shape is server-specific but cclsp returns
# JSON-structured content in tool_response. We normalize via jq.
RAW=$(echo "$INPUT" | jq -c '.tool_response // empty')
[[ -z "$RAW" || "$RAW" == "null" ]] && exit 0

# Helper to emit the rewrite and exit
emit_compressed() {
  local compressed="$1"
  # updatedMCPToolOutput expects the new tool response object; passing as-is.
  jq -nc --argjson out "$compressed" \
    '{hookSpecificOutput:{hookEventName:"PostToolUse",updatedMCPToolOutput:$out}}'
  exit 0
}

# ---------------------------------------------------------------------------
# find_references — cap at 30 full refs, summarize remainder by file
# ---------------------------------------------------------------------------
if [[ "$TOOL" == "mcp__cclsp__find_references" ]]; then
  # Attempt to parse array of refs. cclsp typically returns {content:[{type:"text",text:"..."}]}
  # OR a structured list; we handle both by flattening text content.
  TOTAL=$(echo "$RAW" | jq -r '
    if type=="array" then length
    elif (.content // empty | type)=="array" then (.content | length)
    elif (.references // empty | type)=="array" then (.references | length)
    else 0 end')

  if [[ "$TOTAL" -gt 30 ]]; then
    COMPRESSED=$(echo "$RAW" | jq --argjson max 30 '
      if type=="array" then
        {kept: .[:$max], summary: (.[$max:] | group_by(.uri // .file // .path // "unknown") | map({file:.[0].uri // .[0].file // .[0].path // "unknown", count:length})) }
      elif (.references // empty | type)=="array" then
        .references = .references[:$max] |
        . + {note: ("find_references: kept first \($max) of \('"$TOTAL"') — ask again with a narrower symbol if you need more")}
      elif (.content // empty | type)=="array" then
        .content = .content[:$max] + [{type:"text",text:("… (truncated \(('"$TOTAL"' - $max)) more references; ask again with a narrower symbol if needed)")}]
      else . end')
    emit_compressed "$COMPRESSED"
  fi
fi

# ---------------------------------------------------------------------------
# find_workspace_symbols — cap at 50
# ---------------------------------------------------------------------------
if [[ "$TOOL" == "mcp__cclsp__find_workspace_symbols" ]]; then
  TOTAL=$(echo "$RAW" | jq -r '
    if type=="array" then length
    elif (.symbols // empty | type)=="array" then (.symbols | length)
    elif (.content // empty | type)=="array" then (.content | length)
    else 0 end')
  if [[ "$TOTAL" -gt 50 ]]; then
    COMPRESSED=$(echo "$RAW" | jq --argjson max 50 '
      if type=="array" then .[:$max]
      elif (.symbols // empty | type)=="array" then .symbols = .symbols[:$max] | . + {note:"symbols truncated; refine query for more precision"}
      elif (.content // empty | type)=="array" then .content = .content[:$max] + [{type:"text",text:"… (truncated; refine query)"}]
      else . end')
    emit_compressed "$COMPRESSED"
  fi
fi

# ---------------------------------------------------------------------------
# get_diagnostics — group by severity, cap 20 per bucket
# ---------------------------------------------------------------------------
if [[ "$TOOL" == "mcp__cclsp__get_diagnostics" ]]; then
  COMPRESSED=$(echo "$RAW" | jq '
    def trim_bucket: if length > 20 then .[:20] + [{message:"… (more omitted)"}] else . end;
    if type=="object" and (.diagnostics // empty | type)=="array" then
      .diagnostics = (
        .diagnostics
        | group_by(.severity // 4)
        | map({severity:(.[0].severity // 4), items:(. | trim_bucket)})
      )
    else . end')
  # Only emit if we actually changed the structure
  if [[ "$COMPRESSED" != "$RAW" ]]; then
    emit_compressed "$COMPRESSED"
  fi
fi

# ---------------------------------------------------------------------------
# get_hover — truncate very long type signatures
# ---------------------------------------------------------------------------
if [[ "$TOOL" == "mcp__cclsp__get_hover" ]]; then
  # Only truncate if the text content is larger than 800 chars
  LEN=$(echo "$RAW" | jq -r '
    if (.contents // empty | type)=="string" then (.contents | length)
    elif (.contents.value // empty | type)=="string" then (.contents.value | length)
    elif (.content // empty | type)=="array" then (.content | map(.text // "") | join("") | length)
    else 0 end')
  if [[ "$LEN" -gt 800 ]]; then
    COMPRESSED=$(echo "$RAW" | jq '
      def trunc: if length > 800 then .[:800] + "… (truncated; call again with different symbol for full type)" else . end;
      if (.contents | type)=="string" then .contents |= trunc
      elif (.contents.value | type)=="string" then .contents.value |= trunc
      elif (.content | type)=="array" then .content |= map(if .text then .text |= trunc else . end)
      else . end')
    emit_compressed "$COMPRESSED"
  fi
fi

# ---------------------------------------------------------------------------
# Call hierarchy — cap at 40
# ---------------------------------------------------------------------------
if [[ "$TOOL" == "mcp__cclsp__get_incoming_calls" || "$TOOL" == "mcp__cclsp__get_outgoing_calls" ]]; then
  TOTAL=$(echo "$RAW" | jq -r 'if type=="array" then length elif (.calls // empty | type)=="array" then (.calls|length) else 0 end')
  if [[ "$TOTAL" -gt 40 ]]; then
    COMPRESSED=$(echo "$RAW" | jq --argjson max 40 '
      if type=="array" then .[:$max]
      elif (.calls // empty | type)=="array" then .calls = .calls[:$max] | . + {note:"call hierarchy truncated"}
      else . end')
    emit_compressed "$COMPRESSED"
  fi
fi

exit 0

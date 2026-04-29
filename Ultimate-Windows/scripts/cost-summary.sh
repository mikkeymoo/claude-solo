#!/usr/bin/env bash
# cost-summary.sh — SessionStart hook (second in chain, after bootstrap-encoding)
# Parses today's JSONL usage files and emits a one-line cost/cache summary.
# Throttled: skips if last run was < 5 min ago.
# Exit 0 always — never block session startup.

set -euo pipefail

CLAUDE_HOME="${HOME}/.claude"
THROTTLE_FILE="${CLAUDE_HOME}/.last-cost-summary"
THROTTLE_SECS=300   # 5 minutes

# Throttle check
if [[ -f "$THROTTLE_FILE" ]]; then
  last_run=$(cat "$THROTTLE_FILE" 2>/dev/null || echo 0)
  now=$(date +%s)
  if (( now - last_run < THROTTLE_SECS )); then
    exit 0
  fi
fi

# Requires jq
command -v jq >/dev/null 2>&1 || exit 0

TODAY=$(date +%Y-%m-%d)

# Find all JSONL files modified today across all projects
mapfile -t jsonl_files < <(find "${CLAUDE_HOME}/projects" -name "*.jsonl" -newer /tmp 2>/dev/null | xargs -I{} bash -c 'test "$(date -r "{}" +%Y-%m-%d 2>/dev/null)" = "'"$TODAY"'" && echo "{}"' 2>/dev/null || true)

# Fallback: find any JSONL files at all (some CC versions use different layout)
if [[ ${#jsonl_files[@]} -eq 0 ]]; then
  mapfile -t jsonl_files < <(find "${CLAUDE_HOME}/projects" -name "*.jsonl" 2>/dev/null || true)
fi

if [[ ${#jsonl_files[@]} -eq 0 ]]; then
  exit 0
fi

# Parse usage from JSONL files
stats=$(jq -s '
  [ .[] | select(.usage != null) | .usage ]
  | {
      cache_read:    (map(.cache_read_input_tokens // 0) | add // 0),
      cache_5m:      (map(.cache_creation_input_tokens // (.cache_creation.ephemeral_5m_input_tokens // 0)) | add // 0),
      cache_1h:      (map(.cache_creation.ephemeral_1h_input_tokens // 0) | add // 0),
      input:         (map(.input_tokens // 0) | add // 0),
      output:        (map(.output_tokens // 0) | add // 0)
    }
' "${jsonl_files[@]}" 2>/dev/null || echo '{}')

cache_read=$(printf '%s' "$stats" | jq -r '.cache_read // 0')
cache_5m=$(printf '%s' "$stats" | jq -r '.cache_5m // 0')
cache_1h=$(printf '%s' "$stats" | jq -r '.cache_1h // 0')
input=$(printf '%s' "$stats" | jq -r '.input // 0')
output=$(printf '%s' "$stats" | jq -r '.output // 0')

# Skip if no meaningful data
total_tokens=$(( cache_read + cache_5m + cache_1h + input + output ))
[[ $total_tokens -eq 0 ]] && exit 0

# Compute cache hit ratio
total_input=$(( cache_read + cache_5m + cache_1h + input ))
if (( total_input > 0 )); then
  hit_ratio=$(( cache_read * 100 / total_input ))
else
  hit_ratio=0
fi

# Estimate cost (Sonnet 4.6 rates as of 2026-04 — flag stale on next CC release)
# Rates per 1M tokens: cache_read=0.30, cache_write_5m=3.75, cache_write_1h=3.75, input=3.00, output=15.00
# Using integer arithmetic (millicents = 1/1000 cent)
cost_millicents=$(( cache_read * 30 / 100000 + cache_5m * 375 / 100000 + cache_1h * 375 / 100000 + input * 300 / 100000 + output * 1500 / 100000 ))
cost_dollars=$(echo "scale=2; $cost_millicents / 100000" | bc 2>/dev/null || echo "?")

# Format token counts (k)
fmt_k() { echo "scale=0; $1 / 1000" | bc 2>/dev/null || echo "?"; }
r_k=$(fmt_k "$cache_read")
w5_k=$(fmt_k "$cache_5m")
w1_k=$(fmt_k "$cache_1h")

echo "[cost] today: ${r_k}k reads, ${w5_k}k 5m-writes, ${w1_k}k 1h-writes (${hit_ratio}% hit) ~\$${cost_dollars}"

if (( hit_ratio < 60 && total_input > 10000 )); then
  echo "  cache hit ratio low -- see ~/.claude/COST-OPTIMIZATION.md"
fi

# Update throttle timestamp
date +%s > "$THROTTLE_FILE" 2>/dev/null || true

exit 0

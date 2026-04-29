#!/usr/bin/env bash
# quota-warmup-warn.sh — SessionStart hook (third in chain)
# Reads recent JSONL to estimate the current 5h usage window and burn rate.
# Visibility only — does not manipulate quota. Exit 0 always.

set -euo pipefail

CLAUDE_HOME="${HOME}/.claude"

command -v jq >/dev/null 2>&1 || exit 0
command -v bc >/dev/null 2>&1 || exit 0

# Find all JSONL files from the last 5 hours
now_epoch=$(date +%s)
window_start=$(( now_epoch - 18000 ))  # 5h = 18000s
window_start_iso=$(date -d "@${window_start}" -u +%Y-%m-%dT%H:%M:%S 2>/dev/null || \
                   date -r "${window_start}" -u +%Y-%m-%dT%H:%M:%S 2>/dev/null || true)

[[ -z "$window_start_iso" ]] && exit 0

mapfile -t jsonl_files < <(find "${CLAUDE_HOME}/projects" -name "*.jsonl" 2>/dev/null || true)
[[ ${#jsonl_files[@]} -eq 0 ]] && exit 0

# Parse entries within the 5h window
window_stats=$(jq -s --arg ws "$window_start_iso" '
  [ .[] | select(.timestamp >= $ws and .usage != null) ]
  | {
      count:      length,
      first_ts:   (map(.timestamp) | sort | first // null),
      last_ts:    (map(.timestamp) | sort | last // null),
      total_in:   (map((.usage.input_tokens // 0) + (.usage.cache_read_input_tokens // 0) + (.usage.cache_creation_input_tokens // 0)) | add // 0),
      total_out:  (map(.usage.output_tokens // 0) | add // 0)
    }
' "${jsonl_files[@]}" 2>/dev/null || echo '{}')

count=$(printf '%s' "$window_stats" | jq -r '.count // 0')
[[ "$count" -eq 0 ]] && exit 0

first_ts=$(printf '%s' "$window_stats" | jq -r '.first_ts // ""')
total_in=$(printf '%s' "$window_stats" | jq -r '.total_in // 0')
total_out=$(printf '%s' "$window_stats" | jq -r '.total_out // 0')
total_tokens=$(( total_in + total_out ))

[[ $total_tokens -eq 0 ]] && exit 0

# Calculate elapsed time since window start
if [[ -n "$first_ts" ]]; then
  first_epoch=$(date -d "$first_ts" +%s 2>/dev/null || date -jf "%Y-%m-%dT%H:%M:%S" "$first_ts" +%s 2>/dev/null || echo "$window_start")
else
  first_epoch=$window_start
fi

elapsed_secs=$(( now_epoch - first_epoch ))
elapsed_min=$(( elapsed_secs / 60 ))
elapsed_h=$(( elapsed_min / 60 ))
elapsed_rem=$(( elapsed_min % 60 ))

# Format elapsed time
if (( elapsed_h > 0 )); then
  elapsed_str="${elapsed_h}h ${elapsed_rem}m"
else
  elapsed_str="${elapsed_min}m"
fi

# Format window start time (local)
window_start_local=$(date -d "@${first_epoch}" "+%H:%M" 2>/dev/null || \
                     date -r "${first_epoch}" "+%H:%M" 2>/dev/null || echo "unknown")

# Format token count
tokens_k=$(echo "scale=0; $total_tokens / 1000" | bc 2>/dev/null || echo "?")

echo "[quota] 5h window started ${window_start_local} (${elapsed_str} ago), ${tokens_k}k tokens used"

exit 0

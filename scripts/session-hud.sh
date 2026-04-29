#!/usr/bin/env bash
# session-hud.sh — SessionStart hook (fourth in chain, after quota-warmup)
# Emits a compact "you are here" panel: branch, sprint status, recent changes, TODOs.
# Throttled: skips if same session_id ran in last 10 min.
# Exit 0 always.

set -euo pipefail

CLAUDE_HOME="${HOME}/.claude"
THROTTLE_FILE="${CLAUDE_HOME}/.last-session-hud"
THROTTLE_SECS=600  # 10 minutes
COLS="${COLUMNS:-80}"

# Throttle check
if [[ -f "$THROTTLE_FILE" ]]; then
  last_run=$(cat "$THROTTLE_FILE" 2>/dev/null || echo 0)
  now=$(date +%s)
  if (( now - last_run < THROTTLE_SECS )); then
    exit 0
  fi
fi

# Must be inside a git repo
git rev-parse --git-dir >/dev/null 2>&1 || exit 0

# Separator width
sep_width=$(( COLS > 80 ? 80 : COLS ))
sep=$(printf '%*s' "$sep_width" '' | tr ' ' '-')

echo "$sep"
echo "[hud] session context"
echo "$sep"

# Git state
branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "unknown")
dirty_count=$(git status --short 2>/dev/null | wc -l || echo 0)
ahead_behind=$(git rev-list --left-right --count "HEAD...@{u}" 2>/dev/null | awk '{print "+"$1" -"$2}' || echo "+0 -0")
echo "  git: $branch  |  dirty: $dirty_count  |  vs origin: $ahead_behind"

# Active sprint
planning_dir="$(git rev-parse --show-toplevel 2>/dev/null)/.planning"
if [[ -f "${planning_dir}/SPRINT.md" ]]; then
  sprint_line=$(head -3 "${planning_dir}/SPRINT.md" | grep -v '^#' | head -1 | sed 's/^[[:space:]]*//')
  echo "  sprint: $sprint_line"
fi

# Last checkpoint
if [[ -f "${planning_dir}/CHECKPOINT.md" ]]; then
  cp_time=$(grep -E '^(Saved:|# Compaction checkpoint)' "${planning_dir}/CHECKPOINT.md" 2>/dev/null \
    | head -1 \
    | sed -E 's/^Saved: //; s/^# Compaction checkpoint — //' \
    || true)
  [[ -n "$cp_time" ]] && echo "  checkpoint: $cp_time"
fi

# Top 3 modified files in last 24h
echo "  recent (24h):"
git log --since="24 hours ago" --name-only --pretty=format: 2>/dev/null \
  | grep -v '^$' \
  | sort | uniq -c | sort -rn \
  | head -3 \
  | awk '{printf "    [%s] %s\n", $1, $2}' \
  || true

# Pending TODOs from TODO.md at repo root
repo_root=$(git rev-parse --show-toplevel 2>/dev/null || echo ".")
if [[ -f "${repo_root}/TODO.md" ]]; then
  todo_count=$(grep -c '^\- \[ \]' "${repo_root}/TODO.md" 2>/dev/null || echo 0)
  [[ "$todo_count" -gt 0 ]] && echo "  pending TODOs: $todo_count unchecked items in TODO.md"
fi

echo "$sep"

# Update throttle
date +%s > "$THROTTLE_FILE" 2>/dev/null || true

exit 0

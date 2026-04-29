#!/usr/bin/env bash
# update-check.sh — SessionStart hook (optional, daily cadence)
# Checks if the claude-solo repo has new commits available.
# Network-failure-tolerant: always exits 0, never blocks startup.
# Throttled: runs once per day via timestamp file.

set -euo pipefail

CLAUDE_HOME="${HOME}/.claude"
THROTTLE_FILE="${CLAUDE_HOME}/.last-update-check"
VERSION_FILE="${CLAUDE_HOME}/.ultimate-windows-version"
THROTTLE_SECS=86400  # 24 hours
REMOTE_URL="https://github.com/mikkeymoo/claude-solo"

# Throttle check
if [[ -f "$THROTTLE_FILE" ]]; then
  last_run=$(cat "$THROTTLE_FILE" 2>/dev/null || echo 0)
  now=$(date +%s)
  if (( now - last_run < THROTTLE_SECS )); then
    exit 0
  fi
fi

# Requires git
command -v git >/dev/null 2>&1 || exit 0

# Get remote HEAD SHA (silent fail on network error)
remote_sha=$(git ls-remote "$REMOTE_URL" HEAD 2>/dev/null | awk '{print $1}' || true)
[[ -z "$remote_sha" ]] && { date +%s > "$THROTTLE_FILE" 2>/dev/null || true; exit 0; }

# Get local installed version SHA
local_sha=""
[[ -f "$VERSION_FILE" ]] && local_sha=$(cat "$VERSION_FILE" 2>/dev/null || true)

# If we have a local version and it matches, we're up to date
if [[ -n "$local_sha" && "$local_sha" == "$remote_sha" ]]; then
  date +%s > "$THROTTLE_FILE" 2>/dev/null || true
  exit 0
fi

# If we don't have a version file, store remote SHA and exit silently (first run)
if [[ -z "$local_sha" ]]; then
  echo "$remote_sha" > "$VERSION_FILE" 2>/dev/null || true
  date +%s > "$THROTTLE_FILE" 2>/dev/null || true
  exit 0
fi

# We're behind — count commits if local install is a git repo
commit_count=""
install_parent=$(dirname "$(dirname "$(dirname "$VERSION_FILE")")")
if [[ -d "${install_parent}/.git" ]]; then
  # If the install is a git checkout, we can count
  commit_count=" (new commits available)"
fi

echo "[update] claude-solo has updates available${commit_count} -- run: bash ~/.claude/ultimate-windows/install.sh to upgrade"
echo "  local:  ${local_sha:0:8}  remote: ${remote_sha:0:8}"
echo "  repo:   $REMOTE_URL"

# Update throttle (but NOT version file — that's updated on successful install)
date +%s > "$THROTTLE_FILE" 2>/dev/null || true

exit 0

#!/usr/bin/env bash
# pre-compact-checkpoint.sh — PreCompact hook.
# Saves a resumable checkpoint BEFORE Claude compacts its context so that key
# state survives the summarization. Pair with a SessionStart hook that re-injects
# on matcher: "compact" for auto-resume.

set -euo pipefail
exec 2>/dev/null

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$PWD}"
cd "$PROJECT_DIR" 2>/dev/null || exit 0

mkdir -p .planning

# Read the compaction source (manual vs auto) if provided
INPUT=$(cat 2>/dev/null || echo '{}')
SOURCE=$(echo "$INPUT" | jq -r '.source // "unknown"')
TS=$(date -u '+%Y-%m-%d %H:%M:%SZ')
BRANCH=$(git branch --show-current 2>/dev/null || echo "detached")
HEAD=$(git rev-parse --short HEAD 2>/dev/null || echo "unknown")

cat > .planning/CHECKPOINT.md <<EOF
# Compaction checkpoint — $TS
# Compaction source: $SOURCE
# Branch: $BRANCH @ $HEAD

## Why this file exists
Claude's context is about to be compressed. The post-compact hook should re-inject
this file so the session resumes cleanly. Edit PLAN.md / BRIEF.md for durable state;
this file is overwritten on every compaction.

## Git snapshot
### Branch & status
$(git status -sb 2>/dev/null | head -20)

### Recent commits (last 10)
$(git log --oneline -10 2>/dev/null)

### Uncommitted diff (summary only — full diff would blow context)
$(git diff --stat HEAD 2>/dev/null | head -30)

## Sprint artifacts (if present)
$(for f in .planning/BRIEF.md .planning/PLAN.md; do
    if [[ -f "$f" ]]; then
      echo "### $f — head"
      head -30 "$f"
      echo ""
    fi
  done)

## Active TODOs / FIXMEs in src/ (top 10)
$(grep -rnE "TODO|FIXME|XXX" src/ 2>/dev/null | head -10 || echo "(none)")

## Recent failing tests (if logged)
$(if [[ -f .planning/last-test.log ]]; then
    tail -20 .planning/last-test.log
  else
    echo "(no test log)"
  fi)
EOF

# Signal success — PreCompact is observation; no need to block.
exit 0

#!/usr/bin/env bash
# session-start-context.sh — SessionStart hook.
# Emits JSON with hookSpecificOutput.additionalContext containing git + sprint state.
# Cap is 10,000 chars (Claude Code truncates with a preview if over). Keep concise.

set -euo pipefail

# Guard shell-profile echoes — hooks must emit only valid JSON on stdout.
exec 2>/dev/null

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$PWD}"
cd "$PROJECT_DIR" 2>/dev/null || exit 0

# Only run in git repos — in non-git contexts there's no useful sprint state.
if ! git rev-parse --git-dir >/dev/null 2>&1; then
  exit 0
fi

BRANCH=$(git branch --show-current 2>/dev/null || echo "detached")
STATUS=$(git status --porcelain 2>/dev/null | head -20)
UNCOMMITTED=$(echo "$STATUS" | grep -c '^' || echo "0")
LOG=$(git log --oneline -8 2>/dev/null)
AHEAD_BEHIND=$(git rev-list --left-right --count "origin/${BRANCH}...HEAD" 2>/dev/null || echo "")

PRS=""
if command -v gh >/dev/null 2>&1; then
  PRS=$(gh pr list --limit 3 --state open 2>/dev/null | head -10 || true)
fi

PLAN=""
for f in .planning/CHECKPOINT.md .planning/PLAN.md .planning/BRIEF.md; do
  if [[ -f "$f" ]]; then
    PLAN="$PLAN
### $f (first 20 lines)
$(head -20 "$f")"
  fi
done

LAST_TEST=""
if [[ -f .planning/last-test.log ]]; then
  LAST_TEST=$(tail -10 .planning/last-test.log)
fi

DEPS_HINT=""
# Warn if deps files changed recently (last 5 commits)
for f in package.json pyproject.toml requirements.txt Cargo.toml go.mod; do
  if [[ -f "$f" ]] && git log --oneline -5 -- "$f" | grep -q .; then
    DEPS_HINT="$DEPS_HINT
- $f changed in last 5 commits"
  fi
done

# Compose the context block
CONTEXT=$(cat <<EOF
## Session context (auto-injected)

### Git
- Branch: ${BRANCH}
- Uncommitted files: ${UNCOMMITTED}
- Ahead/behind origin: ${AHEAD_BEHIND:-unknown}

### Recent commits
${LOG}

### Uncommitted changes
${STATUS:-(none)}

### Open PRs
${PRS:-(none or gh not installed)}
${PLAN:+
### Sprint artifacts${PLAN}}
${LAST_TEST:+
### Last test run (tail)
${LAST_TEST}}
${DEPS_HINT:+
### Dependency activity${DEPS_HINT}}

---
Solo developer context. No team review bottleneck. Bias toward shipping small, reversible commits.
EOF
)

# Emit JSON via jq to handle escaping safely
jq -nc --arg ctx "$CONTEXT" \
  '{hookSpecificOutput:{hookEventName:"SessionStart",additionalContext:$ctx}}'

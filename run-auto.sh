#!/usr/bin/env bash
# claude-solo auto-mode (ralph pattern)
#
# Runs Claude Code autonomously in a loop until the task is complete.
# Uses --dangerouslySkipPermissions — Claude acts without confirmation prompts.
#
# Usage:
#   bash run-auto.sh                    # runs from .planning/PLAN.md
#   bash run-auto.sh "fix the login bug"  # one-shot task
#   bash run-auto.sh --max 5           # max 5 iterations (default: 10)
#
# Requirements: Claude Code CLI (`claude`) must be installed and authenticated.

set -e

MAX_ITER=10
TASK=""

# Parse args
while [[ $# -gt 0 ]]; do
    case "$1" in
        --max) MAX_ITER="$2"; shift 2 ;;
        *) TASK="$1"; shift ;;
    esac
done

# Build task prompt
if [[ -z "$TASK" ]]; then
    if [[ -f ".planning/PLAN.md" ]]; then
        TASK="$(cat .planning/PLAN.md)"
        echo "  Using .planning/PLAN.md as task"
    elif [[ -f ".planning/BRIEF.md" ]]; then
        TASK="$(cat .planning/BRIEF.md)"
        echo "  Using .planning/BRIEF.md as task"
    else
        echo "Error: no task provided and no .planning/PLAN.md found."
        echo "Usage: bash run-auto.sh \"your task\" OR create .planning/PLAN.md first"
        exit 1
    fi
fi

CONTINUE_PROMPT="Continue working on the task. Check git log to see what's been done. Keep going until all tasks are complete and tests pass. When fully done, output exactly: TASK_COMPLETE"

echo ""
echo "claude-solo auto-mode"
echo "  Max iterations: $MAX_ITER"
echo "  Task: ${TASK:0:80}..."
echo ""
echo "  ⚠️  Running with --dangerouslySkipPermissions"
echo "  Press Ctrl+C to stop at any time."
echo ""

ITER=0
INITIAL=true

while [[ $ITER -lt $MAX_ITER ]]; do
    ITER=$((ITER + 1))
    echo "── Iteration $ITER / $MAX_ITER ──────────────────────────────────"

    if $INITIAL; then
        PROMPT="$TASK

When you are fully done and all tests pass, output exactly on its own line: TASK_COMPLETE"
        INITIAL=false
    else
        PROMPT="$CONTINUE_PROMPT"
    fi

    OUTPUT=$(claude --dangerouslySkipPermissions -p "$PROMPT" 2>&1)
    echo "$OUTPUT"

    if echo "$OUTPUT" | grep -q "TASK_COMPLETE"; then
        echo ""
        echo "✅ Task complete after $ITER iteration(s)."
        exit 0
    fi

    echo ""
done

echo ""
echo "⚠️  Reached max iterations ($MAX_ITER) without TASK_COMPLETE signal."
echo "Run again to continue, or check the current state with: rtk git log --oneline"
exit 1

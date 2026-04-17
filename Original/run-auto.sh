#!/usr/bin/env bash
# claude-solo auto-mode (ralph pattern)
#
# Runs Claude Code autonomously in a loop until the task is complete.
# Uses --dangerouslySkipPermissions — Claude acts without confirmation prompts.
#
# Usage:
#   bash run-auto.sh                      # runs from .planning/PLAN.md
#   bash run-auto.sh "fix the login bug"  # one-shot task
#   bash run-auto.sh --max 5             # max 5 iterations (default: 10)
#
# Requirements: Claude Code CLI (`claude`) must be installed and authenticated.

set -e

MAX_ITER=10
TASK=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --max) MAX_ITER="$2"; shift 2 ;;
        *) TASK="$1"; shift ;;
    esac
done

if [[ -z "$TASK" ]]; then
    if [[ -f ".planning/PLAN.md" ]]; then
        TASK="$(cat .planning/PLAN.md)"
        echo "  Using .planning/PLAN.md as task"
    elif [[ -f ".planning/BRIEF.md" ]]; then
        TASK="$(cat .planning/BRIEF.md)"
        echo "  Using .planning/BRIEF.md as task"
    else
        echo "Error: no task provided and no .planning/PLAN.md found."
        echo "Usage: bash run-auto.sh \"your task\"  OR create .planning/PLAN.md first"
        exit 1
    fi
fi

STATUS_INSTRUCTIONS='
After EVERY response, append a RALPH_STATUS block:

```
RALPH_STATUS
tasks_done: [comma-separated list of completed task names]
tasks_remaining: [comma-separated list of remaining task names]
tests_passing: yes|no|partial
blockers: [none, or describe what is blocking]
EXIT_SIGNAL: false
```

Set EXIT_SIGNAL: true ONLY when ALL tasks are done AND all tests pass.
'

CONTINUE_PROMPT="Continue. Check git log for what's been done. Keep working until EXIT_SIGNAL is true.$STATUS_INSTRUCTIONS"

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
    echo "── Iteration $ITER / $MAX_ITER $(date '+%H:%M:%S') ──────────────────────────"

    if $INITIAL; then
        PROMPT="$TASK
$STATUS_INSTRUCTIONS"
        INITIAL=false
    else
        PROMPT="$CONTINUE_PROMPT"
    fi

    OUTPUT=$(claude --model claude-sonnet-4-6 --dangerouslySkipPermissions -p "$PROMPT" 2>&1)
    echo "$OUTPUT"

    # Parse RALPH_STATUS block
    if echo "$OUTPUT" | grep -q "EXIT_SIGNAL: true"; then
        DONE_TASKS=$(echo "$OUTPUT" | grep "tasks_done:" | tail -1 | sed 's/tasks_done: //')
        echo ""
        echo "✅ Auto-mode complete after $ITER iteration(s)."
        echo "   Done: $DONE_TASKS"
        exit 0
    fi

    # Show remaining tasks if present
    REMAINING=$(echo "$OUTPUT" | grep "tasks_remaining:" | tail -1 | sed 's/tasks_remaining: //')
    if [[ -n "$REMAINING" && "$REMAINING" != "none" ]]; then
        echo "  → Remaining: $REMAINING"
    fi

    echo ""
done

echo ""
echo "⚠️  Reached max iterations ($MAX_ITER) without EXIT_SIGNAL."
echo "Run again to continue, or check: rtk git log --oneline"
exit 1

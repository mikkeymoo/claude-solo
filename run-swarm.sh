#!/usr/bin/env bash
# claude-solo swarm launcher
#
# Starts a Claude Code session configured for swarm-style parallel work
# with agent teams enabled and quality gate hooks active.
#
# Usage:
#   bash run-swarm.sh                          # Interactive swarm session
#   bash run-swarm.sh "implement auth module"  # Swarm with initial task
#   bash run-swarm.sh --teammates 5            # Specify team size hint
#   bash run-swarm.sh --gate                   # Enable stop gate (blocks premature shutdown)
#   bash run-swarm.sh --split                  # Force tmux split-pane mode
#   bash run-swarm.sh --agent swarm-lead       # Use swarm-lead as the main agent

set -euo pipefail

# Defaults
TASK=""
TEAMMATES=""
GATE=0
SPLIT_MODE=""
AGENT_FLAG=""
EXTRA_ARGS=()

# Parse arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
    --teammates)
      TEAMMATES="$2"
      shift 2
      ;;
    --gate)
      GATE=1
      shift
      ;;
    --split)
      SPLIT_MODE="--teammate-mode tmux"
      shift
      ;;
    --in-process)
      SPLIT_MODE="--teammate-mode in-process"
      shift
      ;;
    --agent)
      AGENT_FLAG="--agent $2"
      shift 2
      ;;
    --help|-h)
      echo "claude-solo swarm launcher"
      echo ""
      echo "Usage:"
      echo "  bash run-swarm.sh                          # Interactive swarm"
      echo "  bash run-swarm.sh \"task description\"        # Swarm with task"
      echo "  bash run-swarm.sh --teammates 5            # Team size hint"
      echo "  bash run-swarm.sh --gate                   # Enable stop gate"
      echo "  bash run-swarm.sh --split                  # tmux split panes"
      echo "  bash run-swarm.sh --agent swarm-lead       # Use specific agent"
      echo ""
      echo "Options:"
      echo "  --teammates N    Suggest N teammates in the prompt"
      echo "  --gate           Block lead from stopping until all tasks done"
      echo "  --split          Force tmux split-pane mode"
      echo "  --in-process     Force in-process mode (no tmux)"
      echo "  --agent NAME     Use a specific agent as the main session"
      echo "  --help           Show this help"
      echo ""
      echo "Environment:"
      echo "  CLAUDE_SOLO_SWARM_GATE=1   Enable stop gate (same as --gate)"
      exit 0
      ;;
    -*)
      EXTRA_ARGS+=("$1")
      shift
      ;;
    *)
      TASK="$1"
      shift
      ;;
  esac
done

# Ensure agent teams are enabled
export CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1
export CLAUDE_SOLO_SWARM_GATE="${GATE}"

# Build the prompt
PROMPT=""
if [[ -n "$TASK" ]]; then
  PROMPT="$TASK"

  # Add team size hint
  if [[ -n "$TEAMMATES" ]]; then
    PROMPT="${PROMPT}

Create an agent team with ${TEAMMATES} teammates to work on this."
  fi
fi

# Check for Claude Code
if ! command -v claude &>/dev/null; then
  echo "Error: 'claude' CLI not found. Install Claude Code first."
  echo "  npm install -g @anthropic-ai/claude-code"
  exit 1
fi

# Check for tmux if split mode requested
if [[ "$SPLIT_MODE" == *"tmux"* ]] && ! command -v tmux &>/dev/null; then
  echo "Warning: tmux not found. Falling back to in-process mode."
  SPLIT_MODE="--teammate-mode in-process"
fi

echo "========================================"
echo "  claude-solo swarm session"
echo "========================================"
echo "  Agent teams:  enabled"
echo "  Stop gate:    $([ "$GATE" = "1" ] && echo "ON" || echo "off")"
[[ -n "$SPLIT_MODE" ]] && echo "  Display:      ${SPLIT_MODE#--teammate-mode }"
[[ -n "$TEAMMATES" ]] && echo "  Teammates:    ~${TEAMMATES}"
[[ -n "$AGENT_FLAG" ]] && echo "  Agent:        ${AGENT_FLAG#--agent }"
echo "========================================"
echo ""

# Launch Claude Code
CMD="claude"
[[ -n "$SPLIT_MODE" ]] && CMD="$CMD $SPLIT_MODE"
[[ -n "$AGENT_FLAG" ]] && CMD="$CMD $AGENT_FLAG"
[[ ${#EXTRA_ARGS[@]} -gt 0 ]] && CMD="$CMD ${EXTRA_ARGS[*]}"

if [[ -n "$PROMPT" ]]; then
  CMD="$CMD -p \"$PROMPT\""
fi

eval "$CMD"

#!/usr/bin/env bash
# bootstrap-windows-encoding.sh — SessionStart hook (wired first)
# Ensures UTF-8 encoding is active for Python and Git Bash on Windows.
# Exports vars to $CLAUDE_ENV_FILE so they persist across Bash tool calls.
# Exit 0 always — never block session startup.

set -euo pipefail

# Only meaningful on Windows/Git Bash
if [[ "${MSYSTEM:-}" == "" && "${OSTYPE:-}" != msys* && "${OSTYPE:-}" != cygwin* ]]; then
  exit 0
fi

ENV_FILE="${CLAUDE_ENV_FILE:-}"

_export_var() {
  local key="$1" val="$2"
  # Set in current shell
  export "$key=$val"
  # Persist to Claude env file if available
  if [[ -n "$ENV_FILE" && -f "$ENV_FILE" ]]; then
    if ! grep -q "^${key}=" "$ENV_FILE" 2>/dev/null; then
      echo "${key}=${val}" >> "$ENV_FILE"
    fi
  fi
}

changed=0

if [[ "${PYTHONIOENCODING:-}" != "utf-8" ]]; then
  _export_var "PYTHONIOENCODING" "utf-8"
  changed=1
fi

if [[ "${PYTHONUTF8:-}" != "1" ]]; then
  _export_var "PYTHONUTF8" "1"
  changed=1
fi

if [[ $changed -eq 1 ]]; then
  echo "[bootstrap] Windows UTF-8 encoding active (PYTHONIOENCODING=utf-8, PYTHONUTF8=1)"
else
  echo "[bootstrap] Windows UTF-8 encoding already set"
fi

exit 0

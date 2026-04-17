#!/usr/bin/env bash
# notify-desktop.sh — cross-platform desktop notification for the Notification hook.
# Gated on notification_type to avoid alert fatigue.

set -euo pipefail
exec 2>/dev/null

INPUT=$(cat)
MSG=$(echo "$INPUT" | jq -r '.message // "Claude Code is waiting"')
TYPE=$(echo "$INPUT" | jq -r '.notification_type // ""')

# Only alert on events that actually need your attention — skip routine pings
case "$TYPE" in
  permission_prompt|idle_prompt|elicitation_dialog|"") ;;   # notify
  auth_success) exit 0 ;;                                    # don't notify
esac

UNAME=$(uname 2>/dev/null || echo unknown)

case "$UNAME" in
  Linux*)
    if command -v notify-send >/dev/null 2>&1; then
      notify-send --icon=dialog-information --expire-time=8000 "Claude Code" "$MSG" || true
    fi
    # Terminal bell fallback (always safe, no deps)
    printf '\a' >/dev/tty 2>/dev/null || true
    ;;
  Darwin*)
    if command -v osascript >/dev/null 2>&1; then
      osascript -e "display notification \"${MSG//\"/\\\"}\" with title \"Claude Code\" sound name \"Pop\"" || true
    fi
    ;;
  MINGW*|MSYS*|CYGWIN*)
    # Windows via Git Bash / MSYS: fall back to msg.exe or terminal bell
    if command -v powershell.exe >/dev/null 2>&1; then
      powershell.exe -NoProfile -Command "\$wshell = New-Object -ComObject Wscript.Shell; \$wshell.Popup('${MSG//\'/\'\'}', 0, 'Claude Code', 64) | Out-Null" 2>/dev/null &
    fi
    printf '\a' >/dev/tty 2>/dev/null || true
    ;;
  *)
    printf '\a' >/dev/tty 2>/dev/null || true
    ;;
esac

exit 0

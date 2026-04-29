#!/usr/bin/env bash
# notify-desktop.sh — Windows/Git Bash desktop notification for the Notification hook.
# Gated on notification_type to avoid alert fatigue.
# Strategy: BurntToast (Windows 10/11 toast) → Windows Forms balloon tip → terminal bell.

set -euo pipefail
exec 2>/dev/null

INPUT=$(cat)
MSG=$(echo "$INPUT" | jq -r '.message // "Claude Code is waiting"')
TYPE=$(echo "$INPUT" | jq -r '.notification_type // ""')

# Only alert on events that need attention — skip routine pings
case "$TYPE" in
  permission_prompt|idle_prompt|elicitation_dialog|"") ;;  # notify
  auth_success) exit 0 ;;                                   # skip
esac

# Sanitize message for PowerShell single-quoted string context.
# PS single-quoted strings are literal — only ' needs escaping ('' = escaped ').
# We also strip control characters that could corrupt the notification.
SAFE_MSG="${MSG//\'/\'\'}"                     # ' → '' (PS single-quote escape)
SAFE_MSG="${SAFE_MSG//$'\n'/ }"               # strip newlines
SAFE_MSG="${SAFE_MSG//$'\r'/ }"               # strip carriage returns
SAFE_MSG="${SAFE_MSG:0:200}"                  # cap length — balloon tips truncate anyway

# Prefer pwsh (PowerShell 7+) over legacy powershell.exe; both are checked.
PS_EXE=""
command -v pwsh         >/dev/null 2>&1 && PS_EXE="pwsh"
command -v pwsh.exe     >/dev/null 2>&1 && PS_EXE="pwsh.exe"
[[ -z "$PS_EXE" ]] && command -v powershell.exe >/dev/null 2>&1 && PS_EXE="powershell.exe"

if [[ -n "$PS_EXE" ]]; then
  # Cache BurntToast availability so we don't cold-start PowerShell on every notification.
  # The cache is invalidated by deleting ~/.cache/claude-burnttoast-check manually.
  BT_CACHE="${HOME}/.cache/claude-burnttoast-check"
  if [[ ! -f "$BT_CACHE" ]]; then
    mkdir -p "$(dirname "$BT_CACHE")" 2>/dev/null || true
    if "$PS_EXE" -NoProfile -Command \
        "Get-Module -ListAvailable BurntToast -ErrorAction SilentlyContinue | Select-Object -First 1" \
        2>/dev/null | grep -q "BurntToast"; then
      echo "1" > "$BT_CACHE"
    else
      echo "0" > "$BT_CACHE"
    fi
  fi
  BURNTTOAST_AVAILABLE=$(cat "$BT_CACHE" 2>/dev/null || echo "0")

  if [[ "$BURNTTOAST_AVAILABLE" == "1" ]]; then
    # BurntToast: native Windows 10/11 toast notification with action support.
    # Install with: Install-Module BurntToast -Scope CurrentUser
    "$PS_EXE" -NoProfile -WindowStyle Hidden -Command \
      "Import-Module BurntToast; New-BurntToastNotification -Text 'Claude Code','${SAFE_MSG}'" \
      2>/dev/null &
  else
    # Fallback 1: MessageBox.Show (modal, no extra modules, Windows Forms).
    # Uses non-blocking background job via Start-Process to avoid locking the shell.
    "$PS_EXE" -NoProfile -WindowStyle Hidden -Command "
      Add-Type -AssemblyName System.Windows.Forms;
      [System.Windows.Forms.MessageBox]::Show('${SAFE_MSG}','Claude Code',[System.Windows.Forms.MessageBoxButtons]::OK,[System.Windows.Forms.MessageBoxIcon]::Information) | Out-Null" \
      2>/dev/null &
  fi
fi

# Terminal bell — always fires as final fallback
printf '\a' >/dev/tty 2>/dev/null || true

exit 0

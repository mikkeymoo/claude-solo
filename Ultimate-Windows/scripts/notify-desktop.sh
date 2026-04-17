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

if command -v powershell.exe >/dev/null 2>&1; then
  # Cache BurntToast availability so we don't cold-start PowerShell on every notification.
  # The cache is invalidated by deleting ~/.cache/claude-burnttoast-check manually.
  BT_CACHE="${HOME}/.cache/claude-burnttoast-check"
  if [[ ! -f "$BT_CACHE" ]]; then
    mkdir -p "$(dirname "$BT_CACHE")" 2>/dev/null || true
    if powershell.exe -NoProfile -Command \
        "Get-Module -ListAvailable BurntToast -ErrorAction SilentlyContinue | Select-Object -First 1" \
        2>/dev/null | grep -q "BurntToast"; then
      echo "1" > "$BT_CACHE"
    else
      echo "0" > "$BT_CACHE"
    fi
  fi
  BURNTTOAST_AVAILABLE=$(cat "$BT_CACHE" 2>/dev/null || echo "0")

  if [[ "$BURNTTOAST_AVAILABLE" == "1" ]]; then
    # BurntToast: proper Windows 10/11 toast notification.
    # Install with: Install-Module BurntToast -Scope CurrentUser
    powershell.exe -NoProfile -WindowStyle Hidden -Command \
      "Import-Module BurntToast; New-BurntToastNotification -Text 'Claude Code','${SAFE_MSG}'" \
      2>/dev/null &
  else
    # Fallback: Windows Forms balloon tip (no extra modules needed).
    powershell.exe -NoProfile -WindowStyle Hidden -Command "
      Add-Type -AssemblyName System.Windows.Forms;
      Add-Type -AssemblyName System.Drawing;
      \$n = New-Object System.Windows.Forms.NotifyIcon;
      \$n.Icon = [System.Drawing.SystemIcons]::Information;
      \$n.BalloonTipTitle = 'Claude Code';
      \$n.BalloonTipText = '${SAFE_MSG}';
      \$n.Visible = \$true;
      \$n.ShowBalloonTip(8000);
      Start-Sleep -Milliseconds 9000;
      \$n.Dispose()" 2>/dev/null &
  fi
fi

# Terminal bell — always fires as final fallback
printf '\a' >/dev/tty 2>/dev/null || true

exit 0

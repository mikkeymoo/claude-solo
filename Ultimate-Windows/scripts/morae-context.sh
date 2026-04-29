#!/usr/bin/env bash
# morae-context.sh — SessionStart hook (last in chain)
# Injects Morae/eDiscovery environment reminders when CWD matches known project patterns.
# No-op silently when CWD does not match. Exit 0 always.

set -euo pipefail

cwd="${PWD:-$(pwd)}"

# Pattern match against known Morae project directories (case-insensitive)
is_morae=0
morae_patterns=(
  '[Mm]orae'
  '[Rr]elativity'
  '[Uu][Bb][Ss]'
  '[Pp]rudential'
  '[Ee][Dd]iscovery'
  '[Nn]uix'
  '[Dd][Ii][Ss][Cc][Oo]'
  '[Ee]verlaw'
)

for pat in "${morae_patterns[@]}"; do
  if [[ "$cwd" == *${pat}* ]]; then
    is_morae=1
    break
  fi
done

[[ $is_morae -eq 0 ]] && exit 0

echo "[morae] eDiscovery context active"
echo "  Environments: Zurich, US, dev.morae.global"
echo "  REMINDER: Custom Pages DLL version conflicts -- pin to platform-specific version before building"
echo "  REMINDER: RabbitMQ is pinned -- do NOT upgrade with package manager"
echo "  REMINDER: Relativity SQL -- use parameterized queries via Invoke-Sqlcmd, not string interpolation"
echo "  REMINDER: PBIP files use UTF-8; avoid BOM in Power BI theme JSON"

exit 0

#!/usr/bin/env bash
# morae-powerbi-validate.sh — PostToolUse hook for Edit|Write|MultiEdit
# Validates PBIP/PBIR/TMDL/JSON files against Morae brand palette and JSON validity.
# Only active when MORAE_POWERBI_VALIDATION=1 env var is set.
# Exit 0 always — advisory warnings only.

set -euo pipefail

# Gate on env var
[[ "${MORAE_POWERBI_VALIDATION:-0}" != "1" ]] && exit 0

input="$(cat)"

# Extract file path from tool input
file_path="$(printf '%s' "$input" | jq -r '.tool_input.file_path // .tool_input.path // ""' 2>/dev/null || true)"
[[ -z "$file_path" ]] && exit 0

# Only act on PBIP/PBIR/TMDL/JSON files
case "$file_path" in
  *.pbip|*.pbir|*.tmdl) ;;
  *.json)
    # Only act on Power BI-related JSON (theme files, report config, etc.)
    if ! printf '%s' "$file_path" | grep -qiE '(pbip|pbir|powerbi|theme|report|model)'; then
      exit 0
    fi
    ;;
  *) exit 0 ;;
esac

issues=()

# 1. Validate JSON parses cleanly (for .json, .pbip, .pbir)
case "$file_path" in
  *.json|*.pbip|*.pbir)
    if [[ -f "$file_path" ]]; then
      if ! jq empty "$file_path" 2>/dev/null; then
        issues+=("JSON parse error in $file_path — file is not valid JSON after edit")
      fi
    fi
    ;;
esac

# 2. Check theme references against Morae brand palette
# Morae brand: Orange #FF6900, Off-White #EDE5DE, IBM Plex Sans
# Detect hardcoded colors that drift from approved palette
if [[ -f "$file_path" ]]; then
  # Look for hex colors in the file
  bad_colors=$(grep -oiP '#[0-9A-F]{6}' "$file_path" 2>/dev/null | tr '[:lower:]' '[:upper:]' | sort -u | grep -vE '^#(FF6900|EDE5DE|FFFFFF|000000|F5F5F5|333333|666666|999999|CCCCCC|E8E0D8|D4C9BE|C0AFA4)$' || true)

  if [[ -n "$bad_colors" ]]; then
    color_list=$(printf '%s' "$bad_colors" | tr '\n' ',' | sed 's/,$//')
    issues+=("[brand] Unrecognized colors in Power BI file: $color_list  |  Morae palette: #FF6900 (orange), #EDE5DE (off-white), plus neutrals")
  fi
fi

# Output warnings
if [[ ${#issues[@]} -gt 0 ]]; then
  echo "[morae-powerbi]"
  for issue in "${issues[@]}"; do
    echo "  WARN: $issue"
  done
fi

exit 0

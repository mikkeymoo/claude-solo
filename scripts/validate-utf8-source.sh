#!/usr/bin/env bash
# validate-utf8-source.sh — PreToolUse hook for Edit|Write|MultiEdit
# Detects mojibake byte sequences in content about to be written.
# Blocks (exit 2) if mojibake found; passes (exit 0) if clean.
# Also warns (exit 0) on UTF-8 BOM but does not block.

set -euo pipefail

# Read the tool input JSON from stdin
input="$(cat)"

# Extract content fields — check new_string (Edit) and content (Write/MultiEdit)
new_string="$(printf '%s' "$input" | jq -r '.tool_input.new_string // ""' 2>/dev/null || true)"
content="$(printf '%s' "$input" | jq -r '.tool_input.content // ""' 2>/dev/null || true)"

check_text="$new_string$content"

[[ -z "$check_text" ]] && exit 0

# Mojibake detection patterns (UTF-8 read as cp1252 then re-encoded to UTF-8)
# These are the most common Windows codec corruption signatures
mojibake_patterns=(
  'â€"'    # em dash  (U+2014) corrupted
  'â€™'    # right single quote (U+2019) corrupted
  'â€œ'    # left double quote (U+201C) corrupted
  'â€'     # partial em dash corruption
  'Â '     # non-breaking space corruption
  'Ã©'     # é corrupted
  'Ã¨'     # è corrupted
  'Ã '     # à corrupted
  'Ã¢'     # â corrupted
  'Ã®'     # î corrupted
  'Ã´'     # ô corrupted
  'Ã»'     # û corrupted
  'Ã§'     # ç corrupted
)

for pat in "${mojibake_patterns[@]}"; do
  if printf '%s' "$check_text" | grep -qF "$pat" 2>/dev/null; then
    printf '{"decision":"block","reason":"Content contains mojibake sequence '\''%s'\'' — text was likely misencoded (UTF-8 read as cp1252). Re-source the content as UTF-8 before writing. Common fix: set PYTHONIOENCODING=utf-8 or open the source file in an editor that can detect encoding and re-save as UTF-8."}\n' "$pat"
    exit 2
  fi
done

# Check for sequences of 3+ replacement characters near alphanumerics
# (dropped chars indicate encoding mismatch)
if printf '%s' "$check_text" | grep -qP '\w[?]{3,}\w' 2>/dev/null; then
  printf '{"decision":"block","reason":"Content contains 3+ consecutive replacement characters (???) adjacent to word characters — this indicates dropped Unicode codepoints from a codec mismatch. Re-source the content as UTF-8."}\n'
  exit 2
fi

# BOM detection — warn but do not block
# UTF-8 BOM is EF BB BF; in bash string it appears as the three-byte sequence
if printf '%s' "$check_text" | LC_ALL=C grep -qP '^\xEF\xBB\xBF' 2>/dev/null; then
  printf '{"decision":"approve","reason":"[warn] Content starts with a UTF-8 BOM (\\xEF\\xBB\\xBF). Some Windows tools require BOM; others break on it. Proceeding — remove BOM if this causes issues."}\n'
  exit 0
fi

exit 0

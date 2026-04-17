#!/usr/bin/env bash
# post-format-and-heal.sh — PostToolUse hook for Edit|Write|MultiEdit.
#
# 1. Auto-format the edited file (prettier/black/ruff format/rustfmt/gofmt).
# 2. Run LSP-backed diagnostics (tsc/pyright/mypy/cargo check). These are the
#    same language servers cclsp exposes as MCP tools, invoked via CLI.
# 3. If diagnostics fail, emit a blocking response that feeds the errors back
#    to Claude as a new user turn — self-healing loop.
#
# Solo-developer tuned: runs aggressively (no team to coordinate with) but never
# edits code itself — only formats + reports. Formatters are idempotent and safe.

set -euo pipefail
exec 2>/dev/null

INPUT=$(cat)
FILE=$(echo "$INPUT" | jq -r '.tool_input.file_path // .tool_input.path // empty')

# No file path (e.g. MultiEdit dict form) → nothing to do
[[ -z "$FILE" ]] && exit 0
[[ ! -f "$FILE" ]] && exit 0

# Skip generated / vendored / large dirs
case "$FILE" in
  *node_modules/*|*/dist/*|*/build/*|*/target/*|*.min.js|*.min.css|*/.venv/*|*/__pycache__/*|*/vendor/*)
    exit 0 ;;
esac

ext="${FILE##*.}"
errors=""

# ---------------------------------------------------------------------------
# FORMATTERS — run first, non-blocking
# ---------------------------------------------------------------------------
case "$ext" in
  ts|tsx|js|jsx|mjs|cjs|json|md|css|scss|html|yaml|yml)
    if command -v prettier >/dev/null 2>&1; then
      prettier --write "$FILE" >/dev/null 2>&1 || true
    elif command -v pnpm >/dev/null 2>&1 && [[ -f package.json ]] && grep -q '"prettier"' package.json; then
      pnpm exec prettier --write "$FILE" >/dev/null 2>&1 || true
    fi
    if command -v biome >/dev/null 2>&1 && [[ -f biome.json ]]; then
      biome format --write "$FILE" >/dev/null 2>&1 || true
    fi
    ;;
  py)
    if command -v ruff >/dev/null 2>&1; then
      ruff format "$FILE" >/dev/null 2>&1 || true
      ruff check --fix "$FILE" >/dev/null 2>&1 || true
    elif command -v black >/dev/null 2>&1; then
      black -q "$FILE" 2>/dev/null || true
    fi
    ;;
  rs)
    command -v rustfmt >/dev/null 2>&1 && rustfmt "$FILE" 2>/dev/null || true
    ;;
  go)
    command -v gofmt >/dev/null 2>&1 && gofmt -w "$FILE" 2>/dev/null || true
    command -v goimports >/dev/null 2>&1 && goimports -w "$FILE" 2>/dev/null || true
    ;;
  sh|bash)
    command -v shfmt >/dev/null 2>&1 && shfmt -w "$FILE" 2>/dev/null || true
    ;;
esac

# ---------------------------------------------------------------------------
# LSP-BACKED DIAGNOSTICS — blocking when fails
# These invoke the same language servers cclsp uses, via CLI.
# ---------------------------------------------------------------------------
collect_error() {
  local label="$1" out="$2"
  errors="${errors}
### ${label}
${out}"
}

case "$ext" in
  ts|tsx)
    if [[ -f tsconfig.json ]] && command -v tsc >/dev/null 2>&1; then
      if ! out=$(tsc --noEmit --pretty false 2>&1 | grep -F "$(realpath "$FILE")" | head -30); then
        :
      fi
      if [[ -n "${out:-}" ]]; then
        collect_error "TypeScript ($FILE)" "$out"
      fi
    fi
    ;;
  py)
    if command -v pyright >/dev/null 2>&1; then
      if out=$(pyright --outputjson "$FILE" 2>/dev/null | jq -r '.generalDiagnostics[] | select(.severity=="error") | "\(.range.start.line + 1):\(.range.start.character + 1) — \(.message)"' 2>/dev/null | head -20); then
        if [[ -n "$out" ]]; then
          collect_error "Pyright ($FILE)" "$out"
        fi
      fi
    elif command -v mypy >/dev/null 2>&1; then
      out=$(mypy --no-color-output --no-error-summary "$FILE" 2>&1 | grep -E "^[^:]+:[0-9]+:" | head -20 || true)
      [[ -n "$out" ]] && collect_error "Mypy ($FILE)" "$out"
    fi
    if command -v ruff >/dev/null 2>&1; then
      out=$(ruff check --no-fix --output-format=concise "$FILE" 2>&1 | head -20 || true)
      [[ -n "$out" ]] && collect_error "Ruff ($FILE)" "$out"
    fi
    ;;
  rs)
    if [[ -f Cargo.toml ]] && command -v cargo >/dev/null 2>&1; then
      out=$(cargo check --message-format=short 2>&1 | grep -E "^error" | head -10 || true)
      [[ -n "$out" ]] && collect_error "Cargo check" "$out"
    fi
    ;;
  go)
    if command -v go >/dev/null 2>&1; then
      out=$(go vet "./$(dirname "$FILE")/..." 2>&1 | head -10 || true)
      [[ -n "$out" ]] && collect_error "go vet" "$out"
    fi
    ;;
esac

# ---------------------------------------------------------------------------
# Emit blocking feedback if there are errors.
# Use hookSpecificOutput.additionalContext so errors are injected into the
# model context (plain stdout from PostToolUse is not surfaced to Claude).
# ---------------------------------------------------------------------------
if [[ -n "$errors" ]]; then
  REASON=$(cat <<EOF
LSP diagnostics failed after your edit to ${FILE}. Fix these before the next tool call:
${errors}

Re-run the same tool once you've fixed the errors. If the diagnostic is wrong, say so explicitly in a reply rather than silently retrying.
EOF
)
  jq -nc --arg r "$REASON" '{decision:"block",reason:$r,hookSpecificOutput:{hookEventName:"PostToolUse",additionalContext:$r}}'
  exit 0
fi

# Silent success
exit 0

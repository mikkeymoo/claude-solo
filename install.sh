#!/usr/bin/env bash
# install.sh — claude-solo unified installer.
# Requires bash (Git Bash on Windows).
#
# Usage:
#   bash install.sh                     # install (merge mode, recommended)
#   bash install.sh --fresh             # replace existing config (backup taken)
#   bash install.sh --project           # add project override to CWD
#   bash install.sh --dry-run           # show what would happen, change nothing
#   bash install.sh --uninstall         # remove a prior claude-solo install
#   bash install.sh --verify            # check prerequisites only

set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
CLAUDE_HOME="${HOME}/.claude"
BACKUP_DIR="${CLAUDE_HOME}/.claude-solo-backup/$(date +%Y%m%d-%H%M%S)"
MANIFEST="${CLAUDE_HOME}/.claude-solo-manifest"

# ---------------------------------------------------------------------------
# Flags
# ---------------------------------------------------------------------------
MODE="merge"     # merge | fresh
DRY_RUN=0
UNINSTALL=0
VERIFY_ONLY=0
PROJECT_MODE=0
BACKUP=1
ASSUME_YES=0

# ---------------------------------------------------------------------------
# Output helpers
# ---------------------------------------------------------------------------
GREEN='\033[0;32m'; YELLOW='\033[0;33m'; RED='\033[0;31m'; CYAN='\033[0;36m'
BOLD='\033[1m'; NC='\033[0m'

say()  { printf "${CYAN}[install]${NC} %s\n" "$*"; }
ok()   { printf "${GREEN}  ✓${NC} %s\n" "$*"; }
warn() { printf "${YELLOW}  ⚠${NC} %s\n" "$*"; }
die()  { printf "${RED}  ✗${NC} %s\n" "$*" >&2; exit 1; }
hdr()  { printf "\n${BOLD}%s${NC}\n" "$*"; }

do_run() {
  if [[ $DRY_RUN -eq 1 ]]; then
    printf "  ${YELLOW}[dry-run]${NC} %s\n" "$*"
    return 0
  fi
  "$@"
}

dry_append() {
  local file="$1"; shift
  if [[ $DRY_RUN -eq 1 ]]; then
    printf "  ${YELLOW}[dry-run]${NC} append to %s via: %s\n" "$file" "$*"
    return 0
  fi
  "$@" >> "$file"
}

backup_path() {
  local path="$1"
  [[ $BACKUP -eq 0 ]] && return 0
  [[ ! -e "$path" ]] && return 0
  do_run mkdir -p "$BACKUP_DIR"
  local rel="${path#"$HOME"/}"
  do_run mkdir -p "$BACKUP_DIR/$(dirname "$rel")"
  do_run cp -a "$path" "$BACKUP_DIR/$rel"
  ok "Backed up $path"
}

# ---------------------------------------------------------------------------
# Parse args
# ---------------------------------------------------------------------------
while [[ $# -gt 0 ]]; do
  case "$1" in
    --fresh)      MODE="fresh"       ;;
    --yes|-y)     ASSUME_YES=1       ;;
    --project)    PROJECT_MODE=1     ;;
    --no-backup)  BACKUP=0           ;;
    --dry-run|-n) DRY_RUN=1          ;;
    --uninstall)  UNINSTALL=1        ;;
    --verify)     VERIFY_ONLY=1      ;;
    -h|--help)
      grep '^#' "$0" | head -8 | sed 's/^# \{0,1\}//'
      exit 0 ;;
    *) die "Unknown flag: $1  (run with --help for usage)" ;;
  esac
  shift
done

# ---------------------------------------------------------------------------
# Prerequisite checks
# ---------------------------------------------------------------------------
check_prereqs() {
  say "Checking prerequisites"
  local missing=()
  for bin in jq bash; do
    if command -v "$bin" >/dev/null 2>&1; then
      ok "$bin: $(command -v "$bin")"
    else
      missing+=("$bin")
    fi
  done
  if ! command -v claude >/dev/null 2>&1; then
    warn "claude not on PATH — install still proceeds but smoke test skipped"
  else
    ok "claude: $(claude --version 2>/dev/null | head -1 || echo 'version unknown')"
  fi
  if [[ ${#missing[@]} -gt 0 ]]; then
    die "Missing required tools: ${missing[*]}"
  fi
  for bin in gh ruff node; do
    command -v "$bin" >/dev/null 2>&1 || warn "$bin not on PATH (optional — some hook features will no-op)"
  done

  # Auto-install npm-based optional tools if npm is available
  local npm_missing=()
  for bin in prettier tsc pyright; do
    command -v "$bin" >/dev/null 2>&1 || npm_missing+=("$bin")
  done
  if [[ ${#npm_missing[@]} -gt 0 ]]; then
    if command -v npm >/dev/null 2>&1; then
      say "Auto-installing missing npm tools: ${npm_missing[*]}"
      local npm_pkgs=()
      for bin in "${npm_missing[@]}"; do
        [[ "$bin" == "tsc" ]] && npm_pkgs+=("typescript") || npm_pkgs+=("$bin")
      done
      if [[ $DRY_RUN -eq 1 ]]; then
        printf "  ${YELLOW}[dry-run]${NC} would run: npm install -g %s\n" "${npm_pkgs[*]}"
      else
        npm install -g "${npm_pkgs[@]}" && ok "Installed: ${npm_pkgs[*]}" || warn "npm install failed — install manually: npm install -g ${npm_pkgs[*]}"
      fi
    else
      for bin in "${npm_missing[@]}"; do
        warn "$bin not on PATH (optional — some hook features will no-op)"
      done
    fi
  fi

  # cache-fix-wrapper detection (advisory — CC v2.1.81+ cache TTL regression)
  if command -v cache-fix-wrapper >/dev/null 2>&1; then
    ok "cache-fix-wrapper detected: $(command -v cache-fix-wrapper)"
  else
    local cc_version=""
    cc_version=$(claude --version 2>/dev/null | head -1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1 || true)
    if [[ -n "$cc_version" ]]; then
      local major minor patch
      IFS='.' read -r major minor patch <<< "$cc_version"
      if (( major > 2 )) || (( major == 2 && minor > 1 )) || (( major == 2 && minor == 1 && patch >= 81 )); then
        warn "Claude Code v${cc_version} may suffer 4-20x cost increase on resumed sessions"
        warn "  due to 5m TTL cache regression. Consider installing:"
        warn "  https://github.com/cnighswonger/claude-code-cache-fix"
        warn "  See COST-OPTIMIZATION.md for details"
      fi
    fi
  fi

  # lean-ctx detection (optional token-saving layer)
  if command -v lean-ctx >/dev/null 2>&1; then
    ok "lean-ctx detected: $(command -v lean-ctx)"
  else
    warn "lean-ctx not found (optional) — install for ~13-token file re-reads: cargo install lean-ctx"
  fi
}

# ---------------------------------------------------------------------------
# Scripts install
# ---------------------------------------------------------------------------
install_scripts() {
  local src_dir="$1"
  local dst_dir="$2"
  say "Installing hook scripts → $dst_dir"
  if [[ -d "$dst_dir" ]]; then
    backup_path "$dst_dir"
    do_run rm -rf "$dst_dir"
  fi
  do_run mkdir -p "$dst_dir"
  shopt -s nullglob
  local count=0
  for f in "$src_dir/"*.sh; do
    do_run cp "$f" "$dst_dir/$(basename "$f")"
    do_run chmod +x "$dst_dir/$(basename "$f")"
    ok "Installed $(basename "$f")"
    (( count++ )) || true
  done
  # Also install any .ps1 scripts (Windows helpers)
  for f in "$src_dir/"*.ps1; do
    do_run cp "$f" "$dst_dir/$(basename "$f")"
    ok "Installed $(basename "$f")"
    (( count++ )) || true
  done
  shopt -u nullglob
  [[ $count -eq 0 ]] && warn "No scripts found in $src_dir" || true
}

# ---------------------------------------------------------------------------
# Manifest helper
# ---------------------------------------------------------------------------
_manifest_add() {
  local manifest="$1" rel_path="$2"
  [[ $DRY_RUN -eq 1 ]] && return 0
  echo "$rel_path" >> "$manifest"
}

# ---------------------------------------------------------------------------
# Agents install
# ---------------------------------------------------------------------------
install_agents() {
  local src_dir="$1"
  local manifest="$2"
  say "Installing agents → $CLAUDE_HOME/agents/"
  do_run mkdir -p "$CLAUDE_HOME/agents"
  [[ $DRY_RUN -eq 0 ]] && : > "$manifest"
  shopt -s nullglob
  local count=0
  for f in "$src_dir/"*.md; do
    local name; name=$(basename "$f" .md)
    # ult- prefix avoids collisions with user-managed agents in merge mode
    local target="$CLAUDE_HOME/agents/ult-${name}.md"
    [[ -f "$target" ]] && backup_path "$target"
    do_run cp "$f" "$target"
    do_run sed -i "s/^name: ${name}$/name: ult-${name}/" "$target"
    ok "Installed ult-$name.md"
    _manifest_add "$manifest" "agents/ult-${name}.md"
    (( count++ )) || true
  done
  shopt -u nullglob
  [[ $count -eq 0 ]] && warn "No agent .md files found in $src_dir" || true
}

# ---------------------------------------------------------------------------
# Skills install — top-level (~/.claude/skills/<name>/SKILL.md)
# ---------------------------------------------------------------------------
install_skills() {
  local src_dir="$1"
  local manifest="$2"
  say "Installing skills → $CLAUDE_HOME/skills/"
  do_run mkdir -p "$CLAUDE_HOME/skills"
  shopt -s nullglob
  local count=0
  for dir in "$src_dir/"*/; do
    local name; name=$(basename "$dir")
    local target="$CLAUDE_HOME/skills/$name"
    if [[ ! -f "$dir/SKILL.md" ]]; then
      warn "Skipping $name — no SKILL.md found"
      continue
    fi
    [[ -d "$target" ]] && backup_path "$target"
    do_run mkdir -p "$target"
    do_run cp "$dir/SKILL.md" "$target/SKILL.md"
    ok "Installed skill: $name"
    _manifest_add "$manifest" "skills/$name/SKILL.md"
    (( count++ )) || true
  done
  shopt -u nullglob
  [[ $count -eq 0 ]] && warn "No skill directories found in $src_dir" || true
}

# ---------------------------------------------------------------------------
# Commands install — top-level (~/.claude/commands/<name>.md)
# Preserves mm: namespace prefix in frontmatter (invoked as /mm:name).
# ---------------------------------------------------------------------------
install_commands() {
  local src_dir="$1"
  local manifest="$2"
  say "Installing commands → $CLAUDE_HOME/commands/"
  do_run mkdir -p "$CLAUDE_HOME/commands"
  shopt -s nullglob
  local count=0
  for f in "$src_dir/"*.md; do
    local base; base=$(basename "$f")
    local target="$CLAUDE_HOME/commands/$base"
    [[ -f "$target" ]] && backup_path "$target"
    do_run cp "$f" "$target"
    ok "Installed command: $base"
    _manifest_add "$manifest" "commands/$base"
    (( count++ )) || true
  done
  shopt -u nullglob
  [[ $count -eq 0 ]] && warn "No command .md files found in $src_dir" || true
}

# ---------------------------------------------------------------------------
# Rules install — ~/.claude/rules/<name>.md
# ---------------------------------------------------------------------------
install_rules() {
  local src_dir="$1"
  local manifest="$2"
  say "Installing rules → $CLAUDE_HOME/rules/"
  do_run mkdir -p "$CLAUDE_HOME/rules"
  shopt -s nullglob
  local count=0
  for f in "$src_dir/"*.md; do
    local base; base=$(basename "$f")
    local target="$CLAUDE_HOME/rules/$base"
    [[ -f "$target" ]] && backup_path "$target"
    do_run cp "$f" "$target"
    ok "Installed rule: $base"
    _manifest_add "$manifest" "rules/$base"
    (( count++ )) || true
  done
  shopt -u nullglob
  [[ $count -eq 0 ]] && warn "No rule .md files found in $src_dir" || true
}

# ---------------------------------------------------------------------------
# settings.json install
# ---------------------------------------------------------------------------
install_settings() {
  local src="$1"
  local target="$CLAUDE_HOME/settings.json"
  if [[ ! -f "$target" ]]; then
    say "No existing settings.json — writing"
    do_run cp "$src" "$target"
    ok "Wrote $target"
    return
  fi
  backup_path "$target"
  if [[ "$MODE" == "fresh" ]]; then
    warn "--fresh: overwriting existing settings.json (backup taken)"
    do_run cp "$src" "$target"
    ok "Overwrote $target"
    return
  fi
  say "Existing settings.json found — merge mode, NOT overwriting."
  say "Diff (yours → repo) — merge manually if needed:"
  diff -u "$target" "$src" | head -80 || true
  warn "Repo settings.json is at: $src"
}

# ---------------------------------------------------------------------------
# Purge prior claude-solo artifacts (fresh mode only)
# ---------------------------------------------------------------------------
purge_artifacts() {
  local manifest="$1"
  say "Purging prior claude-solo artifacts (fresh mode)"
  _manifest_uninstall "$manifest"

  # Legacy cleanup: prior installs used namespaced subdirs
  if [[ -d "$CLAUDE_HOME/skills/ult" ]]; then
    backup_path "$CLAUDE_HOME/skills/ult"
    do_run rm -rf "$CLAUDE_HOME/skills/ult"
    ok "Removed legacy skills/ult/"
  fi
  if [[ -d "$CLAUDE_HOME/commands/mm" ]]; then
    backup_path "$CLAUDE_HOME/commands/mm"
    do_run rm -rf "$CLAUDE_HOME/commands/mm"
    ok "Removed legacy commands/mm/"
  fi
  # Legacy variant script dirs
  for ns in ultimate ultimate-windows; do
    if [[ -d "$CLAUDE_HOME/$ns" ]]; then
      backup_path "$CLAUDE_HOME/$ns"
      do_run rm -rf "$CLAUDE_HOME/$ns"
      ok "Removed legacy ~/.claude/$ns/"
    fi
  done
}

# ---------------------------------------------------------------------------
# Remove every path listed in a manifest (paths relative to $CLAUDE_HOME)
# ---------------------------------------------------------------------------
_manifest_uninstall() {
  local manifest="$1"
  [[ ! -f "$manifest" ]] && return 0
  local removed_dirs=()
  while IFS= read -r rel; do
    [[ -z "$rel" ]] && continue
    local full="$CLAUDE_HOME/$rel"
    if [[ -e "$full" ]]; then
      do_run rm -f "$full"
      ok "Removed $rel"
      removed_dirs+=("$(dirname "$full")")
    fi
  done < "$manifest"
  local d
  for d in "${removed_dirs[@]}"; do
    if [[ -d "$d" ]] && [[ -z "$(ls -A "$d" 2>/dev/null)" ]]; then
      do_run rmdir "$d" 2>/dev/null || true
    fi
  done
  do_run rm -f "$manifest"
}

# ---------------------------------------------------------------------------
# Ensure all hooks are wired in settings.json.
# Uses jq to surgically add missing entries without touching user-managed keys.
# ---------------------------------------------------------------------------
ensure_hooks_wired() {
  local scripts_dir="$1"
  local target="$CLAUDE_HOME/settings.json"
  [[ ! -f "$target" ]] && return
  if [[ $DRY_RUN -eq 1 ]]; then
    printf "  ${YELLOW}[dry-run]${NC} would patch settings.json to wire claude-solo hooks\n"
    return
  fi
  say "Ensuring claude-solo hooks are wired in settings.json"

  _wire_hook() {
    local event="$1" check_str="$2" entry="$3"
    if ! jq -e "(.hooks.${event} // [])[] | .hooks[]? | select(.command | contains(\"${check_str}\"))" "$target" >/dev/null 2>&1; then
      jq ".hooks.${event} = ([${entry}] + (.hooks.${event} // []))" "$target" > "$target.tmp" && mv "$target.tmp" "$target"
      ok "Wired ${check_str} into ${event}"
    else
      ok "${check_str} already wired in ${event}"
    fi
  }

  # PostToolUse
  _wire_hook "PostToolUse" \
    "post-format-and-heal" \
    '{"matcher":"Edit|Write|MultiEdit","hooks":[{"type":"command","command":"bash ~/.claude/scripts/post-format-and-heal.sh","timeout":60000}]}'

  _wire_hook "PostToolUse" \
    "compress-lsp-output" \
    '{"matcher":"mcp__serena__.*","hooks":[{"type":"command","command":"bash ~/.claude/scripts/compress-lsp-output.sh","timeout":5000}]}'

  _wire_hook "PostToolUse" \
    "morae-powerbi-validate" \
    '{"matcher":"Edit|Write|MultiEdit","hooks":[{"type":"command","command":"bash ~/.claude/scripts/morae-powerbi-validate.sh","timeout":10000}]}'

  # SessionStart
  _wire_hook "SessionStart" \
    "bootstrap-windows-encoding" \
    '{"hooks":[{"type":"command","command":"bash ~/.claude/scripts/bootstrap-windows-encoding.sh","statusMessage":"Bootstrapping Windows UTF-8 encoding...","timeout":5000}]}'

  _wire_hook "SessionStart" \
    "cost-summary" \
    '{"hooks":[{"type":"command","command":"bash ~/.claude/scripts/cost-summary.sh","statusMessage":"Summarizing today'"'"'s token usage...","timeout":10000}]}'

  _wire_hook "SessionStart" \
    "quota-warmup-warn" \
    '{"hooks":[{"type":"command","command":"bash ~/.claude/scripts/quota-warmup-warn.sh","statusMessage":"Checking quota window...","timeout":10000}]}'

  _wire_hook "SessionStart" \
    "session-hud" \
    '{"hooks":[{"type":"command","command":"bash ~/.claude/scripts/session-hud.sh","statusMessage":"Loading session HUD...","timeout":10000}]}'

  _wire_hook "SessionStart" \
    "session-start-context" \
    '{"hooks":[{"type":"command","command":"bash ~/.claude/scripts/session-start-context.sh","statusMessage":"Loading git + sprint context...","timeout":10000}]}'

  _wire_hook "SessionStart" \
    "morae-context" \
    '{"hooks":[{"type":"command","command":"bash ~/.claude/scripts/morae-context.sh","statusMessage":"Checking project context...","timeout":5000}]}'

  _wire_hook "SessionStart" \
    "update-check" \
    '{"hooks":[{"type":"command","command":"bash ~/.claude/scripts/update-check.sh","statusMessage":"Checking for updates...","timeout":15000}]}'

  # PreCompact
  _wire_hook "PreCompact" \
    "pre-compact-checkpoint" \
    '{"hooks":[{"type":"command","command":"bash ~/.claude/scripts/pre-compact-checkpoint.sh","statusMessage":"Saving checkpoint before compaction..."}]}'

  # PreToolUse
  _wire_hook "PreToolUse" \
    "validate-readonly-query" \
    '{"matcher":"Bash","hooks":[{"type":"command","command":"bash ~/.claude/scripts/validate-readonly-query.sh"}]}'

  _wire_hook "PreToolUse" \
    "validate-utf8-source" \
    '{"matcher":"Edit|Write|MultiEdit","hooks":[{"type":"command","command":"bash ~/.claude/scripts/validate-utf8-source.sh"}]}'

  _wire_hook "PreToolUse" \
    "enforce-lsp-navigation" \
    '{"matcher":"Grep|Glob","hooks":[{"type":"command","command":"bash ~/.claude/scripts/enforce-lsp-navigation.sh"}]}'

  # Notification
  _wire_hook "Notification" \
    "notify-desktop" \
    '{"hooks":[{"type":"command","command":"bash ~/.claude/scripts/notify-desktop.sh"}]}'
}

# ---------------------------------------------------------------------------
# CLAUDE.md install
# ---------------------------------------------------------------------------
install_claude_md() {
  local src="$1"
  local target="$CLAUDE_HOME/CLAUDE.md"
  local marker_start="<!-- claude-solo:start -->"
  local marker_end="<!-- claude-solo:end -->"

  if [[ -f "$target" ]] && grep -Fq "$marker_start" "$target"; then
    ok "CLAUDE.md already has claude-solo block — skipping"
    return
  fi

  if [[ "$MODE" == "fresh" ]]; then
    if [[ -f "$target" ]]; then
      backup_path "$target"
      warn "--fresh: replacing CLAUDE.md (backup taken)"
    fi
    do_run cp "$src" "$target"
    ok "Wrote $target"
    return
  fi

  # Merge mode: append a clearly-marked block
  [[ -f "$target" ]] && backup_path "$target"
  say "Appending claude-solo block to CLAUDE.md"
  if [[ $DRY_RUN -eq 1 ]]; then
    printf "  ${YELLOW}[dry-run]${NC} would append claude-solo block to %s\n" "$target"
    return
  fi
  {
    [[ -f "$target" ]] && echo ""
    echo "$marker_start"
    cat "$src"
    echo "$marker_end"
  } >> "$target"
  ok "Appended block to $target"
}

# ---------------------------------------------------------------------------
# Project override install
# ---------------------------------------------------------------------------
install_project_override() {
  local src_dir="$1"
  say "Installing project-override into: $PWD"
  if ! git rev-parse --git-dir >/dev/null 2>&1; then
    warn "Not inside a git repo — you probably want to run this inside a project"
  fi
  do_run mkdir -p .claude
  if [[ -f .claude/settings.json ]]; then
    backup_path "$PWD/.claude/settings.json"
    warn ".claude/settings.json exists — showing diff, not overwriting:"
    diff -u .claude/settings.json "$src_dir/settings.json" || true
    warn "Merge manually if you want these rules."
  else
    do_run cp "$src_dir/settings.json" .claude/settings.json
    ok "Wrote .claude/settings.json"
  fi
  if [[ -f .gitignore ]]; then
    if grep -Fq ".claude/settings.local.json" .gitignore 2>/dev/null; then
      ok ".gitignore already has claude-solo entries"
    else
      backup_path "$PWD/.gitignore"
      dry_append .gitignore printf '\n# --- claude-solo additions ---\n'
      dry_append .gitignore cat "$REPO_DIR/gitignore-additions.txt"
      ok "Appended gitignore-additions.txt"
    fi
  else
    if [[ -f "$REPO_DIR/gitignore-additions.txt" ]]; then
      do_run cp "$REPO_DIR/gitignore-additions.txt" .gitignore
      ok "Wrote .gitignore"
    fi
  fi
  say "Project install complete."
}

# ---------------------------------------------------------------------------
# Smoke test
# ---------------------------------------------------------------------------
smoke_test() {
  local scripts_dir="$1"
  if [[ $DRY_RUN -eq 1 ]]; then
    say "[dry-run] skipping smoke test — nothing was installed"
    return
  fi
  say "Running smoke checks"
  local settings="$CLAUDE_HOME/settings.json"
  local smoke_ok=1

  # 1. settings.json JSON validity
  if jq empty "$settings" 2>/dev/null; then
    ok "settings.json parses as valid JSON"
  else
    warn "settings.json does NOT parse as valid JSON — fix before use"
    smoke_ok=0
  fi

  # 2. Encoding check — validate settings.json is valid UTF-8
  if [[ -f "$settings" ]]; then
    if command -v iconv >/dev/null 2>&1; then
      if iconv -f UTF-8 -t UTF-8 "$settings" >/dev/null 2>&1; then
        ok "settings.json encoding looks clean (UTF-8 valid)"
      else
        warn "settings.json contains non-UTF-8 bytes — re-run scripts/Setup-WindowsEncoding.ps1"
        smoke_ok=0
      fi
    else
      ok "settings.json encoding check skipped (iconv not available)"
    fi
  fi

  # 3. Hook scripts executable count
  local n=0
  shopt -s nullglob
  for f in "$scripts_dir/"*.sh; do
    [[ -x "$f" ]] && (( n++ )) || true
  done
  shopt -u nullglob
  ok "Hook scripts executable: $n"

  # 4. Verify critical hooks are wired in settings.json
  local expected_hooks=(
    "bootstrap-windows-encoding"
    "cost-summary"
    "quota-warmup-warn"
    "session-hud"
    "session-start-context"
    "morae-context"
    "update-check"
    "post-format-and-heal"
    "compress-lsp-output"
    "validate-readonly-query"
    "validate-utf8-source"
    "enforce-lsp-navigation"
    "pre-compact-checkpoint"
  )
  local wired=0 missing_hooks=()
  for hook in "${expected_hooks[@]}"; do
    if jq -e ".. | strings | select(contains(\"${hook}\"))" "$settings" >/dev/null 2>&1; then
      (( wired++ )) || true
    else
      missing_hooks+=("$hook")
    fi
  done
  ok "Hooks wired in settings.json: $wired/${#expected_hooks[@]}"
  if [[ ${#missing_hooks[@]} -gt 0 ]]; then
    warn "Missing hooks (run installer to fix): ${missing_hooks[*]}"
    smoke_ok=0
  fi

  # 5. Hook syntax check — bash -n validates without executing (avoids stdin hangs)
  local syntax_pass=0 syntax_fail=0
  shopt -s nullglob
  for f in "$scripts_dir/"*.sh; do
    local base; base=$(basename "$f")
    if bash -n "$f" 2>/dev/null; then
      (( syntax_pass++ )) || true
    else
      warn "$base: syntax error (bash -n failed)"
      (( syntax_fail++ )) || true
    fi
  done
  shopt -u nullglob
  if [[ $syntax_fail -gt 0 ]]; then
    warn "Hook syntax errors: $syntax_fail script(s) failed bash -n"
    smoke_ok=0
  else
    ok "Hook syntax check: $syntax_pass scripts OK"
  fi

  # 6. Agent count
  local agents; agents=$(ls "$CLAUDE_HOME/agents/"ult-*.md 2>/dev/null | wc -l)
  ok "Agents installed (ult-*): $agents/5"

  # 7. Skills count
  local skills; skills=$(ls -d "$CLAUDE_HOME/skills/"*/ 2>/dev/null | wc -l)
  ok "Skills installed: $skills"

  # 8. Commands count
  local cmds; cmds=$(ls "$CLAUDE_HOME/commands/"*.md 2>/dev/null | wc -l)
  ok "Commands installed: $cmds"

  if [[ $smoke_ok -eq 1 ]]; then
    ok "All smoke checks passed"
  else
    warn "Some smoke checks failed — review warnings above before using"
  fi
}

# ---------------------------------------------------------------------------
# Uninstall
# ---------------------------------------------------------------------------
uninstall() {
  say "Uninstalling claude-solo"

  if [[ -f "$MANIFEST" ]]; then
    _manifest_uninstall "$MANIFEST"
    ok "Manifest cleared"
  else
    warn "No manifest at $MANIFEST — cannot safely identify files"
    warn "Manually remove ~/.claude/agents/ult-*.md, ~/.claude/scripts/, etc."
  fi

  # Remove scripts dir
  if [[ -d "$CLAUDE_HOME/scripts" ]]; then
    backup_path "$CLAUDE_HOME/scripts"
    do_run rm -rf "$CLAUDE_HOME/scripts"
    ok "Removed ~/.claude/scripts/"
  fi

  # Legacy variant dirs
  for ns in ultimate ultimate-windows; do
    [[ -d "$CLAUDE_HOME/$ns" ]] && { backup_path "$CLAUDE_HOME/$ns"; do_run rm -rf "$CLAUDE_HOME/$ns"; ok "Removed ~/.claude/$ns/"; }
  done

  local cm="$CLAUDE_HOME/CLAUDE.md"
  if [[ -f "$cm" ]] && grep -Fq "<!-- claude-solo:start -->" "$cm"; then
    backup_path "$cm"
    if [[ $DRY_RUN -eq 0 ]]; then
      sed -i '/<!-- claude-solo:start -->/,/<!-- claude-solo:end -->/d' "$cm"
      ok "Stripped claude-solo block from CLAUDE.md"
    else
      printf "  ${YELLOW}[dry-run]${NC} would strip claude-solo block from CLAUDE.md\n"
    fi
  fi

  say "Uninstall complete."
  say "NOTE: settings.json is NOT touched — remove hook entries manually from ~/.claude/settings.json."
  exit 0
}

# ---------------------------------------------------------------------------
# Main install
# ---------------------------------------------------------------------------
run_install() {
  local src_scripts="$REPO_DIR/scripts"
  local src_agents="$REPO_DIR/agents"
  local src_skills="$REPO_DIR/skills"
  local src_commands="$REPO_DIR/commands"
  local src_rules="$REPO_DIR/rules"
  local src_settings="$REPO_DIR/settings.json"
  local src_claude_md="$REPO_DIR/CLAUDE.md"
  local src_project_override="$REPO_DIR/project-override"
  local dst_scripts="$CLAUDE_HOME/scripts"

  for d in "$src_scripts" "$src_agents" "$src_skills" "$src_commands" "$src_rules"; do
    [[ ! -d "$d" ]] && die "Required directory not found: $d"
  done
  [[ ! -f "$src_settings" ]] && die "settings.json not found at $src_settings"
  [[ ! -f "$src_claude_md" ]] && die "CLAUDE.md not found at $src_claude_md"

  hdr "claude-solo install"
  say "Source:  $REPO_DIR"
  say "Target:  $CLAUDE_HOME"
  say "Mode:    $MODE$([[ $DRY_RUN -eq 1 ]] && echo ' (dry-run)')"
  say "Backup:  $([[ $BACKUP -eq 1 ]] && echo "$BACKUP_DIR" || echo 'DISABLED')"
  echo ""

  check_prereqs
  [[ $VERIFY_ONLY -eq 1 ]] && { say "Verify-only — exiting"; exit 0; }

  [[ $PROJECT_MODE -eq 1 ]] && { install_project_override "$src_project_override"; exit 0; }
  [[ $UNINSTALL -eq 1 ]] && { uninstall; exit 0; }

  [[ "$MODE" == "fresh" ]] && purge_artifacts "$MANIFEST"

  install_scripts  "$src_scripts"  "$dst_scripts"
  install_agents   "$src_agents"   "$MANIFEST"
  install_skills   "$src_skills"   "$MANIFEST"
  install_commands "$src_commands" "$MANIFEST"
  install_rules    "$src_rules"    "$MANIFEST"
  install_settings "$src_settings"
  ensure_hooks_wired "$dst_scripts"
  install_claude_md "$src_claude_md"

  # statusline.sh
  if [[ -f "$dst_scripts/statusline.sh" ]]; then
    [[ -f "$CLAUDE_HOME/statusline.sh" ]] && backup_path "$CLAUDE_HOME/statusline.sh"
    do_run cp "$dst_scripts/statusline.sh" "$CLAUDE_HOME/statusline.sh"
    do_run chmod +x "$CLAUDE_HOME/statusline.sh"
    ok "Installed statusline.sh → $CLAUDE_HOME/statusline.sh"
  fi

  # COST-OPTIMIZATION.md reference doc
  if [[ -f "$REPO_DIR/COST-OPTIMIZATION.md" ]]; then
    do_run cp "$REPO_DIR/COST-OPTIMIZATION.md" "$CLAUDE_HOME/COST-OPTIMIZATION.md"
    ok "Installed COST-OPTIMIZATION.md → $CLAUDE_HOME/"
  fi

  # Write installed version SHA (used by update-check.sh)
  if command -v git >/dev/null 2>&1 && [[ -d "$REPO_DIR/.git" ]]; then
    local installed_sha; installed_sha=$(git -C "$REPO_DIR" rev-parse HEAD 2>/dev/null || true)
    if [[ -n "$installed_sha" ]] && [[ $DRY_RUN -eq 0 ]]; then
      echo "$installed_sha" > "$CLAUDE_HOME/.claude-solo-version"
      ok "Wrote installed version: ${installed_sha:0:8}"
    fi
  fi

  echo ""
  smoke_test "$dst_scripts"
  echo ""
  say "Install complete."
  say "Start a fresh claude session and run /agents to confirm ult-code-reviewer, etc."
  say "Commands are invoked as /mm:name (e.g. /mm:brief, /mm:cost, /mm:hud)."
  [[ $BACKUP -eq 1 && $DRY_RUN -eq 0 ]] && say "Backups at: $BACKUP_DIR"
  echo ""
  say "Optional: BurntToast for Windows toast notifications:"
  say "  Run in PowerShell: Install-Module BurntToast -Scope CurrentUser"
  say "Optional: lean-ctx for file-read caching (~13 tokens/re-read):"
  say "  cargo install lean-ctx  (or: npm install -g lean-ctx-bin)"
}

# ---------------------------------------------------------------------------
# Entry point
# ---------------------------------------------------------------------------
run_install

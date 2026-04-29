#!/usr/bin/env bash
# install.sh — Unified installer for claude-solo configurations.
# Requires bash (Git Bash on Windows).
#
# Usage:
#   bash install.sh                     # interactive menu (recommended)
#   bash install.sh --original          # install Original (claude-solo classic)
#   bash install.sh --linux             # install Ultimate-Linux
#   bash install.sh --windows           # install Ultimate-Windows
#   bash install.sh --linux --fresh     # Ultimate-Linux, replace existing config
#   bash install.sh --windows --fresh   # Ultimate-Windows, replace existing config
#   bash install.sh --linux --project   # add Ultimate-Linux project override to CWD
#   bash install.sh --windows --project # add Ultimate-Windows project override to CWD
#   bash install.sh --dry-run           # show what would happen, change nothing
#   bash install.sh --uninstall         # remove an installed variant (interactive)
#   bash install.sh --uninstall --linux    # remove Ultimate-Linux directly
#   bash install.sh --uninstall --windows  # remove Ultimate-Windows directly
#   bash install.sh --verify            # check prerequisites only

set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
CLAUDE_HOME="${HOME}/.claude"
BACKUP_DIR="${CLAUDE_HOME}/.ultimate-backup/$(date +%Y%m%d-%H%M%S)"

# ---------------------------------------------------------------------------
# Flags
# ---------------------------------------------------------------------------
VARIANT=""       # original | linux | windows
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

# Execute a command, or print it in dry-run mode.
# Usage: do_run cmd arg1 arg2 ...  (NO string quoting — pass real args)
do_run() {
  if [[ $DRY_RUN -eq 1 ]]; then
    printf "  ${YELLOW}[dry-run]${NC} %s\n" "$*"
    return 0
  fi
  "$@"
}

# Append output of a command to a file, or print in dry-run mode.
# Usage: dry_append <file> <cmd> [args...]
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
    --original)   VARIANT="original" ;;
    --linux)      VARIANT="linux"    ;;
    --windows)    VARIANT="windows"  ;;
    --fresh)      MODE="fresh"       ;;
    --yes|-y)     ASSUME_YES=1       ;;
    --project)    PROJECT_MODE=1     ;;
    --no-backup)  BACKUP=0           ;;
    --dry-run|-n) DRY_RUN=1          ;;
    --uninstall)  UNINSTALL=1        ;;
    --verify)     VERIFY_ONLY=1      ;;
    -h|--help)
      grep '^#' "$0" | head -18 | sed 's/^# \{0,1\}//'
      exit 0 ;;
    *) die "Unknown flag: $1  (run with --help for usage)" ;;
  esac
  shift
done

# ---------------------------------------------------------------------------
# Interactive menu
# ---------------------------------------------------------------------------
interactive_menu() {
  hdr "claude-solo installer"
  echo ""
  printf "  Which variant would you like to install?\n\n"
  printf "    ${BOLD}[1]${NC} Original         — classic claude-solo setup\n"
  printf "    ${BOLD}[2]${NC} Ultimate-Linux   — enhanced build (Linux/macOS)\n"
  printf "    ${BOLD}[3]${NC} Ultimate-Windows — enhanced build (Windows/Git Bash)\n"
  printf "    ${BOLD}[q]${NC} Quit\n"
  echo ""
  printf "  Choice: "
  read -r choice

  case "$choice" in
    1) VARIANT="original" ;;
    2) VARIANT="linux"    ;;
    3) VARIANT="windows"  ;;
    q|Q) say "Exiting."; exit 0 ;;
    *) die "Invalid choice: $choice" ;;
  esac

  if [[ "$VARIANT" != "original" ]]; then
    echo ""
    printf "  Install mode?\n\n"
    printf "    ${BOLD}[1]${NC} Merge (default) — coexists with existing config, agents prefixed ult-\n"
    printf "    ${BOLD}[2]${NC} Fresh           — replaces existing config (backup taken automatically)\n"
    printf "    ${BOLD}[3]${NC} Project only    — add override to current directory's .claude/\n"
    echo ""
    printf "  Choice [1]: "
    read -r mode_choice

    case "${mode_choice:-1}" in
      1) MODE="merge"               ;;
      2) MODE="fresh"               ;;
      3) PROJECT_MODE=1; MODE="merge" ;;
      *) die "Invalid choice: $mode_choice" ;;
    esac
  fi
}

# ---------------------------------------------------------------------------
# Prerequisite checks
# ---------------------------------------------------------------------------
check_prereqs_ultimate() {
  local variant_label="$1"
  say "Checking prerequisites for ${variant_label}"
  local missing=()
  for bin in jq node bash; do
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
  for bin in gh ruff; do
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
      # tsc ships inside the 'typescript' package
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
    # Parse claude version to warn only on affected range
    local cc_version=""
    cc_version=$(claude --version 2>/dev/null | head -1 | grep -oP '\d+\.\d+\.\d+' | head -1 || true)
    if [[ -n "$cc_version" ]]; then
      local major minor patch
      IFS='.' read -r major minor patch <<< "$cc_version"
      # Affected: >= 2.1.81 (until ENABLE_PROMPT_CACHING_1H fix in v2.1.108)
      if (( major > 2 )) || (( major == 2 && minor > 1 )) || (( major == 2 && minor == 1 && patch >= 81 )); then
        warn "Claude Code v${cc_version} may suffer 4-20x cost increase on resumed sessions"
        warn "  due to 5m TTL cache regression. Consider installing:"
        warn "  https://github.com/cnighswonger/claude-code-cache-fix"
        warn "  See Ultimate-Windows/COST-OPTIMIZATION.md for details"
      fi
    fi
  fi

  # lean-ctx detection (optional token-saving layer)
  if command -v lean-ctx >/dev/null 2>&1; then
    ok "lean-ctx detected: $(command -v lean-ctx)"
  else
    warn "lean-ctx not found (optional) — install for ~13-token file re-reads: cargo install lean-ctx"
    warn "  See Ultimate-Windows/COST-OPTIMIZATION.md for lean-ctx + RTK integration notes"
  fi
}

check_prereqs_original() {
  say "Checking prerequisites for Original"
  command -v bash >/dev/null 2>&1 || die "bash not found"
  ok "bash: $(command -v bash)"
}

# ---------------------------------------------------------------------------
# Scripts install
# ---------------------------------------------------------------------------
install_scripts() {
  local src_dir="$1"
  local dst_dir="$2"
  say "Installing hook scripts → $dst_dir"
  # Backup and wipe destination so removed scripts don't persist across reinstalls
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
  shopt -u nullglob
  [[ $count -eq 0 ]] && warn "No .sh files found in $src_dir" || true
}

# ---------------------------------------------------------------------------
# Manifest helper — record an installed path (relative to CLAUDE_HOME)
# ---------------------------------------------------------------------------
_manifest_add() {
  local manifest="$1" rel_path="$2"
  [[ $DRY_RUN -eq 1 ]] && return 0
  echo "$rel_path" >> "$manifest"
}

# ---------------------------------------------------------------------------
# Agents install — writes a manifest for clean per-variant uninstall
# Manifest entries use paths relative to $CLAUDE_HOME (e.g. agents/ult-foo.md)
# ---------------------------------------------------------------------------
install_agents() {
  local src_dir="$1"
  local manifest="$2"
  say "Installing agents → $CLAUDE_HOME/agents/"
  do_run mkdir -p "$CLAUDE_HOME/agents"
  # Reset manifest for this install run
  [[ $DRY_RUN -eq 0 ]] && : > "$manifest"
  shopt -s nullglob
  local count=0
  for f in "$src_dir/"*.md; do
    local name; name=$(basename "$f" .md)
    # Always use ult- prefix to avoid collisions with user's own agents in both modes
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
# Skills install — top-level (~/.claude/skills/<name>/SKILL.md) so Claude Code
# discovers them. Nested subdirs (e.g. skills/ult/foo) are NOT auto-discovered.
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
# Commands install — top-level (~/.claude/commands/<name>.md). Strips any
# `mm:` namespace prefix from the frontmatter `name:` field so invocation
# matches filename (e.g. /brief, not /mm:brief).
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
    # Normalize frontmatter: drop mm: prefix from the name field if present
    do_run sed -i 's/^name: mm:\(.*\)$/name: \1/' "$target"
    ok "Installed command: $base"
    _manifest_add "$manifest" "commands/$base"
    (( count++ )) || true
  done
  shopt -u nullglob
  [[ $count -eq 0 ]] && warn "No command .md files found in $src_dir" || true
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
  say "Diff (yours → variant) — merge manually if needed:"
  diff -u "$target" "$src" | head -80 || true
  warn "Variant settings.json is at: $src"
}

# ---------------------------------------------------------------------------
# Purge prior Ultimate artifacts — called by fresh mode before reinstalling.
# Uses the per-variant manifest to remove ONLY what we previously installed,
# so user-managed agents/skills/commands alongside ours are left untouched.
# Legacy layouts (skills/ult/, commands/mm/) are also cleaned up opportunistically.
# Never touches hooks/, settings.json, CLAUDE.md, or env (handled separately).
# ---------------------------------------------------------------------------
purge_ult_artifacts() {
  local scripts_ns="$1"   # e.g. "ultimate-windows"
  local manifest="$2"     # full path to the manifest file
  say "Purging prior ${scripts_ns} artifacts (fresh mode)"

  _manifest_uninstall "$manifest"

  # Legacy cleanup: prior installer used namespaced subdirs. Remove them so
  # stale copies don't linger alongside the new top-level layout.
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

  # Scripts dir is handled by install_scripts (wipe+replace) — skip here
}

# ---------------------------------------------------------------------------
# Remove every path listed in a manifest (paths relative to $CLAUDE_HOME).
# After deleting files, rmdirs the containing directories if they're empty
# (handles skills/<name>/ which would otherwise be left as an empty dir).
# Safe to call with a missing manifest (no-op).
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
  # Clean up now-empty parent dirs (e.g. skills/<name>/ after removing SKILL.md)
  local d
  for d in "${removed_dirs[@]}"; do
    if [[ -d "$d" ]] && [[ -z "$(ls -A "$d" 2>/dev/null)" ]]; then
      do_run rmdir "$d" 2>/dev/null || true
    fi
  done
  do_run rm -f "$manifest"
}

# ---------------------------------------------------------------------------
# Ensure critical Ultimate-Windows hooks are wired in settings.json
# Runs after install_settings in both merge and fresh modes. Uses jq to
# surgically add missing hook entries without touching user-managed keys.
# ---------------------------------------------------------------------------
ensure_hooks_wired() {
  local scripts_dir="$1"
  local target="$CLAUDE_HOME/settings.json"
  [[ ! -f "$target" ]] && return
  if [[ $DRY_RUN -eq 1 ]]; then
    printf "  ${YELLOW}[dry-run]${NC} would patch settings.json to wire Ultimate-Windows hooks\n"
    return
  fi
  say "Ensuring Ultimate-Windows hooks are wired in settings.json"

  _wire_hook() {
    local event="$1" check_str="$2" entry="$3"
    if ! jq -e "(.hooks.${event} // [])[] | .hooks[]? | select(.command | contains(\"${check_str}\"))" "$target" >/dev/null 2>&1; then
      jq ".hooks.${event} = ([${entry}] + (.hooks.${event} // []))" "$target" > "$target.tmp" && mv "$target.tmp" "$target"
      ok "Wired ${check_str} into ${event}"
    else
      ok "${check_str} already wired in ${event}"
    fi
  }

  _wire_hook "PostToolUse" \
    "post-format-and-heal" \
    '{"matcher":"Edit|Write|MultiEdit","hooks":[{"type":"command","command":"bash ~/.claude/ultimate-windows/scripts/post-format-and-heal.sh","timeout":60000}]}'

  _wire_hook "PostToolUse" \
    "compress-lsp-output" \
    '{"matcher":"mcp__serena__.*","hooks":[{"type":"command","command":"bash ~/.claude/ultimate-windows/scripts/compress-lsp-output.sh","timeout":5000}]}'

  _wire_hook "PostToolUse" \
    "morae-powerbi-validate" \
    '{"matcher":"Edit|Write|MultiEdit","hooks":[{"type":"command","command":"bash ~/.claude/ultimate-windows/scripts/morae-powerbi-validate.sh","timeout":10000}]}'

  _wire_hook "SessionStart" \
    "bootstrap-windows-encoding" \
    '{"hooks":[{"type":"command","command":"bash ~/.claude/ultimate-windows/scripts/bootstrap-windows-encoding.sh","statusMessage":"Bootstrapping Windows UTF-8 encoding...","timeout":5000}]}'

  _wire_hook "SessionStart" \
    "cost-summary" \
    '{"hooks":[{"type":"command","command":"bash ~/.claude/ultimate-windows/scripts/cost-summary.sh","statusMessage":"Summarizing today'"'"'s token usage...","timeout":10000}]}'

  _wire_hook "SessionStart" \
    "quota-warmup-warn" \
    '{"hooks":[{"type":"command","command":"bash ~/.claude/ultimate-windows/scripts/quota-warmup-warn.sh","statusMessage":"Checking quota window...","timeout":10000}]}'

  _wire_hook "SessionStart" \
    "session-hud" \
    '{"hooks":[{"type":"command","command":"bash ~/.claude/ultimate-windows/scripts/session-hud.sh","statusMessage":"Loading session HUD...","timeout":10000}]}'

  _wire_hook "SessionStart" \
    "session-start-context" \
    '{"hooks":[{"type":"command","command":"bash ~/.claude/ultimate-windows/scripts/session-start-context.sh","statusMessage":"Loading git + sprint context...","timeout":10000}]}'

  _wire_hook "SessionStart" \
    "morae-context" \
    '{"hooks":[{"type":"command","command":"bash ~/.claude/ultimate-windows/scripts/morae-context.sh","statusMessage":"Checking project context...","timeout":5000}]}'

  _wire_hook "SessionStart" \
    "update-check" \
    '{"hooks":[{"type":"command","command":"bash ~/.claude/ultimate-windows/scripts/update-check.sh","statusMessage":"Checking for updates...","timeout":15000}]}'

  _wire_hook "PreCompact" \
    "pre-compact-checkpoint" \
    '{"hooks":[{"type":"command","command":"bash ~/.claude/ultimate-windows/scripts/pre-compact-checkpoint.sh","statusMessage":"Saving checkpoint before compaction..."}]}'

  _wire_hook "PreToolUse" \
    "validate-readonly-query" \
    '{"matcher":"Bash","hooks":[{"type":"command","command":"bash ~/.claude/ultimate-windows/scripts/validate-readonly-query.sh"}]}'

  _wire_hook "PreToolUse" \
    "validate-utf8-source" \
    '{"matcher":"Edit|Write|MultiEdit","hooks":[{"type":"command","command":"bash ~/.claude/ultimate-windows/scripts/validate-utf8-source.sh"}]}'

  _wire_hook "PreToolUse" \
    "enforce-lsp-navigation" \
    '{"matcher":"Grep|Glob","hooks":[{"type":"command","command":"bash ~/.claude/ultimate-windows/scripts/enforce-lsp-navigation.sh"}]}'
}

# ---------------------------------------------------------------------------
# CLAUDE.md install
# ---------------------------------------------------------------------------
install_claude_md() {
  local src="$1"
  local marker_start="$2"
  local marker_end="$3"
  local target="$CLAUDE_HOME/CLAUDE.md"

  if [[ -f "$target" ]] && grep -Fq "$marker_start" "$target"; then
    ok "CLAUDE.md already has this variant's block — skipping"
    return
  fi

  if [[ "$MODE" == "fresh" ]]; then
    if [[ -f "$target" ]]; then
      backup_path "$target"
      warn "--fresh: replacing CLAUDE.md$([[ $DRY_RUN -eq 1 ]] && echo ' (dry-run — no actual backup yet)' || echo ' (backup taken)')"
    fi
    do_run cp "$src" "$target"
    ok "Wrote $target"
    return
  fi

  # Merge mode: append a clearly-marked block
  [[ -f "$target" ]] && backup_path "$target"
  say "Appending variant block to CLAUDE.md"
  if [[ $DRY_RUN -eq 1 ]]; then
    printf "  ${YELLOW}[dry-run]${NC} would append %s...%s block to %s\n" "$marker_start" "$marker_end" "$target"
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
  local variant_label="$2"
  say "Installing $variant_label project-override into: $PWD"
  if ! git rev-parse --git-dir >/dev/null 2>&1; then
    warn "Not inside a git repo — you probably want to run this inside a project"
  fi
  do_run mkdir -p .claude
  if [[ -f .claude/settings.json ]]; then
    backup_path "$PWD/.claude/settings.json"
    warn ".claude/settings.json exists — showing diff, not overwriting:"
    diff -u .claude/settings.json "$src_dir/project-override/settings.json" || true
    warn "Merge manually if you want these rules."
  else
    do_run cp "$src_dir/project-override/settings.json" .claude/settings.json
    ok "Wrote .claude/settings.json"
  fi
  if [[ -f .gitignore ]]; then
    if grep -Fq ".claude/settings.local.json" .gitignore 2>/dev/null; then
      ok ".gitignore already has ultimate entries"
    else
      backup_path "$PWD/.gitignore"
      dry_append .gitignore printf '\n# --- ultimate additions ---\n'
      dry_append .gitignore cat "$src_dir/gitignore-additions.txt"
      ok "Appended gitignore-additions.txt"
    fi
  else
    do_run cp "$src_dir/gitignore-additions.txt" .gitignore
    ok "Wrote .gitignore"
  fi
  say "Project install complete."
}

# ---------------------------------------------------------------------------
# Smoke test — skipped in dry-run (nothing was installed)
# ---------------------------------------------------------------------------
smoke_test_ultimate() {
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

  # 2. Mojibake detection in settings.json (_comment fields with ? where em-dashes should be)
  if [[ -f "$settings" ]]; then
    mojibake_hits=$(grep -oP 'â€"|â€™|Â |Ã©|Ã¨' "$settings" 2>/dev/null || true)
    comment_question=$(grep -oP '"_comment[^"]*":\s*"[^"]*[?]{2,}[^"]*"' "$settings" 2>/dev/null || true)
    if [[ -n "$mojibake_hits" ]]; then
      warn "settings.json contains mojibake sequences — re-run Setup-WindowsEncoding.ps1 to fix encoding"
      smoke_ok=0
    elif [[ -n "$comment_question" ]]; then
      warn "settings.json _comment fields contain multiple '?' — possible em-dash corruption"
      smoke_ok=0
    else
      ok "settings.json encoding looks clean (no mojibake detected)"
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

  # 5. Self-validation: run each hook with --smoke-test flag
  local self_test_pass=0 self_test_warn=0
  shopt -s nullglob
  for f in "$scripts_dir/"*.sh; do
    local base; base=$(basename "$f")
    if bash "$f" --smoke-test >/dev/null 2>&1; then
      (( self_test_pass++ )) || true
    else
      # Exit code 99 = "I don't support --smoke-test" — treat as warning not error
      local ec=$?
      if [[ $ec -eq 99 ]]; then
        (( self_test_warn++ )) || true
      else
        warn "$base: --smoke-test flag returned exit $ec"
      fi
    fi
  done
  shopt -u nullglob
  ok "Hook self-tests: $self_test_pass passed, $self_test_warn skipped (no --smoke-test support)"

  # 6. Agent count
  local agents; agents=$(ls "$CLAUDE_HOME/agents/"ult-*.md 2>/dev/null | wc -l)
  ok "Agents installed (ult-*): $agents/5"

  if [[ $smoke_ok -eq 1 ]]; then
    ok "All smoke checks passed"
  else
    warn "Some smoke checks failed — review warnings above before using"
  fi
}

# ---------------------------------------------------------------------------
# Uninstall — uses per-variant manifest to avoid clobbering the other variant
# ---------------------------------------------------------------------------
uninstall_interactive() {
  hdr "Uninstall"
  echo ""
  printf "  Which variant to uninstall?\n\n"
  printf "    ${BOLD}[1]${NC} Ultimate-Linux  \n"
  printf "    ${BOLD}[2]${NC} Ultimate-Windows\n"
  printf "    ${BOLD}[q]${NC} Quit\n"
  echo ""
  printf "  Choice: "
  read -r uchoice
  case "$uchoice" in
    1) _uninstall_ultimate "ultimate"         "<!-- ultimate:start -->"         "<!-- ultimate:end -->"         ;;
    2) _uninstall_ultimate "ultimate-windows" "<!-- ultimate-windows:start -->" "<!-- ultimate-windows:end -->" ;;
    q|Q) say "Exiting."; exit 0 ;;
    *) die "Invalid choice" ;;
  esac
}

_uninstall_ultimate() {
  local scripts_ns="$1"
  local marker_start="$2"
  local marker_end="$3"
  local manifest="$CLAUDE_HOME/.${scripts_ns}-manifest"

  say "Uninstalling $scripts_ns"

  if [[ -f "$manifest" ]]; then
    _manifest_uninstall "$manifest"
    ok "Manifest cleared"
  else
    warn "No manifest at $manifest — cannot safely identify files belonging to this variant"
    warn "Manually remove $CLAUDE_HOME/agents/ult-*.md and related commands/skills if needed"
  fi

  # Legacy cleanup (older installs used subdir namespaces)
  [[ -d "$CLAUDE_HOME/skills/ult" ]] && { do_run rm -rf "$CLAUDE_HOME/skills/ult"; ok "Removed legacy skills/ult/"; }
  [[ -d "$CLAUDE_HOME/commands/mm" ]] && { do_run rm -rf "$CLAUDE_HOME/commands/mm"; ok "Removed legacy commands/mm/"; }
  [[ -d "$CLAUDE_HOME/$scripts_ns" ]] && { do_run rm -rf "$CLAUDE_HOME/$scripts_ns"; ok "Removed ~/.claude/$scripts_ns/"; }

  local cm="$CLAUDE_HOME/CLAUDE.md"
  if [[ -f "$cm" ]] && grep -Fq "$marker_start" "$cm"; then
    backup_path "$cm"
    if [[ $DRY_RUN -eq 0 ]]; then
      sed -i "/${marker_start//\//\\/}/,/${marker_end//\//\\/}/d" "$cm"
      ok "Stripped variant block from CLAUDE.md"
    else
      printf "  ${YELLOW}[dry-run]${NC} would strip %s block from CLAUDE.md\n" "$scripts_ns"
    fi
  fi

  say "Uninstall complete."
  say "NOTE: settings.json is NOT touched — remove the hook entries manually from ~/.claude/settings.json."
  exit 0
}

# ---------------------------------------------------------------------------
# Install: Original
# ---------------------------------------------------------------------------
run_original() {
  local src="$REPO_DIR/Original"
  [[ ! -d "$src" ]] && die "Original/ directory not found in $REPO_DIR"
  check_prereqs_original
  [[ $VERIFY_ONLY -eq 1 ]] && { say "Verify-only — exiting"; exit 0; }
  [[ $UNINSTALL -eq 1 ]] && die "Original has no automated uninstall — see Original/README.md"
  say "Delegating to Original/setup.sh"
  if [[ ! -f "$src/setup.sh" ]]; then
    die "Original/setup.sh not found — cannot install Original variant"
  fi
  if [[ $DRY_RUN -eq 1 ]]; then
    printf "  ${YELLOW}[dry-run]${NC} would execute: bash %s/setup.sh\n" "$src"
    return
  fi
  bash "$src/setup.sh"
}

# ---------------------------------------------------------------------------
# Install: Ultimate-Linux
# ---------------------------------------------------------------------------
run_linux() {
  local src="$REPO_DIR/Ultimate-Linux"
  local scripts_target="$CLAUDE_HOME/ultimate/scripts"
  local manifest="$CLAUDE_HOME/.ultimate-manifest"
  [[ ! -d "$src" ]] && die "Ultimate-Linux/ directory not found in $REPO_DIR"

  hdr "Ultimate-Linux install"
  say "Source:  $src"
  say "Target:  $CLAUDE_HOME"
  say "Mode:    $MODE$([[ $DRY_RUN -eq 1 ]] && echo ' (dry-run)')"
  say "Backup:  $([[ $BACKUP -eq 1 ]] && echo "$BACKUP_DIR" || echo 'DISABLED')"
  echo ""

  check_prereqs_ultimate "Ultimate-Linux"
  [[ $VERIFY_ONLY -eq 1 ]] && { say "Verify-only — exiting"; exit 0; }
  [[ $UNINSTALL -eq 1 ]] && _uninstall_ultimate "ultimate" "<!-- ultimate:start -->" "<!-- ultimate:end -->"
  [[ $PROJECT_MODE -eq 1 ]] && { install_project_override "$src" "Ultimate-Linux"; exit 0; }

  [[ "$MODE" == "fresh" ]] && purge_ult_artifacts "ultimate" "$manifest"

  install_scripts  "$src/scripts" "$scripts_target"
  install_agents   "$src/agents"   "$manifest"
  install_skills   "$src/skills"   "$manifest"
  install_commands "$src/commands" "$manifest"
  install_settings "$src/settings.json"
  ensure_hooks_wired "$scripts_target"
  install_claude_md "$src/CLAUDE.md" "<!-- ultimate:start -->" "<!-- ultimate:end -->"

  echo ""
  smoke_test_ultimate "$scripts_target"
  echo ""
  say "Install complete."
  say "Try it: start a fresh claude session and run /agents — expect ult-code-reviewer, etc."
  [[ $BACKUP -eq 1 && $DRY_RUN -eq 0 ]] && say "Backups at: $BACKUP_DIR"
}

# ---------------------------------------------------------------------------
# Install: Ultimate-Windows
# ---------------------------------------------------------------------------
run_windows() {
  local src="$REPO_DIR/Ultimate-Windows"
  local scripts_target="$CLAUDE_HOME/ultimate-windows/scripts"
  local manifest="$CLAUDE_HOME/.ultimate-windows-manifest"
  [[ ! -d "$src" ]] && die "Ultimate-Windows/ directory not found in $REPO_DIR"

  hdr "Ultimate-Windows install"
  say "Source:  $src"
  say "Target:  $CLAUDE_HOME"
  say "Mode:    $MODE$([[ $DRY_RUN -eq 1 ]] && echo ' (dry-run)')"
  say "Backup:  $([[ $BACKUP -eq 1 ]] && echo "$BACKUP_DIR" || echo 'DISABLED')"
  echo ""

  check_prereqs_ultimate "Ultimate-Windows"
  [[ $VERIFY_ONLY -eq 1 ]] && { say "Verify-only — exiting"; exit 0; }
  [[ $UNINSTALL -eq 1 ]] && _uninstall_ultimate "ultimate-windows" "<!-- ultimate-windows:start -->" "<!-- ultimate-windows:end -->"
  [[ $PROJECT_MODE -eq 1 ]] && { install_project_override "$src" "Ultimate-Windows"; exit 0; }

  [[ "$MODE" == "fresh" ]] && purge_ult_artifacts "ultimate-windows" "$manifest"

  install_scripts  "$src/scripts" "$scripts_target"
  install_agents   "$src/agents"   "$manifest"
  install_skills   "$src/skills"   "$manifest"
  install_commands "$src/commands" "$manifest"
  install_settings "$src/settings.json"
  ensure_hooks_wired "$scripts_target"
  install_claude_md "$src/CLAUDE.md" "<!-- ultimate-windows:start -->" "<!-- ultimate-windows:end -->"

  echo ""
  smoke_test_ultimate "$scripts_target"
  echo ""
  say "Install complete."
  say "Try it: start a fresh claude session and run /agents — expect ult-code-reviewer, etc."
  [[ $BACKUP -eq 1 && $DRY_RUN -eq 0 ]] && say "Backups at: $BACKUP_DIR"

  # Install COST-OPTIMIZATION.md to ~/.claude/ for reference by hooks
  if [[ -f "$src/COST-OPTIMIZATION.md" ]]; then
    do_run cp "$src/COST-OPTIMIZATION.md" "$CLAUDE_HOME/COST-OPTIMIZATION.md"
    ok "Installed COST-OPTIMIZATION.md → $CLAUDE_HOME/"
  fi

  # Write installed version SHA (used by update-check.sh)
  if command -v git >/dev/null 2>&1 && [[ -d "$REPO_DIR/.git" ]]; then
    local installed_sha; installed_sha=$(git -C "$REPO_DIR" rev-parse HEAD 2>/dev/null || true)
    if [[ -n "$installed_sha" ]]; then
      echo "$installed_sha" > "$CLAUDE_HOME/.ultimate-windows-version"
      ok "Wrote installed version: ${installed_sha:0:8}"
    fi
  fi

  echo ""
  say "Optional: BurntToast for Windows 10/11 toast notifications:"
  say "  Run in PowerShell: Install-Module BurntToast -Scope CurrentUser"
  say "Optional: lean-ctx for file-read caching (~13 tokens/re-read):"
  say "  cargo install lean-ctx  (or: npm install -g lean-ctx-bin)"
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
main() {
  # --uninstall with explicit variant flag skips the interactive menu
  if [[ $UNINSTALL -eq 1 && -n "$VARIANT" ]]; then
    case "$VARIANT" in
      linux)   _uninstall_ultimate "ultimate"         "<!-- ultimate:start -->"         "<!-- ultimate:end -->"         ;;
      windows) _uninstall_ultimate "ultimate-windows" "<!-- ultimate-windows:start -->" "<!-- ultimate-windows:end -->" ;;
      original) die "Original has no automated uninstall — see Original/README.md" ;;
    esac
  fi

  # --uninstall with no variant: interactive prompt
  [[ $UNINSTALL -eq 1 && -z "$VARIANT" ]] && { uninstall_interactive; exit 0; }

  [[ -z "$VARIANT" ]] && interactive_menu

  case "$VARIANT" in
    original) run_original ;;
    linux)    run_linux    ;;
    windows)  run_windows  ;;
    *) die "Unknown variant: $VARIANT" ;;
  esac
}

main "$@"

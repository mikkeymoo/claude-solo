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
# Agents install — writes a manifest for clean per-variant uninstall
# ---------------------------------------------------------------------------
install_agents() {
  local src_dir="$1"
  local manifest="$2"
  say "Installing agents"
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
    [[ $DRY_RUN -eq 0 ]] && echo "ult-$name.md" >> "$manifest"
    (( count++ )) || true
  done
  shopt -u nullglob
  [[ $count -eq 0 ]] && warn "No agent .md files found in $src_dir" || true
}

# ---------------------------------------------------------------------------
# Skills install
# ---------------------------------------------------------------------------
install_skills() {
  local src_dir="$1"
  say "Installing skills → skills/ult/"
  local base="$CLAUDE_HOME/skills/ult"
  do_run mkdir -p "$base"
  shopt -s nullglob
  local count=0
  for dir in "$src_dir/"*/; do
    local name; name=$(basename "$dir")
    local target="$base/$name"
    [[ -d "$target" ]] && backup_path "$target"
    do_run mkdir -p "$target"
    if [[ -f "$dir/SKILL.md" ]]; then
      do_run cp "$dir/SKILL.md" "$target/"
      ok "Installed skill: $name"
      (( count++ )) || true
    else
      warn "Skipping $name — no SKILL.md found"
    fi
  done
  shopt -u nullglob
  [[ $count -eq 0 ]] && warn "No skill directories found in $src_dir" || true
}

# ---------------------------------------------------------------------------
# Commands install
# ---------------------------------------------------------------------------
install_commands() {
  local src_dir="$1"
  say "Installing commands → $CLAUDE_HOME/commands/mm"
  local target_dir="$CLAUDE_HOME/commands/mm"
  # Backup and wipe so removed commands don't persist across reinstalls
  if [[ -d "$target_dir" ]]; then
    backup_path "$target_dir"
    do_run rm -rf "$target_dir"
  fi
  do_run mkdir -p "$target_dir"
  shopt -s nullglob
  local count=0
  for f in "$src_dir/"*.md; do
    do_run cp "$f" "$target_dir/$(basename "$f")"
    ok "Installed command: $(basename "$f")"
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
# Purge all prior Ultimate artifacts — called by fresh mode before reinstalling.
# Backs up then wipes agents/, skills/ult/, commands/mm/. This ensures only
# what the variant ships ends up installed — no orphaned files from prior runs.
# Never touches hooks/, settings.json, CLAUDE.md, or env (handled separately).
# ---------------------------------------------------------------------------
purge_ult_artifacts() {
  local scripts_ns="$1"   # e.g. "ultimate-windows"
  say "Purging prior ${scripts_ns} artifacts (fresh mode)"

  # Agents — backup entire dir, wipe it, recreate empty
  if [[ -d "$CLAUDE_HOME/agents" ]]; then
    backup_path "$CLAUDE_HOME/agents"
    do_run rm -rf "$CLAUDE_HOME/agents"
    ok "Removed agents/"
  fi
  do_run mkdir -p "$CLAUDE_HOME/agents"

  # Skills — wipe ult/ and any loose root-level skill dirs
  if [[ -d "$CLAUDE_HOME/skills" ]]; then
    backup_path "$CLAUDE_HOME/skills"
    do_run rm -rf "$CLAUDE_HOME/skills"
    ok "Removed skills/"
  fi
  do_run mkdir -p "$CLAUDE_HOME/skills"

  # Commands — wipe mm/ only (other command namespaces are not ours)
  if [[ -d "$CLAUDE_HOME/commands/mm" ]]; then
    backup_path "$CLAUDE_HOME/commands/mm"
    do_run rm -rf "$CLAUDE_HOME/commands/mm"
    ok "Removed commands/mm/"
  fi

  # Scripts dir is handled by install_scripts (wipe+replace) — skip here
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
    '{"matcher":"mcp__cclsp__.*","hooks":[{"type":"command","command":"bash ~/.claude/ultimate-windows/scripts/compress-lsp-output.sh","timeout":5000}]}'

  _wire_hook "SessionStart" \
    "session-start-context" \
    '{"hooks":[{"type":"command","command":"bash ~/.claude/ultimate-windows/scripts/session-start-context.sh","statusMessage":"Loading git + sprint context...","timeout":10000}]}'

  _wire_hook "PreCompact" \
    "pre-compact-checkpoint" \
    '{"hooks":[{"type":"command","command":"bash ~/.claude/ultimate-windows/scripts/pre-compact-checkpoint.sh","statusMessage":"Saving checkpoint before compaction..."}]}'
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
  if jq empty "$CLAUDE_HOME/settings.json" 2>/dev/null; then
    ok "settings.json parses as valid JSON"
  else
    warn "settings.json does NOT parse as valid JSON — fix before use"
  fi
  local n=0
  shopt -s nullglob
  for f in "$scripts_dir/"*.sh; do
    [[ -x "$f" ]] && (( n++ )) || true
  done
  shopt -u nullglob
  ok "Hook scripts executable: $n"
  local agents; agents=$(ls "$CLAUDE_HOME/agents/"ult-*.md 2>/dev/null | wc -l)
  ok "Agents installed (ult-*): $agents/5"
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

  # Remove only agents that this variant installed, tracked via manifest
  if [[ -f "$manifest" ]]; then
    while IFS= read -r agent_file; do
      local full="$CLAUDE_HOME/agents/$agent_file"
      if [[ -f "$full" ]]; then
        do_run rm -f "$full"
        ok "Removed $agent_file"
      fi
    done < "$manifest"
    do_run rm -f "$manifest"
    ok "Removed manifest"
  else
    warn "No manifest at $manifest — cannot safely identify which agents belong to this variant"
    warn "Manually remove $CLAUDE_HOME/agents/ult-*.md if needed"
  fi

  [[ -d "$CLAUDE_HOME/skills/ult" ]] && { do_run rm -rf "$CLAUDE_HOME/skills/ult"; ok "Removed skills/ult/"; }
  [[ -d "$CLAUDE_HOME/commands/mm" ]] && { do_run rm -rf "$CLAUDE_HOME/commands/mm"; ok "Removed commands/mm/"; }
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
  install_agents   "$src/agents"  "$manifest"
  install_skills   "$src/skills"
  install_commands "$src/commands"
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
  install_agents   "$src/agents"  "$manifest"
  install_skills   "$src/skills"
  install_commands "$src/commands"
  install_settings "$src/settings.json"
  ensure_hooks_wired "$scripts_target"
  install_claude_md "$src/CLAUDE.md" "<!-- ultimate-windows:start -->" "<!-- ultimate-windows:end -->"

  echo ""
  smoke_test_ultimate "$scripts_target"
  echo ""
  say "Install complete."
  say "Try it: start a fresh claude session and run /agents — expect ult-code-reviewer, etc."
  [[ $BACKUP -eq 1 && $DRY_RUN -eq 0 ]] && say "Backups at: $BACKUP_DIR"

  echo ""
  say "Optional: BurntToast for Windows 10/11 toast notifications:"
  say "  Run in PowerShell: Install-Module BurntToast -Scope CurrentUser"
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

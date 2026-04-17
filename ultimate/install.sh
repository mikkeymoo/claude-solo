#!/usr/bin/env bash
# install.sh — deploy the ultimate/ Claude Code config to this machine.
#
# Default mode is SAFE MERGE: prefixes ultimate agents with `ult-` and nests
# skills under `ult/` so it coexists with your existing claude-solo install
# without overwriting anything. Hook scripts live in their own namespace at
# ~/.claude/ultimate/scripts/ (referenced from ultimate's settings.json).
#
# Usage:
#   bash install.sh                 # Option B: namespaced merge (safe, default)
#   bash install.sh --fresh         # Option A: replace existing (aggressive)
#   bash install.sh --reset         # DESTRUCTIVE: wipe ~/.claude/{agents,skills,ultimate}/ then fresh install
#   bash install.sh --reset --yes   # skip the confirmation prompt
#   bash install.sh --project       # add project-override to CWD's .claude/
#   bash install.sh --dry-run       # show what would happen, change nothing
#   bash install.sh --no-backup     # skip backups (not recommended)
#   bash install.sh --uninstall     # remove everything this script installed
#   bash install.sh --verify        # check prerequisites, don't install

set -euo pipefail

# ---------------------------------------------------------------------------
# Config
# ---------------------------------------------------------------------------
MODE="merge"
BACKUP=1
DRY_RUN=0
UNINSTALL=0
VERIFY_ONLY=0
PROJECT_MODE=0
RESET=0
ASSUME_YES=0

ULTIMATE_DIR="$(cd "$(dirname "$0")" && pwd)"
CLAUDE_HOME="${HOME}/.claude"
ULTIMATE_SCRIPTS="${CLAUDE_HOME}/ultimate/scripts"
BACKUP_DIR="${CLAUDE_HOME}/.ultimate-backup/$(date +%Y%m%d-%H%M%S)"

# ---------------------------------------------------------------------------
# Output helpers
# ---------------------------------------------------------------------------
GREEN='\033[0;32m'; YELLOW='\033[0;33m'; RED='\033[0;31m'; CYAN='\033[0;36m'; NC='\033[0m'
say() { printf "${CYAN}[ultimate]${NC} %s\n" "$*"; }
ok()  { printf "${GREEN}  ✓${NC} %s\n" "$*"; }
warn(){ printf "${YELLOW}  ⚠${NC} %s\n" "$*"; }
die() { printf "${RED}  ✗${NC} %s\n" "$*"; exit 1; }

do_run() {
  if [[ $DRY_RUN -eq 1 ]]; then
    printf "  ${YELLOW}[dry-run]${NC} %s\n" "$*"
  else
    eval "$@"
  fi
}

backup() {
  local path="$1"
  [[ $BACKUP -eq 0 ]] && return 0
  [[ ! -e "$path" ]] && return 0
  do_run "mkdir -p '$BACKUP_DIR'"
  local rel="${path#$HOME/}"
  do_run "mkdir -p '$BACKUP_DIR/$(dirname "$rel")'"
  do_run "cp -a '$path' '$BACKUP_DIR/$rel'"
  ok "Backed up $path"
}

# ---------------------------------------------------------------------------
# Args
# ---------------------------------------------------------------------------
while [[ $# -gt 0 ]]; do
  case "$1" in
    --fresh) MODE="fresh" ;;
    --reset) MODE="fresh"; RESET=1 ;;
    --yes|-y) ASSUME_YES=1 ;;
    --project) PROJECT_MODE=1 ;;
    --no-backup) BACKUP=0 ;;
    --dry-run|-n) DRY_RUN=1 ;;
    --uninstall) UNINSTALL=1 ;;
    --verify) VERIFY_ONLY=1 ;;
    -h|--help)
      grep '^#' "$0" | head -20 | sed 's/^# \{0,1\}//'
      exit 0 ;;
    *) die "Unknown flag: $1" ;;
  esac
  shift
done

# ---------------------------------------------------------------------------
# Prerequisite check
# ---------------------------------------------------------------------------
check_prereqs() {
  say "Checking prerequisites"
  local missing=()
  for bin in jq node bash; do
    command -v "$bin" >/dev/null 2>&1 || missing+=("$bin")
  done
  if ! command -v claude >/dev/null 2>&1; then
    warn "claude not on PATH — install still proceeds but can't smoke-test"
  else
    local v
    v=$(claude --version 2>/dev/null | head -1 || echo "unknown")
    ok "claude: $v"
  fi
  for bin in jq node bash; do
    command -v "$bin" >/dev/null 2>&1 && ok "$bin: $(command -v "$bin")"
  done
  if [[ ${#missing[@]} -gt 0 ]]; then
    die "Missing required: ${missing[*]}  (install with: sudo dnf install ${missing[*]})"
  fi
  # Optional tools — warn but don't block
  for bin in gh prettier tsc ruff pyright; do
    if ! command -v "$bin" >/dev/null 2>&1; then
      warn "$bin not on PATH (optional — some hook features will no-op)"
    fi
  done
}

# ---------------------------------------------------------------------------
# Uninstall
# ---------------------------------------------------------------------------
uninstall() {
  say "Uninstalling ultimate config"
  # Namespaced artifacts (merge mode)
  for f in "$CLAUDE_HOME/agents/"ult-*.md; do
    [[ -f "$f" ]] && { do_run "rm -f '$f'"; ok "Removed $(basename "$f")"; }
  done
  [[ -d "$CLAUDE_HOME/skills/ult" ]] && { do_run "rm -rf '$CLAUDE_HOME/skills/ult'"; ok "Removed skills/ult"; }
  # Commands (merge mode: commands/mm, fresh mode: commands/mm)
  [[ -d "$CLAUDE_HOME/commands/mm" ]] && { do_run "rm -rf '$CLAUDE_HOME/commands/mm'"; ok "Removed commands/mm"; }
  # Fresh-mode artifacts
  for name in code-reviewer researcher refactor-agent db-reader deploy-guard; do
    f="$CLAUDE_HOME/agents/$name.md"
    if [[ -f "$f" ]]; then
      # Only delete if it matches ours (has our telltale description marker)
      if grep -q "^description:.*ultimate\|TRIGGER\|Solo-developer" "$f" 2>/dev/null; then
        do_run "rm -f '$f'"
        ok "Removed $name.md (matched ultimate signature)"
      else
        warn "$name.md exists but doesn't look like ours — leaving alone"
      fi
    fi
  done
  for s in riper daily-brief tech-debt security-review; do
    [[ -d "$CLAUDE_HOME/skills/$s" ]] && { do_run "rm -rf '$CLAUDE_HOME/skills/$s'"; ok "Removed skills/$s"; }
  done
  # Hook scripts
  [[ -d "$CLAUDE_HOME/ultimate" ]] && { do_run "rm -rf '$CLAUDE_HOME/ultimate'"; ok "Removed ultimate/"; }
  # CLAUDE.md marker block
  local cm="$CLAUDE_HOME/CLAUDE.md"
  if [[ -f "$cm" ]] && grep -Fq "<!-- ultimate:start -->" "$cm"; then
    backup "$cm"
    do_run "sed -i '/<!-- ultimate:start -->/,/<!-- ultimate:end -->/d' '$cm'"
    ok "Stripped ultimate block from CLAUDE.md"
  fi
  say "Uninstall complete. Backups (if any) are under $CLAUDE_HOME/.ultimate-backup/"
  say "NOTE: settings.json is NOT touched by uninstall (you merged it manually)."
  say "Review ~/.claude/settings.json and remove the ultimate hook entries by hand."
  exit 0
}

# ---------------------------------------------------------------------------
# Project-mode install
# ---------------------------------------------------------------------------
install_project() {
  say "Installing project-override into: $PWD"
  [[ ! -d .git ]] && warn "Not a git repo — you probably want to run this inside a project"
  do_run "mkdir -p .claude"
  if [[ -f .claude/settings.json ]]; then
    backup "$PWD/.claude/settings.json"
    warn ".claude/settings.json exists — showing diff, not overwriting:"
    diff -u .claude/settings.json "$ULTIMATE_DIR/project-override/settings.json" || true
    warn "Merge manually if you want the ultimate rules."
  else
    do_run "cp '$ULTIMATE_DIR/project-override/settings.json' .claude/settings.json"
    ok "Wrote .claude/settings.json"
  fi
  if [[ -f .gitignore ]]; then
    if grep -Fq ".claude/settings.local.json" .gitignore 2>/dev/null; then
      ok ".gitignore already has ultimate entries"
    else
      backup "$PWD/.gitignore"
      do_run "printf '\n# --- ultimate additions ---\n' >> .gitignore"
      do_run "cat '$ULTIMATE_DIR/gitignore-additions.txt' >> .gitignore"
      ok "Appended gitignore-additions.txt"
    fi
  else
    do_run "cp '$ULTIMATE_DIR/gitignore-additions.txt' .gitignore"
    ok "Wrote .gitignore"
  fi
  say "Project install complete."
  exit 0
}

# ---------------------------------------------------------------------------
# Reset (nuke-and-pave) — used by --reset
# ---------------------------------------------------------------------------
do_reset() {
  say "RESET MODE — will wipe and reinstall:"
  echo "    $CLAUDE_HOME/agents/     (ALL agents, not just ultimate's)"
  echo "    $CLAUDE_HOME/skills/     (ALL skills, not just ultimate's)"
  echo "    $CLAUDE_HOME/ultimate/   (hook scripts)"
  echo "  Also replaces (via --fresh): settings.json, CLAUDE.md"
  echo ""
  say "NOT touched: commands/mm/ (wiped separately), memory/, rules/, .planning/, anything else"
  echo ""
  if [[ $BACKUP -eq 1 ]]; then
    say "Everything will be backed up to: $BACKUP_DIR"
  else
    warn "BACKUPS DISABLED (--no-backup) — this is irreversible"
  fi
  echo ""
  if [[ $ASSUME_YES -ne 1 && $DRY_RUN -ne 1 ]]; then
    printf "${YELLOW}  Type 'reset' to confirm: ${NC}"
    read -r confirm
    [[ "$confirm" != "reset" ]] && die "Aborted — did not confirm"
  fi

  for sub in agents skills ultimate commands/mm; do
    local path="$CLAUDE_HOME/$sub"
    if [[ -d "$path" ]]; then
      backup "$path"
      do_run "rm -rf '$path'"
      ok "Wiped $sub/"
    else
      ok "$sub/ does not exist — nothing to wipe"
    fi
  done
}

# ---------------------------------------------------------------------------
# Scripts (hook binaries) — same in both merge and fresh mode
# ---------------------------------------------------------------------------
install_scripts() {
  say "Installing hook scripts → $ULTIMATE_SCRIPTS"
  do_run "mkdir -p '$ULTIMATE_SCRIPTS'"
  for f in "$ULTIMATE_DIR/scripts/"*.sh; do
    local target="$ULTIMATE_SCRIPTS/$(basename "$f")"
    [[ -f "$target" ]] && backup "$target"
    do_run "cp '$f' '$target'"
    do_run "chmod +x '$target'"
    ok "Installed $(basename "$f")"
  done
}

# ---------------------------------------------------------------------------
# Agents
# ---------------------------------------------------------------------------
install_agents() {
  say "Installing agents (mode: $MODE)"
  do_run "mkdir -p '$CLAUDE_HOME/agents'"
  for f in "$ULTIMATE_DIR/agents/"*.md; do
    local name; name=$(basename "$f" .md)
    local target
    if [[ "$MODE" == "merge" ]]; then
      target="$CLAUDE_HOME/agents/ult-$name.md"
      [[ -f "$target" ]] && backup "$target"
      do_run "cp '$f' '$target'"
      # Rewrite name field so the agent shows up as ult-<name>
      do_run "sed -i 's/^name: $name$/name: ult-$name/' '$target'"
      ok "Installed ult-$name.md"
    else
      target="$CLAUDE_HOME/agents/$name.md"
      [[ -f "$target" ]] && backup "$target"
      do_run "cp '$f' '$target'"
      ok "Installed $name.md"
    fi
  done
}

# ---------------------------------------------------------------------------
# Skills
# ---------------------------------------------------------------------------
install_skills() {
  say "Installing skills (mode: $MODE)"
  local base
  if [[ "$MODE" == "merge" ]]; then
    base="$CLAUDE_HOME/skills/ult"
  else
    base="$CLAUDE_HOME/skills"
  fi
  do_run "mkdir -p '$base'"
  for dir in "$ULTIMATE_DIR/skills/"*/; do
    local name; name=$(basename "$dir")
    local target="$base/$name"
    [[ -d "$target" ]] && backup "$target"
    do_run "mkdir -p '$target'"
    do_run "cp '$dir/SKILL.md' '$target/'"
    ok "Installed skill: $name"
  done
}

# ---------------------------------------------------------------------------
# Commands
# ---------------------------------------------------------------------------
install_commands() {
  say "Installing commands → $CLAUDE_HOME/commands/mm"
  local target="$CLAUDE_HOME/commands/mm"
  [[ -d "$target" ]] && backup "$target"
  do_run "mkdir -p '$target'"
  for f in "$ULTIMATE_DIR/commands/"*.md; do
    local name; name=$(basename "$f")
    do_run "cp '$f' '$target/$name'"
    ok "Installed command: $name"
  done
}

# ---------------------------------------------------------------------------
# settings.json + CLAUDE.md — merge-safe
# ---------------------------------------------------------------------------
install_settings() {
  local target="$CLAUDE_HOME/settings.json"
  if [[ ! -f "$target" ]]; then
    say "No existing settings.json — installing ultimate's"
    do_run "cp '$ULTIMATE_DIR/settings.json' '$target'"
    ok "Wrote $target"
    return
  fi
  backup "$target"
  if [[ "$MODE" == "fresh" ]]; then
    warn "--fresh: overwriting existing settings.json (backup taken)"
    do_run "cp '$ULTIMATE_DIR/settings.json' '$target'"
    ok "Overwrote $target"
    return
  fi
  say "Existing settings.json found — merge mode, NOT overwriting."
  say "Diff (yours → ultimate):"
  diff -u "$target" "$ULTIMATE_DIR/settings.json" | head -80 || true
  warn "Review the diff above. Merge manually with your editor."
  warn "Ultimate's settings.json is at: $ULTIMATE_DIR/settings.json"
}

install_claude_md() {
  local target="$CLAUDE_HOME/CLAUDE.md"
  local marker_start="<!-- ultimate:start -->"
  local marker_end="<!-- ultimate:end -->"
  if [[ -f "$target" ]] && grep -Fq "$marker_start" "$target"; then
    ok "CLAUDE.md already has ultimate block — skipping"
    return
  fi
  [[ -f "$target" ]] && backup "$target"
  if [[ "$MODE" == "fresh" && -f "$target" ]]; then
    warn "--fresh: replacing CLAUDE.md (backup taken)"
    do_run "cp '$ULTIMATE_DIR/CLAUDE.md' '$target'"
    ok "Wrote $target"
    return
  fi
  say "Appending ultimate block to CLAUDE.md"
  if [[ $DRY_RUN -eq 1 ]]; then
    echo "  [dry-run] would append ultimate block to $target"
  else
    {
      [[ -f "$target" ]] && echo ""
      echo "$marker_start"
      cat "$ULTIMATE_DIR/CLAUDE.md"
      echo "$marker_end"
    } >> "$target"
    ok "Appended ultimate block"
  fi
}

# ---------------------------------------------------------------------------
# Smoke test
# ---------------------------------------------------------------------------
smoke_test() {
  say "Running smoke checks"
  if jq empty "$CLAUDE_HOME/settings.json" 2>/dev/null; then
    ok "settings.json parses as JSON"
  else
    warn "settings.json does NOT parse — fix before using"
  fi
  local n=0
  for f in "$ULTIMATE_SCRIPTS/"*.sh; do
    [[ -x "$f" ]] && n=$((n + 1))
  done
  ok "Hook scripts executable: $n"
  if [[ "$MODE" == "merge" ]]; then
    local agents; agents=$(ls "$CLAUDE_HOME/agents/"ult-*.md 2>/dev/null | wc -l)
    local skills; skills=$(ls -d "$CLAUDE_HOME/skills/ult/"*/ 2>/dev/null | wc -l)
    ok "Namespaced agents: $agents/5"
    ok "Namespaced skills: $skills/4"
  else
    local agents; agents=$(ls "$CLAUDE_HOME/agents/"{code-reviewer,researcher,refactor-agent,db-reader,deploy-guard}.md 2>/dev/null | wc -l)
    ok "Agents installed: $agents/5"
  fi
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
main() {
  say "Ultimate Claude Code config installer"
  say "Source:    $ULTIMATE_DIR"
  say "Target:    $CLAUDE_HOME"
  say "Mode:      $MODE$([[ $RESET -eq 1 ]] && echo ' + RESET (wipe first)')  $([[ $DRY_RUN -eq 1 ]] && echo '(dry-run)')"
  say "Backup:    $([[ $BACKUP -eq 1 ]] && echo "$BACKUP_DIR" || echo 'DISABLED')"
  echo ""

  check_prereqs
  [[ $VERIFY_ONLY -eq 1 ]] && { say "Verify-only — exiting"; exit 0; }
  [[ $UNINSTALL -eq 1 ]] && uninstall
  [[ $PROJECT_MODE -eq 1 ]] && install_project
  [[ $RESET -eq 1 ]] && do_reset

  install_scripts
  install_agents
  install_skills
  install_commands
  install_settings
  install_claude_md
  echo ""
  smoke_test
  echo ""
  say "Install complete."
  if [[ "$MODE" == "merge" ]]; then
    say "Try it: start a fresh \`claude\` session and run /agents — you should see ult-code-reviewer, ult-researcher, etc."
  else
    say "Try it: start a fresh \`claude\` session and run /agents — you should see code-reviewer, researcher, etc."
  fi
  [[ $BACKUP -eq 1 ]] && say "Backups at: $BACKUP_DIR"

  offer_lean_ctx
}

# ---------------------------------------------------------------------------
# Optional: lean-ctx — shell + file-read context compressor
# ---------------------------------------------------------------------------
offer_lean_ctx() {
  [[ $DRY_RUN -eq 1 ]] && return
  echo ""
  say "Optional: lean-ctx (shell output + file-read context compressor)"
  say "Complements ultimate's LSP compressor — covers the shell/file-read side."
  say "Install: curl -fsSL https://leanctx.com/install.sh | sh"
  echo ""
  if command -v lean-ctx >/dev/null 2>&1; then
    ok "lean-ctx already installed: $(lean-ctx --version 2>/dev/null || echo 'version unknown')"
    return
  fi
  if [[ $ASSUME_YES -eq 1 ]]; then
    say "Installing lean-ctx (--yes flag set)..."
    curl -fsSL https://leanctx.com/install.sh | sh
    if command -v lean-ctx >/dev/null 2>&1; then
      lean-ctx setup
      ok "lean-ctx installed and configured"
      install_lean_ctx_vscode
    else
      warn "lean-ctx install may have failed — check above output"
    fi
    return
  fi
  printf "${YELLOW}  Install lean-ctx now? [y/N]: ${NC}"
  read -r answer
  if [[ "$answer" =~ ^[Yy]$ ]]; then
    curl -fsSL https://leanctx.com/install.sh | sh
    if command -v lean-ctx >/dev/null 2>&1; then
      lean-ctx setup
      ok "lean-ctx installed and configured"
      install_lean_ctx_vscode
    else
      warn "lean-ctx install may have failed — check above output"
    fi
  else
    say "Skipped. Install later: curl -fsSL https://leanctx.com/install.sh | sh && lean-ctx setup"
  fi
}

install_lean_ctx_vscode() {
  if ! command -v code >/dev/null 2>&1; then
    warn "VS Code CLI (code) not on PATH — skipping extension install"
    say "Install manually: code --install-extension yvgude.lean-ctx"
    return
  fi
  say "Installing lean-ctx VS Code extension..."
  if code --install-extension yvgude.lean-ctx 2>/dev/null; then
    ok "VS Code extension yvgude.lean-ctx installed"
    say "Open Command Palette → 'lean-ctx: Setup' to configure"
  else
    warn "VS Code extension install failed — try: code --install-extension yvgude.lean-ctx"
  fi
}

main "$@"

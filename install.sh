#!/usr/bin/env bash
# install.sh — claude-solo unified installer.
# Requires bash (Git Bash on Windows).
#
# Usage:
#   bash install.sh                     # install (merge mode, recommended)
#   bash install.sh --fresh             # replace existing config (backup taken)
#   bash install.sh --project           # add project override to CWD
#   bash install.sh --with-cache-fix    # opt in to local cache proxy wiring
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
INSTALL_CACHE_FIX=0

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

# Detect Windows (MSYS/Git Bash/Cygwin)
is_windows() {
  [[ "${MSYSTEM:-}" != "" || "${OSTYPE:-}" == "msys" || "${OSTYPE:-}" == "cygwin" ]]
}

# Find PowerShell executable (pwsh preferred over powershell.exe)
find_pwsh() {
  command -v pwsh 2>/dev/null || command -v powershell.exe 2>/dev/null || true
}

# Surgically add/update a key in settings.json .env block without touching anything else.
# Skips if key already set to correct value; warns if set to a different value.
_patch_settings_env() {
  local key="$1" value="$2"
  local target="$CLAUDE_HOME/settings.json"
  [[ ! -f "$target" ]] && return 0
  [[ $DRY_RUN -eq 1 ]] && { printf "  ${YELLOW}[dry-run]${NC} would set env.%s=%s in settings.json\n" "$key" "$value"; return 0; }

  local current
  current=$(jq -r ".env[\"${key}\"] // empty" "$target" 2>/dev/null || true)

  if [[ "$current" == "$value" ]]; then
    ok "settings.json env.${key} already correct"
    return 0
  fi
  if [[ -n "$current" && "$current" != "$value" ]]; then
    warn "settings.json env.${key} is '${current}', expected '${value}' — skipping (set manually if needed)"
    return 0
  fi

  jq ".env[\"${key}\"] = \"${value}\"" "$target" > "$target.tmp" && mv "$target.tmp" "$target"
  ok "Set env.${key}=${value} in settings.json"
}

_remove_settings_env_key() {
  local key="$1"
  local target="$CLAUDE_HOME/settings.json"
  [[ ! -f "$target" ]] && return 0
  [[ $DRY_RUN -eq 1 ]] && { printf "  ${YELLOW}[dry-run]${NC} would remove env.%s from settings.json\n" "$key"; return 0; }

  if jq -e --arg key "$key" '.env[$key] != null' "$target" >/dev/null 2>&1; then
    jq --arg key "$key" 'if .env then .env |= with_entries(select(.key != $key)) else . end' "$target" > "$target.tmp" && mv "$target.tmp" "$target"
    ok "Removed env.${key} from settings.json"
  else
    ok "settings.json env.${key} not set"
  fi
}

_unwire_hook_by_command_fragment() {
  local event="$1" fragment="$2"
  local target="$CLAUDE_HOME/settings.json"
  [[ ! -f "$target" ]] && return 0
  [[ $DRY_RUN -eq 1 ]] && { printf "  ${YELLOW}[dry-run]${NC} would remove %s from %s hooks\n" "$fragment" "$event"; return 0; }

  jq --arg event "$event" --arg fragment "$fragment" '
    .hooks = (.hooks // {}) |
    .hooks[$event] = (
      (.hooks[$event] // [])
      | map(
          select(
            ((((.hooks // []) | map(.command // "") | join(" ")) | contains($fragment)) | not)
          )
        )
    )
  ' "$target" > "$target.tmp" && mv "$target.tmp" "$target"
  ok "Ensured ${fragment} is not wired in ${event}"
}

find_native_claude_binary() {
  local candidate
  local -a candidates=()

  if [[ -d "$HOME/.local/share/claude/versions" ]]; then
    mapfile -t candidates < <(find "$HOME/.local/share/claude/versions" -mindepth 1 -maxdepth 1 -type f 2>/dev/null | sort -V -r)
    for candidate in "${candidates[@]}"; do
      [[ -x "$candidate" ]] && { printf '%s\n' "$candidate"; return 0; }
    done
  fi

  if [[ -d "$HOME/.vscode/extensions" ]]; then
    mapfile -t candidates < <(find "$HOME/.vscode/extensions" -path '*/resources/native-binary/claude' -type f 2>/dev/null | sort -V -r)
    for candidate in "${candidates[@]}"; do
      [[ -x "$candidate" ]] && { printf '%s\n' "$candidate"; return 0; }
    done
  fi

  if [[ -d "$HOME/.cursor/extensions" ]]; then
    mapfile -t candidates < <(find "$HOME/.cursor/extensions" -path '*/resources/native-binary/claude' -type f 2>/dev/null | sort -V -r)
    for candidate in "${candidates[@]}"; do
      [[ -x "$candidate" ]] && { printf '%s\n' "$candidate"; return 0; }
    done
  fi

  return 1
}

repair_claude_launcher() {
  local launcher="$HOME/.local/bin/claude"
  local resolved native head_line should_repair=0

  do_run mkdir -p "$HOME/.local/bin"

  if [[ -L "$launcher" ]]; then
    resolved=$(readlink -f "$launcher" 2>/dev/null || true)
    if [[ -n "$resolved" && "$resolved" == "$HOME/.local/share/claude/versions/"* && -x "$resolved" ]]; then
      ok "claude launcher already points to native binary"
      return 0
    fi
    should_repair=1
  elif [[ ! -e "$launcher" ]]; then
    should_repair=1
  elif [[ -f "$launcher" ]]; then
    head_line=$(head -n 1 "$launcher" 2>/dev/null || true)
    if [[ "$head_line" == '#!'* ]] && grep -qE 'npm-global|@anthropic-ai/claude-code|claude-code-cache-fix|cli\.js' "$launcher" 2>/dev/null; then
      should_repair=1
    fi
  fi

  native=$(find_native_claude_binary || true)
  if [[ -z "$native" ]]; then
    warn "No native Claude binary found for launcher repair"
    return 0
  fi

  if [[ $should_repair -eq 1 ]]; then
    [[ -e "$launcher" || -L "$launcher" ]] && backup_path "$launcher"
    do_run ln -sfn "$native" "$launcher"
    ok "Repaired claude launcher → $native"
  else
    ok "Leaving existing claude launcher untouched"
  fi
}

# ---------------------------------------------------------------------------
# Parse args
# ---------------------------------------------------------------------------
while [[ $# -gt 0 ]]; do
  case "$1" in
    --fresh)      MODE="fresh"       ;;
    --yes|-y)     ASSUME_YES=1       ;;
    --project)    PROJECT_MODE=1     ;;
    --with-cache-fix) INSTALL_CACHE_FIX=1 ;;
    --without-cache-fix) INSTALL_CACHE_FIX=0 ;;
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
# Ruff: find on disk, add to PATH, or install
# ---------------------------------------------------------------------------
fix_ruff() {
  # Already on PATH — done
  if command -v ruff >/dev/null 2>&1; then
    ok "ruff: $(command -v ruff)"
    return
  fi

  # Search common install locations (not yet on PATH)
  local ruff_dir=""
  local search_dirs=()

  if is_windows; then
    # Python installer default: %LOCALAPPDATA%\Programs\Python\Python3x\Scripts
    local lad="${LOCALAPPDATA:-}"
    if [[ -z "$lad" ]] && command -v cmd.exe >/dev/null 2>&1; then
      lad=$(cmd.exe /c "echo %LOCALAPPDATA%" 2>/dev/null | tr -d '\r\n' || true)
    fi
    if [[ -n "$lad" ]]; then
      local lad_unix
      lad_unix=$(cygpath -u "$lad" 2>/dev/null \
        || printf '%s' "$lad" | sed 's|\\|/|g; s|^\([A-Za-z]\):|/\L\1|')
      for d in "$lad_unix"/Programs/Python/Python3*/Scripts; do
        search_dirs+=("$d")
      done
    fi
    search_dirs+=("$HOME/scoop/apps/python/current/Scripts")
    search_dirs+=("$HOME/AppData/Roaming/Python/Python3"*/Scripts)
  fi
  search_dirs+=("$HOME/.local/bin" "$HOME/.cargo/bin" "/usr/local/bin")

  for d in "${search_dirs[@]}"; do
    if [[ -f "$d/ruff" || -f "$d/ruff.exe" ]]; then
      ruff_dir="$d"
      break
    fi
  done

  # Not found anywhere — install via pip or pipx
  if [[ -z "$ruff_dir" ]]; then
    if [[ $DRY_RUN -eq 1 ]]; then
      printf "  ${YELLOW}[dry-run]${NC} would install ruff via pip\n"
      return
    fi
    local pip_cmd
    pip_cmd=$(command -v pip3 2>/dev/null || command -v pip 2>/dev/null || true)
    if [[ -n "$pip_cmd" ]]; then
      say "  Installing ruff via pip..."
      if ! "$pip_cmd" install ruff --quiet 2>&1 | tail -2; then
        warn "pip install ruff failed — install manually: pip install ruff"
        return
      fi
    elif command -v pipx >/dev/null 2>&1; then
      say "  Installing ruff via pipx..."
      if ! pipx install ruff >/dev/null 2>&1; then
        warn "pipx install ruff failed — install manually: pipx install ruff"
        return
      fi
    else
      warn "ruff not installed and pip/pipx unavailable — install manually: pip install ruff"
      return
    fi
    # Re-check PATH after install (pip may have put it there)
    if command -v ruff >/dev/null 2>&1; then
      ok "ruff installed: $(command -v ruff)"
      return
    fi
    # Re-scan for the newly installed binary
    for d in "${search_dirs[@]}"; do
      if [[ -f "$d/ruff" || -f "$d/ruff.exe" ]]; then
        ruff_dir="$d"
        break
      fi
    done
  fi

  if [[ -n "$ruff_dir" ]]; then
    export PATH="$ruff_dir:$PATH"
    ok "ruff found at $ruff_dir — added to PATH for this session"
    # Persist to ~/.bashrc
    local bashrc="$HOME/.bashrc"
    if ! grep -qF "$ruff_dir" "$bashrc" 2>/dev/null; then
      printf '\n# ruff — added by claude-solo installer\nexport PATH="%s:$PATH"\n' "$ruff_dir" >> "$bashrc"
      ok "Persisted to ~/.bashrc (takes effect in new shells)"
    else
      ok "$ruff_dir already in ~/.bashrc"
    fi
    # Subshells can't push env changes to the parent — print the command so
    # the user can run it directly, or source ~/.bashrc to reload the profile
    printf "  ${YELLOW}→ Update current terminal (run this):${NC} export PATH=\"%s:\$PATH\"\n" "$ruff_dir"
    printf "  ${YELLOW}  or:${NC} source ~/.bashrc\n"
  else
    warn "ruff not found after install — hooks requiring ruff will no-op"
  fi
}

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
  command -v gh >/dev/null 2>&1 || warn "gh not on PATH (optional — GitHub features will no-op)"
  fix_ruff

  # Auto-install npm-based formatter tools
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
        npm install -g "${npm_pkgs[@]}" 2>&1 | tail -2 && ok "Installed: ${npm_pkgs[*]}" \
          || warn "npm install failed — install manually: npm install -g ${npm_pkgs[*]}"
      fi
    else
      for bin in "${npm_missing[@]}"; do
        warn "$bin not on PATH (optional) — install Node.js to enable auto-install"
      done
    fi
  fi
}

# ---------------------------------------------------------------------------
# Cache-fix installer
# Installs claude-code-cache-fix npm proxy, patches settings.json, wires hook.
# Handles: npm missing, already installed, install failure, settings missing,
#          env key conflicts, dry-run, version detection.
# ---------------------------------------------------------------------------
install_cache_fix() {
  if [[ $INSTALL_CACHE_FIX -ne 1 ]]; then
    say "Skipping cache-fix (opt-in only; preserving native Claude path)"
    _remove_settings_env_key "ANTHROPIC_BASE_URL"
    _remove_settings_env_key "ENABLE_PROMPT_CACHING_1H"
    return 0
  fi

  say "Installing cache-fix (claude-code-cache-fix)"

  if ! command -v npm >/dev/null 2>&1; then
    warn "npm not found — skipping cache-fix (install Node.js to enable)"
    return 0
  fi
  if ! command -v node >/dev/null 2>&1; then
    warn "node not found — skipping cache-fix"
    return 0
  fi

  if [[ $DRY_RUN -eq 1 ]]; then
    printf "  ${YELLOW}[dry-run]${NC} would run: npm install -g claude-code-cache-fix\n"
    printf "  ${YELLOW}[dry-run]${NC} would set ANTHROPIC_BASE_URL + ENABLE_PROMPT_CACHING_1H in settings.json\n"
    return 0
  fi

  # Check if already installed (fast path)
  local npm_root; npm_root=$(npm root -g 2>/dev/null || true)
  local proxy_script="${npm_root}/claude-code-cache-fix/proxy/server.mjs"

  if [[ -f "$proxy_script" ]]; then
    ok "claude-code-cache-fix already installed: $proxy_script"
  else
    say "  Running: npm install -g claude-code-cache-fix"
    if npm install -g claude-code-cache-fix 2>&1 | tail -3; then
      # Re-resolve after install
      npm_root=$(npm root -g 2>/dev/null || true)
      proxy_script="${npm_root}/claude-code-cache-fix/proxy/server.mjs"
      if [[ -f "$proxy_script" ]]; then
        ok "Installed claude-code-cache-fix"
      else
        warn "npm install ran but proxy/server.mjs not found at expected path — check manually"
        warn "  Expected: $proxy_script"
        return 0
      fi
    else
      warn "npm install claude-code-cache-fix failed — skipping proxy setup"
      warn "  Install manually: npm install -g claude-code-cache-fix"
      return 0
    fi
  fi

  # Patch settings.json with required env vars
  # ANTHROPIC_BASE_URL: routes Claude Code API calls through the local proxy
  _patch_settings_env "ANTHROPIC_BASE_URL" "http://127.0.0.1:9801"
  # ENABLE_PROMPT_CACHING_1H: restores 1h TTL natively on CC v2.1.108+ (belt-and-suspenders)
  _patch_settings_env "ENABLE_PROMPT_CACHING_1H" "1"

  ok "Cache-fix installed — proxy will auto-start on session start via hook"
}

# ---------------------------------------------------------------------------
# Optional tools installer
# (reserved for future optional tools)
# ---------------------------------------------------------------------------
install_optional_tools() {
  say "Installing optional tools — nothing to install"
}

# ---------------------------------------------------------------------------
# Windows encoding setup
# Runs Setup-WindowsEncoding.ps1 to set UTF-8 env vars, patch PowerShell
# profile, and ensure settings.json is written in UTF-8.
# ---------------------------------------------------------------------------
setup_windows_encoding() {
  is_windows || return 0
  local pwsh; pwsh=$(find_pwsh)
  [[ -z "$pwsh" ]] && return 0

  local script="$CLAUDE_HOME/scripts/Setup-WindowsEncoding.ps1"
  [[ ! -f "$script" ]] && return 0

  if [[ $DRY_RUN -eq 1 ]]; then
    printf "  ${YELLOW}[dry-run]${NC} would run Setup-WindowsEncoding.ps1\n"
    return 0
  fi

  say "Configuring Windows UTF-8 encoding"
  if "$pwsh" -NoProfile -ExecutionPolicy Bypass -File "$script" 2>&1 | tail -3; then
    ok "Windows encoding configured (UTF-8)"
  else
    warn "Windows encoding setup encountered errors — run manually if needed:"
    warn "  powershell -ExecutionPolicy Bypass -File ~/.claude/scripts/Setup-WindowsEncoding.ps1"
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
# Hooks install (JS files → ~/.claude/hooks/)
# ---------------------------------------------------------------------------
install_hooks() {
  local src_dir="$1"
  local dst_dir="$2"
  say "Installing JS hooks → $dst_dir"
  if [[ -d "$dst_dir" ]]; then
    backup_path "$dst_dir"
    do_run rm -rf "$dst_dir"
  fi
  do_run mkdir -p "$dst_dir"
  shopt -s nullglob
  local count=0
  for f in "$src_dir/"*.js; do
    do_run cp "$f" "$dst_dir/$(basename "$f")"
    ok "Installed $(basename "$f")"
    (( count++ )) || true
  done
  shopt -u nullglob
  [[ $count -eq 0 ]] && warn "No .js hook files found in $src_dir" || true
  # Copy package.json so node treats hooks as ESM (required for import syntax)
  if [[ -f "$src_dir/package.json" ]]; then
    do_run cp "$src_dir/package.json" "$dst_dir/package.json"
  fi
}

# ---------------------------------------------------------------------------
# MCP config install (mcp.json → ~/.claude/mcp.json)
# ---------------------------------------------------------------------------
install_mcp() {
  local src="$1"
  local dst="$CLAUDE_HOME/mcp.json"
  [[ ! -f "$src" ]] && { warn "mcp.json not found at $src — skipping"; return 0; }
  say "Installing mcp.json → $dst"
  if [[ -f "$dst" ]]; then
    backup_path "$dst"
  fi
  do_run cp "$src" "$dst"
  ok "Installed mcp.json (all servers disabled by default — enable what you need)"
}

# ---------------------------------------------------------------------------
# Keybindings install (keybindings.json → ~/.claude/keybindings.json)
# ---------------------------------------------------------------------------
install_keybindings() {
  local src="$1"
  local dst="$CLAUDE_HOME/keybindings.json"
  [[ ! -f "$src" ]] && { warn "keybindings.json not found at $src — skipping"; return 0; }
  say "Installing keybindings.json → $dst"
  [[ -f "$dst" ]] && backup_path "$dst"
  do_run cp "$src" "$dst"
  ok "Installed keybindings.json"
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
    local target="$CLAUDE_HOME/agents/ult-${name}.md"
    [[ -f "$target" ]] && backup_path "$target"
    do_run cp "$f" "$target"
    # Add ult- prefix only if not already present (idempotent)
    do_run sed -i "s/^name: ${name}$/name: ult-${name}/" "$target"
    ok "Installed ult-$name.md"
    _manifest_add "$manifest" "agents/ult-${name}.md"
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
    # Copy all files in the skill directory (SKILL.md + helpers like .py, .sh)
    for f in "$dir"*; do
      [[ -f "$f" ]] || continue
      local fname; fname=$(basename "$f")
      do_run cp "$f" "$target/$fname"
      _manifest_add "$manifest" "skills/$name/$fname"
    done
    ok "Installed skill: $name"
    (( count++ )) || true
  done
  shopt -u nullglob
  [[ $count -eq 0 ]] && warn "No skill directories found in $src_dir" || true
}


# ---------------------------------------------------------------------------
# Rules install
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
# Purge prior artifacts (fresh mode)
# Wipes ALL agents/skills/commands/rules so no legacy garbage survives.
# ---------------------------------------------------------------------------
purge_artifacts() {
  local manifest="$1"
  say "Purging prior claude-solo artifacts (fresh mode)"

  # Wipe all managed dirs entirely — clears third-party and legacy content too
  for dir_name in agents skills commands rules hooks; do
    if [[ -d "$CLAUDE_HOME/$dir_name" ]]; then
      backup_path "$CLAUDE_HOME/$dir_name"
      do_run rm -rf "$CLAUDE_HOME/$dir_name"
      ok "Wiped ~/.claude/$dir_name/ (backup taken)"
    fi
  done

  # Remove stale manifest (files already gone)
  [[ -f "$manifest" ]] && do_run rm -f "$manifest" && ok "Cleared manifest"

  # Legacy namespace cleanup
  for ns in ultimate ultimate-windows; do
    if [[ -d "$CLAUDE_HOME/$ns" ]]; then
      backup_path "$CLAUDE_HOME/$ns"
      do_run rm -rf "$CLAUDE_HOME/$ns"
      ok "Removed legacy ~/.claude/$ns/"
    fi
  done
}

# ---------------------------------------------------------------------------
# Manifest uninstall
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
# Wire hooks into settings.json
# NOTE: _wire_hook PREPENDS each entry. To control execution order, the hook
# that should run FIRST must be wired LAST (it ends up at array index 0).
# Current SessionStart execution order (first→last):
#   bootstrap-windows-encoding → cost-summary → quota-warmup-warn →
#   session-hud → session-start-context → morae-context → update-check
# Optional when --with-cache-fix is enabled:
#   start-cache-proxy runs before all of the above
# ---------------------------------------------------------------------------
ensure_hooks_wired() {
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

  # SessionStart — wired in REVERSE execution order (last wired = first executed)
  # update-check runs last in the session start sequence
  _wire_hook "SessionStart" \
    "update-check" \
    '{"hooks":[{"type":"command","command":"bash ~/.claude/scripts/update-check.sh","statusMessage":"Checking for updates...","timeout":15000}]}'

  _wire_hook "SessionStart" \
    "morae-context" \
    '{"hooks":[{"type":"command","command":"bash ~/.claude/scripts/morae-context.sh","statusMessage":"Checking project context...","timeout":5000}]}'

  _wire_hook "SessionStart" \
    "session-start-context" \
    '{"hooks":[{"type":"command","command":"bash ~/.claude/scripts/session-start-context.sh","statusMessage":"Loading git + sprint context...","timeout":10000}]}'

  _wire_hook "SessionStart" \
    "session-hud" \
    '{"hooks":[{"type":"command","command":"bash ~/.claude/scripts/session-hud.sh","statusMessage":"Loading session HUD...","timeout":10000}]}'

  _wire_hook "SessionStart" \
    "quota-warmup-warn" \
    '{"hooks":[{"type":"command","command":"bash ~/.claude/scripts/quota-warmup-warn.sh","statusMessage":"Checking quota window...","timeout":10000}]}'

  _wire_hook "SessionStart" \
    "cost-summary" \
    '{"hooks":[{"type":"command","command":"bash ~/.claude/scripts/cost-summary.sh","statusMessage":"Summarizing today'"'"'s token usage...","timeout":10000}]}'

  _wire_hook "SessionStart" \
    "bootstrap-windows-encoding" \
    '{"hooks":[{"type":"command","command":"bash ~/.claude/scripts/bootstrap-windows-encoding.sh","statusMessage":"Bootstrapping Windows UTF-8 encoding...","timeout":5000}]}'

  if [[ $INSTALL_CACHE_FIX -eq 1 ]]; then
    # start-cache-proxy wired LAST → prepended to front → runs FIRST
    # Ensures proxy is up before any API calls are made in the session
    _wire_hook "SessionStart" \
      "start-cache-proxy" \
      '{"hooks":[{"type":"command","command":"bash ~/.claude/scripts/start-cache-proxy.sh","statusMessage":"Starting cache proxy...","timeout":8000}]}'
  else
    _unwire_hook_by_command_fragment "SessionStart" "start-cache-proxy"
  fi

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
      if [[ ! -f "$REPO_DIR/gitignore-additions.txt" ]]; then
        warn "gitignore-additions.txt not found in $REPO_DIR, skipping .gitignore append"
      else
        backup_path "$PWD/.gitignore"
        dry_append .gitignore printf '\n# --- claude-solo additions ---\n'
        dry_append .gitignore cat "$REPO_DIR/gitignore-additions.txt"
        ok "Appended gitignore-additions.txt"
      fi
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

  # 2. Encoding check
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

  # 4. Critical hooks wired
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
  if [[ $INSTALL_CACHE_FIX -eq 1 ]]; then
    expected_hooks=("start-cache-proxy" "${expected_hooks[@]}")
  fi
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

  # 5. Hook syntax check (bash -n — no stdin hang risk)
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

  # 5b. JS hook syntax check (node --check)
  local js_pass=0 js_fail=0
  local hooks_dir="$CLAUDE_HOME/hooks"
  if command -v node >/dev/null 2>&1 && [[ -d "$hooks_dir" ]]; then
    shopt -s nullglob
    for f in "$hooks_dir/"*.js; do
      local base; base=$(basename "$f")
      local node_err
      if node_err=$(node --check "$f" 2>&1); then
        (( js_pass++ )) || true
      else
        warn "$base: JS syntax error — $node_err"
        (( js_fail++ )) || true
      fi
    done
    shopt -u nullglob
    if [[ $js_fail -gt 0 ]]; then
      warn "JS hook syntax errors: $js_fail file(s) failed node --check"
      smoke_ok=0
    else
      ok "JS hook syntax check: $js_pass hooks OK"
    fi
  fi

  # 6. Cache-fix proxy package present
  local npm_root; npm_root=$(npm root -g 2>/dev/null || true)
  if [[ $INSTALL_CACHE_FIX -eq 1 ]]; then
    if [[ -n "$npm_root" && -f "${npm_root}/claude-code-cache-fix/proxy/server.mjs" ]]; then
      ok "claude-code-cache-fix proxy installed"
      # Check ANTHROPIC_BASE_URL is set
      local proxy_url; proxy_url=$(jq -r '.env.ANTHROPIC_BASE_URL // empty' "$settings" 2>/dev/null || true)
      if [[ "$proxy_url" == "http://127.0.0.1:9801" ]]; then
        ok "ANTHROPIC_BASE_URL → proxy (:9801)"
      else
        warn "ANTHROPIC_BASE_URL not set to proxy — cache-fix may not be active"
        smoke_ok=0
      fi
    else
      warn "claude-code-cache-fix not installed — requested proxy mode is incomplete"
      warn "  Retry with npm available or omit --with-cache-fix"
      smoke_ok=0
    fi
  else
    local proxy_url; proxy_url=$(jq -r '.env.ANTHROPIC_BASE_URL // empty' "$settings" 2>/dev/null || true)
    if [[ -z "$proxy_url" ]]; then
      ok "Cache-fix proxy disabled — native Claude path preserved"
    else
      warn "ANTHROPIC_BASE_URL is still set while cache-fix is disabled"
      smoke_ok=0
    fi
  fi

  # 7. Agent, skill counts
  local agents; agents=$(ls "$CLAUDE_HOME/agents/"ult-*.md 2>/dev/null | wc -l)
  local skills; skills=$(ls -d "$CLAUDE_HOME/skills/"*/ 2>/dev/null | wc -l)
  ok "Agents: $agents/5  |  Skills: $skills"

  echo ""
  if [[ $smoke_ok -eq 1 ]]; then
    ok "All smoke checks passed"
  else
    warn "Some checks failed — review warnings above"
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
    warn "No manifest at $MANIFEST — cannot safely identify installed files"
    warn "Manually remove ~/.claude/agents/ult-*.md, ~/.claude/scripts/, etc."
  fi

  if [[ -d "$CLAUDE_HOME/scripts" ]]; then
    backup_path "$CLAUDE_HOME/scripts"
    do_run rm -rf "$CLAUDE_HOME/scripts"
    ok "Removed ~/.claude/scripts/"
  fi

  for ns in ultimate ultimate-windows; do
    [[ -d "$CLAUDE_HOME/$ns" ]] && {
      backup_path "$CLAUDE_HOME/$ns"
      do_run rm -rf "$CLAUDE_HOME/$ns"
      ok "Removed ~/.claude/$ns/"
    }
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
  say "NOTE: settings.json is NOT touched — remove hook entries manually if desired."
  exit 0
}

# ---------------------------------------------------------------------------
# Main install
# ---------------------------------------------------------------------------
run_install() {
  local src_scripts="$REPO_DIR/scripts"
  local src_hooks="$REPO_DIR/hooks"
  local src_keybindings="$REPO_DIR/keybindings.json"
  local src_mcp="$REPO_DIR/mcp.json"
  local src_agents="$REPO_DIR/agents"
  local src_skills="$REPO_DIR/skills"
  local src_rules="$REPO_DIR/rules"
  local src_settings="$REPO_DIR/settings.json"
  local src_claude_md="$REPO_DIR/CLAUDE.md"
  local src_project_override="$REPO_DIR/project-override"
  local dst_scripts="$CLAUDE_HOME/scripts"
  local dst_hooks="$CLAUDE_HOME/hooks"

  for d in "$src_scripts" "$src_hooks" "$src_agents" "$src_skills" "$src_rules"; do
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

  repair_claude_launcher
  check_prereqs
  [[ $VERIFY_ONLY -eq 1 ]] && { say "Verify-only — exiting"; exit 0; }
  [[ $PROJECT_MODE -eq 1 ]] && { install_project_override "$src_project_override"; exit 0; }
  [[ $UNINSTALL -eq 1 ]] && { uninstall; exit 0; }

  [[ "$MODE" == "fresh" ]] && purge_artifacts "$MANIFEST"

  install_scripts     "$src_scripts"     "$dst_scripts"
  install_hooks       "$src_hooks"       "$dst_hooks"
  install_keybindings "$src_keybindings"
  install_mcp         "$src_mcp"
  install_agents      "$src_agents"      "$MANIFEST"
  install_skills   "$src_skills"   "$MANIFEST"
  install_rules    "$src_rules"    "$MANIFEST"
  install_settings "$src_settings"
  ensure_hooks_wired
  install_claude_md "$src_claude_md"

  # statusline
  if [[ -f "$dst_scripts/statusline.sh" ]]; then
    [[ -f "$CLAUDE_HOME/statusline.sh" ]] && backup_path "$CLAUDE_HOME/statusline.sh"
    do_run cp "$dst_scripts/statusline.sh" "$CLAUDE_HOME/statusline.sh"
    do_run chmod +x "$CLAUDE_HOME/statusline.sh"
    ok "Installed statusline.sh → $CLAUDE_HOME/statusline.sh"
  fi

  # Reference docs
  if [[ -f "$REPO_DIR/COST-OPTIMIZATION.md" ]]; then
    do_run cp "$REPO_DIR/COST-OPTIMIZATION.md" "$CLAUDE_HOME/COST-OPTIMIZATION.md"
    ok "Installed COST-OPTIMIZATION.md → $CLAUDE_HOME/"
  fi

  # Version SHA for update-check.sh
  if command -v git >/dev/null 2>&1 && [[ -d "$REPO_DIR/.git" ]]; then
    local sha; sha=$(git -C "$REPO_DIR" rev-parse HEAD 2>/dev/null || true)
    if [[ -n "$sha" ]] && [[ $DRY_RUN -eq 0 ]]; then
      echo "$sha" > "$CLAUDE_HOME/.claude-solo-version"
      echo "$REPO_DIR" > "$CLAUDE_HOME/.claude-solo-repo"
      ok "Wrote installed version: ${sha:0:8} (repo: $REPO_DIR)"
    fi
  fi

  # Auto-install everything optional
  echo ""
  install_cache_fix
  echo ""
  install_optional_tools
  echo ""
  setup_windows_encoding

  echo ""
  smoke_test "$dst_scripts"
  echo ""
  say "Install complete."
  say "Start a fresh Claude Code session — all hooks, agents, and skills are active."
  say "Skills: /brief  /riper  /fix  /quality  /ship  /hud  /cost  /swarm ..."
  [[ $INSTALL_CACHE_FIX -eq 1 ]] && say "Cache-fix proxy mode: enabled (npm-managed local proxy)" || say "Cache-fix proxy mode: disabled (native Claude path preserved)"
  [[ $BACKUP -eq 1 && $DRY_RUN -eq 0 ]] && say "Backups at: $BACKUP_DIR"
}

# ---------------------------------------------------------------------------
# Entry point
# ---------------------------------------------------------------------------
run_install

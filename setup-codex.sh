#!/usr/bin/env bash
# claude-solo Codex setup — Linux / WSL / macOS
#
# Usage:
#   bash setup-codex.sh             -> installs globally (~/.codex)
#   bash setup-codex.sh --project   -> installs into current project (./.codex)
#   bash setup-codex.sh --both      -> installs globally and project
#   bash setup-codex.sh --uninstall -> remove managed Codex block/files

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GLOBAL_DIR="$HOME/.codex"
PROJECT_DIR="$(pwd)/.codex"

SCOPE="global"
UNINSTALL=false

for arg in "$@"; do
  case "$arg" in
    --project) SCOPE="project" ;;
    --both) SCOPE="both" ;;
    --uninstall) UNINSTALL=true ;;
  esac
done

strip_block() {
  local file="$1"
  [ -f "$file" ] || return 0
  python3 - "$file" <<'PY'
import re, sys, pathlib
p = pathlib.Path(sys.argv[1])
text = p.read_text(encoding='utf-8')
text = re.sub(r'<!-- claude-solo-codex:start -->.*?<!-- claude-solo-codex:end -->\n?', '', text, flags=re.S)
p.write_text(text.rstrip() + '\n', encoding='utf-8')
PY
}

install_to() {
  local TARGET="$1"
  echo ""
  echo "  Installing Codex to: $TARGET"

  node "$REPO_DIR/scripts/render-providers.mjs" >/dev/null

  mkdir -p "$TARGET/skills" "$TARGET/agents" "$TARGET/hooks"

  # Install generated skills and agents
  rm -rf "$TARGET/skills/mm-"* 2>/dev/null || true
  for agent in "$REPO_DIR"/src/codex/agents/*.toml; do
    [ -f "$agent" ] || continue
    rm -f "$TARGET/agents/$(basename "$agent")"
  done
  cp -R "$REPO_DIR/src/codex/skills/." "$TARGET/skills/"
  cp "$REPO_DIR/src/codex/agents/"*.toml "$TARGET/agents/"
  cp "$REPO_DIR/src/codex/hooks/mm-hook.js" "$TARGET/hooks/mm-hook.js"
  chmod +x "$TARGET/hooks/mm-hook.js"

  # AGENTS.md managed block append/replace
  local AGENTS_FILE="$TARGET/AGENTS.md"
  touch "$AGENTS_FILE"
  strip_block "$AGENTS_FILE"
  cat "$REPO_DIR/src/codex/AGENTS.md" >> "$AGENTS_FILE"

  # Config: safe default is sidecar file if config already exists
  if [ -f "$TARGET/config.toml" ]; then
    cp "$REPO_DIR/src/codex/config.toml" "$TARGET/config.claude-solo.toml"
    echo "    ✓ Wrote config sidecar: $TARGET/config.claude-solo.toml"
  else
    cp "$REPO_DIR/src/codex/config.toml" "$TARGET/config.toml"
    echo "    ✓ Wrote config: $TARGET/config.toml"
  fi

  # MCP template
  if [ ! -f "$TARGET/mcp.json" ]; then
    cp "$REPO_DIR/src/codex/mcp.json" "$TARGET/mcp.json"
  fi

  echo "$REPO_DIR" > "$TARGET/.claude-solo-source"
  echo "    ✓ Installed Codex skills, agents, wrappers"
}

uninstall_from() {
  local TARGET="$1"
  echo ""
  echo "  Uninstalling Codex from: $TARGET"

  strip_block "$TARGET/AGENTS.md"
  rm -rf "$TARGET/skills/mm-"* 2>/dev/null || true
  for agent in "$REPO_DIR"/src/codex/agents/*.toml; do
    [ -f "$agent" ] || continue
    rm -f "$TARGET/agents/$(basename "$agent")"
  done
  rm -f "$TARGET/hooks/mm-hook.js"
  rm -f "$TARGET/config.claude-solo.toml"
  rm -f "$TARGET/.claude-solo-source"

  echo "    ✓ Done"
}

echo ""
echo "claude-solo codex setup"

if $UNINSTALL; then
  if [ "$SCOPE" = "project" ]; then
    uninstall_from "$PROJECT_DIR"
  elif [ "$SCOPE" = "both" ]; then
    uninstall_from "$GLOBAL_DIR"
    uninstall_from "$PROJECT_DIR"
  else
    uninstall_from "$GLOBAL_DIR"
  fi
else
  if [ "$SCOPE" = "project" ]; then
    install_to "$PROJECT_DIR"
  elif [ "$SCOPE" = "both" ]; then
    install_to "$GLOBAL_DIR"
    install_to "$PROJECT_DIR"
  else
    install_to "$GLOBAL_DIR"
  fi
fi

echo ""
echo "Use generated Codex skills: \$mm-brief, \$mm-plan, ..."
echo "Hook wrapper: node .codex/hooks/mm-hook.js <event>"

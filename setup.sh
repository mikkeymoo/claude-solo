#!/usr/bin/env bash
# claude-solo setup — Linux / WSL / macOS
#
# Usage:
#   bash setup.sh             → installs globally (~/.claude)  [default]
#   bash setup.sh --project   → installs into current project (./.claude)
#   bash setup.sh --both      → installs globally AND into current project
#   bash setup.sh --uninstall → removes from global
#   bash setup.sh --uninstall --project → removes from project
#   bash setup.sh --no-backup → skip automatic backup of existing files

set -e

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GLOBAL_DIR="$HOME/.claude"
PROJECT_DIR="$(pwd)/.claude"

MARKER_START="<!-- claude-solo:start -->"
MARKER_END="<!-- claude-solo:end -->"

SCOPE="global"
UNINSTALL=false
NO_BACKUP=false

for arg in "$@"; do
    case $arg in
        --project)    SCOPE="project" ;;
        --both)       SCOPE="both" ;;
        --uninstall)  UNINSTALL=true ;;
        --no-backup)  NO_BACKUP=true ;;
    esac
done

# ── Backup function ──────────────────────────────────────────────────────
backup_existing() {
    local TARGET="$1"
    if $NO_BACKUP; then return; fi

    local BACKUP_DIR="$TARGET/.claude-solo-backup/$(date +%Y%m%d-%H%M%S)"
    local BACKED_UP=false

    # Backup hooks that would be overwritten
    for f in "$REPO_DIR/src/hooks/"*.js; do
        [ -f "$f" ] || continue
        local basename="$(basename "$f")"
        local existing="$TARGET/hooks/$basename"
        if [ -f "$existing" ]; then
            if ! $BACKED_UP; then
                mkdir -p "$BACKUP_DIR/hooks" "$BACKUP_DIR/agents" "$BACKUP_DIR/skills"
                BACKED_UP=true
            fi
            cp "$existing" "$BACKUP_DIR/hooks/$basename"
        fi
    done

    # Backup agents that would be overwritten
    for f in "$REPO_DIR/src/agents/"*.md; do
        [ -f "$f" ] || continue
        local basename="$(basename "$f")"
        local existing="$TARGET/agents/$basename"
        if [ -f "$existing" ]; then
            if ! $BACKED_UP; then
                mkdir -p "$BACKUP_DIR/hooks" "$BACKUP_DIR/agents" "$BACKUP_DIR/skills"
                BACKED_UP=true
            fi
            cp "$existing" "$BACKUP_DIR/agents/$basename"
        fi
    done

    # Backup skills that would be overwritten
    for f in "$REPO_DIR/src/skills/"*.md; do
        [ -f "$f" ] || continue
        local basename="$(basename "$f")"
        local existing="$TARGET/skills/$basename"
        if [ -f "$existing" ]; then
            if ! $BACKED_UP; then
                mkdir -p "$BACKUP_DIR/hooks" "$BACKUP_DIR/agents" "$BACKUP_DIR/skills"
                BACKED_UP=true
            fi
            cp "$existing" "$BACKUP_DIR/skills/$basename"
        fi
    done

    # Backup settings.json and CLAUDE.md
    if [ -f "$TARGET/settings.json" ]; then
        if ! $BACKED_UP; then
            mkdir -p "$BACKUP_DIR"
            BACKED_UP=true
        fi
        cp "$TARGET/settings.json" "$BACKUP_DIR/settings.json"
    fi
    if [ -f "$TARGET/CLAUDE.md" ]; then
        if ! $BACKED_UP; then
            mkdir -p "$BACKUP_DIR"
            BACKED_UP=true
        fi
        cp "$TARGET/CLAUDE.md" "$BACKUP_DIR/CLAUDE.md"
    fi

    if $BACKED_UP; then
        echo "    📦 Backup saved to: $BACKUP_DIR"
    fi
}

# ── Core install function ─────────────────────────────────────────────────
install_to() {
    local TARGET="$1"
    echo ""
    echo "  Installing to: $TARGET"
    echo ""

    # Backup existing files before overwriting
    backup_existing "$TARGET"

    mkdir -p "$TARGET/agents" "$TARGET/skills" "$TARGET/hooks" "$TARGET/logs"

    # CLAUDE.md
    local CLAUDE_MD="$TARGET/CLAUDE.md"
    if [ -f "$CLAUDE_MD" ]; then
        echo "    Found existing CLAUDE.md — appending"
        # Strip previous claude-solo block
        python3 -c "
import re, sys
with open(sys.argv[1], 'r', encoding='utf-8') as f:
    c = f.read()
c = re.sub(r'<!-- claude-solo:start -->.*?<!-- claude-solo:end -->\n?', '', c, flags=re.DOTALL)
with open(sys.argv[1], 'w', encoding='utf-8') as f:
    f.write(c)
" "$CLAUDE_MD"
    fi

    # Append our block
    python3 -c "
import sys
existing = open(sys.argv[1]).read().rstrip() if __import__('os').path.exists(sys.argv[1]) else ''
our = open(sys.argv[2]).read()
result = existing + '\n\n<!-- claude-solo:start -->\n' + our + '\n<!-- claude-solo:end -->\n'
open(sys.argv[1], 'w', encoding='utf-8').write(result)
" "$CLAUDE_MD" "$REPO_DIR/src/CLAUDE.md"
    echo "    ✓ CLAUDE.md"

    # Agents
    for f in "$REPO_DIR/src/agents/"*.md; do
        [ -f "$f" ] || continue
        cp "$f" "$TARGET/agents/$(basename "$f")"
        echo "    ✓ Agent: $(basename "$f")"
    done

    # Skills
    for f in "$REPO_DIR/src/skills/"*.md; do
        [ -f "$f" ] || continue
        cp "$f" "$TARGET/skills/$(basename "$f")"
        echo "    ✓ Skill: $(basename "$f")"
    done

    # Hooks — global only (hooks run globally)
    if [ "$TARGET" = "$GLOBAL_DIR" ]; then
        for f in "$REPO_DIR/src/hooks/"*.js; do
            [ -f "$f" ] || continue
            cp "$f" "$TARGET/hooks/$(basename "$f")"
            chmod +x "$TARGET/hooks/$(basename "$f")"
            echo "    ✓ Hook: $(basename "$f")"
        done
        # Ensure hooks are treated as ES modules
        cp "$REPO_DIR/src/hooks/package.json" "$TARGET/hooks/package.json"
        echo "    ✓ hooks/package.json (ES module support)"
        # Save repo path so /mm-update knows where to pull from
        echo "$REPO_DIR" > "$TARGET/.claude-solo-source"
        echo "    ✓ Source path saved (.claude-solo-source)"
    fi

    # MCP template (copy but don't overwrite)
    if [ -f "$REPO_DIR/src/mcp.json" ] && [ ! -f "$TARGET/mcp.json" ]; then
        cp "$REPO_DIR/src/mcp.json" "$TARGET/mcp.json"
        echo "    ✓ MCP template (mcp.json) — enable servers you need"
    fi

    # Status line config (copy but don't overwrite)
    if [ -f "$REPO_DIR/src/settings/statusline.json" ] && [ ! -f "$TARGET/statusline.json" ]; then
        cp "$REPO_DIR/src/settings/statusline.json" "$TARGET/statusline.json"
        echo "    ✓ Status line config (statusline.json)"
    fi

    # settings.json (merge hooks only)
    local SETTINGS="$TARGET/settings.json"
    python3 - "$SETTINGS" "$REPO_DIR/src/settings/settings.json" <<'PYEOF'
import json, sys, os
settings_path, our_path = sys.argv[1], sys.argv[2]
with open(our_path) as f:
    our = json.load(f)
if os.path.exists(settings_path):
    try:
        existing = json.load(open(settings_path))
    except Exception:
        existing = {}
else:
    existing = {}
if "hooks" not in existing:
    existing["hooks"] = {}
for k, v in our.get("hooks", {}).items():
    if k not in existing["hooks"]:
        existing["hooks"][k] = v
with open(settings_path, "w") as f:
    json.dump(existing, f, indent=2)
print("    ✓ settings.json")
PYEOF
}

# ── Uninstall function ────────────────────────────────────────────────────
uninstall_from() {
    local TARGET="$1"
    echo ""
    echo "  Uninstalling from: $TARGET"

    local CLAUDE_MD="$TARGET/CLAUDE.md"
    if [ -f "$CLAUDE_MD" ]; then
        python3 -c "
import re, sys
with open(sys.argv[1], 'r', encoding='utf-8') as f:
    c = f.read()
c = re.sub(r'<!-- claude-solo:start -->.*?<!-- claude-solo:end -->\n?', '', c, flags=re.DOTALL)
with open(sys.argv[1], 'w', encoding='utf-8') as f:
    f.write(c.rstrip() + '\n')
" "$CLAUDE_MD"
        echo "    ✓ Removed from CLAUDE.md"
    fi

    echo "    ✓ Done. Your own files are untouched."
}

# ── Main ─────────────────────────────────────────────────────────────────
echo ""
echo "claude-solo"

if $UNINSTALL; then
    if [ "$SCOPE" = "project" ]; then
        uninstall_from "$PROJECT_DIR"
    else
        uninstall_from "$GLOBAL_DIR"
    fi
elif [ "$SCOPE" = "project" ]; then
    install_to "$PROJECT_DIR"
    echo ""
    echo "  Installed to project only (./.claude)"
elif [ "$SCOPE" = "both" ]; then
    install_to "$GLOBAL_DIR"
    install_to "$PROJECT_DIR"
    echo ""
    echo "  Installed globally AND to project"
else
    install_to "$GLOBAL_DIR"
    echo ""
    echo "  Installed globally (~/.claude)"
fi

echo ""
echo "Open Claude Code and use:"
echo "  /brief  /plan  /build  /review  /test  /verify  /ship  /retro"
echo ""
echo "Power skills: /handoff  /release  /incident  /docsync  /doctor  /verify"
echo ""

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
export PYTHONUTF8=1

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
    for f in "$REPO_DIR/src/hooks/"*.js "$REPO_DIR/src/hooks/"*.cjs; do
        [ -f "$f" ] || continue
        local basename="$(basename "$f")"
        local existing="$TARGET/hooks/$basename"
        if [ -f "$existing" ]; then
            if ! $BACKED_UP; then
                mkdir -p "$BACKUP_DIR/hooks" "$BACKUP_DIR/agents" "$BACKUP_DIR/skills" "$BACKUP_DIR/commands/mm"
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
                mkdir -p "$BACKUP_DIR/hooks" "$BACKUP_DIR/agents" "$BACKUP_DIR/skills" "$BACKUP_DIR/commands/mm"
                BACKED_UP=true
            fi
            cp "$existing" "$BACKUP_DIR/agents/$basename"
        fi
    done

    # Backup commands that would be overwritten
    for f in "$REPO_DIR/src/commands/mm/"*.md; do
        [ -f "$f" ] || continue
        local basename="$(basename "$f")"
        local existing="$TARGET/commands/mm/$basename"
        if [ -f "$existing" ]; then
            if ! $BACKED_UP; then
                mkdir -p "$BACKUP_DIR/hooks" "$BACKUP_DIR/agents" "$BACKUP_DIR/skills" "$BACKUP_DIR/commands/mm"
                BACKED_UP=true
            fi
            cp "$existing" "$BACKUP_DIR/commands/mm/$basename"
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

    # Render provider artifacts from shared canonical source
    node "$REPO_DIR/scripts/render-providers.mjs" >/dev/null

    # Backup existing files before overwriting
    backup_existing "$TARGET"

    mkdir -p "$TARGET/agents" "$TARGET/commands/mm" "$TARGET/hooks" "$TARGET/logs" "$TARGET/rules"

    # CLAUDE.md
    local CLAUDE_MD="$TARGET/CLAUDE.md"
    if [ -f "$CLAUDE_MD" ]; then
        echo "    Found existing CLAUDE.md — appending"
        # Strip previous claude-solo block
        python -c "
import re, sys
with open(sys.argv[1], 'r', encoding='utf-8') as f:
    c = f.read()
c = re.sub(r'<!-- claude-solo:start -->.*?<!-- claude-solo:end -->\n?', '', c, flags=re.DOTALL)
with open(sys.argv[1], 'w', encoding='utf-8') as f:
    f.write(c)
" "$CLAUDE_MD"
    fi

    # Append our block
    python -c "
import sys
existing = open(sys.argv[1], encoding='utf-8').read().rstrip() if __import__('os').path.exists(sys.argv[1]) else ''
our = open(sys.argv[2]).read()
result = existing + '\n\n<!-- claude-solo:start -->\n' + our + '\n<!-- claude-solo:end -->\n'
open(sys.argv[1], 'w', encoding='utf-8').write(result)
" "$CLAUDE_MD" "$REPO_DIR/src/CLAUDE.md"
    echo "    ✓ CLAUDE.md"

    # For project installs, skip agents/commands if global is already installed
    # (they're already available globally — project copies would create duplicates)
    local SKIP_AGENTS_COMMANDS=false
    if [ "$TARGET" != "$GLOBAL_DIR" ] && [ -f "$GLOBAL_DIR/commands/mm/brief.md" ]; then
        SKIP_AGENTS_COMMANDS=true
        echo "    ℹ  Global install detected — skipping agents/commands (already available globally)" >&2
    fi

    # Agents
    if ! $SKIP_AGENTS_COMMANDS; then
        for f in "$REPO_DIR/src/agents/"*.md; do
            [ -f "$f" ] || continue
            cp "$f" "$TARGET/agents/$(basename "$f")"
            echo "    ✓ Agent: $(basename "$f")"
        done
    fi

    # Commands
    if ! $SKIP_AGENTS_COMMANDS; then
        for f in "$REPO_DIR/src/commands/mm/"*.md; do
            [ -f "$f" ] || continue
            cp "$f" "$TARGET/commands/mm/$(basename "$f")"
            echo "    ✓ Command: $(basename "$f")"
        done
    fi
    # Remove old skills dir if it exists from previous installs
    if [ -d "$TARGET/skills" ]; then
        rm -f "$TARGET/skills/mm-"*.md
    fi

    # Rules (starter rule files — copy, never overwrite user's rules)
    for f in "$REPO_DIR/src/rules/"*.md; do
        [ -f "$f" ] || continue
        local basename="$(basename "$f")"
        local dst="$TARGET/rules/$basename"
        if [ ! -f "$dst" ]; then
            cp "$f" "$dst"
            echo "    ✓ Rule: $basename"
        fi
    done

    # Hooks — global only (hooks run globally)
    if [ "$TARGET" = "$GLOBAL_DIR" ]; then
        # Copy .js hooks
        for f in "$REPO_DIR/src/hooks/"*.js; do
            [ -f "$f" ] || continue
            cp "$f" "$TARGET/hooks/$(basename "$f")"
            chmod +x "$TARGET/hooks/$(basename "$f")"
            echo "    ✓ Hook: $(basename "$f")"
        done
        # Copy .cjs hooks (LSP enforcement guards — CommonJS modules)
        for f in "$REPO_DIR/src/hooks/"*.cjs; do
            [ -f "$f" ] || continue
            cp "$f" "$TARGET/hooks/$(basename "$f")"
            chmod +x "$TARGET/hooks/$(basename "$f")"
            echo "    ✓ Hook: $(basename "$f")"
        done
        # Copy lib/ shared helpers
        mkdir -p "$TARGET/hooks/lib"
        for f in "$REPO_DIR/src/hooks/lib/"*; do
            [ -f "$f" ] || continue
            cp "$f" "$TARGET/hooks/lib/$(basename "$f")"
            echo "    ✓ Hook lib: $(basename "$f")"
        done
        # Copy swarm hooks
        mkdir -p "$TARGET/hooks/swarm"
        for f in "$REPO_DIR/src/hooks/swarm/"*.js; do
            [ -f "$f" ] || continue
            cp "$f" "$TARGET/hooks/swarm/$(basename "$f")"
            chmod +x "$TARGET/hooks/swarm/$(basename "$f")"
            echo "    ✓ Hook swarm: $(basename "$f")"
        done
        cp "$REPO_DIR/src/hooks/swarm/package.json" "$TARGET/hooks/swarm/package.json" 2>/dev/null || true
        # Ensure hooks are treated as ES modules
        cp "$REPO_DIR/src/hooks/package.json" "$TARGET/hooks/package.json"
        echo "    ✓ hooks/package.json (ES module support)"
        # Save repo path so /mm-update knows where to pull from
        echo "$REPO_DIR" > "$TARGET/.claude-solo-source"
        echo "    ✓ Source path saved (.claude-solo-source)"
    fi

    # MCP template — project/discovery list (copy but don't overwrite)
    if [ -f "$REPO_DIR/src/mcp.json" ] && [ ! -f "$TARGET/mcp.json" ]; then
        cp "$REPO_DIR/src/mcp.json" "$TARGET/mcp.json"
        echo "    ✓ MCP template (mcp.json) — enable servers you need"
    fi

    # Global active MCP config — ~/.claude/.mcp.json (Serena + Playwright enabled)
    if [ "$TARGET" = "$GLOBAL_DIR" ] && [ -f "$REPO_DIR/src/settings/mcp-global.json" ]; then
        local GLOBAL_MCP="$TARGET/.mcp.json"
        if [ ! -f "$GLOBAL_MCP" ]; then
            cp "$REPO_DIR/src/settings/mcp-global.json" "$GLOBAL_MCP"
            echo "    ✓ Global MCP config (~/.claude/.mcp.json) — Serena + Playwright enabled"
        else
            echo "    ℹ  ~/.claude/.mcp.json exists — skipping (edit manually to add Serena/Playwright)"
        fi
    fi

    # Status line shell script (global only; bash required)
    if [ "$TARGET" = "$GLOBAL_DIR" ] && [ -f "$REPO_DIR/src/settings/statusline.sh" ]; then
        cp "$REPO_DIR/src/settings/statusline.sh" "$TARGET/statusline.sh"
        chmod +x "$TARGET/statusline.sh"
        echo "    ✓ Status line script (statusline.sh) — requires bash + jq"
    fi

    # Safe-mode settings (global only)
    if [ "$TARGET" = "$GLOBAL_DIR" ] && [ -f "$REPO_DIR/src/settings/settings-safe.json" ]; then
        cp "$REPO_DIR/src/settings/settings-safe.json" "$TARGET/settings-safe.json"
        echo "    ✓ Safe-mode settings (settings-safe.json) — use: claude --safe"
    fi

    # uv (Python package manager — required for Serena MCP)
    if [ "$TARGET" = "$GLOBAL_DIR" ]; then
        if ! command -v uv >/dev/null 2>&1; then
            echo "    Installing uv (required for Serena MCP)..."
            curl -LsSf https://astral.sh/uv/install.sh | sh
            # Reload PATH so uv is available immediately
            export PATH="$HOME/.local/bin:$HOME/.cargo/bin:$PATH"
            if command -v uv >/dev/null 2>&1; then
                echo "    ✓ uv installed ($(uv --version))"
            else
                echo "    ⚠  uv install may need a shell restart — run: source ~/.bashrc"
            fi
        else
            echo "    ✓ uv already installed ($(uv --version))"
        fi
    fi

    # claude-code-cache-fix — install if missing, then install wrapper
    if [ "$TARGET" = "$GLOBAL_DIR" ] && [ -f "$REPO_DIR/src/bin/claude" ]; then
        local WRAPPER_SRC="$REPO_DIR/src/bin/claude"
        local WRAPPER_DST="$HOME/.local/bin/claude"
        # Detect npm global prefix (handles nvm, brew, system npm)
        local NPM_PREFIX
        NPM_PREFIX="$(npm config get prefix 2>/dev/null || echo "$HOME/.npm-global")"
        local CACHE_FIX_PKG="$NPM_PREFIX/lib/node_modules/claude-code-cache-fix/preload.mjs"
        if [ ! -f "$CACHE_FIX_PKG" ]; then
            echo "    Installing claude-code-cache-fix..."
            npm install -g claude-code-cache-fix 2>&1 | grep -E 'added|error|warn' || true
            # Recompute after install (prefix may be set via .npmrc)
            CACHE_FIX_PKG="$(npm config get prefix)/lib/node_modules/claude-code-cache-fix/preload.mjs"
        fi
        if [ -f "$CACHE_FIX_PKG" ]; then
            mkdir -p "$HOME/.local/bin"
            if [ -f "$WRAPPER_DST" ]; then
                if ! diff -q "$WRAPPER_SRC" "$WRAPPER_DST" >/dev/null 2>&1; then
                    cp "$WRAPPER_DST" "$WRAPPER_DST.bak"
                    echo "    📦 Backed up existing wrapper to ~/.local/bin/claude.bak"
                fi
            fi
            cp "$WRAPPER_SRC" "$WRAPPER_DST"
            chmod +x "$WRAPPER_DST"
            echo "    ✓ claude-code-cache-fix installed + wrapper (~/.local/bin/claude)"
        else
            echo "    ⚠  claude-code-cache-fix install failed — wrapper skipped"
            echo "       Run manually: npm install -g claude-code-cache-fix"
        fi
    fi

    # settings.json (merge — add missing keys, never overwrite user values)
    local SETTINGS="$TARGET/settings.json"
    python - "$SETTINGS" "$REPO_DIR/src/settings/settings.json" <<'PYEOF'
import json, sys, os
settings_path, our_path = sys.argv[1], sys.argv[2]
with open(our_path) as f:
    our = json.load(f)
if os.path.exists(settings_path):
    try:
        existing = json.load(open(settings_path, encoding='utf-8'))
    except Exception:
        existing = {}
else:
    existing = {}
# Merge top-level keys that don't exist yet (never overwrite user values)
for key in ("model", "effortLevel", "statusLine", "permissions", "worktree"):
    if key not in existing and key in our:
        existing[key] = our[key]
# Merge hooks: add event keys that don't exist yet
if "hooks" not in existing:
    existing["hooks"] = {}
for k, v in our.get("hooks", {}).items():
    if k not in existing["hooks"]:
        existing["hooks"][k] = v
with open(settings_path, "w") as f:
    json.dump(existing, f, indent=2)
print("    [OK] settings.json")
PYEOF
}

# ── Uninstall function ────────────────────────────────────────────────────
uninstall_from() {
    local TARGET="$1"
    local IS_GLOBAL=false
    [ "$TARGET" = "$GLOBAL_DIR" ] && IS_GLOBAL=true
    echo ""
    echo "  Uninstalling from: $TARGET"

    # Strip CLAUDE.md block
    local CLAUDE_MD="$TARGET/CLAUDE.md"
    if [ -f "$CLAUDE_MD" ]; then
        python -c "
import re, sys
with open(sys.argv[1], 'r', encoding='utf-8') as f:
    c = f.read()
c = re.sub(r'<!-- claude-solo:start -->.*?<!-- claude-solo:end -->\n?', '', c, flags=re.DOTALL)
with open(sys.argv[1], 'w', encoding='utf-8') as f:
    f.write(c.rstrip() + '\n')
" "$CLAUDE_MD"
        echo "    ✓ Removed from CLAUDE.md"
    fi

    # Remove installed agents
    for f in "$REPO_DIR/src/agents/"*.md; do
        [ -f "$f" ] || continue
        local target_file="$TARGET/agents/$(basename "$f")"
        if [ -f "$target_file" ]; then
            rm -f "$target_file"
            echo "    ✓ Removed agent: $(basename "$f")"
        fi
    done

    # Remove installed commands
    for f in "$REPO_DIR/src/commands/mm/"*.md; do
        [ -f "$f" ] || continue
        local target_file="$TARGET/commands/mm/$(basename "$f")"
        if [ -f "$target_file" ]; then
            rm -f "$target_file"
            echo "    ✓ Removed command: $(basename "$f")"
        fi
    done

    # Remove installed hooks (global only)
    if $IS_GLOBAL; then
        for f in "$REPO_DIR/src/hooks/"*.js "$REPO_DIR/src/hooks/"*.cjs; do
            [ -f "$f" ] || continue
            local target_file="$TARGET/hooks/$(basename "$f")"
            if [ -f "$target_file" ]; then
                rm -f "$target_file"
                echo "    ✓ Removed hook: $(basename "$f")"
            fi
        done
        for f in "$REPO_DIR/src/hooks/lib/"*; do
            [ -f "$f" ] || continue
            rm -f "$TARGET/hooks/lib/$(basename "$f")"
        done
        for f in "$REPO_DIR/src/hooks/swarm/"*.js; do
            [ -f "$f" ] || continue
            rm -f "$TARGET/hooks/swarm/$(basename "$f")"
        done
        rm -f "$TARGET/hooks/package.json"
        rm -f "$TARGET/.claude-solo-source"
        rm -f "$TARGET/settings-safe.json"
        echo "    ✓ Removed hooks/package.json, .claude-solo-source, settings-safe.json"
        # Remove wrapper only if it matches ours (don't delete user's custom wrapper)
        local WRAPPER_DST="$HOME/.local/bin/claude"
        if [ -f "$WRAPPER_DST" ] && grep -q "claude-solo" "$WRAPPER_DST" 2>/dev/null; then
            rm -f "$WRAPPER_DST"
            echo "    ✓ Removed wrapper (~/.local/bin/claude)"
        fi
    fi

    echo "    ✓ Done. Your customized files (rules, mcp.json, custom agents) are untouched."
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
echo "  /mm:brief  /mm:plan  /mm:build  /mm:review  /mm:test  /mm:verify  /mm:ship  /mm:retro"
echo ""
echo "Power:   /mm:handoff  /mm:release  /mm:incident  /mm:docsync  /mm:doctor"
echo "New:     /mm:map  /mm:deps  /mm:a11y  /mm:migrate  /mm:onboard  /mm:stale"
echo ""
echo "Safe mode for untrusted repos:  claude --safe"
echo ""

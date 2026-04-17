# Ultimate Claude Code Config — Quickstart

Deploy this `ultimate/` build to a new machine or a new project in **under 5 minutes**.

Target audience: **solo developer**, Claude Code v2.1.105+, existing `claude` wrapper at `~/.local/bin/claude` with `claude-code-cache-fix` preload.

---

## What you get

- `settings.json` — user-scope (`~/.claude/settings.json`)
- `project-override/settings.json` — project-scope (`.claude/settings.json`)
- `CLAUDE.md` — master instruction file
- 5 subagents: `code-reviewer`, `researcher`, `refactor-agent`, `db-reader`, `deploy-guard`
- 4 skills: `riper`, `daily-brief`, `tech-debt`, `security-review`
- 7 hook scripts: bash validator, readonly SQL validator, session-start context, post-edit LSP heal, desktop notify, pre-compact checkpoint, **LSP output compressor** (trims verbose `mcp__cclsp__*` responses — find_references, diagnostics, hover — before they hit the agent context)
- `gitignore-additions.txt` — append to your project `.gitignore`

---

## Prerequisites (verify once per machine)

```bash
claude --version                       # expect >= 2.1.105
command -v jq                          # required by every hook script
command -v gh                          # optional (used by session-start + deploy-guard)
node -v                                # >= 18 (for cache-fix preload)
```

Install missing pieces:

```bash
# jq
sudo dnf install jq        # Fedora (your OS)
# or: sudo apt install jq
# or: brew install jq

# gh (GitHub CLI)
sudo dnf install gh        # Fedora
# or: brew install gh
```

Optional but recommended:
```bash
npm install -g prettier typescript        # for the post-format-and-heal hook
pip install --user ruff pyright           # Python formatting + LSP diagnostics
```

---

## Option A — Fresh install (no existing Claude Code config)

```bash
cd /home/michael/code/claude-solo    # repo with the ultimate/ folder

# 1. User-scope directory
mkdir -p ~/.claude/agents ~/.claude/skills ~/.claude/ultimate/scripts

# 2. Hook scripts → NEW location so we don't collide with any existing ~/.claude/hooks/
cp ultimate/scripts/*.sh ~/.claude/ultimate/scripts/
chmod +x ~/.claude/ultimate/scripts/*.sh

# 3. Settings
cp ultimate/settings.json ~/.claude/settings.json

# 4. Master CLAUDE.md
cp ultimate/CLAUDE.md ~/.claude/CLAUDE.md

# 5. Subagents
cp ultimate/agents/*.md ~/.claude/agents/

# 6. Skills — each skill is a directory containing SKILL.md
for skill in riper daily-brief tech-debt security-review; do
  mkdir -p ~/.claude/skills/$skill
  cp ultimate/skills/$skill/SKILL.md ~/.claude/skills/$skill/
done

# 7. Smoke test — start a fresh session
claude
# In the session: run `/agents` — you should see code-reviewer, researcher, refactor-agent, db-reader, deploy-guard
# Run `/skills` — you should see riper, daily-brief, tech-debt, security-review
```

---

## Option B — Merge with existing claude-solo install

You already have `~/.claude/hooks/`, `~/.claude/agents/`, `~/.claude/skills/` from `bash setup.sh`. This option **does not touch those** — it drops the ultimate build into parallel namespaces so you can test without losing your existing config.

```bash
cd /home/michael/code/claude-solo

# 1. Hook scripts go to a NAMESPACED dir (not ~/.claude/hooks/)
mkdir -p ~/.claude/ultimate/scripts
cp ultimate/scripts/*.sh ~/.claude/ultimate/scripts/
chmod +x ~/.claude/ultimate/scripts/*.sh

# 2. Agents — use a prefix to avoid collision with claude-solo's 28 agents
for a in ultimate/agents/*.md; do
  name=$(basename "$a" .md)
  cp "$a" ~/.claude/agents/ult-$name.md
  # Also update the `name:` field inside each to match the prefix
  sed -i "s/^name: $name$/name: ult-$name/" ~/.claude/agents/ult-$name.md
done

# 3. Skills — namespace under ult/
mkdir -p ~/.claude/skills/ult
for skill in riper daily-brief tech-debt security-review; do
  mkdir -p ~/.claude/skills/ult/$skill
  cp ultimate/skills/$skill/SKILL.md ~/.claude/skills/ult/$skill/
done

# 4. Settings — DO NOT overwrite. Diff and merge manually:
diff ~/.claude/settings.json ultimate/settings.json
# Merge the keys you want into ~/.claude/settings.json with your editor.

# 5. CLAUDE.md — DO NOT overwrite your existing one. Your current setup.sh
#    appends inside <!-- claude-solo:start/end --> markers. You can append the
#    ultimate CLAUDE.md content inside a similar <!-- ultimate:start/end --> block:
echo "
<!-- ultimate:start -->
$(cat ultimate/CLAUDE.md)
<!-- ultimate:end -->
" >> ~/.claude/CLAUDE.md
```

---

## Project-scope install (per-repo override)

After user-scope is set up, drop the project override in ANY repo you want stricter rules for:

```bash
cd /path/to/target/repo
mkdir -p .claude

cp /home/michael/code/claude-solo/ultimate/project-override/settings.json .claude/settings.json

# Append the gitignore stanza
cat /home/michael/code/claude-solo/ultimate/gitignore-additions.txt >> .gitignore

# Commit so future-you and CI see the same rules
git add .claude/settings.json .gitignore
git commit -m "chore: add ultimate claude config project overrides"
```

---

## Verification checklist

After install, in a fresh `claude` session:

```
/agents
```
→ Expect: `code-reviewer`, `researcher`, `refactor-agent`, `db-reader`, `deploy-guard` (or `ult-*` prefixed in Option B).

```
/skills
```
→ Expect: `riper`, `daily-brief`, `tech-debt`, `security-review`.

**Smoke-test the bash guard:**
```
Ask Claude to run: rm -rf /tmp/bogus-test
```
→ Should be blocked with "rm -rf pattern blocked" as the reason. If it runs, the hook is not wired.

**Smoke-test post-format:**
```
Ask Claude to edit a .ts or .py file in a broken way (missing import, type error)
```
→ Should auto-format, then block the next tool call with the LSP/tsc/pyright error. If it silently continues, the hook is not wired or the language server isn't installed.

**Smoke-test session-start:**
```
Exit Claude and re-enter in a git repo
```
→ First message from Claude should include the branch name, recent commits, and any open PRs.

---

## Pair with lean-ctx (optional, recommended)

The ultimate build includes `compress-lsp-output.sh` which trims verbose LSP output — but the **shell / file-read side** is left untouched. For that, install [lean-ctx](https://github.com/yvgude/lean-ctx) — a Rust binary that compresses shell output (git, grep, ls, cargo, npm, test runners) and caches file reads before they reach the LLM. Claims 60-95% token reduction on those paths.

The two are complementary:

| Layer | Ultimate | lean-ctx |
|---|---|---|
| LSP / MCP tool output | ✅ `compress-lsp-output.sh` | ❌ |
| Shell output (git, rg, cargo) | ❌ | ✅ shell hook |
| File reads (cached) | ❌ | ✅ MCP server |
| PreToolUse safety (rm -rf, DROP TABLE) | ✅ `validate-bash.sh` | ❌ |
| Post-edit LSP diagnostics gate | ✅ `post-format-and-heal.sh` | ❌ |

Install lean-ctx alongside:
```bash
curl -fsSL https://leanctx.com/install.sh | sh
lean-ctx setup              # auto-configures Claude Code
lean-ctx doctor             # verify
```

Check for conflicts after install:
```bash
jq . ~/.claude/settings.json    # should still parse
```
Lean-ctx's `setup` merges non-destructively; ultimate's hooks live under `~/.claude/ultimate/scripts/` so they won't collide with lean-ctx's additions.

---

## Troubleshooting

| Symptom | Likely cause | Fix |
|---|---|---|
| Hooks don't fire at all | `settings.json` not valid JSON | `jq . ~/.claude/settings.json` to check |
| "jq: command not found" in transcript | `jq` missing on PATH | Install `jq` |
| validate-bash blocks legit commands | Pattern too aggressive | Edit the specific `grep -E` line in `~/.claude/ultimate/scripts/validate-bash.sh` |
| Notification silent | `notify-send` missing | Install `libnotify` (`sudo dnf install libnotify`) |
| post-format blocks every edit | `tsc` / `pyright` strict diagnostics | Loosen `tsconfig.json` OR comment out the diagnostics block in `post-format-and-heal.sh` |
| `deploy-guard` runs when you didn't ask | Project override's `Agent(deploy-guard)` deny not in effect | Ensure `.claude/settings.json` was copied into the target repo |

---

## Uninstall

```bash
rm -rf ~/.claude/ultimate/
rm ~/.claude/agents/code-reviewer.md ~/.claude/agents/researcher.md \
   ~/.claude/agents/refactor-agent.md ~/.claude/agents/db-reader.md \
   ~/.claude/agents/deploy-guard.md
rm -rf ~/.claude/skills/riper ~/.claude/skills/daily-brief \
       ~/.claude/skills/tech-debt ~/.claude/skills/security-review
# Revert ~/.claude/settings.json from your backup.
```

If you used the Option B prefix:
```bash
rm ~/.claude/agents/ult-*.md
rm -rf ~/.claude/skills/ult/
rm -rf ~/.claude/ultimate/
```

# Ultimate Claude Code Config — Windows Quickstart

Deploy this `Ultimate-Windows/` build on Windows using **Git Bash**. Run the
unified `install.sh` at the repo root — it handles everything.

Target audience: **solo developer**, Claude Code v2.1.105+, Git Bash installed.

---

## What you get

- `settings.json` — user-scope (`~/.claude/settings.json`)
- `project-override/settings.json` — project-scope (`.claude/settings.json`)
- `CLAUDE.md` — master instruction file
- 5 subagents: `code-reviewer`, `researcher`, `refactor-agent`, `db-reader`, `deploy-guard`
- 4 skills: `riper`, `daily-brief`, `tech-debt`, `security-review`
- 6 hook scripts at `~/.claude/ultimate-windows/scripts/`:
  - `session-start-context.sh` — injects git + sprint state at session start
  - `post-format-and-heal.sh` — auto-formats edits and runs LSP diagnostics
  - `compress-lsp-output.sh` — trims verbose `mcp__cclsp__*` output
  - `notify-desktop.sh` — Windows toast notification (BurntToast or balloon tip)
  - `pre-compact-checkpoint.sh` — saves checkpoint before context compaction
  - `validate-readonly-query.sh` — enforces SELECT-only for the `db-reader` agent

---

## Prerequisites

### Required
```bash
# Verify these are on your PATH in Git Bash:
bash --version        # Git Bash (comes with Git for Windows)
node --version        # >= 18  (https://nodejs.org)
jq --version          # https://jqlang.github.io/jq/download/
claude --version      # >= 2.1.105
```

**Installing jq on Windows:**
```bash
# Option A — winget (built into Windows 11)
winget install jqlang.jq

# Option B — Chocolatey
choco install jq

# Option C — Scoop
scoop install jq

# Option D — manual: download jq-windows-amd64.exe from https://jqlang.github.io/jq/download/
# rename to jq.exe, place in C:\Program Files\Git\usr\bin\ (on PATH for Git Bash)
```

### Optional (enables formatters and LSP diagnostics in post-format-and-heal hook)
```bash
# TypeScript / JavaScript
npm install -g prettier typescript

# Python
pip install ruff pyright
# or: pip install black mypy

# GitHub CLI (used by session-start for open PRs)
winget install GitHub.cli
# or: choco install gh

# Rust, Go formatters — install their respective toolchains normally
# rustfmt ships with rustup; gofmt ships with the Go installer
```

### Optional — BurntToast (proper Windows 10/11 toast notifications)
```powershell
# Run in PowerShell (not Git Bash):
Install-Module BurntToast -Scope CurrentUser
```
Without BurntToast, the hook falls back to a Windows Forms balloon tip — still works, just older-looking.

---

## Install

From the repo root in Git Bash:

```bash
bash install.sh
```

The installer prompts you to choose:
- `[1] Original` — classic claude-solo
- `[2] Ultimate-Linux` — Linux/macOS enhanced build
- `[3] Ultimate-Windows` — this build (Windows/Git Bash)

Select **[3]**, then choose your install mode:
- **Merge (default)** — coexists with any existing Claude config, prefixes agents with `ult-`
- **Fresh** — replaces existing config (backup taken automatically)

---

## Manual install (if you prefer)

```bash
# 1. Hook scripts → namespaced dir (won't collide with existing ~/.claude/hooks/)
mkdir -p ~/.claude/ultimate-windows/scripts
cp Ultimate-Windows/scripts/*.sh ~/.claude/ultimate-windows/scripts/
chmod +x ~/.claude/ultimate-windows/scripts/*.sh

# 2. Settings — ONLY if you don't already have ~/.claude/settings.json
cp Ultimate-Windows/settings.json ~/.claude/settings.json
# If you DO have one, diff and merge manually:
# diff ~/.claude/settings.json Ultimate-Windows/settings.json

# 3. CLAUDE.md — append (don't overwrite if you have one)
echo "" >> ~/.claude/CLAUDE.md
echo "<!-- ultimate-windows:start -->" >> ~/.claude/CLAUDE.md
cat Ultimate-Windows/CLAUDE.md >> ~/.claude/CLAUDE.md
echo "<!-- ultimate-windows:end -->" >> ~/.claude/CLAUDE.md

# 4. Agents (merge mode — prefix avoids collision)
mkdir -p ~/.claude/agents
for a in Ultimate-Windows/agents/*.md; do
  name=$(basename "$a" .md)
  cp "$a" ~/.claude/agents/ult-$name.md
  sed -i "s/^name: $name$/name: ult-$name/" ~/.claude/agents/ult-$name.md
done

# 5. Skills
mkdir -p ~/.claude/skills/ult
for skill in riper daily-brief tech-debt security-review; do
  mkdir -p ~/.claude/skills/ult/$skill
  cp Ultimate-Windows/skills/$skill/SKILL.md ~/.claude/skills/ult/$skill/
done

# 6. Commands
mkdir -p ~/.claude/commands/mm
cp Ultimate-Windows/commands/*.md ~/.claude/commands/mm/
```

---

## Per-project override (optional)

After user-scope install, add stricter per-repo rules:

```bash
cd /path/to/your/project
mkdir -p .claude
cp /c/Code/Github/claude-solo/Ultimate-Windows/project-override/settings.json .claude/settings.json
cat /c/Code/Github/claude-solo/Ultimate-Windows/gitignore-additions.txt >> .gitignore

git add .claude/settings.json .gitignore
git commit -m "chore: add ultimate-windows claude config overrides"
```

---

## Verification

Start a fresh `claude` session and run:

```
/agents
```
Expect: `ult-code-reviewer`, `ult-researcher`, `ult-refactor-agent`, `ult-db-reader`, `ult-deploy-guard`
(no `ult-` prefix if you used --fresh mode)

```
/skills
```
Expect: `riper`, `daily-brief`, `tech-debt`, `security-review` (under `ult/` namespace in merge mode)

**Smoke-test the session hook:** Exit Claude and re-open in a git repo. The first message should show branch name, recent commits, and open PRs.

**Smoke-test notifications:** Ask Claude to do something that takes a moment. You should see a Windows toast or balloon notification.

**Smoke-test post-format (if tsc installed):** Ask Claude to edit a `.ts` file with a type error. The hook should block with the TypeScript error.

---

## Windows-specific notes

| Topic | Detail |
|-------|--------|
| Shell | All hooks run under `bash` (Git Bash). `bash.exe` must be in your `PATH`. |
| Paths | `~` expands to `C:\Users\<you>` in Git Bash. |
| `chmod +x` | Git Bash accepts it; cosmetic on Windows but harmless. |
| `jq` | Must be `jq.exe` on PATH — every hook depends on it. |
| `sed -i` | Git Bash ships GNU sed — same behaviour as Linux, no `-i ''` suffix needed. |
| Notifications | BurntToast → Windows Forms balloon → terminal bell (preference order). |
| `realpath` | Available in Git Bash via coreutils. |
| Formatters | `prettier`, `ruff`, `tsc` etc. must be on the Windows `PATH` (not just WSL). |

---

## Troubleshooting

| Symptom | Likely cause | Fix |
|---------|-------------|-----|
| Hooks don't fire | `settings.json` invalid JSON | `jq . ~/.claude/settings.json` |
| `jq: command not found` | jq not on PATH | Install jq (see Prerequisites) |
| No desktop notification | BurntToast not installed | `Install-Module BurntToast` (optional) |
| post-format blocks every edit | tsc/pyright strict errors | Loosen tsconfig OR comment out diagnostics block |
| `bash: ...scripts/...: No such file` | Scripts not copied | Re-run `bash install.sh` |
| `realpath: command not found` | Git Bash coreutils missing | Reinstall Git for Windows (full installer) |

---

## Uninstall

```bash
rm -rf ~/.claude/ultimate-windows/
rm -f ~/.claude/agents/ult-*.md
rm -rf ~/.claude/skills/ult/
rm -rf ~/.claude/commands/mm/
# Remove the <!-- ultimate-windows:start/end --> block from ~/.claude/CLAUDE.md manually
# Restore ~/.claude/settings.json from backup at ~/.claude/.ultimate-backup/
```

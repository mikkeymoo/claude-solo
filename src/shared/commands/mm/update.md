---
name: mm:update
description: "Pull the latest claude-solo from GitHub and reinstall — auto-detects global and/or project install. Accepts optional flags: --global, --project, --both."
argument-hint: "[--global | --project | --both]"
---

Update claude-solo to the latest version from the main branch.

## Step 1 — Find the source repo

```bash
cat ~/.claude/.claude-solo-source 2>/dev/null
```

If that file is missing, check common locations:
```bash
ls ~/claude-solo/setup.sh 2>/dev/null && echo "found: ~/claude-solo"
ls ~/Code/claude-solo/setup.sh 2>/dev/null && echo "found: ~/Code/claude-solo"
ls ~/projects/claude-solo/setup.sh 2>/dev/null && echo "found: ~/projects/claude-solo"
```

If still not found, ask the user: "Where is your claude-solo repo? (provide the full path)"
Store the answer and continue.

## Step 2 — Detect what's currently installed

```bash
# Check global install
ls ~/.claude/commands/mm/brief.md 2>/dev/null && echo "global: installed" || echo "global: not installed"

# Check project install (current directory)
ls .claude/commands/mm/brief.md 2>/dev/null && echo "project: installed" || echo "project: not installed"
```

Determine scope based on what's installed and any argument passed:
- `--global` → update global only
- `--project` → update project only
- `--both` → update both
- No argument → update whatever is installed (if both: update both; if only one: update that one)

## Step 3 — Pull latest

```bash
cd [REPO_PATH]
rtk git fetch origin
rtk git log --oneline HEAD..origin/main
```

If there are no new commits, report "Already up to date." and stop.

Otherwise show what's coming:
```bash
rtk git log --oneline HEAD..origin/main
```

Then pull:
```bash
rtk git pull origin main
```

If pull fails (conflicts, network error) — stop and report the error. Do not force anything.

## Step 4 — Reinstall

Run setup for the detected scope(s).

**On Linux/macOS/WSL/Git Bash:**
```bash
# Global:
bash [REPO_PATH]/setup.sh

# Project only:
bash [REPO_PATH]/setup.sh --project

# Both:
bash [REPO_PATH]/setup.sh --both
```

**On Windows (PowerShell):**
```powershell
# Global:
& "[REPO_PATH]\setup.ps1"

# Project only:
& "[REPO_PATH]\setup.ps1" --project

# Both:
& "[REPO_PATH]\setup.ps1" --both
```

Detect platform with:
```bash
uname -s 2>/dev/null || echo "windows"
```

## Step 5 — Verify and report

```bash
# Show new commit hash
cd [REPO_PATH] && rtk git log --oneline -1

# Count installed commands and agents
ls ~/.claude/commands/mm/*.md 2>/dev/null | wc -l
ls ~/.claude/agents/*.md 2>/dev/null | wc -l
```

If project scope was updated, check that too:
```bash
ls .claude/commands/mm/*.md 2>/dev/null | wc -l
ls .claude/agents/*.md 2>/dev/null | wc -l
```

End with a summary like:
```
✅ claude-solo updated to a1b2c3d
   Global (~/.claude): 50 commands, 28 agents
   Project (./.claude): 50 commands, 28 agents  ← if applicable

Restart Claude Code to pick up the new hooks and commands.
```

---
name: mm:update
description: Pull the latest claude-solo from GitHub and reinstall it. Prompts for install mode (merge / fresh / dry-run / verify). TRIGGER when user says "update claude-solo", "upgrade claude-solo", "reinstall claude-solo", "/mm:update", or "pull latest config".
---

# claude-solo Update & Install

You are updating the claude-solo configuration framework. Follow these steps exactly.

## Step 1 — Find the repo

Run:

```bash
cat ~/.claude/.claude-solo-repo 2>/dev/null || echo "NOT_FOUND"
```

- If path is returned: store it as REPO_PATH. Verify it exists: `[[ -d "$REPO_PATH/.git" ]]`
- If `NOT_FOUND` or path invalid: tell the user the repo path is unknown and ask them to provide it, OR offer to clone fresh:
  ```bash
  git clone https://github.com/mikkeymoo/claude-solo.git ~/claude-solo
  ```
  Then use that path.

## Step 2 — Show current state

Run these in parallel:

```bash
# Installed version
cat ~/.claude/.claude-solo-version 2>/dev/null | head -c 8 || echo "unknown"

# Current repo status
git -C "$REPO_PATH" log -1 --format="%h %s (%cr)" 2>/dev/null

# What's available on origin/main
git -C "$REPO_PATH" fetch origin --quiet 2>/dev/null
git -C "$REPO_PATH" log origin/main -1 --format="%h %s (%cr)" 2>/dev/null

# How far behind
git -C "$REPO_PATH" rev-list HEAD..origin/main --count 2>/dev/null
```

Show the user a compact summary:

```
claude-solo update
  installed : <sha> — <subject> (<age>)
  available : <sha> — <subject> (<age>)
  commits behind : <N>   (or "up to date")
```

If already up to date AND installed SHA matches HEAD, ask: "Already up to date — reinstall anyway? (y/N)"
If user says N, stop here.

## Step 3 — Prompt for install mode

Present this menu and wait for the user's choice:

```
Choose install mode:

  1. merge      — Pull latest + install, keep any local customizations (default)
  2. fresh      — Pull latest + wipe and reinstall everything clean
  3. dry-run    — Pull latest, preview what would change, make no changes
  4. verify     — Skip install, just run the smoke test on current install
  5. pull-only  — git pull only, don't run install.sh

Enter 1-5 (or press Enter for merge):
```

Use AskUserQuestion for this.

## Step 4 — Execute

### pull-only (5)

```bash
git -C "$REPO_PATH" pull origin main
```

### verify (4)

```bash
bash "$REPO_PATH/install.sh" --verify-only
```

### dry-run (3)

```bash
git -C "$REPO_PATH" pull origin main && \
bash "$REPO_PATH/install.sh" --dry-run
```

### merge (1, default)

```bash
git -C "$REPO_PATH" pull origin main && \
bash "$REPO_PATH/install.sh"
```

### fresh (2)

Confirm with the user first: "This wipes ~/.claude/agents, skills, commands, rules, hooks, and scripts before reinstalling. Backups are taken. Continue? (y/N)"

If confirmed:

```bash
git -C "$REPO_PATH" pull origin main && \
bash "$REPO_PATH/install.sh" --fresh
```

## Step 5 — Report

After install completes, show:

- Exit code (0 = success)
- New installed version SHA
- Any warnings from the output
- "Start a fresh Claude Code session to pick up all changes."

If the install failed (non-zero exit), surface the last 20 lines of output and suggest running `bash install.sh --dry-run` to diagnose.

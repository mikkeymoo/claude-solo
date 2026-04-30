# claude-solo

Claude Code configuration for solo developers. 47 skills, 5 subagents, 25 hooks. One installer.

```bash
bash install.sh
```

---

## What you can say

### Build a feature

```
/brief Add rate limiting to the /api/upload endpoint
```

```
/riper --plan
```

```
/riper --build
```

```
/riper --auto Add dark mode toggle to the settings page
```

### Fix a bug

```
/fix TypeError: Cannot read property 'id' of undefined in UserCard.tsx
```

```
/fix --deep The webhook handler sometimes drops events under load
```

```
/fix --triage CI has been failing since yesterday
```

```
/fix --bisect The login page stopped working sometime this week
```

### Quick change (skip the ceremony)

```
/quick Fix the off-by-one error in pagination.py line 42
```

```
/quick Add .webp to the allowed upload extensions
```

### Review before commit

```
/code-review-excellence
```

```
/code-review-excellence --staff
```

```
/code-review-excellence --adversarial
```

### Ship it

```
/quality --gate
```

```
/ship
```

```
/security
```

### Test

```
/tdd Add a cart checkout flow
```

```
/tdd --write
```

```
/test-gen
```

### Explore & understand

```
/zoom-out
```

```
/zoom-out --explore
```

```
How does the authentication flow work end-to-end?
```

```
Where does the session token get validated? Trace the full path.
```

### Parallelize work

```
/swarm 4
```

```
/swarm --status
```

```
/swarm --results
```

### Scaffold a new project

```
/scaffold --react
```

```
/scaffold --next
```

```
/scaffold --fastapi
```

```
/scaffold --python
```

### Manage dependencies

```
/deps --audit
```

```
/deps --clean
```

### Track costs

```
/cost
```

```
/cost --trend
```

### Incident response

```
/incident
```

```
/migrate --plan
```

### Utilities

```
/hud --doctor
```

```
/changelog
```

```
/ci
```

```
/release
```

```
/onboard
```

---

## Natural-language prompts (no slash command needed)

You don't always need a slash command. These work just as well:

```
Add user avatar upload to the profile page
```

```
The /api/users endpoint returns 500 when the email contains a plus sign
```

```
Memory usage grows unbounded after ~2 hours of running
```

```
Refactor the database layer to use repository pattern
```

```
Review the changes I just made to the auth module
```

```
Where does the session token get validated across the codebase?
```

```
What's the test coverage for the payment module?
```

```
How much did I spend on tokens this week?
```

---

## How the sprint pipeline works

The canonical end-to-end workflow:

```
/brief → /riper --plan → /riper --build → /code-review-excellence → /quality --gate → /ship
```

1. **`/brief`** captures the idea into `.planning/BRIEF.md` (problem, goal, scope, constraints). Asks clarifying questions if vague.
2. **`/riper --plan`** researches the codebase, generates 2-4 approaches, asks you to pick, then decomposes into atomic tasks. Writes `.planning/PLAN.md`. No code yet.
3. **`/riper --build`** executes tasks one at a time. Each task: write code, write tests, atomic commit. Spawns `ult-code-reviewer` before each commit.
4. **`/code-review-excellence`** runs a 3-pass review. Findings: must fix / should fix / consider.
5. **`/quality --gate`** runs lint, typecheck, tests, secrets scan, smoke check. Pass or fail.
6. **`/ship`** creates the PR, merges, confirms CI.

Or skip all of that: **`/riper --auto`** runs the full pipeline hands-off.

---

## Specialist subagents

| Agent                | Model  | What it does                                   |
| -------------------- | ------ | ---------------------------------------------- |
| `ult-code-reviewer`  | Opus   | 3-pass staff-engineer review before commits    |
| `ult-researcher`     | Haiku  | Fast cross-file codebase investigation         |
| `ult-refactor-agent` | Sonnet | Large renames in isolated git worktree         |
| `ult-db-reader`      | Haiku  | Read-only DB inspector (SELECT only, enforced) |
| `ult-deploy-guard`   | Opus   | Pre-deploy GO/NO-GO gate (human-trigger only)  |

The code reviewer spawns automatically before commits. The researcher activates for cross-cutting questions. The deploy guard must be invoked explicitly:

```
/agents deploy-guard
```

---

## All 47 skills

**Sprint:** `/brief` `/riper --plan` `/riper --build` `/riper --auto` `/riper --search` `/code-review-excellence` `/quality --gate` `/ship` `/retro`

**Workflow:** `/workflow` `/swarm` `/swarm --status` `/swarm --results` `/quick`

**Debug:** `/fix` `/fix --deep` `/fix --triage` `/fix --bisect`

**Test:** `/tdd` `/tdd --write` `/test-gen`

**Quality:** `/quality --deps` `/quality --a11y` `/quality --gate` `/cleanup` `/cleanup --aggressive` `/security` `/perf`

**Review:** `/code-review-excellence --staff` `/code-review-excellence --adversarial` `/api-design` `/design-an-interface` `/grill-me` `/premortem`

**Deps & CI:** `/deps` `/deps --audit` `/deps --clean` `/changelog` `/ci` `/release`

**Explore:** `/zoom-out` `/zoom-out --explore` `/hud` `/hud --doctor` `/hud --map` `/onboard` `/lsp-status`

**Incident:** `/incident` `/migrate --plan` `/migrate --execute` `/migrate --verify`

**Scaffold:** `/scaffold --react` `/scaffold --next` `/scaffold --fastapi` `/scaffold --express` `/scaffold --python`

**Meta:** `/docs` `/docs --api` `/refactor` `/config` `/session` `/cost` `/cost --trend` `/write-a-skill` `/sketch`

---

## Hooks (25 entries)

Hooks fire automatically. You don't invoke them.

| Event        | What happens                                                                                                                                     |
| ------------ | ------------------------------------------------------------------------------------------------------------------------------------------------ |
| SessionStart | UTF-8 encoding, cost summary, quota check, HUD, git+sprint context, update check                                                                 |
| PreToolUse   | Block write SQL in db-reader, enforce UTF-8 before writes, conventional commit enforcement, LSP-over-Grep nudge, large file + gitignore warnings |
| PostToolUse  | Auto-format + lint-fix after edits, compress LSP output, test runner (opt-in), commit message suggestion, latency tracking, dashboard events     |
| PreCompact   | Save checkpoint before context compaction                                                                                                        |
| Stop         | Block stop if dirty tree, TODO markers, or failing tests                                                                                         |
| Subagent     | Dashboard lifecycle events on start/stop                                                                                                         |

---

## Install

```bash
bash install.sh              # Merge with existing config
bash install.sh --fresh      # Replace config (backup taken)
bash install.sh --project    # Add project override to CWD
bash install.sh --dry-run    # Preview only
bash install.sh --uninstall  # Remove using manifest
bash install.sh --verify     # Check prerequisites
```

**Requires:** `bash` (Git Bash on Windows), `jq`

**What gets installed:**

```
~/.claude/
  scripts/       18 lifecycle scripts
  hooks/         21 JS hooks
  agents/        5 subagents (ult-* prefix)
  skills/        47 skills
  rules/         10 engineering rules
  settings.json  Permissions, hooks, env vars
  CLAUDE.md      Working style + routing
```

## Cost optimization

Handled automatically by the installer:

1. **cache-fix proxy** — fixes 5m→1h cache TTL regression in CC v2.1.81+
2. **Session hygiene** — long sessions, checkpoints, LSP over Grep
3. **`/cost --trend`** — week-over-week comparison to spot regressions

## Windows encoding

Fixes `charmap` codec errors and `settings.json` mojibake:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/Setup-WindowsEncoding.ps1
```

## Changelog

See [CHANGELOG.md](CHANGELOG.md). Current: **v0.8.0** (2026-04-29)

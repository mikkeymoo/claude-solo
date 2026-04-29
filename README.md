# claude-solo

Claude Code configuration for solo developers. One flat repo, one installer, no variant selection.

## Quickstart

```bash
# Install (merge — coexists with existing config)
bash install.sh

# Fresh install (replaces existing config, backup taken automatically)
bash install.sh --fresh

# Dry run (preview without changing anything)
bash install.sh --dry-run

# Add project override to current directory
bash install.sh --project

# Uninstall
bash install.sh --uninstall

# Check prerequisites only
bash install.sh --verify
```

**Requirements:** `bash` (Git Bash on Windows), `jq`

**Auto-installed by the installer (if not present):** `claude-code-cache-fix` (npm)

## What gets installed

```
~/.claude/
  scripts/           18 lifecycle scripts (bash + node)
  hooks/             21 JS hooks (PreToolUse, PostToolUse, Stop, SubagentStart/Stop)
  agents/            5 specialist subagents (ult-* prefix)
  skills/            47 skills (bare /name invocation)
  rules/             10 engineering rules (auto-loaded)
  settings.json      Wired hooks, permissions, env vars
  CLAUDE.md          Working style + agent/skill routing
  statusline.sh      One Dark Pro compact statusline
```

---

## Workflows & examples

### The sprint pipeline (end-to-end feature development)

The canonical workflow for shipping a feature from idea to production:

```
/brief → /riper --plan → /riper --build → /code-review-excellence → /quality --gate → /ship → /retro
```

**Step 1 — Capture the idea:**

```
You: /brief Add rate limiting to the /api/upload endpoint

Claude writes .planning/BRIEF.md with problem, goal, scope, constraints.
Asks clarifying questions if the idea is vague.
Ends with: "Brief saved. Ready to /riper --plan?"
```

**Step 2 — Plan it:**

```
You: /riper --plan

Claude reads the brief, researches the codebase (Phase 1),
generates 2-4 approaches (Phase 2), asks you to pick one,
then decomposes into atomic tasks with acceptance criteria (Phase 3).
Writes .planning/PLAN.md. Does NOT write any code yet.
```

**Step 3 — Build it:**

```
You: /riper --build

Claude executes tasks from PLAN.md one at a time.
Each task → write code → write/update tests → atomic commit.
Spawns ult-code-reviewer before each commit.
```

**Step 4 — Review:**

```
You: /code-review-excellence

Claude spawns the code reviewer subagent for a 3-pass staff-engineer review.
Findings labeled: 🔴 must fix / 🟡 should fix / 🔵 consider
```

**Step 5 — Gate:**

```
You: /quality --gate

Runs lint, typecheck, full test suite, secrets scan, smoke check.
Writes .planning/VERIFY.md with pass/fail table.
"✅ Verification passed. Ready to /ship." or "🔴 Verification failed."
```

**Step 6 — Ship:**

```
You: /ship

Final test run → create PR → merge → confirm CI green.
Ends with: "Shipped."
```

### Quick fix (small, obvious changes)

Skip the full pipeline for single-file fixes, config tweaks, typos:

```
You: /quick Fix the off-by-one error in pagination.py line 42

Claude: restates the task → locates the file → makes the minimal fix →
writes a test → commits. Done in 4 steps. If it grows beyond
5 files, auto-escalates to /riper.
```

### Bug debugging

Four modes depending on severity:

```
# Tactical fix — you know roughly what's wrong
You: /fix TypeError: Cannot read property 'id' of undefined in UserCard.tsx

# Deep debugging — hard or intermittent issue
You: /fix --deep The webhook handler sometimes drops events under load

# Universal triage — any error type, routes to right strategy
You: /fix --triage CI has been failing since yesterday

# Git bisect — find the commit that broke it
You: /fix --bisect The login page stopped working sometime this week
```

### Parallel multi-agent work

For plans with many independent tasks:

```
You: /swarm 4

Claude reads PLAN.md, finds 8 tasks, groups into dependency waves:
  Wave 1: Tasks 1-4 (independent) → 4 parallel agents in isolated worktrees
  Wave 2: Tasks 5-6 (depend on Wave 1) → 2 parallel agents
  Wave 3: Tasks 7-8 (depend on Wave 2) → 2 parallel agents

Each agent uses ult-code-reviewer before committing.
After all waves, runs /quality --gate on the merged result.
```

Monitor progress:

```
You: /swarm --status     # See active worktrees and agent progress
You: /swarm --results    # View merged outcomes after completion
```

### Full autopilot

For when you trust the pipeline end-to-end:

```
You: /riper --auto Add dark mode toggle to the settings page

Claude runs the full pipeline hands-off:
brief → research → plan → build → review → test → ship → retro
```

### Test-driven development

```
# Full TDD loop (red → green → refactor, vertical slices)
You: /tdd Add a cart checkout flow

# Just generate tests for existing code
You: /tdd --write
```

The TDD skill enforces vertical slices (one test → one implementation → repeat), not horizontal slices (all tests then all code).

### Code review modes

```
# Constructive review (default) — balanced feedback
You: /code-review-excellence

# Staff-engineer review — deep expertise, architectural concerns
You: /code-review-excellence --staff

# Adversarial review — red-team stress test, finds edge cases
You: /code-review-excellence --adversarial
```

### Security audit

```
You: /security

OWASP-based audit: injection, auth, secrets, input validation,
dependency CVEs, security headers. Findings labeled by severity
(🔴 CRITICAL / 🟡 HIGH / 🔵 MEDIUM). Auto-fixes critical findings.
Includes confidence scoring (0-100) per finding.
```

### Dependency management

```
You: /deps --audit     # CVE scan + outdated packages + license issues
You: /deps --clean     # Find and remove unused dependencies
You: /deps             # Full audit + upgrade plan
```

### Project scaffolding

```
You: /scaffold --react      # Vite + React + TypeScript + Router
You: /scaffold --next       # Next.js App Router + API routes
You: /scaffold --fastapi    # FastAPI + SQLAlchemy + Alembic
You: /scaffold --express    # Express + TypeScript + Prisma
You: /scaffold --python     # Python package with ruff + mypy + pytest
```

### Cost tracking

```
You: /cost              # Today/week/month token usage + cost breakdown
You: /cost --trend      # Week-over-week comparison with bar chart
```

### Exploration & onboarding

```
You: /zoom-out                  # Quick 3-5 min codebase overview
You: /zoom-out --explore        # Deep architectural analysis
You: /hud                       # Session HUD (branch, sprint, todos)
You: /hud --doctor              # Project health check
You: /onboard                   # Generate full onboarding guide
```

### Incident response

```
You: /incident

Guided postmortem Q&A: timeline, impact, root cause, fix, prevention.
Writes .planning/POSTMORTEM-{date}.md.
```

### Migration assistant

```
You: /migrate --plan     # Plan a framework/library migration
You: /migrate --execute  # Execute the migration plan
You: /migrate --verify   # Verify migration succeeded
```

---

## Specialist subagents

Installed with `ult-` prefix. Claude routes to these automatically based on task type, or you can reference them directly.

| Agent                | Model  | Purpose                                      | When used                                    |
| -------------------- | ------ | -------------------------------------------- | -------------------------------------------- |
| `ult-code-reviewer`  | Opus   | Staff-engineer 3-pass code review            | Before every commit (auto-spawned)           |
| `ult-researcher`     | Haiku  | Fast codebase investigation across >3 files  | Architecture questions, "where is X" queries |
| `ult-refactor-agent` | Sonnet | Large-scale renames in isolated git worktree | Renames >10 files, API shape changes         |
| `ult-db-reader`      | Haiku  | Read-only database inspector (SELECT only)   | Schema checks, query debugging               |
| `ult-deploy-guard`   | Opus   | Pre-deploy GO/NO-GO checklist                | Human-trigger only before production ship    |

**Agent examples:**

```
# The code reviewer runs automatically before commits, but you can invoke it directly:
You: Review the changes I just made to the auth module

# Research agent for cross-cutting questions:
You: Where does the session token get validated across the codebase?

# Deploy guard (human-trigger only):
You: /agents deploy-guard
```

---

## Hooks (25 entries across 6 events)

| Event         | Hook                            | Purpose                                                        |
| ------------- | ------------------------------- | -------------------------------------------------------------- |
| SessionStart  | `bootstrap-windows-encoding.sh` | Set UTF-8 env vars before anything runs                        |
| SessionStart  | `cost-summary.sh`               | Today's token/cost summary (throttled 5min)                    |
| SessionStart  | `quota-warmup-warn.sh`          | 5h quota window visibility                                     |
| SessionStart  | `session-hud.sh`                | Branch, sprint, recent files, TODO count (throttled 10min)     |
| SessionStart  | `session-start-context.sh`      | Git + sprint state injected into model context                 |
| SessionStart  | `morae-context.sh`              | eDiscovery reminders when CWD matches known patterns           |
| SessionStart  | `update-check.sh`               | Daily update notice (network-failure-tolerant)                 |
| PreToolUse    | `validate-readonly-query.sh`    | Block write SQL from db-reader subagent                        |
| PreToolUse    | `pre-tool-use.js`               | Conventional commits enforcement + danger warnings             |
| PreToolUse    | `validate-utf8-source.sh`       | Block mojibake before it corrupts files                        |
| PreToolUse    | `large-file.js`                 | Warn on Write >500 lines or >50KB (advisory)                   |
| PreToolUse    | `gitignore-check.js`            | Warn on writes to gitignored paths (advisory)                  |
| PreToolUse    | `enforce-lsp-navigation.sh`     | Nudge: prefer LSP over Grep for code symbols                   |
| PostToolUse   | `post-format-and-heal.sh`       | Auto-format + LSP diagnostics after edits                      |
| PostToolUse   | `lint-fix.js`                   | Auto lint-then-fix: runs eslint/ruff/clippy, exits 2 on error  |
| PostToolUse   | `compress-lsp-output.sh`        | Trim verbose Serena MCP output                                 |
| PostToolUse   | `morae-powerbi-validate.sh`     | Power BI brand/JSON validation (opt-in via env var)            |
| PostToolUse   | `dashboard-agent.js`            | Post tool lifecycle events to local dashboard on :9876         |
| PostToolUse   | `test-fix.js`                   | Run tests after edits, exit 2 on failure (opt-in: AUTO_TEST=1) |
| PostToolUse   | `commit-msg.js`                 | Suggest conventional commit message from staged diff           |
| PostToolUse   | `latency-track.js`              | Track per-tool timing, alert if >30s (advisory)                |
| PreCompact    | `pre-compact-checkpoint.sh`     | Save checkpoint before context compaction                      |
| Stop          | `stop-gate.js`                  | Block stop if dirty tree, TODO markers, or tests fail          |
| SubagentStart | `dashboard-agent.js`            | Post subagent lifecycle events to dashboard                    |
| SubagentStop  | `dashboard-agent.js`            | Post subagent lifecycle events to dashboard                    |

---

## Skills reference (47 total)

### Sprint pipeline

| Skill                     | Purpose                               |
| ------------------------- | ------------------------------------- |
| `/brief [idea]`           | Capture idea → `.planning/BRIEF.md`   |
| `/riper --plan`           | Research + plan → `.planning/PLAN.md` |
| `/riper --build`          | Execute tasks from plan               |
| `/riper --auto`           | Full hands-off autopilot pipeline     |
| `/riper --search`         | Research phase only                   |
| `/code-review-excellence` | Constructive code review              |
| `/quality --gate`         | Hard pass/fail verification gate      |
| `/ship`                   | Final tests → PR → merge → post-ship  |
| `/retro`                  | Sprint retrospective                  |

### Workflow modes

| Skill              | Purpose                                         |
| ------------------ | ----------------------------------------------- |
| `/workflow`        | Choose execution mode (auto/parallel/tdd/quick) |
| `/swarm [N]`       | Parallel agents in isolated worktrees           |
| `/swarm --status`  | Monitor active swarm agents                     |
| `/swarm --results` | View merged wave outcomes                       |
| `/quick [task]`    | Fast path for small changes                     |

### Debugging

| Skill           | Purpose                                         |
| --------------- | ----------------------------------------------- |
| `/fix [error]`  | Tactical bug fix                                |
| `/fix --deep`   | Hypothesis-driven systematic debugging          |
| `/fix --triage` | Universal troubleshooter (routes by error type) |
| `/fix --bisect` | Git bisect regression finder                    |

### Quality & security

| Skill                   | Purpose                                     |
| ----------------------- | ------------------------------------------- |
| `/tdd`                  | Red-green-refactor TDD loop                 |
| `/tdd --write`          | Generate tests for existing code            |
| `/test-gen`             | Comprehensive test generation               |
| `/quality --deps`       | CVE scan + outdated packages + licenses     |
| `/quality --a11y`       | WCAG 2.1 AA accessibility audit             |
| `/quality --gate`       | Lint + types + tests + secrets + smoke      |
| `/cleanup`              | Dead code + duplication removal             |
| `/cleanup --aggressive` | Maximum dead code removal with confirmation |
| `/security`             | OWASP audit + CVE scan (manual trigger)     |
| `/perf`                 | Performance profiling                       |

### Review & design

| Skill                                   | Purpose                                   |
| --------------------------------------- | ----------------------------------------- |
| `/code-review-excellence --staff`       | Staff-engineer review                     |
| `/code-review-excellence --adversarial` | Red-team adversarial review               |
| `/api-design`                           | REST API review and design                |
| `/design-an-interface`                  | Generate multiple interface designs       |
| `/grill-me`                             | Stress-test a plan with hard questions    |
| `/premortem`                            | Identify failure modes before they happen |

### Dependencies & CI

| Skill           | Purpose                                      |
| --------------- | -------------------------------------------- |
| `/deps`         | Full dependency audit + upgrade plan         |
| `/deps --audit` | Security audit only                          |
| `/deps --clean` | Remove unused dependencies                   |
| `/changelog`    | Generate changelog from conventional commits |
| `/ci`           | CI status, failing checks, retry             |
| `/release`      | Version bump + changelog + tag               |

### Exploration

| Skill                 | Purpose                          |
| --------------------- | -------------------------------- |
| `/zoom-out`           | Quick codebase context (3-5 min) |
| `/zoom-out --explore` | Deep architectural analysis      |
| `/hud`                | Session HUD                      |
| `/hud --doctor`       | Project health check             |
| `/hud --map`          | Codebase map                     |
| `/onboard`            | Generate onboarding guide        |
| `/lsp-status`         | Check LSP server registration    |

### Incident & migration

| Skill                | Purpose                                           |
| -------------------- | ------------------------------------------------- |
| `/incident`          | Structured postmortem → `.planning/POSTMORTEM.md` |
| `/migrate --plan`    | Plan framework/library migration                  |
| `/migrate --execute` | Execute migration                                 |
| `/migrate --verify`  | Verify migration succeeded                        |

### DX & tooling

| Skill                    | Purpose                                         |
| ------------------------ | ----------------------------------------------- |
| `/scaffold [--template]` | New project (react/next/fastapi/express/python) |
| `/sketch`                | Rapid prototype                                 |
| `/docs`                  | Documentation generation                        |
| `/docs --api`            | OpenAPI 3.0 spec from route handlers            |
| `/refactor`              | Targeted refactoring                            |
| `/config`                | Manage rules, scheduled tasks, CI               |
| `/session`               | Save/restore context                            |
| `/cost`                  | Token usage + cost analysis                     |
| `/cost --trend`          | Week-over-week comparison                       |
| `/write-a-skill`         | Scaffold a new skill                            |

### Observability

| Skill           | Purpose                                |
| --------------- | -------------------------------------- |
| `/cost`         | Token/cost analysis from JSONL logs    |
| `/cost --trend` | Week-over-week comparison + bar chart  |
| `/hud`          | Session HUD with branch + sprint state |

---

## Common prompts (copy-paste ready)

These are natural-language prompts that trigger skills and agents effectively:

### Starting new work

```
Add user avatar upload to the profile page
```

```
/brief We need a webhook system that retries failed deliveries with exponential backoff
```

```
/riper --auto Refactor the database layer to use repository pattern
```

### Fixing things

```
The /api/users endpoint returns 500 when the email contains a plus sign
```

```
/fix --deep Memory usage grows unbounded after ~2 hours of running
```

```
/fix --triage Everything broke after merging the feature branch
```

### Before shipping

```
/code-review-excellence --adversarial
```

```
/quality --gate
```

```
/security
```

### Understanding code

```
How does the authentication flow work end-to-end?
```

```
/zoom-out --explore
```

```
Where does the session token get validated? Trace the full path.
```

### Day-to-day

```
/cost --trend
```

```
/hud --doctor
```

```
/deps --audit
```

---

## Windows encoding

Fixes `charmap` codec errors and `settings.json` mojibake — two common Windows bugs.

One-shot fix (run once from PowerShell, no installer needed):

```powershell
powershell -ExecutionPolicy Bypass -File scripts/Setup-WindowsEncoding.ps1
```

## Cost optimization

The installer handles all three automatically:

1. **cache-fix proxy** — fixes the 5m→1h cache TTL regression in CC v2.1.81+. Auto-installed via `npm install -g claude-code-cache-fix`; `ANTHROPIC_BASE_URL=http://127.0.0.1:9801` patched into `settings.json`.
2. **Session hygiene** — keep sessions long, use checkpoints, prefer LSP over Grep.
3. **`/cost --trend`** — week-over-week token/cost comparison to spot regressions early.

## Install modes

| Flag          | Behavior                                                             |
| ------------- | -------------------------------------------------------------------- |
| (none)        | Merge — coexists with existing config, agents prefixed `ult-`        |
| `--fresh`     | Replace — overwrites config, backup taken automatically              |
| `--project`   | Project override — adds `.claude/settings.json` to current directory |
| `--dry-run`   | Preview only — no files changed                                      |
| `--verify`    | Check prerequisites only                                             |
| `--uninstall` | Remove installed files using manifest                                |

## Changelog

See [CHANGELOG.md](CHANGELOG.md).

Current: **v0.8.0** (2026-04-29) — 47 skills, 21 hooks, observability dashboard, auto lint-fix, confidence scoring

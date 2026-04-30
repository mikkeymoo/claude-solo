# claude-solo

Claude Code configuration for solo developers. 47 skills, 5 subagents, 25 hooks. One installer.

```bash
bash install.sh
```

---

## Examples

Every example below shows: what you type, what skill/agent activates, what hooks fire, and what artifacts are produced.

### Build a feature end-to-end

```
You:   /brief Add rate limiting to the /api/upload endpoint
```

> **Skill:** `brief` activates. Asks clarifying questions (per-user? per-IP? what limit?), then writes `.planning/BRIEF.md` with problem, goal, scope, constraints, open questions. Ends with "Brief saved. Ready to `/riper --plan`?"

```
You:   /riper --plan
```

> **Skill:** `riper` activates in RESEARCH phase. Uses `ult-researcher` agent (Haiku, read-only) to scan the codebase for existing rate-limit patterns, middleware chain, and test coverage. Produces research findings, then advances to INNOVATE phase — generates 2-4 approaches (e.g., in-memory vs Redis, middleware vs decorator). Asks you to pick. After you choose, enters PLAN phase — decomposes into atomic tasks with acceptance criteria. Writes `.planning/PLAN.md`. No code written yet.

```
You:   /riper --build
```

> **Skill:** `riper` activates in EXECUTE phase. Works through each task in PLAN.md:
>
> 1. Writes code → **PostToolUse hooks fire:** `post-format-and-heal.sh` auto-formats the file, `lint-fix.js` runs the project linter (eslint/ruff/clippy) and auto-fixes violations, `enforce-lsp-navigation.sh` nudges if Grep was used instead of LSP
> 2. Writes/updates tests → same PostToolUse hooks fire again
> 3. Before each `git commit` → **PreToolUse hook:** `pre-tool-use.js` enforces conventional commit format. **Agent:** `ult-code-reviewer` (Opus, 3-pass) spawns automatically — does a blind bug hunt, edge case analysis, then acceptance audit. Returns findings labeled must-fix / should-fix / consider
> 4. Commits with `feat(api): add rate limiting middleware`
>
> Repeats for each task in the plan.

```
You:   /code-review-excellence --adversarial
```

> **Skill:** `code-review-excellence` activates in adversarial mode. **Agent:** spawns `ult-code-reviewer` (Opus) in red-team mode — actively tries to break the code. Looks for race conditions, edge cases, security holes, missing error handling. Returns prioritized findings with confidence scores (0-100).

```
You:   /quality --gate
```

> **Skill:** `quality` activates in gate mode. Runs 6 mechanical checks in sequence:
>
> 1. **Lint** — detects and runs eslint/ruff/clippy. Pass/fail + violation count
> 2. **Type check** — runs tsc/mypy/cargo check. Pass/fail + error count
> 3. **Tests** — runs full test suite. Pass/fail + counts
> 4. **Smoke check** — dev server responds / CLI runs --help / library imports
> 5. **Changed files** — flags files with no test coverage
> 6. **Secrets scan** — runs bundled `secrets_scanner.py` for hardcoded secrets
>
> Writes `.planning/VERIFY.md` with results table. Either "Verification passed. Ready to `/ship`." or "Verification failed." with what to fix.

```
You:   /ship
```

> **Skill:** `ship` activates. Runs final test suite. Creates PR via `gh pr create` with summary, test plan, breaking changes. Merges. Confirms CI green. **Hook:** `stop-gate.js` checks for dirty tree and TODO markers before session can end. Ends with "Shipped."

---

### Full autopilot (single prompt, entire pipeline)

```
You:   /riper --auto Add dark mode toggle to the settings page
```

> **Skill:** `riper` activates in auto mode. Runs the full pipeline without stopping:
>
> 1. **RESEARCH** — `ult-researcher` agent scans for existing theme handling, CSS variables, settings page structure
> 2. **INNOVATE** — generates approaches, picks the best fit automatically
> 3. **PLAN** — writes `.planning/PLAN.md` with atomic tasks
> 4. **EXECUTE** — implements each task. On every file edit: `post-format-and-heal.sh` formats, `lint-fix.js` lints. Before every commit: `ult-code-reviewer` reviews. `pre-tool-use.js` enforces conventional commits
> 5. **REVIEW** — spawns `ult-code-reviewer` for a final pass over all changes
> 6. Runs tests, ships, writes retro notes

---

### Fix a bug (tactical)

```
You:   /fix TypeError: Cannot read property 'id' of undefined in UserCard.tsx
```

> **Skill:** `fix` activates in default (tactical) mode. Steps:
>
> 1. **Reproduce** — confirms the error, gets the full stack trace
> 2. **Locate** — uses Serena LSP (`find_symbol`, `find_references`) to trace the code path. **Hook:** `enforce-lsp-navigation.sh` nudges if Grep is used instead of LSP
> 3. **Root cause** — states the problem in one sentence before writing any fix
> 4. **Fix** — minimal change. **PostToolUse hooks:** `post-format-and-heal.sh` formats, `lint-fix.js` lints and auto-fixes
> 5. **Verify** — runs relevant tests. **Hook:** `test-fix.js` confirms tests pass
> 6. **Commit** — `fix(ui): handle undefined user in UserCard`. **Agent:** `ult-code-reviewer` reviews before commit. **Hook:** `pre-tool-use.js` validates conventional commit format

---

### Fix a bug (deep, systematic)

```
You:   /fix --deep The webhook handler sometimes drops events under load
```

> **Skill:** `fix` activates in deep mode. Different approach — doesn't patch, investigates:
>
> 1. **Characterize** — what fails, when, how often, since when?
> 2. **Gather data** — reads logs, adds instrumentation, runs with verbose output
> 3. **Hypothesize** — lists 2-3 root causes ranked by likelihood (e.g., race condition in queue, connection pool exhaustion, timeout too aggressive)
> 4. **Test hypotheses** — fastest test first, adds logging/assertions. Uses `ult-researcher` agent if the investigation spans many files
> 5. **Confirm** — one-sentence root cause before any fix
> 6. **Fix + verify** — minimal fix, no regression. Same hooks and code reviewer as tactical mode

---

### Fix a bug (triage — don't know what kind of problem it is)

```
You:   /fix --triage CI has been failing since yesterday
```

> **Skill:** `fix` activates in triage mode. Routes by error type:
>
> | Detected type       | What happens                                              |
> | ------------------- | --------------------------------------------------------- |
> | Build failure       | Reads compiler output, fixes module/import/bundler errors |
> | Test failure        | Reads assertion errors, traces to root cause              |
> | CI failure          | Uses `gh run view` to pull logs, identifies failing step  |
> | Dependency conflict | Checks lockfile, version mismatches                       |
> | Environment issue   | Checks env vars, runtime versions                         |
>
> Announces "Triaged as: [type]. Investigating..." then follows the appropriate fix strategy.

---

### Find the commit that broke something

```
You:   /fix --bisect The login page stopped working sometime this week
```

> **Skill:** `fix` activates in bisect mode. Runs `git bisect` to binary-search through commits. Identifies the first bad commit, reads the diff, explains what changed and why it broke. Proposes a fix.

---

### Quick change (no ceremony)

```
You:   /quick Fix the off-by-one error in pagination.py line 42
```

> **Skill:** `quick` activates. Four steps, no stopping:
>
> 1. **Clarify** — restates task in one sentence, confirms it's small
> 2. **Locate** — reads the file. **Hook:** `enforce-lsp-navigation.sh` nudges LSP use
> 3. **Implement** — makes the fix + writes minimal test. **PostToolUse hooks:** `post-format-and-heal.sh` formats, `lint-fix.js` auto-lints
> 4. **Commit** — stages explicitly, commits. **Agent:** `ult-code-reviewer` reviews. **Hook:** `pre-tool-use.js` enforces conventional format
>
> If the change grows beyond 5 files, auto-escalates to `/riper`.

---

### Code review (three modes)

```
You:   /code-review-excellence
```

> **Skill:** `code-review-excellence` activates (constructive mode). **Agent:** spawns `ult-code-reviewer` (Opus). 3-pass review:
>
> 1. **Blind hunt** — reads the diff with fresh eyes, flags bugs and logic errors
> 2. **Edge cases** — looks for missing null checks, race conditions, error paths
> 3. **Acceptance audit** — does the change match the stated goal?
>
> Returns findings: must-fix / should-fix / consider.

```
You:   /code-review-excellence --staff
```

> Same agent, but operates as a staff engineer. Focuses on architectural concerns, long-term maintainability, API design. Asks "will this scale?" and "what breaks when requirements change?"

```
You:   /code-review-excellence --adversarial
```

> Same agent, red-team mode. Actively tries to break the code. Looks for security holes, data corruption paths, undefined behavior. Confidence scores (0-100) on each finding.

---

### Test-driven development

```
You:   /tdd Add a cart checkout flow
```

> **Skill:** `tdd` activates. Enforces vertical slices (one test at a time, not all tests then all code):
>
> 1. **RED** — write one failing test for the simplest behavior
> 2. **GREEN** — write the minimum code to make it pass. **PostToolUse hooks:** format + lint
> 3. **REFACTOR** — clean up without changing behavior. **Agent:** `ult-code-reviewer` reviews
> 4. Repeat for next behavior
>
> Each cycle produces one atomic commit. Never writes all tests first.

```
You:   /tdd --write
```

> Same skill, but generates tests for existing code instead of driving new implementation. Reads the code, identifies untested behaviors, writes tests that verify through public interfaces.

---

### Parallel multi-agent work

```
You:   /swarm 4
```

> **Skill:** `swarm` activates. Reads `.planning/PLAN.md`:
>
> 1. **Analyze** — identifies 8 tasks, maps dependencies
> 2. **Partition** — groups into waves of independent work (tasks touching the same file are NOT independent)
> 3. **Spawn** — Wave 1: 4 `ult-refactor-agent` instances (Sonnet), each in an isolated git worktree. **Hook:** `dashboard-agent.js` posts SubagentStart events
> 4. **Monitor** — agents run in background. Each agent uses `ult-code-reviewer` before committing
> 5. **Merge** — after Wave 1 completes, merges worktree branches back. Resolves conflicts
> 6. **Next wave** — Wave 2: 2 agents for dependent tasks. Wave 3: remaining tasks
> 7. **Verify** — runs `/quality --gate` on the merged result
>
> **Hook:** `dashboard-agent.js` posts SubagentStop events as each finishes.

```
You:   /swarm --status
```

> Shows active worktrees from `git worktree list`, branch names, last commit, and recent tool activity for each running agent.

---

### Security audit

```
You:   /security
```

> **Skill:** `security` activates (manual trigger only — never auto-fires). Scopes to files changed since last tag. Runs 6 checks:
>
> 1. **Injection** — SQL injection, command injection, path traversal
> 2. **Auth** — all endpoints protected? JWT verified? `alg:none` rejected?
> 3. **Secrets** — runs bundled `secrets_scanner.py` (Shannon entropy analysis, pattern matching for AWS/GitHub/Slack/Stripe keys)
> 4. **Input validation** — validated at boundaries? HTML sanitized?
> 5. **Dependencies** — `npm audit` / `pip-audit` / `cargo audit` for CRITICAL/HIGH CVEs
> 6. **Headers** — CSP, X-Content-Type-Options, X-Frame-Options
>
> Findings labeled: CRITICAL (auto-fixed + committed) / HIGH (fix before release) / MEDIUM-LOW (backlog). Each finding has a confidence score (0-100).

---

### Explore a codebase

```
You:   /zoom-out
```

> **Skill:** `zoom-out` activates. Quick 3-5 minute overview: project structure, key modules, entry points, data flow, tech stack.

```
You:   /zoom-out --explore
```

> Deep-dive mode. **Agent:** spawns `ult-researcher` (Haiku) for parallel file reads across the codebase. Maps the full architecture: module boundaries, dependency graph, data flow, API surface, test coverage gaps.

```
You:   How does the authentication flow work end-to-end?
```

> No skill — Claude handles directly but **routes to `ult-researcher` agent** (Haiku, read-only) because the question spans >3 files. The researcher uses Serena LSP to trace from login endpoint → middleware → JWT validation → session store. Returns a synthesized report with file:line citations.

```
You:   Where does the session token get validated across the codebase?
```

> Same pattern — **routes to `ult-researcher` agent**. Uses `find_symbol` and `find_referencing_symbols` via Serena LSP to find all validation call sites. Returns a map of every file and function that touches the token.

---

### Scaffold a new project

```
You:   /scaffold --react
```

> **Skill:** `scaffold` activates. Generates a complete working project:
>
> - `src/App.tsx` with React Router setup
> - `src/components/Home.tsx` with example content
> - `vite.config.ts`, `tsconfig.json` (strict mode), `package.json`
> - `.env.example` with `VITE_API_URL` placeholder
> - `README.md` with install/run/build/test instructions
>
> **PostToolUse hooks fire on every file write:** `post-format-and-heal.sh` formats each file, `lint-fix.js` lints, `validate-utf8-source.sh` checks encoding, `large-file.js` warns if any file >500 lines.

```
You:   /scaffold --fastapi
```

> Same skill, Python template: `src/<pkg>/`, `tests/`, `pyproject.toml`, `.env.example`, ruff + mypy + pytest setup. Runs `pip install -e ".[dev]"` and verifies with tests/lint/types.

---

### Dependency management

```
You:   /deps --audit
```

> **Skill:** `deps` activates. Auto-detects package manager (npm/pnpm/pip/cargo). Runs:
>
> 1. **CVE scan** — `npm audit` / `pip-audit` / `cargo audit`
> 2. **Outdated packages** — flags anything >1 major version behind
> 3. **License audit** — flags GPL/AGPL in commercial projects
> 4. **Unused deps** — scans imports to find packages not used anywhere
>
> Produces prioritized action plan: do now (blocking CVEs) → do this week (major bumps) → next sprint (cleanup).

```
You:   /deps --clean
```

> Same skill, cleanup mode. Finds unused dependencies and removes them. Runs tests after each removal to confirm nothing breaks.

---

### Cost tracking

```
You:   /cost --trend
```

> **Skill:** `cost` activates. Runs `python ~/.claude/skills/cost/cost_report.py --trend`. Parses `~/.claude/projects/**/*.jsonl` logs. Shows:
>
> - This week vs last week: cache reads, cache writes, input, output, cost
> - 7-day bar chart of daily spend
> - Cache hit ratio comparison
> - Top 5 most expensive sessions
> - Optimization suggestions (low cache hit → longer sessions, high output → shorter responses)

---

### Incident postmortem

```
You:   /incident
```

> **Skill:** `incident` activates. Guided Q&A: what happened, when, who was affected, timeline, root cause, fix, what will prevent recurrence. Writes `.planning/POSTMORTEM-{date}.md`.

---

### Migration assistant

```
You:   /migrate --plan Upgrade React Router from v5 to v6
```

> **Skill:** `migrate` activates in plan mode. **Agent:** `ult-researcher` scans for all v5 patterns (`useHistory`, `<Switch>`, `<Redirect>`). Produces a migration plan with each change mapped to a file and a v6 equivalent. Writes `.planning/MIGRATION.md`.

```
You:   /migrate --execute
```

> Executes the plan. Each file change → **PostToolUse hooks** (format, lint, test). Each logical group → atomic commit with `ult-code-reviewer` review.

```
You:   /migrate --verify
```

> Runs full test suite + type check + smoke test to confirm migration didn't break anything.

---

### Project health and session management

```
You:   /hud --doctor
```

> **Skill:** `hud` activates in doctor mode. Checks: git state, uncommitted changes, dependency health, test suite status, TODO count, stale branches, disk usage.

```
You:   /hud
```

> Session HUD: current branch, commits ahead/behind, sprint state from `.planning/`, recent files, token usage this session.

```
You:   /onboard
```

> **Skill:** `onboard` activates. **Agent:** `ult-researcher` scans the entire codebase. Writes `.planning/ONBOARDING.md` with: what this project does, tech stack, how to run, how to test, key modules, data flow, common tasks.

---

### Natural-language prompts (no slash command needed)

You don't always need a slash command. Claude routes to the right skill or agent automatically:

```
You:   Add user avatar upload to the profile page
```

> Recognized as a multi-file feature → triggers `riper` skill (Research → Plan → Execute → Review).

```
You:   The /api/users endpoint returns 500 when the email contains a plus sign
```

> Recognized as a bug → triggers `fix` skill in tactical mode.

```
You:   Refactor the database layer to use repository pattern
```

> Recognized as a multi-file refactor → triggers `riper` skill. If the rename touches >10 files, `ult-refactor-agent` gets spawned in an isolated worktree.

```
You:   Review the changes I just made to the auth module
```

> Triggers `code-review-excellence` skill → spawns `ult-code-reviewer` agent.

```
You:   How much did I spend on tokens this week?
```

> Triggers `cost` skill → runs the Python cost report script.

---

## What happens automatically (hooks)

Hooks fire without you doing anything. Here's what runs in the background:

**When a session starts:**

- `bootstrap-windows-encoding.sh` — sets UTF-8 env vars (Windows)
- `cost-summary.sh` — prints today's token spend (throttled 5min)
- `quota-warmup-warn.sh` — warns if you're in a quota cooling window
- `session-hud.sh` — shows branch, sprint state, recent files, TODOs (throttled 10min)
- `session-start-context.sh` — injects git state + sprint artifacts into context
- `update-check.sh` — daily update notice

**When Claude edits a file:**

- `validate-utf8-source.sh` — blocks the edit if it would introduce encoding corruption
- `large-file.js` — warns if the file is >500 lines or >50KB
- `gitignore-check.js` — warns if the file is gitignored
- `post-format-and-heal.sh` — auto-formats the file + runs LSP diagnostics
- `lint-fix.js` — runs the project linter, auto-fixes what it can, exits 2 if errors remain (so Claude fixes them)
- `test-fix.js` — runs tests after edits (opt-in: `AUTO_TEST=1`)

**When Claude commits:**

- `pre-tool-use.js` — enforces conventional commit message format
- `commit-msg.js` — suggests a commit message from the staged diff

**When Claude searches code:**

- `enforce-lsp-navigation.sh` — nudges to use Serena LSP instead of Grep for symbol navigation

**When a subagent runs:**

- `dashboard-agent.js` — posts lifecycle events to local dashboard on :9876

**When context compacts:**

- `pre-compact-checkpoint.sh` — saves `.planning/CHECKPOINT.md` so the session resumes cleanly

**When Claude tries to stop:**

- `stop-gate.js` — blocks if there's a dirty tree, TODO markers, or failing tests

---

## Specialist subagents

| Agent                | Model  | What it does                                   | Triggered by                                       |
| -------------------- | ------ | ---------------------------------------------- | -------------------------------------------------- |
| `ult-code-reviewer`  | Opus   | 3-pass staff-engineer review                   | Auto before commits; `/code-review-excellence`     |
| `ult-researcher`     | Haiku  | Fast cross-file codebase investigation         | Questions spanning >3 files; `/zoom-out --explore` |
| `ult-refactor-agent` | Sonnet | Large renames in isolated git worktree         | Renames >10 files; `/swarm`; `/refactor`           |
| `ult-db-reader`      | Haiku  | Read-only DB inspector (SELECT only, enforced) | Any DB query; hook blocks write SQL                |
| `ult-deploy-guard`   | Opus   | Pre-deploy GO/NO-GO gate                       | Human-trigger only: `/agents deploy-guard`         |

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

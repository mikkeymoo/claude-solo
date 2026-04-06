# claude-solo

Best-of Claude Code config — 7-stage pipeline, smart agents, hooks, and skills in one install.

Combines the best patterns from gstack, GSD, and SuperClaude. No domain lock-in.

## Install

**Windows (PowerShell):**
```powershell
git clone https://github.com/mikkeymoo/claude-solo.git
cd claude-solo

.\setup.ps1              # Install globally (all projects)
.\setup.ps1 --project    # Install into current project only
.\setup.ps1 --both       # Install globally AND into current project
```

**Linux / WSL / macOS:**
```bash
git clone https://github.com/mikkeymoo/claude-solo.git
cd claude-solo

bash setup.sh             # Install globally (all projects)
bash setup.sh --project   # Install into current project only
bash setup.sh --both      # Install globally AND into current project
```

**Uninstall:**
```powershell
.\setup.ps1 --uninstall           # Remove from global
.\setup.ps1 --uninstall --project # Remove from project
```

Open Claude Code and you're done. Your commands are prefixed with `mm:` so they don't collide with other skill sets.

---

## What Gets Installed

### Skills (Slash Commands)

**The Sprint Pipeline (run in order):**
| Command | What it does | Time |
|---------|-------------|------|
| `/mm:brief` | Define scope + acceptance criteria | 15 min |
| `/mm:plan` | Atomic tasks, architecture, test matrix | 30 min |
| `/mm:build` | Implement in waves, atomic commits | 60-120 min |
| `/mm:review` | Staff-engineer review, auto-fixes | 30 min |
| `/mm:test` | Unit + integration + cross-platform | 30-45 min |
| `/mm:ship` | Merge, verify deploy, monitor | 15-30 min |
| `/mm:retro` | What shipped, what to fix, next sprint | 15 min |

**Power Skills:**
| Command | What it does |
|---------|-------------|
| `/mm:autopilot` | Full hands-off pipeline: idea → spec → build → QA → validate |
| `/mm:tdd` | Strict TDD mode: red → green → refactor, no code before failing test |
| `/mm:parallel` | Execute independent tasks simultaneously in waves |
| `/mm:doctor` | Diagnose project + Claude Code health (git, deps, tests, secrets) |
| `/mm:deepsearch` | Deep multi-source research with synthesis and citations |
| `/mm:quick` | Rapid flow for small tasks: clarify → implement → review in one shot |
| `/mm:explain` | Deep code explanation — traces data flow, answers why not just what |
| `/mm:estimate` | Structured effort estimate with confidence intervals and risk flags |
| `/mm:distill` | Lossless compress large docs/plans to reduce context token cost |
| `/mm:ready` | Pre-build readiness gate — verifies brief, plan, env, and clarity |
| `/mm:aislopcleaner` | Regression-tests-first cleanup — dead code, duplication, needless abstraction, AI padding |
| `/mm:pause` | Save session context to resume in a fresh window |
| `/mm:resume` | Restore context from a paused session and continue |
| `/mm:tokens` | Show estimated token usage breakdown for today's session |
| `/mm:update` | Pull latest claude-solo from GitHub and reinstall |

**Enterprise Review Suite:**
| Command | What it does |
|---------|-------------|
| `/mm:security` | Full OWASP audit — injection, auth, secrets, API exposure, deps |
| `/mm:adversarial` | Attacker mindset review — exploit vectors, logic abuse, insider threat |
| `/mm:compliance` | Enterprise checklist — audit logging, PII, multi-tenancy, SOC2 surface |

**CI/CD:**
| Command | What it does |
|---------|-------------|
| `/mm:ci` | Review or generate GitHub Actions workflow for the current project |
| `/mm:pr` | Create structured PR with description, test plan, breaking changes |
| `/mm:changelog` | Generate CHANGELOG from git history, tag release |

### Agents
| Agent | Role |
|-------|------|
| `senior-reviewer` | Specific, prioritized code reviews (🔴/🟡/🔵) |
| `planner` | Turns vague requirements into executable atomic tasks |
| `debugger` | Systematic root-cause analysis, never guesses |
| `test-writer` | Tests that catch real bugs, not coverage theater |
| `git-workflow` | Branch strategy, atomic commits, conflict resolution, PR descriptions |
| `sql-specialist` | SQL Server / T-SQL queries, schema design, index tuning, migrations |
| `python-data` | Pandas/Polars, data pipelines, ETL, memory-efficient data work |
| `security-auditor` | Enterprise security expert — OWASP, auth design, attack surface, SOC2 |
| `ci-engineer` | GitHub Actions specialist — workflow design, caching, deploy gating |
| `performance-optimizer` | Bottleneck diagnosis — profiles before optimizing, measures before/after |
| `database-architect` | Schema design, migrations, indexes, multi-tenant isolation (SQL Server primary) |
| `api-designer` | REST API design — consistent shapes, correct status codes, versioning, auth |

### Hooks
| Hook | What it does |
|------|-------------|
| `pre-tool-use` | Warns about dangerous commands via stderr (advisory only, never blocks) |
| `post-tool-use` | Logs commands, nudges RTK usage for token savings |
| `prompt-submit` | Auto-injects sprint context (BRIEF.md, PLAN.md) into every prompt |

### CLAUDE.md (appended, never overwrites)
- 7-stage sprint rules and order
- RTK token optimization command examples
- Cross-platform coding rules (Windows + Linux)
- Atomic git commit workflow
- Code quality principles (no premature abstraction, etc.)

---

## The 7-Stage Sprint

Every feature, every fix — follow the pipeline in order:

```
/mm:brief    →  scope it          (15 min)
/mm:plan     →  plan it           (30 min)
/mm:build    →  build it          (60-120 min)
/mm:review   →  review it         (30 min)
/mm:test     →  test it           (30-45 min)
/mm:ship     →  ship it           (15-30 min)
/mm:retro    →  learn from it     (15 min)
```

**Total: 4-6 hours for a well-scoped feature.**

---

## Auto-Mode (Ralph Pattern)

Run Claude fully autonomously — no confirmation prompts, loops until done.

```bash
# Linux/WSL — runs from .planning/PLAN.md
bash run-auto.sh

# One-shot task
bash run-auto.sh "implement the user auth endpoints from PLAN.md"

# Windows
.\run-auto.ps1
.\run-auto.ps1 "fix the failing tests"

# Limit iterations (default: 10)
bash run-auto.sh --max 5
```

**Requires**: Claude Code CLI installed + authenticated. Uses `--dangerouslySkipPermissions`.
**Stops when**: Claude outputs `TASK_COMPLETE` or max iterations reached.
**Use for**: well-scoped tasks with a clear PLAN.md. Not for vague open-ended work.

---

## Global vs Project Install

| Scope | Where | When to use |
|-------|-------|-------------|
| `global` (default) | `~/.claude/` | Your config for all projects |
| `--project` | `./.claude/` | Project-specific overrides |
| `--both` | Both | Override global with project-specific customization |

**Tip**: Install globally first, then use `--project` to override agents or skills per-project.

---

## Safe to Install

- **CLAUDE.md**: appended inside markers, never overwrites your content
- **settings.json**: hooks are merged, your existing settings preserved
- **agents/skills**: only adds files, doesn't touch what you already have
- **Uninstall**: removes only what it installed, leaves your config intact

---

## What This Doesn't Include

- No domain-specific tools
- No openclaw (ever)
- No premium tier, no telemetry, no accounts

---

## Optional: MCP Servers

claude-solo works without any MCPs. Context7 is already bundled with Claude Code.
For Playwright (browser automation/E2E) and other optional integrations: → [docs/recommended-mcps.md](docs/recommended-mcps.md)

---

MIT licensed.

---
name: mm:help
description: "Show the claude-solo workflow guide — all commands, when to use each, common workflows, and quick-start examples. Your in-session reference."
---

Print the following help guide exactly as written:

---

# claude-solo — Workflow Guide

## The Core Idea

Every task runs through a pipeline. The pipeline catches problems before they become expensive.
Small tasks use `/mm:quick`. Big tasks use the full 7-stage sprint.

---

## Choosing Your Workflow

**Is this a small change?** (bug fix, config tweak, refactor under 2h, single file)
→ Use `/mm:quick`

**Is this a feature, new system, or anything touching auth/DB/payments?**
→ Use the full sprint (start with `/mm:brief`)

**Don't know where to start in an unfamiliar codebase?**
→ Run `/mm:map` first

**Need to just build something autonomously without babysitting?**
→ Use `/mm:autopilot` or run `bash run-auto.sh` from the terminal

---

## The 7-Stage Sprint

Run these in order. Don't skip stages.

```
/mm:brief    Define scope + acceptance criteria        ~15 min
/mm:plan     Atomic tasks, dependencies, test matrix   ~30 min
/mm:build    Implement in waves, commit atomically      ~1-2 hrs
/mm:review   Staff-engineer code review, auto-fix       ~30 min
/mm:test     Unit + integration + cross-platform        ~30 min
/mm:verify   Hard gate: lint, types, tests, secrets     ~10 min
/mm:ship     Merge, verify deploy, monitor              ~15 min
/mm:retro    What shipped, what to fix, next sprint     ~15 min
```

**Between stages:** save with `/mm:handoff` to resume in a fresh context window.
**Before /ship:** `/mm:verify` must produce a PASS. If it fails, fix and re-run.
**After a long build:** run `/mm:review` before `/mm:test`. It catches what you missed.

---

## Quick-Start Examples

**"I need to add a new API endpoint"**
```
/mm:brief       ← scope it
/mm:plan        ← design it
/mm:build       ← build it
/mm:review      ← review it
/mm:test        ← test it
/mm:verify      ← gate it
/mm:ship        ← ship it
```

**"I have a bug to fix"**
```
/mm:quick fix the null pointer in UserService.getProfile
```

**"I'm new to this codebase"**
```
/mm:map         ← understand the structure first
/mm:brief       ← then scope your task
```

**"I need to review this PR / code for security"**
```
/mm:security    ← OWASP audit
/mm:adversarial ← attacker mindset
```

**"I want to run this hands-free"**
```
/mm:brief → /mm:plan → then:
/mm:autopilot   ← hands-off build + QA
```

---

## All Commands

### Sprint Pipeline
| Command | What it does |
|---------|-------------|
| `/mm:brief` | Define scope, acceptance criteria, constraints |
| `/mm:plan` | Atomic task breakdown, architecture, test matrix |
| `/mm:build` | Implement in waves with atomic commits |
| `/mm:review` | Staff-engineer review — 🔴 auto-fixed, 🟡 listed |
| `/mm:test` | Run + write tests, verify coverage |
| `/mm:verify` | Hard pass/fail: lint, typecheck, tests, secrets scan |
| `/mm:ship` | Merge, deploy, smoke test, monitor |
| `/mm:retro` | What shipped, what broke, what's next |

### Fast Tracks
| Command | When to use |
|---------|-------------|
| `/mm:quick` | Small changes under 2h — skips full pipeline |
| `/mm:autopilot` | Fully hands-off: idea → spec → build → QA |
| `/mm:tdd` | Strict red → green → refactor cycle |

### Orientation & Planning
| Command | What it does |
|---------|-------------|
| `/mm:map` | Codebase structure map — start here in unfamiliar repos |
| `/mm:estimate` | Effort estimate with confidence intervals and risks |
| `/mm:ready` | Pre-build gate: is the brief + plan actually ready? |
| `/mm:parallel` | Run independent tasks simultaneously in waves |

### Health & Quality
| Command | What it does |
|---------|-------------|
| `/mm:doctor` | Full project health check (git, deps, tests, secrets, env) |
| `/mm:deps` | Dependency audit: CVEs, outdated packages, license issues |
| `/mm:stale` | Find dead code, old TODOs, commented-out blocks |
| `/mm:a11y` | WCAG 2.1 AA accessibility audit with auto-fix |

### Review & Security
| Command | What it does |
|---------|-------------|
| `/mm:security` | OWASP audit — injection, auth, secrets, API exposure |
| `/mm:adversarial` | Attacker mindset — exploit vectors, logic abuse |
| `/mm:compliance` | Enterprise checklist — audit logging, PII, SOC2 |

### Database & Infrastructure
| Command | What it does |
|---------|-------------|
| `/mm:migrate` | Safe DB migration — locking-aware, with rollback |
| `/mm:sql-dev` | SQL schema design and query helpers |

### CI/CD & Git
| Command | What it does |
|---------|-------------|
| `/mm:ci` | Generate or review GitHub Actions workflow |
| `/mm:pr` | Create a structured PR with test plan |
| `/mm:changelog` | Generate CHANGELOG from git history |

### Session Management
| Command | What it does |
|---------|-------------|
| `/mm:handoff` | Save full session context — resume in a fresh window |
| `/mm:resume` | Restore context from a handoff or checkpoint |
| `/mm:tokens` | Show today's estimated token usage by tool |

### Documentation & Onboarding
| Command | What it does |
|---------|-------------|
| `/mm:onboard` | Generate docs/ONBOARDING.md for new contributors |
| `/mm:docsync` | Sync README, CLAUDE.md, and API docs with current code |
| `/mm:dev-docs` | Generate planning + context docs before a feature |
| `/mm:explain` | Deep code explanation — why, not just what |

### Maintenance
| Command | What it does |
|---------|-------------|
| `/mm:release` | Version bump, changelog, release notes, rollout checklist |
| `/mm:incident` | Production debug — repro, root cause, fix, retro |
| `/mm:build-and-fix` | Run build, auto-fix errors ≤ 5, re-verify |
| `/mm:update` | Pull latest claude-solo and reinstall |

---

## Agents — When to Use Them

Agents are specialists. Call them when you need deep expertise on a specific problem.

**In your prompt, just say:** `Use the <agent-name> agent to...`

| If you need... | Use this agent |
|----------------|----------------|
| A thorough code review | `senior-reviewer` |
| Security audit or auth design | `security-auditor` |
| DB schema / migration help | `database-architect` or `migration-specialist` |
| Performance diagnosis | `performance-optimizer` |
| TypeScript errors explained | `type-error-analyzer` |
| Build errors resolved | `build-error-resolver` |
| Tests that actually catch bugs | `test-writer` |
| API design review | `api-designer` |
| CI/CD pipeline setup | `ci-engineer` or `devops-engineer` |
| Dependency / CVE audit | `dependency-auditor` |
| Accessibility audit | `accessibility-auditor` |
| Python code review | `python-expert` or `python-data` |
| Root cause investigation | `root-cause-analyst` |
| Requirements clarification | `requirements-analyst` |
| Docs out of date | `docs-librarian` |
| Circular imports | `circular-dependency-resolver` |

---

## Swarm Mode — Parallel Agent Teams

For large tasks: spin up a coordinated team of agents.

```bash
# Enable once in settings.json:
{ "env": { "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS": "1" } }
```

Then just describe what you want:
```
Refactor the auth module and add a settings page with password change and 2FA
```
Claude picks the team size and agent types. You steer and review.

**Rule of thumb:** if a task would take one agent 4+ hours, use swarm.

---

## Tips

- **Run `/mm:verify` before every `/mm:ship`** — it's the safety net
- **Use `/mm:handoff` at the end of long sessions** — not `/mm:pause` (handoff is richer)
- **Commit atomically** — one logical change per commit, always `feat:` / `fix:` / `refactor:`
- **RTK prefix on all commands** — `rtk git status`, `rtk pnpm test` — saves 60-90% of tokens
- **`/mm:map` in unfamiliar repos** — saves more time than it costs
- **`/mm:doctor` when things feel off** — catches the obvious stuff fast

---

Type any `/mm:` command to get started, or ask me what to run next.

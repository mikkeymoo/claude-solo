---
name: mm-help
description: "Show the claude-solo workflow guide — all commands, when to use each, common workflows, and quick-start examples. Your in-session reference."
---

# mm-help

Show the claude-solo workflow guide — all commands, when to use each, common workflows, and quick-start examples. Your in-session reference.

## Instructions
Print the following help guide exactly as written:

---

# claude-solo — Workflow Guide

## Choose Your Workflow

| Situation | Command |
|-----------|---------|
| Small change (bug, config, refactor < 2h) | `/mm:quick` |
| Feature, auth, DB, payments | Start with `/mm:brief` |
| Unfamiliar codebase | `/mm:map` first |
| Fully hands-off | `/mm:autopilot` |

---

## The 7-Stage Sprint

```
/mm:brief    Define scope + acceptance criteria        ~15 min
/mm:plan     Atomic tasks, dependencies, test matrix   ~30 min
/mm:build    Implement in waves, commit atomically      ~1-2 hrs
/mm:review   Staff-engineer review — auto-fix critical  ~30 min
/mm:test     Unit + integration + cross-platform        ~30 min
/mm:verify   Hard gate: lint, types, tests, secrets     ~10 min
/mm:ship     Merge, deploy, smoke test, monitor         ~15 min
/mm:retro    What shipped, what broke, what's next      ~15 min
```

**Key rules:** `/mm:verify` must PASS before `/mm:ship`. Use `/mm:handoff` between stages in long sessions.

---

## All Commands

### Sprint Pipeline
| Command | What it does |
|---------|-------------|
| `/mm:brief` | Scope, acceptance criteria, constraints |
| `/mm:plan` | Atomic tasks, architecture, test matrix |
| `/mm:build` | Implement in waves with atomic commits |
| `/mm:review` | Staff-engineer review — critical auto-fixed |
| `/mm:test` | Run + write tests, verify coverage |
| `/mm:verify` | Hard pass/fail: lint, typecheck, tests, secrets |
| `/mm:ship` | Merge, deploy, smoke test, monitor |
| `/mm:retro` | What shipped, what broke, next priorities |

### Fast Tracks
| Command | When to use |
|---------|-------------|
| `/mm:quick` | Small changes under 2h |
| `/mm:autopilot` | Hands-off: idea → spec → build → QA |
| `/mm:tdd` | Strict red → green → refactor |
| `/mm:parallel` | Run independent tasks simultaneously |

### Health & Quality
| Command | What it does |
|---------|-------------|
| `/mm:doctor` | Full project health check |
| `/mm:deps` | CVEs, outdated packages, license issues |
| `/mm:stale` | Dead code, old TODOs, commented-out blocks |
| `/mm:a11y` | WCAG 2.1 AA audit with auto-fix |

### Review & Security
| Command | What it does |
|---------|-------------|
| `/mm:security` | OWASP audit — injection, auth, secrets |
| `/mm:adversarial` | Attacker mindset — exploit vectors, logic abuse |
| `/mm:compliance` | Enterprise — audit logging, PII, SOC2 |

### Database & CI/CD
| Command | What it does |
|---------|-------------|
| `/mm:migrate` | Safe DB migration — locking-aware, with rollback |
| `/mm:ci` | Generate or review GitHub Actions workflow |
| `/mm:pr` | Create structured PR with test plan |
| `/mm:changelog` | Generate CHANGELOG from git history |

### Session & Docs
| Command | What it does |
|---------|-------------|
| `/mm:handoff` | Save full session context for fresh window |
| `/mm:resume` | Restore from handoff/checkpoint |
| `/mm:map` | Codebase structure map |
| `/mm:explain` | Deep code explanation — why, not just what |
| `/mm:docsync` | Sync README, CLAUDE.md, API docs with code |
| `/mm:onboard` | Generate contributor onboarding guide |
| `/mm:release` | Version bump, changelog, rollout checklist |
| `/mm:incident` | Production debug — repro, root cause, fix, retro |
| `/mm:tokens` | Today's estimated token usage |

---

## Agents — Specialists On Demand

Say: `Use the <agent-name> agent to...`

| Need | Agent |
|------|-------|
| Code review | `senior-reviewer` |
| Security / auth design | `security-auditor` |
| DB schema / migration | `database-architect`, `migration-specialist` |
| Performance | `performance-optimizer` |
| TypeScript errors | `type-error-analyzer` |
| Build errors | `build-error-resolver` |
| Tests | `test-writer` |
| API design | `api-designer` |
| CI/CD | `ci-engineer`, `devops-engineer` |
| Deps / CVEs | `dependency-auditor` |
| Python | `python-expert`, `python-data` |
| Root cause | `root-cause-analyst` |
| Docs drift | `docs-librarian` |

**Swarm mode** (4+ hour tasks): describe what you want and Claude picks a coordinated agent team. Enable with `"CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS": "1"` in settings.json.

---

## RTK — Always Prefix Commands

`rtk git status` · `rtk pnpm test` · `rtk cargo build` · `rtk gh pr view 123`

Saves **60–90% of tokens** on build/test/git output. Prefix everything.

---

Type any `/mm:` command to get started, or ask what to run next.

# claude-solo Usage Guide

Quick reference for all skills, hooks, agents, and workflows.

---

## Sprint Pipeline (The Core Loop)

Every feature runs through these stages in order:

```
/mm:brief   → scope, criteria, estimate
/mm:plan    → tasks, dependencies, test matrix
/mm:build   → implement in waves, commit atomically
/mm:review  → security, perf, cross-platform review
/mm:test    → unit, integration, E2E tests
/mm:verify  → hard pass/fail gate (lint, types, tests, secrets)
/mm:ship    → PR, merge, deploy, monitor
/mm:retro   → what shipped, what to fix, next priorities
```

For small tasks, use `/mm:quick` to skip the full pipeline.

---

## All Skills

### Sprint Pipeline
| Skill | What It Does |
|-------|-------------|
| `/mm:brief` | Define scope, acceptance criteria, effort estimate |
| `/mm:plan` | Create atomic task list with dependencies and test matrix |
| `/mm:build` | Implement tasks from PLAN.md with atomic commits |
| `/mm:review` | Staff-engineer code review (security, perf, edge cases) |
| `/mm:test` | Write and run unit, integration, and E2E tests |
| `/mm:verify` | Hard verification gate — lint, typecheck, tests, secrets scan |
| `/mm:ship` | Final tests, PR creation, merge, deploy verification |
| `/mm:retro` | Sprint retrospective — what worked, what to fix |

### Quality & Security
| Skill | What It Does |
|-------|-------------|
| `/mm:security` | Full OWASP security audit |
| `/mm:adversarial` | Attacker-mindset review (exploit vectors, logic abuse) |
| `/mm:compliance` | Enterprise compliance checklist (audit logs, PII, SOC2) |
| `/mm:doctor` | Full project health check (git, deps, tests, secrets, env) |
| `/mm:ready` | Pre-build readiness gate (brief, plan, env, clarity) |

### Session Management
| Skill | What It Does |
|-------|-------------|
| `/mm:handoff` | Save rich resume packet for next session |
| `/mm:pause` | Quick session save (lighter than handoff) |
| `/mm:resume` | Restore context from handoff, pause, or checkpoint |

### Release & Ops
| Skill | What It Does |
|-------|-------------|
| `/mm:release` | Version bump, changelog, release notes, rollout checklist |
| `/mm:incident` | Production debug: repro, root cause, fix, retro |
| `/mm:changelog` | Generate CHANGELOG from git history |
| `/mm:ci` | Review or generate GitHub Actions workflows |
| `/mm:pr` | Create structured pull request |

### Research & Docs
| Skill | What It Does |
|-------|-------------|
| `/mm:deepsearch` | Multi-source research with synthesis and citations |
| `/mm:explain` | Deep code explanation — traces data flow, answers "why" |
| `/mm:docsync` | Sync docs with current code (README, CLAUDE.md, API docs) |
| `/mm:distill` | Compress documents for LLM context savings |

### Utilities
| Skill | What It Does |
|-------|-------------|
| `/mm:quick` | Rapid flow for small tasks (skip full pipeline) |
| `/mm:autopilot` | Full hands-off: spec → build → QA → validate |
| `/mm:parallel` | Execute independent tasks simultaneously |
| `/mm:tdd` | Strict test-driven development mode |
| `/mm:estimate` | Structured effort estimate with confidence intervals |
| `/mm:tokens` | Show estimated token usage for today |
| `/mm:aislopcleaner` | Remove AI-generated slop without changing behavior |
| `/mm:update` | Pull latest claude-solo and reinstall |

---

## Hooks (Automatic)

These run without any action from you:

| Hook | When | What It Does |
|------|------|-------------|
| **SessionStart** | Session begins | Injects git branch, sprint state, pending verification |
| **PermissionRequest** | Permission prompt | Auto-approves safe read-only operations |
| **PreToolUse** | Before Bash commands | Warns about dangerous commands (never blocks) |
| **PostToolUse** | After Bash commands | Tracks tokens, suggests RTK usage |
| **PromptSubmit** | You send a prompt | Injects sprint context from .planning/ |
| **PreCompact** | Before context compression | Saves checkpoint to .planning/CHECKPOINT.md |
| **SubagentStop** | Agent finishes | Saves agent output to .planning/agent-outputs/ |
| **SessionEnd** | Session ends | Writes summary to .planning/SESSION-END.md |

---

## Agents (14 Specialized Roles)

Claude uses these automatically when relevant, or you can request them by name.

| Agent | Specialty |
|-------|-----------|
| **planner** | Task breakdown, dependencies, estimates |
| **senior-reviewer** | Code review with severity labels |
| **debugger** | Systematic root-cause analysis |
| **test-writer** | Unit, integration, E2E test suites |
| **git-workflow** | Branch strategy, atomic commits, PR descriptions |
| **sql-specialist** | SQL Server / T-SQL, schema design, query tuning |
| **python-data** | Pandas/Polars, ETL, data pipelines |
| **security-auditor** | OWASP audits, auth design, attack surface analysis |
| **ci-engineer** | GitHub Actions, caching, deploy gating |
| **performance-optimizer** | Profiling, bottleneck diagnosis |
| **database-architect** | Schema design, migrations, indexing strategy |
| **api-designer** | REST API design, response shapes, versioning |
| **release-manager** | Version bumps, changelogs, rollout checklists |
| **docs-librarian** | Doc accuracy, drift detection, README updates |

---

## MCP Servers (Optional)

A template is installed at `~/.claude/mcp.json`. All servers are disabled by default.

**Recommended setup** (enable 2-3 max):
1. **GitHub** — PRs, issues, Actions without context-switching
2. **Playwright** — Real browser testing and E2E validation
3. **One of**: PostgreSQL, Sentry, or Brave Search based on your project

To enable: edit `~/.claude/mcp.json`, set `"disabled": false` for the server, fill in credentials.

See `docs/recommended-mcps.md` for full details.

---

## RTK (Token Optimization)

Prefix all shell commands with `rtk` for 60-90% token savings:

```bash
rtk git status && rtk git diff
rtk gh pr view 123
rtk python -m pytest tests/
rtk npm run build
```

---

## Typical Workflows

### New Feature
```
/mm:brief → /mm:plan → /mm:ready → /mm:build → /mm:review → /mm:test → /mm:verify → /mm:ship → /mm:retro
```

### Bug Fix
```
/mm:quick "fix the login redirect bug"
```

### End of Session
```
/mm:handoff
```

### Start of Session
```
/mm:resume
```

### Production Incident
```
/mm:incident
```

### Releasing a Version
```
/mm:verify → /mm:release
```

### Keeping Docs Current
```
/mm:docsync
```

---

## File Locations

After installation, files live in:

| What | Location |
|------|----------|
| Skills | `~/.claude/skills/*.md` |
| Agents | `~/.claude/agents/*.md` |
| Hooks | `~/.claude/hooks/*.js` |
| Settings | `~/.claude/settings.json` |
| MCP config | `~/.claude/mcp.json` |
| Status line | `~/.claude/statusline.json` |
| Token logs | `~/.claude/logs/` |
| Sprint state | `.planning/` (per project) |

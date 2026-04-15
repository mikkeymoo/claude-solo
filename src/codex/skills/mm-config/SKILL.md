---
name: mm-config
description: "Claude-solo command skill"
---

# mm-config

Claude-solo command skill

## Instructions
---
name: mm:config
description: "Project and Claude Code configuration — path rules, scheduled tasks, GitHub integration, CI/CD workflow, update claude-solo, or show help guide."
argument-hint: "[--rules | --schedule | --github | --ci | --update | --help (default)]"
---

Configuration and setup commands. Default shows the help guide.

- `--rules` — create and manage path-specific Claude rules
- `--schedule` — manage scheduled recurring tasks
- `--github` — set up Claude Code GitHub App + CI workflow
- `--ci` — review or generate GitHub Actions workflow
- `--update [--global|--project|--both]` — pull latest claude-solo
- No argument / `--help` — show the workflow guide

---

## --rules — Path-Specific Rules

Manage `.claude/rules/` — rules apply automatically when Claude edits matching files.

```bash
ls .claude/rules/ 2>/dev/null || echo "no rules directory"
```

Detect what the user wants: **list**, **create**, **edit**, **delete**, or **check** (which rules apply to a path).

**Create a rule** — ask:
1. What paths? (e.g. `src/migrations/**`, `**/*.test.ts`, `src/api/**`)
2. What name for the file?
3. What should Claude do differently for these files?

Write `.claude/rules/<name>.md`:
```markdown
---
description: Rules for <what these files are>
globs: <glob pattern>
---

<rules content>
```

**Delete** — confirm before removing. **List** — show all files with their glob patterns. **Check** — show which rules match a given file path.

---

## --schedule — Scheduled Recurring Tasks

Manage scheduled tasks via CronList, CronCreate, CronDelete tools.

**List**: show all active schedules in a readable table (ID, schedule, last run, next run, prompt summary).

**Add** — ask: what should it do? When? (offer presets: hourly, daily 9am, daily 2am, weekly Mon, weekly Fri, or custom cron). Then use CronCreate.

Pre-built suggestions:
- **Daily health check**: `0 9 * * *` — "Run /mm:doctor and report any issues. Open a GitHub issue if tests are failing."
- **Weekly PR review**: `0 9 * * 1` — "Review all open PRs for security, test coverage, and quality. Post findings as comments."
- **Nightly test run**: `0 2 * * *` — "Run full test suite. Create a GitHub issue titled 'Nightly test failure [date]' if any fail."
- **Weekly dep audit**: `0 10 * * 5` — "Check for outdated or vulnerable dependencies. Report critical vulnerabilities."

**Remove** — list schedules, ask which to delete, confirm, use CronDelete.

---

## --github — GitHub Integration Setup

Detect what exists: `ls .github/workflows/ 2>/dev/null`

Ask: (A) GitHub App for PR @mentions, (B) GitHub Actions CI workflow, or (C) both.

**Option A — GitHub App**: run `/install-github-app`, follow OAuth prompts, add `ANTHROPIC_API_KEY` to repo secrets. Test: comment `@claude what does this PR do?` on any PR.

**Option B — CI Workflow**: generate `.github/workflows/claude.yml` with triggers for pull_request, issue_comment, and issues:assigned. Uses `anthropics/claude-code-action@v1`. Write the file, then prompt to add `ANTHROPIC_API_KEY` secret and push.

---

## --ci — CI/CD Workflow Review or Generate

Detect existing config: `ls .github/workflows/ 2>/dev/null`

**If reviewing existing**: check for test coverage, branch protection, secret handling (in GitHub Secrets not hardcoded), dependency caching, matrix testing if cross-platform, fail-fast on test failure, prod deploy gated on staging. Flag: 🔴 Missing | 🟡 Weak | ✅ Good.

**If generating new**: ask language/runtime, test command, deploy target, trigger (PRs only or PRs + main push). Generate `.github/workflows/ci.yml` with: checkout + runtime setup with caching, install deps, lint, tests with coverage, deploy step (main only, tests must pass). Write the file.

---

## --update — Pull Latest claude-solo

Find the source repo: `cat ~/.claude/.claude-solo-source 2>/dev/null`

Detect scope: what's installed (global `~/.claude/commands/mm/`, project `.claude/commands/mm/`) and any passed flag (`--global`, `--project`, `--both`).

Pull latest:
```bash
cd [REPO_PATH] && rtk git fetch origin && rtk git log --oneline HEAD..origin/main
```
If no new commits: "Already up to date." and stop. Otherwise show the incoming commits, pull, then reinstall (bash `setup.sh` or PowerShell `setup.ps1` for the detected scope).

Verify: show new commit hash, count installed commands and agents. End with: "Restart Claude Code to pick up new hooks and commands."

---

## --help — Workflow Guide

Print the complete workflow guide:

```
# claude-solo — Workflow Guide

## Sprint Pipeline (run in order)
/mm:brief    Define scope + acceptance criteria        ~15 min
/mm:plan     Atomic tasks, dependencies, test matrix   ~30 min
/mm:build    Implement in waves, commit atomically      ~1-2 hrs
/mm:review   Staff-engineer review — auto-fix critical  ~30 min
/mm:test     Unit + integration + cross-platform        ~30 min
/mm:verify   Hard gate: lint, types, tests, secrets     ~10 min
/mm:ship     Merge, deploy, smoke test, monitor         ~15 min
/mm:retro    What shipped, what broke, what's next      ~15 min

## Quick Reference — All 20 Commands
| Sprint | /mm:brief /mm:plan /mm:build /mm:review /mm:test /mm:verify /mm:ship /mm:retro |
| Exec modes | /mm:workflow --auto/--parallel/--tdd/--quick |
| Debug | /mm:troubleshoot [error/symptom] |
| Session | /mm:session [save|restore|tokens] |
| Research | /mm:search [question|--explain|--estimate] |
| Security | /mm:security [--owasp|--adversarial|--compliance] |
| Health | /mm:doctor [--check|--map|--ready] |
| Quality | /mm:quality [--deps|--a11y|--migrate] |
| Cleanup | /mm:cleanup [--audit] |
| Release | /mm:release |
| Docs | /mm:docs [sync|onboard|plan|update|distill] |
| Scaffold | /mm:scaffold [--python|--powershell|--sql] |
| Config | /mm:config [--rules|--schedule|--github|--ci|--update] |

## Agents — Specialists On Demand
Say: "Use the <agent-name> agent to..."
senior-reviewer, security-auditor, database-architect, migration-specialist,
performance-optimizer, python-expert, frontend-architect, sql-specialist,
release-manager, root-cause-analyst, system-architect, planner, debugger,
test-writer, git-workflow, ci-engineer, api-designer, docs-librarian,
refactoring-expert, build-error-resolver, type-error-analyzer, python-data,
dependency-auditor, accessibility-auditor, devops-engineer
```

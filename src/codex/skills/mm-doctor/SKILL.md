---
name: mm-doctor
description: "Claude-solo command skill"
---

# mm-doctor

Claude-solo command skill

## Instructions
---
name: mm:doctor
description: "Project health suite — full diagnostic check (default), codebase orientation map (--map), or pre-build readiness gate (--ready)."
argument-hint: "[--check (default) | --map | --ready]"
---

Project health and orientation suite.

- No argument / `--check` — full health check across 6 areas
- `--map` — generate codebase orientation map
- `--ready` — pre-build readiness gate

---

## --check — Full Health Check

Diagnose your project and Claude Code environment.

**1. Git health**
```bash
rtk git status && rtk git log --oneline -5 && rtk git stash list
```
Check: untracked files for .gitignore, staged uncommitted changes, branch ahead/behind remote, merge conflicts.

**2. Dependencies**
```bash
rtk pnpm outdated 2>/dev/null || pip list --outdated 2>/dev/null || cargo outdated 2>/dev/null || true
rtk pnpm audit 2>/dev/null || true
```
Flag: outdated packages with CVEs, missing packages, lockfile drift.

**3. Tests**
```bash
rtk pnpm test 2>/dev/null || rtk python -m pytest -q 2>/dev/null || rtk cargo test 2>/dev/null || true
```
Report pass/fail count, files with no coverage, skipped tests.

**4. Secrets & credentials**
```bash
grep -r "sk-\|api_key\s*=\|password\s*=\|secret\s*=" --include="*.ts" --include="*.py" --include="*.js" -l . 2>/dev/null
cat .gitignore 2>/dev/null | grep -E "^\.env" || echo "WARNING: .env not in .gitignore"
```

**5. Environment**
```bash
node --version 2>/dev/null; python --version 2>/dev/null
cat .env.example 2>/dev/null || echo "no .env.example"
```
Check required env vars, tool versions vs. project expectations.

**6. Claude Code config**
```bash
ls ~/.claude/hooks/ 2>/dev/null | head -20
ls ~/.claude/commands/mm/ 2>/dev/null | wc -l
ls .planning/ 2>/dev/null || echo "no .planning dir"
```
Check: hooks executable, commands installed, stale planning docs.

For each area: ✅ healthy | ⚠️ warning | 🔴 needs fix

End with: "Top 3 things to fix right now."

---

## --map — Codebase Orientation Map

```bash
rtk git log --oneline -5 && rtk ls src/ 2>/dev/null || rtk ls .
cat package.json 2>/dev/null || cat pyproject.toml 2>/dev/null || cat Cargo.toml 2>/dev/null || true
```

Produce:
1. **Project overview** — what it does (1-2 sentences), language/framework/key deps, entry points
2. **Directory structure** — meaningful dirs only (skip node_modules/dist) with one-line purpose each
3. **Key data flows** — request lifecycle, persistence layer, background jobs
4. **Integration points** — external services, auth mechanism, notable env vars
5. **Where to look for...** — table: adding endpoint, adding model, adding test, changing config
6. **Gotchas** — things that would surprise a new contributor, known tech debt

Save to `.planning/CODEBASE-MAP.md`. Keep scannable — short bullets and file paths, not prose.

---

## --ready — Pre-Build Readiness Gate

Verify everything needed to build is in place before `/mm:build`.

**1. Brief** — does `.planning/BRIEF.md` exist with: what we're building, out of scope, done criteria, hard constraints?

**2. Plan** — does `.planning/PLAN.md` exist with: numbered tasks + estimates, explicit dependencies, done criteria per task, test matrix, schema/API changes listed?

**3. Environment**
```bash
cat .env.example 2>/dev/null && ls node_modules 2>/dev/null || ls .venv 2>/dev/null || true
rtk pnpm test 2>/dev/null || rtk python -m pytest -q 2>/dev/null || true
```
Required env vars set? Dependencies installed? Existing tests passing?

**4. Clarity** — all tasks have specific done-criteria (not "implement X" — "function Y passes test Z"). No tasks labeled TBD.

Report:
```
✅ Brief        — complete
✅ Plan         — 8 tasks, clear dependencies, test matrix present
⚠️  Environment — OPENAI_API_KEY not set in .env
✅ Clarity      — all tasks have specific done criteria

1 issue to fix before /build.
```

If all green: "All clear — ready to /build."
If any red: list what's missing and stop.

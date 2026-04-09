---
name: mm-doctor
description: "Claude-solo command skill"
---

# mm-doctor

Claude-solo command skill

## Instructions
---
name: mm:doctor
description: "Full project health check across git, dependencies, tests, secrets, environment, and Claude Code config. Diagnose before problems find you."
---

Diagnose your project and Claude Code environment. Find problems before they find you.

Run a full health check across 6 areas:

1. **Git health**
```bash
rtk git status
rtk git log --oneline -5
rtk git stash list
```
   - Untracked files that should be in `.gitignore`
   - Staged but uncommitted changes (work at risk)
   - Branch status: ahead/behind remote, merge conflicts
   - Last commit: is it reasonable? (no huge commits, no secrets)

2. **Dependencies**
```bash
rtk pnpm outdated          # Node
pip list --outdated        # Python
cargo outdated             # Rust
rtk pnpm audit             # Node vulnerability check
```
   - Outdated packages with known vulnerabilities
   - Missing packages (imports that don't resolve)
   - Lock file mismatches (package.json vs lock file drift)

3. **Tests**
```bash
rtk pnpm test              # Node
rtk python -m pytest -q    # Python
rtk cargo test             # Rust
```
   - Report pass/fail count
   - Identify files with no test coverage
   - Flag tests that are skipped or marked xfail

4. **Secrets & credentials**
```bash
# Check for leaked secrets in source:
grep -r "sk-\|api_key\s*=\|password\s*=\|secret\s*=" --include="*.ts" --include="*.py" --include="*.js" -l .
# Check .env is gitignored:
cat .gitignore | grep -E "^\.env"
# Check recent git history:
rtk git log --oneline -20
```

5. **Environment**
```bash
node --version && npm --version
python --version
# Check .env.example vs actual env:
cat .env.example 2>/dev/null || echo "no .env.example"
```
   - Required env vars: which are missing from `.env.example` or not set?
   - Tool versions: do they match what the project expects?

6. **Claude Code config**
```bash
ls ~/.claude/hooks/
ls ~/.claude/commands/mm/ | head -20
ls .planning/ 2>/dev/null || echo "no .planning dir"
```
   - Hooks registered and executable?
   - Commands installed and named correctly?
   - `.planning/` directory: stale plans or incomplete retros?

For each area: ✅ healthy | ⚠️ warning | 🔴 needs fix

End with a prioritized list: "Top 3 things to fix right now."

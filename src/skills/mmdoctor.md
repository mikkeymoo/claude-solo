Diagnose your project and Claude Code environment. Find problems before they find you.

Run a full health check across 6 areas:

1. **Git health**
   - Untracked files that should be in `.gitignore`
   - Staged but uncommitted changes (work at risk)
   - Branch status: ahead/behind remote, merge conflicts
   - Last commit: is it reasonable? (no huge commits, no secrets)

2. **Dependencies**
   - Outdated packages with known vulnerabilities (`npm audit`, `pip check`, `cargo audit`)
   - Missing packages (imports that don't resolve)
   - Lock file mismatches (package.json vs package-lock.json drift)

3. **Tests**
   - Run the test suite — report pass/fail count
   - Identify files with no test coverage
   - Flag tests that are skipped or marked xfail

4. **Secrets & credentials**
   - Scan for API keys, passwords, tokens in source files
   - Check `.env` files are in `.gitignore`
   - Scan recent git history for accidentally committed secrets

5. **Environment**
   - Required env vars: which are missing from `.env.example` or not set?
   - Tool versions: Python, Node, etc. — do they match what the project expects?
   - Platform compatibility: any Windows-only or Linux-only code paths?

6. **Claude Code config**
   - Hooks registered and executable?
   - Skills installed and named correctly?
   - `.planning/` directory: stale plans or incomplete retros?

For each area: ✅ healthy | ⚠️ warning | 🔴 needs fix

End with a prioritized list: "Top 3 things to fix right now."

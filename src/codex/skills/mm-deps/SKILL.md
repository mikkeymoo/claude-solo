---
name: mm-deps
description: "Audit project dependencies: vulnerabilities, outdated packages, license issues, unused deps. Produces a prioritized fix list."
---

# mm-deps

Audit project dependencies: vulnerabilities, outdated packages, license issues, unused deps. Produces a prioritized fix list.

## Instructions
Audit this project's dependencies for vulnerabilities, outdated packages, license issues, and bloat.

Delegate to the dependency-auditor agent for a full report.

Run the agent with this scope:

1. **Vulnerability scan** — find CVEs with known fixes
2. **Outdated packages** — flag anything > 1 major version behind
3. **License audit** — flag GPL/AGPL in commercial projects, unknown licenses
4. **Unused dependencies** — find packages in package.json not imported anywhere
5. **Supply chain risks** — unmaintained packages, suspicious new additions

After the agent reports, produce a prioritized action plan:

```markdown
## Dependency Action Plan

### Do now (blocking)
- [ ] upgrade X from 1.2 to 1.4 — CVE-2024-XXXX

### Do this week
- [ ] upgrade Y from 2.0 to 3.0 — major version, check migration guide

### Do next sprint
- [ ] remove Z — unused, confirmed by depcheck

### Review (low priority)
- [ ] A license is LGPL — verify commercial use is OK
```

Ask before running any package installs or updates.

---
name: mm:deps
description: "Audit and update dependencies. Checks for outdated packages, CVEs, and breaking changes."
---

Audit and update dependencies.

1. **Inventory** — detect package manager (npm/pnpm/bun/cargo/pip/go mod) and list outdated packages
2. **CVEs** — run security audit (`npm audit`, `cargo audit`, `pip-audit`, etc.)
3. **Prioritize**:
   - 🔴 CVE with known exploit — update immediately
   - 🟡 Major version bump with breaking changes — review changelog first
   - 🔵 Minor/patch — update in batch
4. **Update** — apply updates in groups; run tests after each group
5. **Commit** — `chore(deps): update <package(s)>` with a note on any breaking changes resolved

Don't update packages that are pinned with a comment explaining why — ask first.

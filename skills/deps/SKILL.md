---
name: deps
description: "Dependency audit and cleanup: security vulnerabilities, outdated packages, unused imports. Auto-detects npm, pnpm, pip, cargo. Use when checking dependencies, upgrading safely, or finding unused packages."
argument-hint: "[--audit|--upgrade|--clean|--why PKG]"
---

# /deps — Dependency Audit & Cleanup

Auto-detects package manager (npm, pnpm, pip, cargo) and performs dependency analysis.

## Modes

### --audit (default)

Security and freshness check:

1. Run bundled `dep_analyzer.py` to identify unused and outdated packages
2. Run native security scanner:
   - **npm/pnpm**: `npm audit --json`
   - **pip**: `pip-audit --format json` (or `pip install pip-audit` if missing)
   - **cargo**: `cargo audit --json`
3. Report structure:
   - 🔴 **CRITICAL CVEs** first (CVSS ≥ 9.0)
   - 🟡 **HIGH CVEs** (CVSS 7.0–8.9)
   - 📦 **Outdated packages** (show current vs. latest version)
   - 💀 **Unused packages** (in manifest but never imported)

### --upgrade

Interactive upgrade guide:

1. Run `dep_analyzer.py` to list outdated packages
2. For each outdated package:
   - Show current version, latest version, age
   - Flag breaking changes (major version bump) as risky
   - Show which files import it (helps assess risk)
3. Ask which to upgrade (safe: patch/minor; risky: major)
4. Output suggested `npm update` / `pip install --upgrade` / `cargo update` commands

### --clean

Find and remove unused dependencies:

1. Run `dep_analyzer.py --unused` to list packages in manifest never imported
2. Confirm each removal
3. Run:
   - **npm**: `npm uninstall <pkg>`
   - **pnpm**: `pnpm remove <pkg>`
   - **pip**: Remove from requirements.txt or pyproject.toml
   - **cargo**: Remove from Cargo.toml
4. Commit: `chore(deps): remove unused <pkg>`

### --why PKG

Explain why a package is installed:

Run `dep_analyzer.py --why PKG` to show:

- Which files import/require PKG
- How many import sites
- Whether it's a direct dependency (package.json) or transitive

## Bundled Script

Run `python skills/deps/dep_analyzer.py [options]` for package analysis.

Flags:

- `--unused` — list packages in manifest but never imported
- `--why PKG` — show which files import a given package
- `--outdated` — check for newer versions (requires internet; optional)
- `--format json|text` — machine-readable or human-readable output

Supports:

- **npm/pnpm**: analyzes `package.json` + lockfile, searches `src/`, `lib/`, `app/` for imports
- **pip**: analyzes `requirements.txt` or `pyproject.toml`, searches `.py` files for imports
- **cargo**: analyzes `Cargo.toml`, searches `.rs` files for `use` statements

Gracefully handles missing package managers (e.g., running in a repo with only npm).

## SUCCESS CRITERIA

- [ ] Correct package manager auto-detected (or explicit error if none found)
- [ ] `--audit` lists CVEs in severity order, shows outdated packages, flags unused
- [ ] `--upgrade` shows version diffs and import site counts, distinguishes safe from risky
- [ ] `--clean` requires confirmation before uninstalling
- [ ] `--why PKG` accurately shows all import sites in the codebase
- [ ] No false positives (pkg aliased as different name, dynamic imports, optional dependencies)
- [ ] Script exits gracefully if package manager not installed locally

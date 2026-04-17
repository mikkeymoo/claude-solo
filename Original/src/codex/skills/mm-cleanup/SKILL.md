---
name: mm-cleanup
description: "Code cleanup — find dead/stale code (--audit) or do a full regression-safe cleanup of dead code, duplication, and AI padding."
---

# mm-cleanup

Code cleanup — find dead/stale code (--audit) or do a full regression-safe cleanup of dead code, duplication, and AI padding.

## Instructions
Clean up code quality issues. Two modes:

- `--audit` — find and catalogue issues only (no changes, produces checklist)
- Default — full cleanup: regression-tests-first, multi-pass, quality-gated

---

## --audit mode (find only)

Scan for stale code and produce a cleanup checklist without touching anything.

**1. TODOs/FIXMEs older than 30 days**
```bash
grep -rn "TODO\|FIXME\|HACK\|XXX" --include="*.ts" --include="*.js" --include="*.py" . | grep -v node_modules
```
For each hit: check `rtk git log -1 -- <file>` to see when last touched. Flag items 30+ days old.

**2. Commented-out code**
```bash
grep -rn "^[[:space:]]*//.*[a-zA-Z_]\+\s*(" --include="*.ts" --include="*.js" . | grep -v node_modules | head -50
grep -rn "^[[:space:]]*#.*def \|^[[:space:]]*#.*class " --include="*.py" . | head -50
```

**3. Dead exports (unused)**
```bash
grep -rn "^export " --include="*.ts" . | grep -v node_modules | grep -v ".d.ts" | head -50
```
For each export, verify it's imported somewhere.

**4. Deprecated patterns**
- `any` type in TypeScript
- `eval()` calls, `var` declarations, `console.log` in production code
- Hardcoded localhost/127.0.0.1 URLs

Output as a Markdown checklist. Do not delete anything. End with: "Run `/mm:cleanup` to fix these."

---

## Default mode (full cleanup)

Regression-tests-first. Clean before reviewing — one pass at a time.

**Step 1 — Lock behavior with tests**
```bash
rtk python -m pytest tests/ -x -q   # Python
rtk pnpm test                         # TypeScript
rtk dotnet test                       # .NET
```
If tests are untested, write the narrowest passing test first. Do not start cleanup until baseline is green.

**Step 2 — Plan before touching code**

List smells in target files:
- **Dead code** — unused functions, unreachable branches, debug prints, commented-out blocks
- **Duplication** — copy-paste logic, near-identical helpers
- **Needless abstraction** — one-line wrappers, single-use helper layers
- **Boundary violations** — wrong-layer imports, hidden coupling
- **AI padding** — docstrings on obvious code, over-verbose names, unnecessary type assertions

Order fixes: dead code first (highest signal, lowest risk), abstractions last.
Show plan. Proceed without asking for small scope, ask for large scope.

**Step 3 — Execute one pass at a time**

Pass 1: Dead code → delete unused imports, functions, variables, debug logs. Run tests.
Pass 2: Duplication → consolidate repeated logic. Run tests.
Pass 3: Needless abstraction → inline single-use helpers, flatten indirection. Run tests.
Pass 4: AI padding → remove obvious docstrings, shorten verbose names. Run tests.
Pass 5: Test gaps → add tests for any previously untested behavior.

**Quality gates (all must pass)**
```bash
rtk python -m pytest tests/ -q && rtk python -m ruff check .    # Python
rtk vitest run && rtk pnpm lint && rtk pnpm tsc --noEmit         # TypeScript
rtk dotnet test                                                    # .NET
```

**Output report**
```
MM:CLEANUP REPORT
=================
Scope: [files/module]
Baseline: [X tests passing]
Passes: Dead code: [removed], Duplication: [consolidated], Abstraction: [inlined], AI padding: [cleaned]
Quality gates: Tests PASS | Lint PASS | Types PASS
Changed files: [list]
```

---
name: tech-debt
description: Scan the codebase for technical debt and produce a prioritized, actionable list. Finds duplicated code blocks, dead exports, stale TODO/FIXME older than 30 days, commented-out code blocks, and deprecated API usage. TRIGGER when the user asks to "find tech debt", "clean up", "what should I refactor", "debt audit", or "stale code". Read-only — reports, never edits.
---

# Tech Debt Scanner — Prioritized by Blast Radius

Output a single ranked list. Each item has: severity, evidence, estimated effort to fix. You do not fix anything — this is a reconnaissance skill.

## Scan dimensions (run in parallel)

### 1. Stale markers

```bash
rtk git log --all --diff-filter=A --date=short --pretty=format:'%ad %H' -- '**/*' | head -500
# For each TODO/FIXME/XXX/HACK found, check git blame for age
rtk grep -rn "TODO\|FIXME\|XXX\|HACK" --include="*.{js,ts,py,rs,go,java,cs}" src/
```

Flag any marker older than 30 days with no linked issue/PR.

### 2. Commented-out code

```bash
rtk grep -rnE "^\s*//\s*(if|for|while|function|const|let|return)\b" --include="*.{js,ts}" src/
rtk grep -rnE "^\s*#\s*(def|class|if|for|return)\b" --include="*.py" src/
```

Noise filter: lines preceded by a non-comment line of code.

### 3. Dead exports

- For each exported symbol in `src/**`, run `mcp__serena__find_referencing_symbols` — any with zero external references is a candidate.
- Exclude public API surfaces (anything re-exported from `index.ts` / `__init__.py` at the package root).
- Exclude symbols referenced only in test files if the test itself appears dead.

### 4. Duplication

```bash
# Heuristic: blocks of 6+ identical consecutive lines across files
rtk grep -rn . --include="*.{js,ts,py}" src/ | sort | uniq -c | awk '$1 >= 6 {print}'
```

For each suspected cluster, open both files and confirm it's real duplication (not just boilerplate).

### 5. Deprecated dependencies

```bash
rtk pnpm outdated --long | head -30
rtk pip list --outdated | head -30
rtk npm audit --audit-level=high
```

Flag: majors behind by 2+, anything with an active CVE.

### 6. Forgotten feature flags

```bash
rtk grep -rn "FEATURE_\|FLAG_\|if.*flag" src/
```

Cross-reference with the flag config/service. Any flag 100% on or 100% off for >60 days is a debt item (delete the flag and the dead branch).

## Output format

```
# Tech Debt Report — <repo> — <date>

## 🔴 High — high blast radius, fix soon
1. <file:line> — <problem> — est <S/M/L effort>
   Evidence: <1 line>
   Impact: <why this matters>

## 🟡 Medium — targeted cleanup wins
...

## 🔵 Low — nice to have
...

## Totals
- Stale TODOs: <n>
- Commented-out blocks: <n>
- Dead exports: <n>
- Duplicated blocks: <n>
- Outdated deps (major): <n>
- Stale flags: <n>

## Suggested sprint plan (top 5)
<one-liner each, in priority order>
```

## Severity rubric

- **🔴 High:** security CVE, dead code in hot path, duplication >20 lines across 3+ files, flag on/off for >90 days.
- **🟡 Medium:** stale markers 60+ days, dead exports in public API, outdated deps with no CVE.
- **🔵 Low:** commented-out code, stale markers 30-60 days, minor dep updates.

## Rules

- Never edit. This is an audit skill.
- Every finding must have a file:line reference.
- Do not flag generated code (`dist/`, `build/`, `*.min.js`, vendored deps).
- If the codebase is clean, say so — a short honest report beats a padded one.

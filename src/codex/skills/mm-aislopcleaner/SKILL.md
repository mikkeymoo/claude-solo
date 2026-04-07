---
name: mm-aislopcleaner
description: "Claude-solo command skill"
---

# mm-aislopcleaner

Claude-solo command skill

## Instructions
---
name: mm:aislopcleaner
description: "Regression-tests-first AI slop cleanup. Removes dead code, duplication, over-abstraction, and AI-generated padding without changing behavior."
---

Regression-tests-first AI slop cleanup. Removes noise without changing behavior.

Use when code works but feels bloated, repetitive, over-abstracted, or obviously AI-generated.
Also valid after `/mm:build` — clean before `/mm:review`.

**Scope**: specify files, a module, or run on everything changed since last commit:
```bash
rtk git diff --name-only HEAD~1  # files changed in last commit
```

---

## Step 1 — Lock behavior with tests first

Before touching anything, identify what must not change and verify it's tested:
```bash
# Python
rtk python -m pytest tests/ -x -q

# TypeScript
rtk pnpm test  # or: rtk vitest run

# .NET
rtk dotnet test
```

If behavior is untested, write the narrowest test that covers it **before** cleaning.
Do not start cleanup until the baseline is green.

---

## Step 2 — Cleanup plan (not code yet)

List the smells found in the target files. Categorize each:

- **Dead code** — unused functions, unreachable branches, stale flags, commented-out blocks, debug prints
- **Duplication** — copy-paste logic, repeated conditionals, near-identical helpers
- **Needless abstraction** — one-line wrappers, single-use helper layers, pass-through functions that add nothing
- **Boundary violations** — wrong-layer imports, hidden coupling, leaky responsibilities (e.g., DB logic in a route handler)
- **AI padding** — docstrings on obvious code, excessive comments explaining what the code already says, over-verbose variable names, unnecessary type assertions

Order the fixes: dead code first (highest signal, lowest risk), abstractions last.

Show the plan. Ask: "Proceed with cleanup?" unless scope is clearly small.

---

## Step 3 — Execute one pass at a time

**Pass 1: Dead code**
- Delete unused imports, functions, variables
- Remove unreachable branches
- Remove debug `print()` / `console.log()` / commented-out code
- Run tests after. Must stay green.

**Pass 2: Duplication**
- Consolidate repeated logic into one place
- Remove near-identical helpers — pick the best one, delete the rest
- Run tests after. Must stay green.

**Pass 3: Needless abstraction**
- Inline single-use helpers that add no clarity
- Remove pass-through wrappers
- Flatten unnecessary indirection
- Run tests after. Must stay green.

**Pass 4: AI padding**
- Remove docstrings that restate the function name
- Remove comments that explain obvious code (`# increment counter` above `count += 1`)
- Rename `result_data_object` → `result`, `user_information_dict` → `user`
- Run tests after. Must stay green.

**Pass 5: Test reinforcement** (if gaps found in Step 1)
- Add tests for any behavior that was untested
- Verify edge cases are covered

---

## Quality gates (all must pass before done)

```bash
# Run full suite
rtk python -m pytest tests/ -q       # Python
rtk vitest run                        # TypeScript
rtk dotnet test                       # .NET

# Lint
rtk python -m ruff check .            # Python
rtk pnpm lint                         # TypeScript

# Types
rtk python -m mypy src/               # Python (if configured)
rtk pnpm tsc --noEmit                 # TypeScript
```

If any gate fails, fix it before marking done.

---

## Output report

```
MM:DESLOP REPORT
================

Scope: [files or module]
Baseline: [X tests passing before cleanup]

Passes:
1. Dead code   — [what was removed]
2. Duplication — [what was consolidated]
3. Abstraction — [what was inlined/removed]
4. AI padding  — [what was cleaned]
5. Tests       — [what was added]

Quality gates:
- Tests:      PASS (X passing)
- Lint:       PASS / FAIL
- Types:      PASS / FAIL / N/A

Changed files:
- path/to/file.py — [simplification in one line]

Remaining:
- [none, or deferred items with reason]
```

Do not bundle smell categories into one large edit. One pass, verify, next pass.

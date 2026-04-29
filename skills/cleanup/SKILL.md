---
name: cleanup
description: "Code cleanup — find dead/stale code (--audit) or do a full regression-safe cleanup of dead code, duplication, and AI padding. Use when code quality needs attention."
argument-hint: "[--audit | --aggressive | path/to/scope]"
---

# /cleanup — Code Quality

Three modes:

- `--audit` — find and catalogue issues only (no changes, produces checklist)
- Default — full cleanup: regression-tests-first, multi-pass, quality-gated
- `--aggressive` — maximum dead code removal with safety review (more thorough, use on branch if unsure)

## --audit mode (find only)

Scan for stale code and produce a cleanup checklist without touching anything.

**1. TODOs/FIXMEs older than 30 days**
For each hit: check `rtk git log -1 -- <file>` to see when last touched. Flag items 30+ days old.

**2. Commented-out code**
Scan for commented function definitions, class definitions, and large commented blocks.

**3. Dead exports (unused)**
For each export, verify it's imported somewhere.

**4. Deprecated patterns**

- `any` type in TypeScript
- `eval()` calls, `var` declarations, `console.log` in production code
- Hardcoded localhost URLs

Output as a Markdown checklist. Do not delete anything. End with: "Run `/cleanup` to fix these."

## --aggressive mode (maximum removal)

Maximum dead code removal with safety review. More thorough than default cleanup.

**Step 1 — Static analysis pass**
Run bundled `dead_code_scanner.py --all` to find ALL candidates:

- Unused imports (even if used in comments)
- Unreachable code branches (after `return`, after `raise`, in `else` after `return`)
- Empty error handlers: `except: pass`, `catch (e) {}`, `catch { }`
- Unused function parameters
- Dead feature flags (constants that are always true/false)

**Step 2 — Before/after baseline**
Run linter and capture current warning count. This establishes a baseline for comparison after aggressive cleanup.

**Step 3 — Diff review**
Generate a markdown table showing all planned removals before applying:

```
| File | Line | Item | Type | Confidence |
|------|------|------|------|------------|
| src/utils.ts | 45 | formatDate (unused) | function | High |
| src/index.ts | 12 | unused param | parameter | High |
| src/config.ts | 8 | dead flag | constant | Medium |
```

**Step 4 — Interactive confirmation**
Print the diff table and ask: "Apply all? (y/n/select)". Allow user to confirm all changes, skip, or cherry-pick specific removals.

**Step 5 — Apply and verify**
Remove all confirmed items, run linter again to verify no new warnings are introduced.

**Step 6 — Run tests**
Execute full test suite to ensure no behavioral regressions.

**Step 7 — Commit**
`chore(cleanup): remove dead code — N items removed across M files`

⚠️ **Warning**: `--aggressive` makes more removals than default cleanup. Run tests after. Use on a branch if unsure.

## Default mode (full cleanup)

Regression-tests-first. One pass at a time.

**Step 1 — Lock behavior with tests**
Run existing test suite. Do not start cleanup until baseline is green.

**Step 2 — Plan before touching code**
List smells: dead code, duplication, needless abstraction, boundary violations, AI padding.
Order: dead code first (highest signal, lowest risk), abstractions last.

**Step 3 — Execute one pass at a time**
Pass 1: Dead code → delete unused imports, functions, variables, debug logs. Run tests.
Pass 2: Duplication → consolidate repeated logic. Run tests.
Pass 3: Needless abstraction → inline single-use helpers. Run tests.
Pass 4: AI padding → remove obvious docstrings, shorten verbose names. Run tests.

## Bundled Script

Run `python skills/cleanup/dead_code_scanner.py [path]` for automated scanning.

Flags:

- `--py-only` / `--js-only` — language filter
- `--todos` — stale TODOs only
- `--commented` — commented-out code blocks only

The script uses Python AST for `.py` files and regex heuristics for JS/TS. It detects:
unused imports, potentially unused functions/classes, `console.log`/`debugger` statements,
commented-out code blocks (3+ lines), and stale TODOs with git-blame age.

Use in `--audit` mode: run the script first, then present its output as the checklist.

## SELF-CHECK

Before returning, grade your response:

- [ ] In `--audit` mode: output is a checklist with categories (TODOs, dead code, dead exports, patterns) and no code is modified — PASS/FAIL
- [ ] In default mode: all tests pass before cleanup starts (baseline established) — PASS/FAIL
- [ ] Each pass (dead code → duplication → abstraction → padding) passes tests independently — PASS/FAIL
- [ ] Every deleted item was verified as unused: checked for imports, references, git history (30+ days for TODOs) — PASS/FAIL
- [ ] Summary shows counts: "Removed X unused imports, Y dead functions, Z commented blocks" — PASS/FAIL

If any item is FAIL: revise before returning.

## SUCCESS CRITERIA

- [ ] In `--audit` mode: Output is a checklist with categories (stale TODOs, dead code, dead exports, deprecated patterns) and no code is modified
- [ ] In default mode: All tests pass before cleanup starts (baseline established)
- [ ] Each pass (dead code → duplication → abstraction → padding) runs independently and tests pass after each pass
- [ ] Deleted items are verified as unused: checked for imports, references, and git history (30+ days old for TODOs)
- [ ] Summary shows counts: "Removed X unused imports, Y dead functions, Z commented blocks, N old TODOs"
- [ ] No refactoring is attempted during dead-code removal — each pass focuses on one smell type
- [ ] Final commit message references the pass and changes: `chore(cleanup): remove dead code pass 1`

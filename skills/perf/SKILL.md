---
name: perf
description: "Performance profiling — find and fix common performance anti-patterns. Use when optimizing code, investigating slow areas, or analyzing database queries."
argument-hint: "[--quick | --deep | --db]"
---

# /perf — Performance Analysis

Three modes:

- `--quick` (default) — surface scan for obvious performance anti-patterns
- `--deep` — trace execution paths to identify hot spots and bottlenecks
- `--db` — database query analysis (N+1, unbounded queries, missing indexes)

## --quick mode (surface scan)

Detect obvious anti-patterns without deep instrumentation.

**1. O(n²) patterns**
Find nested loops over the same collection. Example: `for item in list: for other in list:`.
Scan for `for`/`while` loops containing another `for`/`while` at different nesting levels.

**2. Array/object allocations in loops**
Large data structure allocations inside loops (can cause GC pressure, memory bloat).
Look for: `new Array(...)`, `new Map/Set()`, `[]`, `{}` created in every iteration.

**3. Synchronous I/O in hot paths**
Blocking file/network reads in loops or request handlers.
Patterns: `fs.readFileSync`, `open()` without `async`, `.json()` parse in tight loops.

**4. Unnecessary re-renders (React)**
State updates in render paths, missing useCallback/useMemo where needed.
Look for: `setState` in render, expensive operations in component body (not memoized).

**5. String concatenation in loops**
Building strings by repeated concatenation (O(n²) behavior in some languages).
Look for: `s = s + item`, `str += part` in loops.

Output grouped by file with severity (HIGH/MEDIUM/LOW), line numbers, and concrete fix suggestions.

## --deep mode (execution tracing)

Trace call graphs to find hot spots.

**1. Identify entry points**
Start from routes/exports. Use stack traces or profiler data if available.

**2. Trace execution paths**
Follow calls from entry to leaf functions. Flag:

- Functions called frequently (many callers)
- Functions with high cyclomatic complexity
- Deep call chains (>5 levels)

**3. Find bottlenecks**

- Functions called millions of times (accumulation)
- Expensive operations (heavy math, crypto, serialization) not cached
- Synchronous operations on IO boundaries

Output: call graph summary, hottest functions by estimated frequency, optimization path suggestions.

## --db mode (database analysis)

Scan for query anti-patterns.

**1. N+1 detection**
Loop containing a DB/API call. Pattern: `for item in items: query(item.id)`.
Find correlation between loop variables and query parameters.

**2. Unbounded queries**
Queries missing LIMIT or pagination.
Patterns: `SELECT * FROM table` without LIMIT in hot paths.

**3. Missing indexes**
WHERE/JOIN clauses on non-indexed columns (requires schema inspection).
Report fields used in WHERE/JOIN but not marked as indexed.

**4. Inefficient joins**
Cartesian products, missing join conditions, or joining on non-PK fields.

**5. Aggregation without indexes**
GROUP BY, ORDER BY on non-indexed columns.

Output: each finding with severity, SQL pattern, and remediation (add index, pagination, query rewrite).

## Bundled Script

Run `python skills/perf/perf_analyzer.py [path] [--lang py|js|ts|auto] [--format text|json]` for automated detection.

Flags:

- `--lang py` / `--lang js` / `--lang ts` — language filter (default: auto-detect)
- `--format text` — human-readable (default)
- `--format json` — machine-readable JSON output

Detects: O(n²) loops, array allocations in loops, sync I/O in loops, string concatenation, N+1 patterns, unused variables in tight loops.
Groups findings by file, sorts by severity (HIGH → MEDIUM → LOW).

Use in `--quick` mode: run the script first, present its output, then discuss remediation.

## CONFIDENCE SCORING

Rate each finding with a confidence score (0–100):

| Score  | Label    | Meaning                                                        |
| ------ | -------- | -------------------------------------------------------------- |
| 95–100 | Definite | Issue is certain — reproducible, not context-dependent         |
| 75–94  | High     | Very likely an issue, minor context uncertainty                |
| 50–74  | Medium   | Context-dependent — may be intentional or environment-specific |
| <50    | Low      | Flag explicitly — possible false positive, needs human review  |

Format: append `[confidence: N]` to each finding.

Example: `🔴 HIGH — N+1 query pattern in user_posts_loader() — loop with query per item [confidence: 98]`

For LOW confidence findings (<50): prefix with `⚠️ UNCERTAIN:` and explain what additional context would clarify it.

## SELF-CHECK

Before returning, verify:

- [ ] Each finding has: location (file:line), pattern name, estimated impact (HIGH/MEDIUM/LOW), fix suggestion
- [ ] HIGH-impact issues listed first
- [ ] Fixes are concrete (actual code change, not "optimize this")
- [ ] For N+1: query name, loop structure, and pagination/batching fix shown
- [ ] For O(n²): nested loop range, data size estimate, and refactored pseudocode shown
- [ ] No findings are false positives (filter out test code, library code if possible)

If any FAIL: revise the output before returning.

## SUCCESS CRITERIA

- [ ] In `--quick` mode: Surface scan finds all O(n²) patterns, allocations in loops, sync I/O, and string concatenation with line numbers and severity
- [ ] In `--deep` mode: Call graph shows entry points → hot functions, with estimated call frequency or complexity scores
- [ ] In `--db` mode: Each N+1 finding names the loop variable and the query pattern; includes pagination/batch fix
- [ ] All findings include: file:line, pattern type, impact level (HIGH/MEDIUM/LOW), concrete fix code (not just description)
- [ ] Output is grouped by file, sorted by impact (HIGH first)
- [ ] Script runs without external dependencies (stdlib only), handles syntax errors gracefully, and exits with 0 on completion
- [ ] Summary line reports total findings by severity: "X HIGH, Y MEDIUM, Z LOW"

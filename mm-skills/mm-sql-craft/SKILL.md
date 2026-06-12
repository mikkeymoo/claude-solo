---
name: mm-sql-craft
description: "Format, refactor, optimize, and lint Microsoft SQL Server (T-SQL). Reshapes SQL to a consistent house style (block-indented, trailing commas, UPPERCASE keywords, PascalCase schema-qualified names), restructures queries into CTEs/set-based logic, makes predicates SARGable, hardens procedures (XACT_ABORT + TRY/CATCH + THROW), de-risks dynamic SQL (sp_executesql + QUOTENAME), reads execution-plan red flags, and flags anti-patterns (scalar UDFs, table variables, parameter sniffing, key lookups, MERGE, NOLOCK, window-frame bugs). Use when working with .sql files, T-SQL queries, stored procedures, views, functions, or MSSQL DDL — or when the user says: format/clean up this SQL, refactor this query/proc, optimize/tune this query, make it sargable, lint my SQL, harden this proc, t-sql, mssql, sql server."
argument-hint: "[--format | --refactor | --optimize | --lint | --harden] [--ask] [file|paste SQL]"
---

# /mm-sql-craft — T-SQL Format · Refactor · Optimize · Harden · Lint

Works the SQL you give it (a `.sql` file, a paste, or selected text). Target dialect is
**Microsoft SQL Server (T-SQL)**. The canonical house style, the full anti-pattern catalog,
SARGability rules, proc/dynamic-SQL hardening templates, and execution-plan red flags live in
[REFERENCE.md](REFERENCE.md); worked before/after transforms are in [EXAMPLES.md](EXAMPLES.md).
Read those files before a non-trivial refactor/optimize/harden pass — don't work from memory.

## Modes

- **`--format`** — reshape to house style only. **Never** change what the query *does*.
- **`--refactor`** — behavior-preserving restructure (CTEs, set-based rewrites, scalar-UDF→inline-TVF, dedupe, renames). Auto-applies.
- **`--optimize`** — performance: SARGability, type matches, `OR`→`UNION ALL`, key-lookup/covering indexes, window-frame fixes, `SELECT *`, index DDL (create/alter/drop). Auto-applies. May change the plan, not the result set.
- **`--harden`** — production-safety pass on procs/DML: `SET XACT_ABORT, NOCOUNT ON`, `TRY/CATCH` + `;THROW`, `@@TRANCOUNT`-checked rollback, parameterize dynamic SQL (`sp_executesql` + `QUOTENAME`). Auto-applies.
- **`--lint`** — report-only. Find anti-patterns with severity + confidence + fix; change nothing.
- **No flag** — apply `--format`, then auto-apply every `--refactor`, `--optimize`, `--harden`, and behavior-changing lint finding in a single pass. Do **not** ask for confirmation (god mode).
- **`--ask`** — opt-in gating: list findings and confirm each before applying. Use only when the user explicitly requests it. Composable with any mode.

Always show **before → after** and a one-line summary of every change. Label any change that alters
result rows or values as **behavior-changing** in the summary, but still apply it. Confirmation is the
user's responsibility (they can `git diff` or run `--ask`). The **Safety** section below lists the only
changes the skill must never auto-apply — everything else is fair game.

## House style (the defaults this skill enforces)

Full rules + rationale in [REFERENCE.md](REFERENCE.md). The short version:

- **Keywords UPPERCASE** (`SELECT`, `FROM`, `INNER JOIN`); object/column names keep their own case (never re-case identifiers — behavior risk on case-sensitive collations).
- **Block-indented, one item per line, trailing commas.** 4-space indent (2 spaces acceptable for deeply nested CTEs/subqueries).
- **PascalCase, singular, schema-qualified** — `dbo.CustomerOrder`, never bare `CustomerOrder`. Brackets only for reserved words or names with spaces/special chars (`[Order]`, `[From]`).
- **Explicit joins** — `INNER JOIN` / `LEFT JOIN`, never bare `JOIN` or comma-joins. `ON` on its own indented line.
- **Terminate every statement with `;`**. Use `AS` for table aliases; short, meaningful aliases (`c`, `o`).
- **`SET XACT_ABORT, NOCOUNT ON;`** at the top of every stored procedure; wrap proc bodies in `BEGIN … END`; `CREATE OR ALTER`.
- Date ranges as `>= AND <` over `BETWEEN`; `IS NULL` / `IS NOT NULL`; `THROW` over `RAISERROR`; explicit `ROWS` window frames over the implicit `RANGE` default.

```sql
SELECT
    c.CustomerID,
    c.FirstName,
    c.LastName,
    o.OrderDate
FROM dbo.Customer AS c
INNER JOIN dbo.[Order] AS o
    ON o.CustomerID = c.CustomerID
WHERE c.IsActive = 1
    AND o.OrderDate >= '2024-01-01'
ORDER BY o.OrderDate DESC;
```

## Workflow

1. **Read the input.** Identify statement type (query / DML / DDL / proc / view / function / dynamic SQL) and whether it's a file or a paste.
2. **Load depth.** For any refactor/optimize/harden pass, open [REFERENCE.md](REFERENCE.md) (§4 SARGability, §5 anti-patterns, §6 proc shape, §7 dynamic SQL, §8 plan red flags) and match the input against the catalogs.
3. **Pick the pass** from the flag, or default (god mode) above.
4. **Apply** per mode. With no flag (or `--refactor`/`--optimize`/`--harden`), apply every finding — including behavior-changing ones — without asking. Group the summary into *safe* and *behavior-changing* buckets.
5. **Verify** (when a connection is in scope): run before/after, confirm row-count shape is preserved or call out the intended delta; if asked, capture the actual execution plan and confirm seeks replaced scans.
6. **Show before → after** for each change with a one-line reason. For files, edit in place; for pastes, return the result in a ```sql block.
7. **Self-check** (below) before returning.

## Refactor catalog (`--refactor`)
Nested/repeated subqueries → named, ordered CTEs · correlated subquery → `JOIN`/`APPLY` · cursor/`WHILE` loop → set-based ·
scalar UDF in `SELECT`/`WHERE` → inline TVF + `CROSS APPLY` (or schema-bound) · `UNION` → `UNION ALL` when dupes are impossible ·
`MERGE` → separate `INSERT`/`UPDATE`/`DELETE` (MERGE has documented concurrency/trigger bugs — see REFERENCE §5) ·
table variable in a join/large set → `#temp` (statistics) · repeated expressions → CTE or `CROSS APPLY (VALUES…)` · flatten nested views ·
clarify cryptic aliases/columns. Details + examples in [REFERENCE.md](REFERENCE.md) / [EXAMPLES.md](EXAMPLES.md).

## Optimize catalog (`--optimize`)
Make predicates **SARGable** (no functions/conversions on indexed columns; `YEAR(d)=2024` → `d >= '2024-01-01' AND d < '2025-01-01'`) ·
fix implicit conversions (INT-vs-`'1001'`, `VARCHAR`-vs-`NVARCHAR` param) · leading-wildcard `LIKE '%x'` → flag (full-text/redesign) ·
`OR` across different columns → `UNION ALL` (each branch seeks its own index) · `NOT IN` on nullable cols → `NOT EXISTS` ·
scalar UDF in predicate → inline TVF · key-lookup blow-up → covering/`INCLUDE` index · window function: add explicit `ROWS` frame ·
parameter sniffing → `OPTION (RECOMPILE)` / `OPTIMIZE FOR` / split procs (note SQL 2022 PSP) · replace `SELECT *` with explicit columns ·
emit and apply index DDL — covering/filtered indexes (`CREATE INDEX`), rebuilds (`ALTER INDEX … REBUILD`), drop redundant (`DROP INDEX`). Show the DDL, label it, apply it.

## Harden catalog (`--harden`)
Add `SET XACT_ABORT, NOCOUNT ON;` · wrap body in `TRY/CATCH` with `IF @@TRANCOUNT > 0 ROLLBACK; ` then `;THROW` (leading semicolon) ·
no code after the outermost `END CATCH` · explicit transaction around multi-statement writes · `RAISERROR` → `THROW` ·
dynamic SQL: string-concatenated input → `sp_executesql` with typed parameters for **values**, `QUOTENAME()` per identifier part for **object names** (see REFERENCE §7). Templates in [REFERENCE.md](REFERENCE.md) §6–§7.

## Lint catalog (`--lint`)
`SELECT *` · `WITH (NOLOCK)`/`NOLOCK` (dirty reads) · non-SARGable predicates · implicit conversions · missing schema prefix ·
bare/comma joins · `*=`/`=*` · missing `;` · `sp_` proc prefix · scalar UDF in predicate (RBAR + kills parallelism) · table variable joined to a big set ·
`MERGE` (caution) · proc with transaction but no `XACT_ABORT`/`TRY-CATCH` · dynamic SQL built by string concatenation (**injection**) ·
window function with no explicit frame (`LAST_VALUE` bug + spool cost) · `FLOAT`/`REAL` for money · `TOP` without `ORDER BY` · `ORDER BY` ordinal ·
deprecated `TEXT`/`NTEXT`/`IMAGE`, `RAISERROR` · `SELECT` without an `ORDER BY` where order is assumed.
Output each as: `severity — rule — file:line — fix [confidence: N]`. See severity table in [REFERENCE.md](REFERENCE.md) §5.

## Safety

The skill auto-applies edits by default (god mode) — including index DDL and destructive DML. Two classes
are **allowed and auto-applied**, but must be loudly labelled so the user can review the diff:

- **Index DDL** — `CREATE INDEX`, `ALTER INDEX … REBUILD/REORGANIZE`, `DROP INDEX`. Emit as live (non-commented) statements and apply. Label each with its purpose (covering, filtered, dedupe).
- **Destructive DML / DDL** — `DELETE`, `UPDATE`, `TRUNCATE`, `DROP`. Allowed and applied. Preserve any existing `WHERE` exactly; when the operation is unbounded (no `WHERE`, full-table `TRUNCATE`/`DROP`), state the **blast radius** in the summary (table, whole-table scope) so it's unmissable. Never *add* or *widen* a `WHERE` the author didn't write.

These remain hard stops — confirm explicitly regardless of mode:

- **Schema/object renames** — `sp_rename`, table/column renames that callers may depend on.
- **Connecting to a server / executing SQL** — only if the user has provided a connection (e.g. a `.env` in scope) or explicitly asks. Use the connection to *verify* edits and capture plans, not to mutate data unprompted.
- **`LEFT JOIN` → `INNER JOIN`** when the right side might filter rows — flag and require confirmation even though it's an optimization.
- **`MERGE` → split statements** when triggers/`OUTPUT`/`WHEN NOT MATCHED BY SOURCE` semantics could differ — flag the semantic delta.

> God mode is the skill's own posture; it does not override the harness. Destructive SQL run from
> the shell, `git push --force`, and edits to `.env`/secrets are still blocked by project hooks —
> read the hook `reason` and adjust, don't retry blindly.

## Self-check (before returning)
- [ ] `--format` produced **identical semantics** — only whitespace/case/layout changed.
- [ ] Every behavior-changing rewrite is **applied** and clearly labelled in the summary (not gated on confirmation, unless `--ask`).
- [ ] Output matches house style: UPPERCASE keywords, trailing commas, schema-qualified, explicit joins, `;` terminators, explicit window frames.
- [ ] `--harden` output has `SET XACT_ABORT, NOCOUNT ON`, `TRY/CATCH` + `;THROW`, `@@TRANCOUNT` rollback guard, and parameterized dynamic SQL.
- [ ] Each lint finding has location, fix, and confidence; SARGability/anti-pattern claims are grounded in REFERENCE §4–§5, not guessed.
- [ ] Index DDL and destructive DML, if applied, are shown as live statements and labelled with purpose/blast radius (not silent).
- [ ] None of the **Safety** hard-stops were silently crossed (renames, server execution beyond verify, ambiguous `LEFT`→`INNER`, MERGE semantic deltas).
- [ ] If a connection is in scope, the file was executed before/after; row-count shape (and plan, if requested) diff is reported.

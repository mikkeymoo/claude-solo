---
name: sql-craft
description: "Format, refactor, optimize, and lint Microsoft SQL Server (T-SQL). Reshapes SQL to a consistent house style (block-indented, trailing commas, UPPERCASE keywords, PascalCase schema-qualified names), restructures queries into CTEs/set-based logic, makes predicates SARGable, and flags anti-patterns. Use when working with .sql files, T-SQL queries, stored procedures, views, functions, or MSSQL DDL — or when the user says: format/clean up this SQL, refactor this query/proc, optimize/tune this query, make it sargable, lint my SQL, t-sql, mssql, sql server."
argument-hint: "[--format | --refactor | --optimize | --lint] [file|paste SQL]"
---

# /sql-craft — T-SQL Format · Refactor · Optimize · Lint

Works the SQL you give it (a `.sql` file, a paste, or selected text) in one of four passes.
Target dialect is **Microsoft SQL Server (T-SQL)**. The canonical house style is in
[REFERENCE.md](REFERENCE.md); worked before/after transforms are in [EXAMPLES.md](EXAMPLES.md).

## Modes

- **`--format`** — reshape to house style only. **Never** change what the query *does*.
- **`--refactor`** — behavior-preserving restructure (CTEs, set-based rewrites, dedupe, renames).
- **`--optimize`** — performance: SARGability, type matches, `SELECT *`, index hints. May change the plan, not the result set.
- **`--lint`** — report-only. Find anti-patterns with severity + fix; change nothing.
- **No flag** — format the input, then list (don't apply) the refactor/optimize/lint findings and ask which to run.

Always show **before → after** and a one-line summary of every change. Don't silently alter semantics.
When a "fix" would change results (e.g. `LEFT JOIN`→`INNER JOIN`, removing `DISTINCT`), flag it as **behavior-changing** and ask first.

## House style (the defaults this skill enforces)

Full rules + rationale in [REFERENCE.md](REFERENCE.md). The short version:

- **Keywords UPPERCASE** (`SELECT`, `FROM`, `INNER JOIN`); object/column names keep their own case.
- **Block-indented, one item per line, trailing commas.** 4-space indent (2 spaces acceptable for deeply nested CTEs/subqueries).
- **PascalCase, singular, schema-qualified** — `dbo.CustomerOrder`, never bare `CustomerOrder`. Brackets only for reserved words or names with spaces/special chars (`[Order]`, `[From]`).
- **Explicit joins** — `INNER JOIN` / `LEFT JOIN`, never bare `JOIN` or comma-joins. `ON` on its own indented line.
- **Terminate every statement with `;`**. Use `AS` for table aliases; short, meaningful aliases (`c`, `o`).
- **`SET NOCOUNT ON;`** at the top of every stored procedure; wrap proc bodies in `BEGIN … END`.
- Date ranges as `>= AND <` over `BETWEEN`; `IS NULL` / `IS NOT NULL`; `THROW` over `RAISERROR`.

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

1. **Read the input.** Identify statement type (query / DML / DDL / proc / view / function) and whether it's a file or a paste.
2. **Pick the pass** from the flag, or default behavior above.
3. **Apply / report** per mode. For `--optimize` and `--refactor`, separate *safe* changes from *behavior-changing* ones.
4. **Show before → after** for each change with a one-line reason. For files, edit in place; for pastes, return the result in a ```sql block.
5. **Self-check** (below) before returning.

## Refactor catalog (`--refactor`)
Nested/repeated subqueries → CTEs · correlated subquery → `JOIN`/`APPLY` · cursor/`WHILE` loop → set-based ·
`UNION` → `UNION ALL` when dupes are impossible · repeated expressions → CTE or `CROSS APPLY (VALUES…)` ·
deep nesting → named, ordered CTEs · clarify cryptic aliases/columns. Details + examples in [REFERENCE.md](REFERENCE.md) / [EXAMPLES.md](EXAMPLES.md).

## Optimize catalog (`--optimize`)
Make predicates **SARGable** (no functions on indexed columns; `YEAR(d)=2024` → `d >= '2024-01-01' AND d < '2025-01-01'`) ·
fix implicit conversions (`WHERE Id = '1001'` on an INT column) · leading-wildcard `LIKE '%x'` → flag (needs full-text or redesign) ·
replace `SELECT *` with explicit columns · `NOT IN` on nullable cols → `NOT EXISTS` · suggest covering indexes (as commented DDL, never auto-run).

## Lint catalog (`--lint`)
`SELECT *` · `WITH (NOLOCK)` / `NOLOCK` (dirty reads) · non-SARGable predicates · implicit conversions · missing schema prefix ·
bare/comma joins · missing `;` · `sp_` proc prefix · deprecated `TEXT`/`NTEXT`/`IMAGE`, `*=`/`=*`, `RAISERROR` · `SELECT` without an `ORDER BY` where order is assumed.
Output each as: `severity — rule — file:line — fix` with a confidence score. See severity table in [REFERENCE.md](REFERENCE.md).

## Safety
- **Read-only by default.** This skill rewrites *text*; it does not execute SQL. Never connect to a server or run a query unless the user explicitly asks and provides the connection.
- Never emit destructive DML without `WHERE` (`DELETE`/`UPDATE`/`TRUNCATE`/`DROP`); if asked to refactor one, preserve its `WHERE` exactly and flag the blast radius.
- Index suggestions are emitted as commented DDL for human review — never applied.

## Self-check (before returning)
- [ ] `--format` produced **identical semantics** — only whitespace/case/layout changed.
- [ ] Every behavior-changing rewrite is labelled and was confirmed (or left as a flagged suggestion).
- [ ] Output matches house style: UPPERCASE keywords, trailing commas, schema-qualified, explicit joins, `;` terminators.
- [ ] Each lint/optimize finding has location, fix, and confidence.
- [ ] No SQL was executed; no index/DDL change was auto-applied.

# sql-craft — Reference

The complete T-SQL house style, anti-pattern catalog, SARGability rules, proc/dynamic-SQL hardening
templates, and execution-plan red flags. Grounded in the Holywell/Celko SQL style guide, the lowlydba
T-SQL adaptation, Erland Sommarskog's error-handling series, Itzik Ben-Gan on window functions, Aaron
Bertrand on MERGE, and SQL Server performance consensus (see Sources). Where the broader community
disagrees, the choice made here is noted. **When optimizing/hardening, cite the §here — don't work from memory.**

---

## 1. Formatting

### 1.1 Layout
- **One clause per line**, left-aligned, forming a vertical "spine" (`SELECT` / `FROM` / `WHERE` / `GROUP BY` / `HAVING` / `ORDER BY` each start a line).
- **One column / expression per line** in `SELECT`, `GROUP BY`, and long `ON`/`WHERE` chains.
- **Trailing commas** at the end of each line. (Community is genuinely split leading vs trailing; trailing is the more common default and matches the rest of this repo.)
- **Indent 4 spaces.** Use 2 spaces only when nesting gets deep enough that 4 pushes code off-screen (nested CTEs/derived tables).
- Blank line between distinct statements; no trailing whitespace.
- **CTEs**: `WITH Name AS (` on its own line, body indented one level, `)` aligned to `WITH`; chain with `),` then the next name. Order CTEs in reading/dependency order.
- **`IN` lists / `VALUES`**: short lists inline; long lists one item per line, indented, trailing commas.

### 1.2 Casing
- Reserved keywords **UPPERCASE**: `SELECT FROM WHERE INNER JOIN LEFT JOIN ON GROUP BY HAVING ORDER BY UNION ALL CASE WHEN THEN ELSE END AS AND OR NOT IN EXISTS IS NULL OVER PARTITION BY ROWS RANGE`.
- Built-in functions UPPERCASE (`COUNT`, `SUM`, `CAST`, `COALESCE`, `ISNULL`, `ROW_NUMBER`, `STRING_AGG`).
- Object and column names keep their **declared** case (PascalCase per §2). Never re-case identifiers — that's a behavior risk on case-sensitive collations.

### 1.3 Joins
- Always explicit: `INNER JOIN`, `LEFT JOIN`, `RIGHT JOIN`, `FULL JOIN`, `CROSS JOIN`, `CROSS/OUTER APPLY`. Never bare `JOIN`; never comma / `*=` / `=*` joins.
- `ON` on its own line, indented one level under the join; multiple conditions one per line with leading `AND`.

```sql
FROM dbo.Customer AS c
INNER JOIN dbo.[Order] AS o
    ON o.CustomerID = c.CustomerID
    AND o.IsDeleted = 0
LEFT JOIN dbo.Shipment AS s
    ON s.OrderID = o.OrderID
```

### 1.4 Aliases
- Table aliases: short, lowercase-ish initials, always with `AS` (`dbo.Customer AS c`).
- Column aliases: PascalCase, always with `AS` (`SUM(o.Amount) AS TotalAmount`).
- Qualify every column with its table alias once more than one table is in scope.

### 1.5 Other layout rules
- Terminate **every** statement with `;` (mandatory before `WITH`, `THROW`, `MERGE`).
- `CASE` expressions: `WHEN`/`ELSE` indented under `CASE`, `END` aligned to `CASE`.
- **Window functions**: format the `OVER (PARTITION BY … ORDER BY … ROWS …)` clause with each sub-clause readable; always state the frame explicitly (see §9).
- Parenthesize for clarity in mixed `AND`/`OR`; drop redundant parens elsewhere.
- Comments: `--` one line, `/* … */` blocks. Comment the *why*, not the *what*. Don't leave commented-out code — that's what source control is for.

---

## 2. Naming (enforced on refactor / generated DDL)
- **PascalCase, singular, schema-qualified**: `dbo.CustomerOrder`, column `TotalAmount`.
- Brackets `[ ]` **only** when required — reserved words (`[Order]`, `[User]`), or names containing spaces/special chars (`[Ship Date]`). Don't bracket clean identifiers; it's noise.
- Primary key `XxxID` (`CustomerOrderID`); foreign key matches the referenced PK name.
- Stored procedures: verb-based, `usp_` prefix — never `sp_` (collides with system-proc resolution and forces a `master` lookup first).
- No Hungarian / `tbl_` prefixes. Names begin with a letter, ≤ 128 chars, letters/digits/underscores only.
- Suffix conventions where natural: `…ID`, `…Date`, `…Status`, `…Total`, `…Count`, `…Flag` (`BIT`).

---

## 3. Data types (DDL / refactor)
- Dates: `DATE`, `TIME`, `DATETIME2`, `DATETIMEOFFSET` — **not** legacy `DATETIME`/`SMALLDATETIME` for new code. Store ISO-8601. Prefer `SYSDATETIME()` over `GETDATE()` for `DATETIME2`.
- Money / exact math: `DECIMAL(p,s)` / `NUMERIC`, never `FLOAT`/`REAL` (binary rounding silently corrupts sums/comparisons).
- Strings: prefer `NVARCHAR(n)` for user text; never deprecated `TEXT`/`NTEXT`/`IMAGE` → use `…(MAX)`. Beware mixing `VARCHAR` columns with `NVARCHAR` literals/params — implicit conversion (§4) can scan and even mis-rank by collation.
- Always specify length/precision explicitly (`VARCHAR(50)`, not bare `VARCHAR`, which defaults to 1 or 30 depending on context).
- Flags as `BIT`; avoid `sql_variant`. Prefer `IDENTITY` or `SEQUENCE` over home-grown counters.

---

## 4. SARGability (the core of `--optimize`)
A predicate is **SARGable** when SQL Server can seek an index for it. Rule: keep the **indexed column bare on
one side** — apply functions/conversions to the *constant/parameter*, never the column. Non-SARGable predicates
force per-row evaluation (RBAR) even when a suitable index exists. (Caveat: SARGable syntax only pays off if the
index actually exists.)

| Anti-pattern | Why it scans | SARGable rewrite |
|---|---|---|
| `WHERE YEAR(OrderDate) = 2024` | function on column | `WHERE OrderDate >= '2024-01-01' AND OrderDate < '2025-01-01'` |
| `WHERE CONVERT(date, CreatedAt) = @d` | function on column | `WHERE CreatedAt >= @d AND CreatedAt < DATEADD(DAY, 1, @d)` |
| `WHERE UPPER(LastName) = 'MURPHY'` | function on column | rely on case-insensitive collation: `WHERE LastName = 'Murphy'` |
| `WHERE Id = '1001'` (Id is INT) | implicit VARCHAR→INT conversion on the column | `WHERE Id = 1001` |
| `WHERE NvCol = @v` (`NvCol` VARCHAR, `@v` NVARCHAR) | implicit conversion wraps the **column** | type the param/literal to match the column (`VARCHAR`) |
| `WHERE Sku LIKE '%-A'` | leading wildcard | `LIKE 'A%'`, or full-text / redesign if infix match is truly needed |
| `WHERE ISNULL(Status,'') = 'X'` | function on column | `WHERE Status = 'X'` (NULL ≠ 'X' anyway) |
| `WHERE Amount + 0 > 100` | expression on column | `WHERE Amount > 100` |
| `WHERE FirstName = @f OR LastName = @l` | optimizer can't seek two indexes for one `OR` | `UNION ALL` of two single-column seeks (dedupe if needed) — see §5 / EXAMPLES |
| `WHERE dbo.fn_Norm(Email) = @e` | scalar UDF on column → RBAR + serial plan | inline TVF + `CROSS APPLY`, or a persisted computed column + index |

Operators that **seek**: `= > < >= <= BETWEEN IN`, `LIKE 'prefix%'`, `IS [NOT] NULL`.
Operators that usually **scan**: `<> != NOT IN NOT LIKE`. If you can't rewrite, the structural rescue is a
**computed column + index** (`PERSISTED` if the expression is deterministic) — emit as commented DDL unless
god mode is applying index DDL. A truly SARGable rewrite turns an index *scan* into a *seek*; verify with the plan (§8).

---

## 5. Anti-pattern catalog (`--lint`)

| Severity | Rule | Why | Fix |
|---|---|---|---|
| 🔴 HIGH | `WITH (NOLOCK)` / `NOLOCK` | dirty/phantom/non-repeatable reads, can skip or double-read committed rows; not a perf "free lunch", doesn't prevent deadlocks | remove; if low-staleness reads are truly OK, enable `READ COMMITTED SNAPSHOT` at DB level |
| 🔴 HIGH | non-SARGable predicate | forces scans (RBAR) | §4 rewrite |
| 🔴 HIGH | implicit conversion in predicate/join | scans + wrong results on edge values; identical symptoms to a function wrapping the column | match literal/param type to column (incl. `VARCHAR`↔`NVARCHAR`) |
| 🔴 HIGH | scalar UDF in `SELECT`/`WHERE`/`JOIN` | runs once per row (RBAR), forces a **serial** plan, invisible in plans | inline TVF + `CROSS APPLY`, or set-based expression; (SQL 2019 UDF-inlining helps only if it qualifies) |
| 🔴 HIGH | dynamic SQL by string concatenation of input | **SQL injection** + plan-cache bloat | `sp_executesql` params for values, `QUOTENAME()` per identifier part (§7) |
| 🔴 HIGH | destructive DML without `WHERE` | full-table `DELETE`/`UPDATE`; full-object `TRUNCATE`/`DROP` | require/confirm `WHERE`; state blast radius |
| 🟠 MED | `SELECT *` | extra IO, breaks on schema change, defeats covering indexes (key lookups), hides intent | enumerate needed columns |
| 🟠 MED | window function with no explicit frame | implicit `RANGE UNBOUNDED PRECEDING`: `LAST_VALUE` returns current row, + slow on-disk spool / N² risk in row mode | add explicit `ROWS BETWEEN …` (§9) |
| 🟠 MED | table variable joined to a large set | no statistics → 1-row estimate → bad plan / lost parallelism | `#temp` table (has stats); or `OPTION (RECOMPILE)` if small |
| 🟠 MED | `MERGE` | documented concurrency, trigger-firing, and `WHEN NOT MATCHED BY SOURCE` bugs (Bertrand) | split into `INSERT`/`UPDATE`/`DELETE` unless atomic upsert with `HOLDLOCK` is justified |
| 🟠 MED | proc has a transaction but no `XACT_ABORT`/`TRY-CATCH` | error can leave an open transaction / orphaned locks | `SET XACT_ABORT ON` + `TRY/CATCH` + `@@TRANCOUNT` rollback (§6) |
| 🟠 MED | parameter-sniffing-sensitive proc | first call's plan reused for skewed params → unstable perf | `OPTION (RECOMPILE)` / `OPTIMIZE FOR` / split procs; note SQL 2022 Parameter Sensitive Plan optimization |
| 🟠 MED | bare `JOIN` / comma join / `*=` `=*` | ambiguous; `*=` is removed | explicit `INNER`/`LEFT JOIN … ON` |
| 🟠 MED | missing schema prefix | resolution overhead + ambiguity | `dbo.` (or correct schema) |
| 🟠 MED | `NOT IN (subquery)` on nullable col | returns no rows if any NULL | `NOT EXISTS` |
| 🟠 MED | `sp_` proc prefix | collides with system procs; forces a `master` lookup | rename `usp_` |
| 🟡 LOW | `TOP` without `ORDER BY` / `ORDER BY <ordinal>` | non-deterministic rows / fragile to column reorder | add deterministic `ORDER BY` by name |
| 🟡 LOW | `FLOAT`/`REAL` for money | rounding error | `DECIMAL(p,s)` |
| 🟡 LOW | missing `;` terminator | required for some constructs (`WITH`, `THROW`, `MERGE`) | add `;` |
| 🟡 LOW | deprecated `TEXT`/`NTEXT`/`IMAGE`, `RAISERROR` for re-raise | removed/legacy | `…(MAX)`, `THROW` |
| 🟡 LOW | `ORDER BY` assumed but absent | result order isn't guaranteed without it | add explicit `ORDER BY` |

Confidence scoring (append `[confidence: N]`): 95–100 definite · 75–94 high · 50–74 context-dependent · <50 flag as `⚠️ UNCERTAIN` and say what context would resolve it (schema, collation, row counts, indexes, version).

---

## 6. Stored-procedure shape (`--refactor` / `--harden` of procs)
```sql
CREATE OR ALTER PROCEDURE dbo.usp_GetCustomerOrders
    @CustomerID INT,
    @FromDate   DATE
AS
BEGIN
    SET XACT_ABORT, NOCOUNT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        -- ... statements ...
        SELECT
            o.OrderID,
            o.OrderDate,
            o.TotalAmount
        FROM dbo.[Order] AS o
        WHERE o.CustomerID = @CustomerID
            AND o.OrderDate >= @FromDate
        ORDER BY o.OrderDate DESC;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        ;THROW;          -- leading ; so it can't be silently merged into the prior line
    END CATCH;
END;
```
- `SET XACT_ABORT, NOCOUNT ON;` is the first line of the body — together, near-all errors roll the transaction back and abort (the default leaves some errors continuing with an open transaction even inside `TRY/CATCH`).
- `BEGIN … END` wrapper; `CREATE OR ALTER` over drop-and-recreate.
- Re-raise with `;THROW` (preserves the original error number/severity/message; the leading semicolon guards against accidental statement-merge). Prefer it over `RAISERROR`.
- **No code after the outermost `END CATCH`** — readers won't see it and it runs after the error path.
- Only open an explicit transaction for multi-statement writes; read-only procs need no transaction.
- Declare locals and create `#temp` tables near the top; group logic into commented `BEGIN…END` blocks.

---

## 7. Dynamic SQL safety (`--harden`)
Separate **values** from **identifiers** and handle each appropriately. Never concatenate raw input.

- **Values** (search terms, IDs, dates) → `sp_executesql` with typed parameters. A parameter *referenced inside* the batch string is not concatenation — `sp_executesql` binds it, so injection has no surface and the plan caches/reuses.
- **Identifiers** (table/column/schema names — which `sp_executesql` can't parameterize) → `QUOTENAME()` **each part separately** (`QUOTENAME(@schema) + '.' + QUOTENAME(@table)`). `QUOTENAME` brackets one identifier and caps at 128 chars.
- Validate identifiers against `sys.tables`/`sys.columns` when feasible (defense in depth); `PRINT` the built batch while developing.

```sql
DECLARE @sql NVARCHAR(MAX) =
    N'SELECT o.OrderID, o.TotalAmount
      FROM ' + QUOTENAME(@Schema) + N'.' + QUOTENAME(@Table) + N' AS o
      WHERE o.CustomerID = @CustomerID';   -- value stays a real parameter
EXEC sys.sp_executesql
    @sql,
    N'@CustomerID INT',
    @CustomerID = @CustomerID;
```

---

## 8. Reading the execution plan (verify `--optimize`)
When a connection/plan is in scope, confirm the rewrite actually helped. Red flags:

- **Scan where a seek is expected** — `Clustered Index Scan` / `Table Scan` on a selective predicate → missing/non-covering index, non-SARGable predicate, or stale stats.
- **Key Lookup (Clustered) repeated N times** — narrow nonclustered index doesn't cover the query → add `INCLUDE` columns / covering index, or trim `SELECT *`.
- **Estimate ↔ actual mismatch** (est 1 row, actual 1,000,000) — stale statistics, table-variable 1-row guess, or parameter sniffing.
- **Implicit-conversion warning** on the operator — type mismatch wrapping a column (§4).
- **Sort/Hash spills to tempdb** — under-estimated memory grant.
- **Serial plan where parallel expected** — a scalar UDF or other serializing construct (§5).
- **"Missing Index" green hint** — a *suggestion*, not gospel: evaluate width, write cost, and duplicates before applying.

A good `--optimize` result: a scan became a seek, logical reads dropped, the key-lookup count fell, no implicit-conversion warning remains.

---

## 9. Window functions & modern T-SQL
- **Always state the frame.** Omitting it with an `ORDER BY` defaults to `RANGE UNBOUNDED PRECEDING`, which (a) makes `LAST_VALUE` return the *current* row, not the partition's last, and (b) can fall back to a slow on-disk spool / N² scaling in row mode. Prefer `ROWS`:
  - running total: `SUM(x) OVER (PARTITION BY g ORDER BY d ROWS UNBOUNDED PRECEDING)`
  - true last value: `LAST_VALUE(x) OVER (PARTITION BY g ORDER BY d ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING)`
- `ROW_NUMBER` (no ties) vs `RANK`/`DENSE_RANK` (ties share a rank) — pick deliberately.
- **`STRING_AGG`** (2017+): cleaner than `FOR XML PATH`. It **drops NULLs** (wrap with `ISNULL`/`COALESCE` for a placeholder); the separator type must match the input (`VARCHAR` input ⇒ `VARCHAR` separator). It **cannot** be used as a window function (nor can `GROUPING`/`GROUPING_ID`).
- **`OFFSET … FETCH`** (2012+): pagination needs a deterministic `ORDER BY`; deep offsets get expensive — consider keyset (`WHERE Key > @last`) pagination at scale.
- Don't reach for `MERGE` for simple upserts — see §5. If you must, use `HOLDLOCK` and test trigger/`OUTPUT` behavior.

---

## Sources
- Simon Holywell, *SQL Style Guide* — https://www.sqlstyle.guide/ (Celko-aligned; consensus on UPPERCASE keywords + one-clause-per-line)
- John McCall / lowlydba, *T-SQL Style Guide* — https://tsqlstyle.lowlydba.com/ (MSSQL-specific: brackets, `usp_`, `THROW`, type rules)
- Erland Sommarskog, *Error and Transaction Handling in SQL Server* — https://www.sommarskog.se/error_handling/Part1.html (canonical `SET XACT_ABORT, NOCOUNT ON` + `TRY/CATCH` + `;THROW` pattern)
- Brent Ozar, *Non-SARGable Predicates* — https://www.brentozar.com/blitzcache/non-sargable-predicates/
- John Deardurff, *Writing SARGable Expressions in T-SQL* — https://sqlmct.com/writing-sargable-expressions-in-t-sql/
- Itzik Ben-Gan, *T-SQL bugs, pitfalls, and best practices – window functions* — https://sqlperformance.com/2019/08/sql-performance/t-sql-bugs-pitfalls-and-best-practices-window-functions (explicit `ROWS` frame, `LAST_VALUE` default-frame bug)
- Microsoft, *Dynamic SQL & SQL injection* — https://techcommunity.microsoft.com/blog/sqlserver/dynamic-sql--sql-injection/383196 · VladDBA, *Parametrization alone can't prevent SQL injection* — https://vladdba.com/2026/04/15/dynamic-t-sql-sql-injection-quotename-executesql/
- ProcureSQL, *Finding Query Anti-Patterns (scalar UDF / table variable / parameter sniffing / key lookup)* — https://procuresql.com/blog/2024/01/03/query-anti-patterns-developers-sql-server-2022/
- Microsoft Learn, *STRING_AGG (Transact-SQL)* — https://learn.microsoft.com/en-us/sql/t-sql/functions/string-agg-transact-sql
- Stedman Solutions, *Understanding WITH (NOLOCK)* — https://stedmansolutions.com/2025/10/07/understanding-the-with-nolock-hint/
- Note: leading-vs-trailing commas and "river" alignment have **no** community consensus; this skill picks trailing + left-spine and prizes consistency over the specific choice.

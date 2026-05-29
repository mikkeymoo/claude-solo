# sql-craft — Reference

The complete T-SQL house style, anti-pattern catalog, and SARGability rules. Grounded in the
Holywell/Celko SQL style guide, the lowlydba T-SQL adaptation, and SQL Server performance consensus
(see Sources at the end). Where the broader community disagrees, the choice made here is noted.

---

## 1. Formatting

### 1.1 Layout
- **One clause per line**, left-aligned, forming a vertical "spine" (`SELECT` / `FROM` / `WHERE` / `GROUP BY` / `ORDER BY` each start a line).
- **One column / expression per line** in `SELECT`, `GROUP BY`, and long `ON`/`WHERE` chains.
- **Trailing commas** at the end of each line. (Community is genuinely split leading vs trailing; trailing is the more common default and matches the rest of this repo.)
- **Indent 4 spaces.** Use 2 spaces only when nesting gets deep enough that 4 pushes code off-screen (nested CTEs/derived tables).
- Blank line between distinct statements; no trailing whitespace.

### 1.2 Casing
- Reserved keywords **UPPERCASE**: `SELECT FROM WHERE INNER JOIN LEFT JOIN ON GROUP BY HAVING ORDER BY UNION ALL CASE WHEN THEN ELSE END AS AND OR NOT IN EXISTS IS NULL`.
- Built-in functions UPPERCASE (`COUNT`, `SUM`, `CAST`, `COALESCE`, `ISNULL`, `ROW_NUMBER`).
- Object and column names keep their **declared** case (PascalCase per §2). Never re-case identifiers — that's a behavior risk on case-sensitive collations.

### 1.3 Joins
- Always explicit: `INNER JOIN`, `LEFT JOIN`, `RIGHT JOIN`, `FULL JOIN`, `CROSS JOIN`. Never bare `JOIN`; never comma/`*=` joins.
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
- Terminate **every** statement with `;`.
- `CASE` expressions: `WHEN`/`ELSE` indented under `CASE`, `END` aligned to `CASE`.
- Parenthesize for clarity in mixed `AND`/`OR`, but drop redundant parens elsewhere.
- Comments: `--` for one line, `/* … */` for blocks. Comment the *why*, not the *what*. Don't leave commented-out code — that's what source control is for.

---

## 2. Naming (enforced on refactor / generated DDL)
- **PascalCase, singular, schema-qualified**: `dbo.CustomerOrder`, column `TotalAmount`.
- Brackets `[ ]` **only** when required — reserved words (`[Order]`, `[User]`), or names containing spaces/special chars (`[Ship Date]`). Don't bracket clean identifiers; it's noise.
- Primary key `XxxID` (`CustomerOrderID`); foreign key matches the referenced PK name.
- Stored procedures: verb-based, `usp_` prefix — never `sp_` (collides with system-proc resolution).
- No Hungarian/`tbl_` prefixes. Names begin with a letter, ≤ 128 chars, letters/digits/underscores only.
- Suffix conventions where natural: `…ID`, `…Date`, `…Status`, `…Total`, `…Count`, `…Flag`.

---

## 3. Data types (DDL / refactor)
- Dates: `DATE`, `TIME`, `DATETIME2`, `DATETIMEOFFSET` — **not** legacy `DATETIME`/`SMALLDATETIME` for new code. Store ISO-8601.
- Money/exact math: `DECIMAL(p,s)` / `NUMERIC`, never `FLOAT`/`REAL`.
- Strings: prefer `NVARCHAR(n)` for user text; never deprecated `TEXT`/`NTEXT`/`IMAGE` → use `…(MAX)`.
- Always specify length/precision explicitly (`VARCHAR(50)`, not bare `VARCHAR`).

---

## 4. SARGability (the core of `--optimize`)
A predicate is **SARGable** when SQL Server can seek an index for it. Rule: keep the **indexed column bare on one side** — apply functions/conversions to the *constant*, never the column.

| Anti-pattern | Why it scans | SARGable rewrite |
|---|---|---|
| `WHERE YEAR(OrderDate) = 2024` | function on column | `WHERE OrderDate >= '2024-01-01' AND OrderDate < '2025-01-01'` |
| `WHERE CONVERT(date, CreatedAt) = @d` | function on column | `WHERE CreatedAt >= @d AND CreatedAt < DATEADD(DAY, 1, @d)` |
| `WHERE UPPER(LastName) = 'MURPHY'` | function on column | rely on case-insensitive collation: `WHERE LastName = 'Murphy'` |
| `WHERE Id = '1001'` (Id is INT) | implicit VARCHAR→INT conversion | `WHERE Id = 1001` |
| `WHERE Sku LIKE '%-A'` | leading wildcard | `LIKE 'A%'`, or full-text / redesign if infix match is truly needed |
| `WHERE ISNULL(Status,'') = 'X'` | function on column | `WHERE Status = 'X'` (NULL ≠ 'X' anyway) |
| `WHERE Amount + 0 > 100` | expression on column | `WHERE Amount > 100` |

Operators that seek: `= > < >= <= BETWEEN IN`, `LIKE 'prefix%'`, `IS [NOT] NULL`.
Operators that usually scan: `<> != NOT IN NOT LIKE`. If you can't rewrite, the structural rescue is a computed column + index (emit as commented DDL, never auto-apply).

---

## 5. Anti-pattern catalog (`--lint`)

| Severity | Rule | Why | Fix |
|---|---|---|---|
| 🔴 HIGH | `WITH (NOLOCK)` / `NOLOCK` | dirty/phantom/non-repeatable reads; not a perf "free lunch", doesn't prevent deadlocks | remove; if low-staleness reads are truly OK use `READ COMMITTED SNAPSHOT` at DB level |
| 🔴 HIGH | non-SARGable predicate | forces scans (RBAR) | §4 rewrite |
| 🔴 HIGH | implicit conversion in predicate/join | scans + wrong results on edge values | match literal/param type to column |
| 🔴 HIGH | destructive DML without `WHERE` | full-table `DELETE`/`UPDATE` | require a `WHERE`; confirm blast radius |
| 🟠 MED | `SELECT *` | extra IO, breaks on schema change, hides intent | enumerate needed columns |
| 🟠 MED | bare `JOIN` / comma join / `*=` `=*` | ambiguous; `*=` is removed | explicit `INNER`/`LEFT JOIN … ON` |
| 🟠 MED | missing schema prefix | resolution overhead + ambiguity | `dbo.` (or correct schema) |
| 🟠 MED | `NOT IN (subquery)` on nullable col | returns no rows if any NULL | `NOT EXISTS` |
| 🟠 MED | `sp_` proc prefix | collides with system procs | rename `usp_` |
| 🟡 LOW | missing `;` terminator | required for some constructs | add `;` |
| 🟡 LOW | deprecated `TEXT`/`NTEXT`/`IMAGE`, `RAISERROR` | removed/legacy | `…(MAX)`, `THROW` |
| 🟡 LOW | `ORDER BY` assumed but absent | result order isn't guaranteed without it | add explicit `ORDER BY` |

Confidence scoring (append `[confidence: N]`): 95–100 definite · 75–94 high · 50–74 context-dependent · <50 flag as `⚠️ UNCERTAIN` and say what context would resolve it.

---

## 6. Stored-procedure shape (`--refactor` of procs)
```sql
CREATE OR ALTER PROCEDURE dbo.usp_GetCustomerOrders
    @CustomerID INT,
    @FromDate   DATE
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        o.OrderID,
        o.OrderDate,
        o.TotalAmount
    FROM dbo.[Order] AS o
    WHERE o.CustomerID = @CustomerID
        AND o.OrderDate >= @FromDate
    ORDER BY o.OrderDate DESC;
END;
```
- `SET NOCOUNT ON;` first line of body. `BEGIN … END` wrapper. `CREATE OR ALTER` over drop-and-recreate.
- Use `TRY … CATCH` + `THROW` for operationalized DML; wrap multi-statement writes in an explicit transaction.

---

## Sources
- Simon Holywell, *SQL Style Guide* — https://www.sqlstyle.guide/ (Celko-aligned; consensus on UPPERCASE keywords + one-clause-per-line)
- John McCall / lowlydba, *T-SQL Style Guide* — https://tsqlstyle.lowlydba.com/ (MSSQL-specific: brackets, `usp_`, `THROW`, type rules)
- Brent Ozar, *Non-SARGable Predicates* — https://www.brentozar.com/blitzcache/non-sargable-predicates/
- *Writing SARGable Expressions in T-SQL* — https://sqlmct.com/writing-sargable-expressions-in-t-sql/
- Steman Solutions, *Understanding WITH (NOLOCK)* — https://stedmansolutions.com/2025/10/07/understanding-the-with-nolock-hint/
- Note: leading-vs-trailing commas and "river" alignment have **no** community consensus; this skill picks trailing + left-spine and prizes consistency over the specific choice.

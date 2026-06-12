# sql-craft — Worked Examples

Before → after transforms per mode. Each shows the input, the result, and a one-line summary —
the same shape `/mm-sql-craft` should produce in its output. In god mode (no flag) these are *applied*,
not just suggested; behavior-changing ones are applied **and** labelled.

---

## `--format` (semantics-preserving)

**Before**
```sql
select c.customerid, c.firstname,c.lastname, o.orderdate from customer c
join [order] o on o.customerid=c.customerid where c.isactive=1 and o.orderdate>='2024-01-01' order by o.orderdate desc
```

**After**
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
*Keywords uppercased, columns one-per-line with trailing commas, schema-qualified, bare `JOIN`→`INNER JOIN`, `;` added. No results changed.*

---

## `--refactor` — nested subqueries → CTEs

**Before**
```sql
SELECT *
FROM (
    SELECT CustomerID, SUM(TotalAmount) AS Spend
    FROM dbo.[Order]
    WHERE OrderDate >= '2024-01-01'
    GROUP BY CustomerID
) x
WHERE x.Spend > (SELECT AVG(TotalAmount) FROM dbo.[Order]);
```

**After**
```sql
WITH OrderSpend AS (
    SELECT
        o.CustomerID,
        SUM(o.TotalAmount) AS Spend
    FROM dbo.[Order] AS o
    WHERE o.OrderDate >= '2024-01-01'
    GROUP BY o.CustomerID
),
AvgOrder AS (
    SELECT AVG(o.TotalAmount) AS AvgAmount
    FROM dbo.[Order] AS o
)
SELECT
    s.CustomerID,
    s.Spend
FROM OrderSpend AS s
CROSS JOIN AvgOrder AS a
WHERE s.Spend > a.AvgAmount;
```
*Derived table → named CTE, scalar subquery → CTE, `SELECT *` enumerated. Behavior preserved.*

---

## `--refactor` — scalar UDF → inline TVF + CROSS APPLY (perf + parallelism)

**Before**
```sql
SELECT c.CustomerID, dbo.fn_FullName(c.FirstName, c.LastName) AS FullName
FROM dbo.Customer AS c;
-- CREATE FUNCTION dbo.fn_FullName(@f NVARCHAR(50), @l NVARCHAR(50)) RETURNS NVARCHAR(101) AS BEGIN RETURN @f + ' ' + @l END
```

**After**
```sql
SELECT
    c.CustomerID,
    n.FullName
FROM dbo.Customer AS c
CROSS APPLY dbo.fn_FullName(c.FirstName, c.LastName) AS n;
-- Rewrite the function as an inline TVF:
-- CREATE OR ALTER FUNCTION dbo.fn_FullName (@f NVARCHAR(50), @l NVARCHAR(50))
-- RETURNS TABLE AS RETURN (SELECT @f + ' ' + @l AS FullName);
```
*Scalar UDF ran once per row (RBAR) and forced a serial plan; inline TVF lets the optimizer fold it in and parallelize. Same values returned.*

---

## `--refactor` — cursor → set-based (behavior-changing: applied + labelled)

**Before**
```sql
DECLARE @id INT, @bonus DECIMAL(18,2);
DECLARE c CURSOR FOR SELECT EmployeeID FROM dbo.Employee WHERE IsActive = 1;
OPEN c; FETCH NEXT FROM c INTO @id;
WHILE @@FETCH_STATUS = 0
BEGIN
    UPDATE dbo.Employee SET Bonus = Salary * 0.10 WHERE EmployeeID = @id;
    FETCH NEXT FROM c INTO @id;
END
CLOSE c; DEALLOCATE c;
```

**After**
```sql
UPDATE dbo.Employee
SET Bonus = Salary * 0.10
WHERE IsActive = 1;
```
*Row-by-row cursor collapsed to one set-based `UPDATE`. ⚠️ Behavior-changing (locking/trigger fire-once-per-statement vs per-row) — applied, flagged in summary.*

---

## `--optimize` — SARGability + implicit conversion

**Before**
```sql
SELECT o.OrderID, o.OrderDate, o.TotalAmount
FROM dbo.[Order] AS o
WHERE YEAR(o.OrderDate) = 2024
    AND o.CustomerID = '1001';
```

**After**
```sql
SELECT
    o.OrderID,
    o.OrderDate,
    o.TotalAmount
FROM dbo.[Order] AS o
WHERE o.OrderDate >= '2024-01-01'
    AND o.OrderDate < '2025-01-01'
    AND o.CustomerID = 1001;

-- Applied supporting index (god mode emits live; --ask gates it):
CREATE NONCLUSTERED INDEX IX_Order_CustomerID_OrderDate
    ON dbo.[Order] (CustomerID, OrderDate) INCLUDE (TotalAmount);
```
*`YEAR()` → range (seekable); `'1001'` → `1001` removes implicit conversion on the column. Same rows returned. Verify the scan became a seek in the plan (REFERENCE §8).*

---

## `--optimize` — OR across columns → UNION ALL (two seeks)

**Before**
```sql
SELECT p.PersonID, p.FirstName, p.LastName
FROM dbo.Person AS p
WHERE p.FirstName = @f OR p.LastName = @l;
```

**After**
```sql
SELECT p.PersonID, p.FirstName, p.LastName
FROM dbo.Person AS p
WHERE p.FirstName = @f
UNION
SELECT p.PersonID, p.FirstName, p.LastName
FROM dbo.Person AS p
WHERE p.LastName = @l;
```
*A single `OR` across two columns can't seek both indexes; splitting lets each branch seek its own. `UNION` (not `UNION ALL`) preserves the original's implicit de-dup of rows matching both predicates.*

---

## `--optimize` — NOT IN on nullable column (behavior-correcting)

**Before**
```sql
SELECT c.CustomerID
FROM dbo.Customer AS c
WHERE c.CustomerID NOT IN (SELECT o.CustomerID FROM dbo.[Order] AS o);
```

**After**
```sql
SELECT c.CustomerID
FROM dbo.Customer AS c
WHERE NOT EXISTS (
    SELECT 1
    FROM dbo.[Order] AS o
    WHERE o.CustomerID = c.CustomerID
);
```
*`NOT IN` returns zero rows if any `o.CustomerID` is NULL — `NOT EXISTS` is null-safe. ⚠️ Result-changing if NULLs were present; applied and flagged.*

---

## `--optimize` — window function: add explicit ROWS frame

**Before**
```sql
SELECT t.AccountID, t.TxnDate, t.Amount,
    SUM(t.Amount) OVER (PARTITION BY t.AccountID ORDER BY t.TxnDate) AS RunningTotal,
    LAST_VALUE(t.Balance) OVER (PARTITION BY t.AccountID ORDER BY t.TxnDate) AS FinalBalance
FROM dbo.Txn AS t;
```

**After**
```sql
SELECT
    t.AccountID,
    t.TxnDate,
    t.Amount,
    SUM(t.Amount) OVER (
        PARTITION BY t.AccountID ORDER BY t.TxnDate
        ROWS UNBOUNDED PRECEDING
    ) AS RunningTotal,
    LAST_VALUE(t.Balance) OVER (
        PARTITION BY t.AccountID ORDER BY t.TxnDate
        ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING
    ) AS FinalBalance
FROM dbo.Txn AS t;
```
*Implicit `RANGE` default made `LAST_VALUE` return the current row (a bug) and risked a slow on-disk spool. Explicit `ROWS` fixes `FinalBalance` and the spill. ⚠️ `FinalBalance` values change (now correct) — flagged.*

---

## `--harden` — proc hardening (XACT_ABORT + TRY/CATCH + ;THROW)

**Before**
```sql
CREATE PROCEDURE dbo.usp_TransferFunds @From INT, @To INT, @Amt DECIMAL(18,2)
AS
BEGIN TRANSACTION
UPDATE dbo.Account SET Balance = Balance - @Amt WHERE AccountID = @From;
UPDATE dbo.Account SET Balance = Balance + @Amt WHERE AccountID = @To;
COMMIT TRANSACTION
```

**After**
```sql
CREATE OR ALTER PROCEDURE dbo.usp_TransferFunds
    @From INT,
    @To   INT,
    @Amt  DECIMAL(18,2)
AS
BEGIN
    SET XACT_ABORT, NOCOUNT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        UPDATE dbo.Account
        SET Balance = Balance - @Amt
        WHERE AccountID = @From;

        UPDATE dbo.Account
        SET Balance = Balance + @Amt
        WHERE AccountID = @To;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        ;THROW;
    END CATCH;
END;
```
*Without `XACT_ABORT`/`TRY-CATCH`, a failure on the second `UPDATE` could leave the debit committed and the transaction open. Now any error rolls back and re-raises intact. `CREATE`→`CREATE OR ALTER`. Behavior on the happy path is unchanged.*

---

## `--harden` — dynamic SQL injection → sp_executesql + QUOTENAME

**Before**
```sql
DECLARE @sql NVARCHAR(MAX);
SET @sql = 'SELECT * FROM ' + @Table + ' WHERE CustomerID = ' + @CustId;
EXEC(@sql);
```

**After**
```sql
DECLARE @sql NVARCHAR(MAX) =
    N'SELECT o.OrderID, o.TotalAmount
      FROM ' + QUOTENAME(@Schema) + N'.' + QUOTENAME(@Table) + N' AS o
      WHERE o.CustomerID = @CustomerID';
EXEC sys.sp_executesql
    @sql,
    N'@CustomerID INT',
    @CustomerID = @CustId;
```
*`@CustId` was concatenated → injection + plan-cache bloat; now a typed `sp_executesql` parameter. The object name (which can't be parameterized) is bracketed with `QUOTENAME()` per part. `SELECT *` also enumerated. 🔴 Security fix.*

---

## `--refactor` — MERGE → split statements (semantic delta: flag)

**Before**
```sql
MERGE dbo.Target AS t
USING dbo.Source AS s ON t.Id = s.Id
WHEN MATCHED THEN UPDATE SET t.Val = s.Val
WHEN NOT MATCHED THEN INSERT (Id, Val) VALUES (s.Id, s.Val);
```

**After**
```sql
UPDATE t
SET t.Val = s.Val
FROM dbo.Target AS t
INNER JOIN dbo.Source AS s
    ON s.Id = t.Id;

INSERT INTO dbo.Target (Id, Val)
SELECT s.Id, s.Val
FROM dbo.Source AS s
WHERE NOT EXISTS (
    SELECT 1 FROM dbo.Target AS t WHERE t.Id = s.Id
);
```
*`MERGE` has documented concurrency/trigger bugs; split `UPDATE`+`INSERT` is more predictable. ⚠️ Not atomic by default — wrap in a transaction with `HOLDLOCK` on `Target` if concurrent upserts are possible. Flagged before applying.*

---

## `--lint` (report only)

**Input**
```sql
SELECT * FROM Orders WITH (NOLOCK) WHERE CONVERT(varchar, OrderDate) = '2024-01-01'
```

**Report**
```
🔴 HIGH  — NOLOCK dirty reads        — line 1 — remove WITH (NOLOCK); use RCSI if stale reads acceptable           [confidence: 96]
🔴 HIGH  — non-SARGable predicate     — line 1 — CONVERT() on OrderDate → range: OrderDate >= '2024-01-01' AND < '2024-01-02'  [confidence: 95]
🟠 MED   — SELECT *                   — line 1 — list explicit columns                                              [confidence: 90]
🟠 MED   — missing schema prefix      — line 1 — dbo.Orders                                                         [confidence: 82]
🟡 LOW   — missing ; terminator       — line 1 — append ;                                                          [confidence: 99]
Summary: 2 HIGH, 2 MEDIUM, 1 LOW. Nothing changed (lint is report-only). Run with no flag to auto-apply.
```

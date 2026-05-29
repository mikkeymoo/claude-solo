# sql-craft — Worked Examples

Before → after transforms per mode. Each shows the input, the result, and a one-line summary —
the same shape `/sql-craft` should produce in its output.

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

## `--refactor` — cursor → set-based (behavior-changing: confirm)

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
*Row-by-row cursor collapsed to one set-based `UPDATE`. ⚠️ Behavior-changing (locking/trigger semantics differ) — confirm before applying.*

---

## `--optimize` — SARGability

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

-- Suggested supporting index (review before applying):
-- CREATE NONCLUSTERED INDEX IX_Order_CustomerID_OrderDate
--     ON dbo.[Order] (CustomerID, OrderDate) INCLUDE (TotalAmount);
```
*`YEAR()` → range (seekable); `'1001'` → `1001` removes implicit conversion. Index emitted as commented DDL only. Same rows returned.*

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
*`NOT IN` returns zero rows if any `o.CustomerID` is NULL — `NOT EXISTS` is null-safe. ⚠️ Result-changing if NULLs were present; flag it.*

---

## `--lint` (report only)

**Input**
```sql
SELECT * FROM Orders WITH (NOLOCK) WHERE CONVERT(varchar, OrderDate) = '2024-01-01'
```

**Report**
```
🔴 HIGH  — NOLOCK dirty reads        — line 1 — remove WITH (NOLOCK); use RCSI if stale reads acceptable   [confidence: 96]
🔴 HIGH  — non-SARGable predicate     — line 1 — CONVERT() on OrderDate → range: OrderDate >= '2024-01-01' AND < '2024-01-02'  [confidence: 95]
🟠 MED   — SELECT *                   — line 1 — list explicit columns                                       [confidence: 90]
🟠 MED   — missing schema prefix      — line 1 — dbo.Orders                                                  [confidence: 82]
🟡 LOW   — missing ; terminator       — line 1 — append ;                                                    [confidence: 99]
Summary: 2 HIGH, 2 MEDIUM, 1 LOW. Nothing changed (lint is report-only).
```

---
name: relativity-sql
description: Relativity SQL query bundle — domain dedup, processing exceptions, saved-search data sizes, multi-object field population. Includes Invoke-Sqlcmd wrappers and Power BI CSV/Parquet output. Use when: relativity sql, processing exceptions, domain dedup, saved search, ediscovery sql.
---

# /relativity-sql — Relativity SQL Query Bundle

Verified queries for common Relativity eDiscovery operations with PowerShell wrappers.

## Query: Domain Deduplication

Find duplicate email domains across custodians in a workspace:

```sql
SELECT
    LOWER(SUBSTRING([From], CHARINDEX('@', [From]) + 1, LEN([From]))) AS Domain,
    COUNT(*) AS MessageCount,
    COUNT(DISTINCT CustodianArtifactID) AS CustodianCount
FROM [EDDS{WorkspaceID}].[Document]
WHERE [From] LIKE '%@%'
  AND [RelativityNativeType] IN ('Email', 'Email Attachment')
GROUP BY LOWER(SUBSTRING([From], CHARINDEX('@', [From]) + 1, LEN([From])))
HAVING COUNT(*) > 1
ORDER BY MessageCount DESC;
```

## Query: Processing Exceptions

Report processing errors grouped by exception type:

```sql
SELECT
    pe.ExceptionType,
    pe.ExceptionMessage,
    COUNT(*) AS FileCount,
    MIN(pe.CreatedOn) AS FirstSeen,
    MAX(pe.CreatedOn) AS LastSeen
FROM [EDDS{WorkspaceID}].[ProcessingError] pe
WHERE pe.ProcessingSetArtifactID = @ProcessingSetID
GROUP BY pe.ExceptionType, pe.ExceptionMessage
ORDER BY FileCount DESC;
```

## Query: Saved Search Data Sizes

Estimate native file sizes for a saved search result set:

```sql
SELECT
    ss.Name AS SavedSearchName,
    COUNT(d.ArtifactID) AS DocumentCount,
    SUM(CAST(d.NativeFileSize AS BIGINT)) / 1048576.0 AS TotalSizeMB,
    AVG(CAST(d.NativeFileSize AS BIGINT)) / 1024.0 AS AvgSizeKB
FROM [EDDS{WorkspaceID}].[Document] d
JOIN [EDDS].[SearchArtifact] sa
    ON d.ArtifactID IN (
        SELECT ArtifactID FROM [EDDS{WorkspaceID}].[SavedSearchDocuments]
        WHERE SavedSearchID = @SavedSearchID
    )
CROSS JOIN (SELECT @SavedSearchName AS Name) ss
WHERE d.DeletedOn IS NULL;
```

## Query: Multi-Object Field Population

Check which documents have a specific multi-object field populated:

```sql
SELECT
    COUNT(DISTINCT d.ArtifactID) AS TotalDocs,
    COUNT(DISTINCT mof.ParentArtifactID) AS DocsWithField,
    CAST(COUNT(DISTINCT mof.ParentArtifactID) AS FLOAT) /
        NULLIF(COUNT(DISTINCT d.ArtifactID), 0) * 100 AS PopulationPct
FROM [EDDS{WorkspaceID}].[Document] d
LEFT JOIN [EDDS{WorkspaceID}].[{FieldTableName}] mof
    ON d.ArtifactID = mof.ParentArtifactID
WHERE d.DeletedOn IS NULL;
```

## PowerShell Wrapper: Invoke-Sqlcmd

```powershell
function Invoke-RelativityQuery {
    param(
        [Parameter(Mandatory)][string]$ServerInstance,
        [Parameter(Mandatory)][int]$WorkspaceID,
        [Parameter(Mandatory)][string]$Query,
        [hashtable]$Parameters = @{},
        [string]$OutputPath,
        [ValidateSet('CSV','Parquet','Console')][string]$OutputFormat = 'Console'
    )

    $db = "EDDS$WorkspaceID"
    $queryWithDb = $Query -replace '\{WorkspaceID\}', $WorkspaceID

    # Build SqlParameters array
    $sqlParams = $Parameters.GetEnumerator() | ForEach-Object {
        "@$($_.Key)=$($_.Value)"
    }

    try {
        $results = Invoke-Sqlcmd `
            -ServerInstance $ServerInstance `
            -Database $db `
            -Query $queryWithDb `
            -Variable $sqlParams `
            -TrustServerCertificate `
            -ErrorAction Stop

        switch ($OutputFormat) {
            'CSV' {
                $results | Export-Csv -Path $OutputPath -NoTypeInformation -Encoding UTF8
                Write-Host "Exported $($results.Count) rows to $OutputPath"
            }
            'Parquet' {
                # Requires ImportExcel or Parquet.Net module
                if (Get-Module -ListAvailable -Name Parquet) {
                    $results | ConvertTo-Parquet -Path $OutputPath
                } else {
                    Write-Warning "Parquet module not available; falling back to CSV"
                    $results | Export-Csv -Path ($OutputPath -replace '\.parquet$', '.csv') -NoTypeInformation -Encoding UTF8
                }
            }
            default { $results | Format-Table -AutoSize }
        }
    } catch {
        Write-Error "Query failed: $_"
    }
}
```

## Usage

When the user asks for one of these query types, generate the query with their workspace ID substituted, wrap it in `Invoke-RelativityQuery`, and suggest the appropriate output format based on context (CSV for ad-hoc, Parquet for Power BI pipeline).

Always use parameterized queries — never string-interpolate user-provided values into SQL.

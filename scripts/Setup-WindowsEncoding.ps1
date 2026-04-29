# Setup-WindowsEncoding.ps1
# Idempotent Windows encoding setup for Claude Code / Python UTF-8 sessions.
# Pure ASCII source -- no Unicode characters in this file.
# Run once from PowerShell to fix charmap codec errors permanently.
#
# What this does:
#   1. Sets PYTHONIOENCODING=utf-8 and PYTHONUTF8=1 as User env vars
#   2. Adds `chcp 65001` to PowerShell profile (idempotent)
#   3. Merges UTF-8 encoding vars into ~/.claude/settings.json
#   4. Validates JSON after writing; backs up before touching anything
#
# Usage:
#   powershell -ExecutionPolicy Bypass -File Setup-WindowsEncoding.ps1

param(
    [switch]$DryRun = $false
)

$ErrorActionPreference = 'Stop'

function Write-Step { param([string]$msg) Write-Host "[setup] $msg" -ForegroundColor Cyan }
function Write-Ok   { param([string]$msg) Write-Host "  OK  $msg" -ForegroundColor Green }
function Write-Warn { param([string]$msg) Write-Host "  WARN $msg" -ForegroundColor Yellow }
function Write-Dry  { param([string]$msg) if ($DryRun) { Write-Host "  [dry-run] $msg" -ForegroundColor Yellow } }

Write-Step "Windows encoding setup for Claude Code v0.3.0"

# ---------------------------------------------------------------------------
# 1. User-scope environment variables
# ---------------------------------------------------------------------------
Write-Step "Setting User-scope environment variables"

$envVars = @{
    'PYTHONIOENCODING' = 'utf-8'
    'PYTHONUTF8'       = '1'
    'CLAUDE_CODE_USE_POWERSHELL_TOOL' = '1'
}

foreach ($kv in $envVars.GetEnumerator()) {
    $current = [System.Environment]::GetEnvironmentVariable($kv.Key, 'User')
    if ($current -eq $kv.Value) {
        Write-Ok "$($kv.Key) already set to '$($kv.Value)'"
    } else {
        if (-not $DryRun) {
            [System.Environment]::SetEnvironmentVariable($kv.Key, $kv.Value, 'User')
            [System.Environment]::SetEnvironmentVariable($kv.Key, $kv.Value, 'Process')
        }
        Write-Ok "Set $($kv.Key) = '$($kv.Value)'"
        Write-Dry "Would set $($kv.Key) = '$($kv.Value)'"
    }
}

# ---------------------------------------------------------------------------
# 2. PowerShell profile -- add chcp 65001 idempotently
# ---------------------------------------------------------------------------
Write-Step "Patching PowerShell profile for UTF-8 console (chcp 65001)"

$profilePath = $PROFILE.CurrentUserAllHosts
$marker = '# claude-solo: utf8-encoding'
$chcpBlock = @"
$marker
if (`$PSVersionTable.Platform -ne 'Unix') { chcp 65001 | Out-Null }
"@

if (-not (Test-Path $profilePath)) {
    if (-not $DryRun) {
        $profileDir = Split-Path $profilePath
        if (-not (Test-Path $profileDir)) { New-Item -ItemType Directory -Path $profileDir -Force | Out-Null }
        Set-Content -Path $profilePath -Value $chcpBlock -Encoding UTF8
    }
    Write-Ok "Created profile at $profilePath"
    Write-Dry "Would create profile at $profilePath"
} elseif (Select-String -Path $profilePath -Pattern $marker -Quiet) {
    Write-Ok "Profile already has chcp 65001 block"
} else {
    if (-not $DryRun) {
        Add-Content -Path $profilePath -Value "`n$chcpBlock" -Encoding UTF8
    }
    Write-Ok "Appended chcp 65001 to $profilePath"
    Write-Dry "Would append chcp 65001 to $profilePath"
}

# ---------------------------------------------------------------------------
# 3. Merge encoding vars into ~/.claude/settings.json
# ---------------------------------------------------------------------------
Write-Step "Merging encoding vars into ~/.claude/settings.json"

$settingsPath = Join-Path $env:USERPROFILE '.claude\settings.json'

if (-not (Test-Path $settingsPath)) {
    Write-Warn "~/.claude/settings.json not found -- run the claude-solo installer first"
} else {
    # Backup
    $backupPath = "$settingsPath.bak.$(Get-Date -Format 'yyyyMMdd-HHmmss')"
    if (-not $DryRun) { Copy-Item $settingsPath $backupPath }
    Write-Ok "Backed up to $backupPath"
    Write-Dry "Would back up to $backupPath"

    # Parse with cascading fallback: UTF-8 -> cp1252 recovery -> ASCII-strip last resort
    $settingsJson = $null
    $parseSuccess = $false

    foreach ($enc in @('UTF-8', 'windows-1252', 'ASCII')) {
        try {
            $raw = Get-Content -Path $settingsPath -Encoding $enc -Raw
            # Strip BOM if present
            $raw = $raw -replace '^\xEF\xBB\xBF', ''
            $settingsJson = $raw | ConvertFrom-Json
            $parseSuccess = $true
            Write-Ok "Parsed settings.json as $enc"
            break
        } catch {
            Write-Warn "Could not parse as $enc, trying next..."
        }
    }

    if (-not $parseSuccess) {
        Write-Warn "Could not parse settings.json -- skipping merge. Fix manually."
    } else {
        # Ensure .env object exists
        if (-not $settingsJson.PSObject.Properties['env']) {
            $settingsJson | Add-Member -MemberType NoteProperty -Name 'env' -Value ([PSCustomObject]@{})
        }

        # Merge vars
        foreach ($kv in $envVars.GetEnumerator()) {
            if (-not $settingsJson.env.PSObject.Properties[$kv.Key]) {
                $settingsJson.env | Add-Member -MemberType NoteProperty -Name $kv.Key -Value $kv.Value
                Write-Ok "Added $($kv.Key) to settings.json env"
            } else {
                Write-Ok "$($kv.Key) already in settings.json env"
            }
        }

        # Write back
        if (-not $DryRun) {
            $outJson = $settingsJson | ConvertTo-Json -Depth 20
            # Validate before writing
            try {
                $outJson | ConvertFrom-Json | Out-Null
                [System.IO.File]::WriteAllText($settingsPath, $outJson, [System.Text.Encoding]::UTF8)
                Write-Ok "Wrote settings.json (UTF-8, no BOM)"
            } catch {
                Write-Warn "JSON validation failed after merge -- restoring backup"
                Copy-Item $backupPath $settingsPath -Force
            }
        }
        Write-Dry "Would write merged settings.json"
    }
}

# ---------------------------------------------------------------------------
# Done
# ---------------------------------------------------------------------------
Write-Step "Setup complete."
Write-Host ""
Write-Host "  Restart your terminal and PowerShell session to apply changes." -ForegroundColor Cyan
Write-Host "  Test: python -c ""print('hello world')"" should run without charmap errors." -ForegroundColor Cyan

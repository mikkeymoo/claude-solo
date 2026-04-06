# claude-solo setup — Windows PowerShell
#
# Usage:
#   .\setup.ps1              → installs globally (~/.claude) — default
#   .\setup.ps1 --project    → installs into current project (./.claude)
#   .\setup.ps1 --both       → installs globally AND into current project
#   .\setup.ps1 --uninstall  → removes from global
#   .\setup.ps1 --uninstall --project → removes from project
#   .\setup.ps1 -nobackup            → skip automatic backup of existing files

param(
    [switch]$project,
    [switch]$both,
    [switch]$uninstall,
    [switch]$nobackup
)

$REPO_DIR = $PSScriptRoot
$GLOBAL_DIR  = "$env:USERPROFILE\.claude"
$PROJECT_DIR = "$((Get-Location).Path)\.claude"

$MARKER_START = "<!-- claude-solo:start -->"
$MARKER_END   = "<!-- claude-solo:end -->"

function Backup-Existing($TARGET) {
    if ($nobackup) { return }

    $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
    $backupDir = "$TARGET\.claude-solo-backup\$timestamp"
    $backedUp = $false

    # Backup hooks that would be overwritten
    Get-ChildItem "$REPO_DIR\src\hooks\*.js" -ErrorAction SilentlyContinue | ForEach-Object {
        $existing = "$TARGET\hooks\$($_.Name)"
        if (Test-Path $existing) {
            if (-not $backedUp) {
                New-Item -ItemType Directory -Force -Path "$backupDir\hooks" | Out-Null
                New-Item -ItemType Directory -Force -Path "$backupDir\agents" | Out-Null
                New-Item -ItemType Directory -Force -Path "$backupDir\skills" | Out-Null
                $backedUp = $true
            }
            Copy-Item $existing "$backupDir\hooks\$($_.Name)"
        }
    }

    # Backup agents that would be overwritten
    Get-ChildItem "$REPO_DIR\src\agents\*.md" -ErrorAction SilentlyContinue | ForEach-Object {
        $existing = "$TARGET\agents\$($_.Name)"
        if (Test-Path $existing) {
            if (-not $backedUp) {
                New-Item -ItemType Directory -Force -Path "$backupDir\agents" | Out-Null
                $backedUp = $true
            }
            Copy-Item $existing "$backupDir\agents\$($_.Name)"
        }
    }

    # Backup skills that would be overwritten
    Get-ChildItem "$REPO_DIR\src\skills\*.md" -ErrorAction SilentlyContinue | ForEach-Object {
        $existing = "$TARGET\skills\$($_.Name)"
        if (Test-Path $existing) {
            if (-not $backedUp) {
                New-Item -ItemType Directory -Force -Path "$backupDir\skills" | Out-Null
                $backedUp = $true
            }
            Copy-Item $existing "$backupDir\skills\$($_.Name)"
        }
    }

    # Backup settings.json and CLAUDE.md
    if (Test-Path "$TARGET\settings.json") {
        if (-not $backedUp) { New-Item -ItemType Directory -Force -Path $backupDir | Out-Null; $backedUp = $true }
        Copy-Item "$TARGET\settings.json" "$backupDir\settings.json"
    }
    if (Test-Path "$TARGET\CLAUDE.md") {
        if (-not $backedUp) { New-Item -ItemType Directory -Force -Path $backupDir | Out-Null; $backedUp = $true }
        Copy-Item "$TARGET\CLAUDE.md" "$backupDir\CLAUDE.md"
    }

    if ($backedUp) {
        Write-Host "    📦 Backup saved to: $backupDir" -ForegroundColor Yellow
    }
}

function Install-To($TARGET) {
    Write-Host ""
    Write-Host "  Installing to: $TARGET" -ForegroundColor Cyan
    Write-Host ""

    # Backup existing files before overwriting
    Backup-Existing $TARGET

    New-Item -ItemType Directory -Force -Path "$TARGET\agents" | Out-Null
    New-Item -ItemType Directory -Force -Path "$TARGET\skills" | Out-Null
    New-Item -ItemType Directory -Force -Path "$TARGET\hooks" | Out-Null
    New-Item -ItemType Directory -Force -Path "$TARGET\logs"  | Out-Null

    # CLAUDE.md
    $CLAUDE_MD = "$TARGET\CLAUDE.md"
    $OUR_BLOCK = Get-Content "$REPO_DIR\src\CLAUDE.md" -Raw

    if (Test-Path $CLAUDE_MD) {
        $existing = Get-Content $CLAUDE_MD -Raw
        $start = $existing.IndexOf($MARKER_START)
        $end   = $existing.IndexOf($MARKER_END)
        if ($start -ge 0 -and $end -ge 0) {
            $existing = $existing.Substring(0, $start) + $existing.Substring($end + $MARKER_END.Length)
        }
        Write-Host "    Found existing CLAUDE.md — appending" -ForegroundColor Gray
    } else {
        $existing = ""
    }
    $combined = $existing.TrimEnd() + "`n`n$MARKER_START`n$OUR_BLOCK`n$MARKER_END`n"
    Set-Content -Path $CLAUDE_MD -Value $combined -Encoding UTF8
    Write-Host "    ✓ CLAUDE.md" -ForegroundColor Green

    # Agents
    Get-ChildItem "$REPO_DIR\src\agents\*.md" | ForEach-Object {
        Copy-Item $_.FullName "$TARGET\agents\$($_.Name)" -Force
        Write-Host "    ✓ Agent: $($_.Name)" -ForegroundColor Green
    }

    # Skills
    Get-ChildItem "$REPO_DIR\src\skills\*.md" | ForEach-Object {
        Copy-Item $_.FullName "$TARGET\skills\$($_.Name)" -Force
        Write-Host "    ✓ Skill: $($_.Name)" -ForegroundColor Green
    }

    # Hooks (only global hooks make sense — skip for project-level)
    $isGlobal = ($TARGET -eq $GLOBAL_DIR)
    if ($isGlobal) {
        Get-ChildItem "$REPO_DIR\src\hooks\*.js" | ForEach-Object {
            Copy-Item $_.FullName "$TARGET\hooks\$($_.Name)" -Force
            Write-Host "    ✓ Hook: $($_.Name)" -ForegroundColor Green
        }
        # Save repo path so /mm:update knows where to pull from
        Set-Content -Path "$TARGET\.claude-solo-source" -Value $REPO_DIR -Encoding UTF8
        Write-Host "    ✓ Source path saved (.claude-solo-source)" -ForegroundColor Green
    }

    # MCP template (copy but don't overwrite)
    $MCP_SRC = "$REPO_DIR\src\mcp.json"
    $MCP_DST = "$TARGET\mcp.json"
    if ((Test-Path $MCP_SRC) -and -not (Test-Path $MCP_DST)) {
        Copy-Item $MCP_SRC $MCP_DST
        Write-Host "    ✓ MCP template (mcp.json) — enable servers you need" -ForegroundColor Green
    }

    # Status line config (copy but don't overwrite)
    $SL_SRC = "$REPO_DIR\src\settings\statusline.json"
    $SL_DST = "$TARGET\statusline.json"
    if ((Test-Path $SL_SRC) -and -not (Test-Path $SL_DST)) {
        Copy-Item $SL_SRC $SL_DST
        Write-Host "    ✓ Status line config (statusline.json)" -ForegroundColor Green
    }

    # settings.json
    $SETTINGS_PATH = "$TARGET\settings.json"
    $OUR_SETTINGS  = Get-Content "$REPO_DIR\src\settings\settings.json" -Raw | ConvertFrom-Json

    if (Test-Path $SETTINGS_PATH) {
        try {
            $existing_settings = Get-Content $SETTINGS_PATH -Raw | ConvertFrom-Json
        } catch {
            $existing_settings = [PSCustomObject]@{}
        }
    } else {
        $existing_settings = [PSCustomObject]@{}
    }

    if (-not $existing_settings.PSObject.Properties["hooks"]) {
        $existing_settings | Add-Member -MemberType NoteProperty -Name "hooks" -Value $OUR_SETTINGS.hooks
    } else {
        foreach ($hookType in $OUR_SETTINGS.hooks.PSObject.Properties) {
            if (-not $existing_settings.hooks.PSObject.Properties[$hookType.Name]) {
                $existing_settings.hooks | Add-Member -MemberType NoteProperty -Name $hookType.Name -Value $hookType.Value
            }
        }
    }

    $existing_settings | ConvertTo-Json -Depth 10 | Set-Content $SETTINGS_PATH -Encoding UTF8
    Write-Host "    ✓ settings.json" -ForegroundColor Green
}

function Uninstall-From($TARGET) {
    Write-Host ""
    Write-Host "  Uninstalling from: $TARGET" -ForegroundColor Yellow

    # Strip CLAUDE.md block
    $CLAUDE_MD = "$TARGET\CLAUDE.md"
    if (Test-Path $CLAUDE_MD) {
        $content = Get-Content $CLAUDE_MD -Raw
        $start = $content.IndexOf($MARKER_START)
        $end   = $content.IndexOf($MARKER_END)
        if ($start -ge 0 -and $end -ge 0) {
            $content = $content.Substring(0, $start) + $content.Substring($end + $MARKER_END.Length)
            Set-Content $CLAUDE_MD $content.TrimEnd() -Encoding UTF8
            Write-Host "    ✓ Removed from CLAUDE.md" -ForegroundColor Green
        }
    }

    # Remove installed agents/skills/hooks
    @("agents","skills","hooks") | ForEach-Object {
        $dir = "$TARGET\$_"
        if (Test-Path $dir) {
            $files = Get-ChildItem $dir
            if ($files.Count -eq 0) { Remove-Item $dir -Force }
        }
    }

    Write-Host "    ✓ Done. Your own files are untouched." -ForegroundColor Green
}

# ── Main ────────────────────────────────────────────────────────────────────
Write-Host ""
Write-Host "claude-solo" -ForegroundColor Cyan

if ($uninstall) {
    if ($project) {
        Uninstall-From $PROJECT_DIR
    } else {
        Uninstall-From $GLOBAL_DIR
    }
} elseif ($project) {
    Install-To $PROJECT_DIR
    Write-Host ""
    Write-Host "  Installed to project only (./.claude)" -ForegroundColor Gray
} elseif ($both) {
    Install-To $GLOBAL_DIR
    Install-To $PROJECT_DIR
    Write-Host ""
    Write-Host "  Installed globally AND to project" -ForegroundColor Gray
} else {
    Install-To $GLOBAL_DIR
    Write-Host ""
    Write-Host "  Installed globally (~/.claude)" -ForegroundColor Gray
}

Write-Host ""
Write-Host "Open Claude Code and use:" -ForegroundColor Cyan
Write-Host "  /brief  /plan  /build  /review  /test  /verify  /ship  /retro"
Write-Host ""
Write-Host "Power skills: /handoff  /release  /incident  /docsync  /doctor  /verify" -ForegroundColor Gray
Write-Host ""

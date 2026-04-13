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
                $backedUp = $true
            }
            Copy-Item $existing "$backupDir\hooks\$($_.Name)"
        }
    }

    # Backup agents that would be overwritten
    Get-ChildItem "$REPO_DIR\src\agents\*.md" -ErrorAction SilentlyContinue | ForEach-Object {
        $existing = "$TARGET\agents\$($_.Name)"
        if (Test-Path $existing) {
            New-Item -ItemType Directory -Force -Path "$backupDir\agents" | Out-Null
            if (-not $backedUp) { $backedUp = $true }
            Copy-Item $existing "$backupDir\agents\$($_.Name)"
        }
    }

    # Backup commands that would be overwritten
    Get-ChildItem "$REPO_DIR\src\commands\mm\*.md" -ErrorAction SilentlyContinue | ForEach-Object {
        $existing = "$TARGET\commands\mm\$($_.Name)"
        if (Test-Path $existing) {
            New-Item -ItemType Directory -Force -Path "$backupDir\commands\mm" | Out-Null
            if (-not $backedUp) { $backedUp = $true }
            Copy-Item $existing "$backupDir\commands\mm\$($_.Name)"
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

    # Render provider artifacts from shared canonical source
    node "$REPO_DIR\scripts\render-providers.mjs" | Out-Null

    # Backup existing files before overwriting
    Backup-Existing $TARGET

    New-Item -ItemType Directory -Force -Path "$TARGET\agents" | Out-Null
    New-Item -ItemType Directory -Force -Path "$TARGET\commands\mm" | Out-Null
    New-Item -ItemType Directory -Force -Path "$TARGET\hooks" | Out-Null
    New-Item -ItemType Directory -Force -Path "$TARGET\logs"  | Out-Null
    New-Item -ItemType Directory -Force -Path "$TARGET\rules" | Out-Null

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

    # For project installs, skip agents/commands if global is already installed
    # (they're already available globally — project copies would create duplicates)
    $skipAgentsCommands = (-not $isGlobal) -and (Test-Path "$GLOBAL_DIR\commands\mm\brief.md")
    if ($skipAgentsCommands) {
        Write-Host "    ℹ  Global install detected — skipping agents/commands (already available globally)" -ForegroundColor Gray
    }

    # Agents
    if (-not $skipAgentsCommands) {
        Get-ChildItem "$REPO_DIR\src\agents\*.md" | ForEach-Object {
            Copy-Item $_.FullName "$TARGET\agents\$($_.Name)" -Force
            Write-Host "    ✓ Agent: $($_.Name)" -ForegroundColor Green
        }
    }

    # Commands
    if (-not $skipAgentsCommands) {
        Get-ChildItem "$REPO_DIR\src\commands\mm\*.md" -ErrorAction SilentlyContinue | ForEach-Object {
            Copy-Item $_.FullName "$TARGET\commands\mm\$($_.Name)" -Force
            Write-Host "    ✓ Command: $($_.Name)" -ForegroundColor Green
        }
    }
    # Remove old skills dir mm-* files if they exist from previous installs
    if (Test-Path "$TARGET\skills") {
        Get-ChildItem "$TARGET\skills\mm-*.md" -ErrorAction SilentlyContinue | Remove-Item -Force
    }

    # Rules (starter rule files — copy, never overwrite user's rules)
    Get-ChildItem "$REPO_DIR\src\rules\*.md" -ErrorAction SilentlyContinue | ForEach-Object {
        $dst = "$TARGET\rules\$($_.Name)"
        if (-not (Test-Path $dst)) {
            Copy-Item $_.FullName $dst
            Write-Host "    ✓ Rule: $($_.Name)" -ForegroundColor Green
        }
    }

    # Hooks (only global hooks make sense — skip for project-level)
    $isGlobal = ($TARGET -eq $GLOBAL_DIR)
    if ($isGlobal) {
        # .js hooks
        Get-ChildItem "$REPO_DIR\src\hooks\*.js" | ForEach-Object {
            Copy-Item $_.FullName "$TARGET\hooks\$($_.Name)" -Force
            Write-Host "    ✓ Hook: $($_.Name)" -ForegroundColor Green
        }
        # .cjs hooks (LSP enforcement guards — CommonJS modules)
        Get-ChildItem "$REPO_DIR\src\hooks\*.cjs" -ErrorAction SilentlyContinue | ForEach-Object {
            Copy-Item $_.FullName "$TARGET\hooks\$($_.Name)" -Force
            Write-Host "    ✓ Hook: $($_.Name)" -ForegroundColor Green
        }
        # lib/ shared helpers
        New-Item -ItemType Directory -Force -Path "$TARGET\hooks\lib" | Out-Null
        Get-ChildItem "$REPO_DIR\src\hooks\lib\*" -ErrorAction SilentlyContinue | ForEach-Object {
            Copy-Item $_.FullName "$TARGET\hooks\lib\$($_.Name)" -Force
            Write-Host "    ✓ Hook lib: $($_.Name)" -ForegroundColor Green
        }
        # swarm hooks
        New-Item -ItemType Directory -Force -Path "$TARGET\hooks\swarm" | Out-Null
        Get-ChildItem "$REPO_DIR\src\hooks\swarm\*.js" -ErrorAction SilentlyContinue | ForEach-Object {
            Copy-Item $_.FullName "$TARGET\hooks\swarm\$($_.Name)" -Force
            Write-Host "    ✓ Hook swarm: $($_.Name)" -ForegroundColor Green
        }
        if (Test-Path "$REPO_DIR\src\hooks\swarm\package.json") {
            Copy-Item "$REPO_DIR\src\hooks\swarm\package.json" "$TARGET\hooks\swarm\package.json" -Force
        }
        # Ensure hooks are treated as ES modules
        Copy-Item "$REPO_DIR\src\hooks\package.json" "$TARGET\hooks\package.json" -Force
        Write-Host "    ✓ hooks/package.json (ES module support)" -ForegroundColor Green
        # Save repo path so /mm:update knows where to pull from
        Set-Content -Path "$TARGET\.claude-solo-source" -Value $REPO_DIR -Encoding UTF8
        Write-Host "    ✓ Source path saved (.claude-solo-source)" -ForegroundColor Green
    }

    # MCP template — project/discovery list (copy but don't overwrite)
    $MCP_SRC = "$REPO_DIR\src\mcp.json"
    $MCP_DST = "$TARGET\mcp.json"
    if ((Test-Path $MCP_SRC) -and -not (Test-Path $MCP_DST)) {
        Copy-Item $MCP_SRC $MCP_DST
        Write-Host "    ✓ MCP template (mcp.json) — enable servers you need" -ForegroundColor Green
    }

    # Global active MCP config — ~/.claude/.mcp.json (Serena + Playwright enabled)
    if ($isGlobal) {
        $GlobalMcpSrc = "$REPO_DIR\src\settings\mcp-global.json"
        $GlobalMcpDst = "$TARGET\.mcp.json"
        if ((Test-Path $GlobalMcpSrc) -and -not (Test-Path $GlobalMcpDst)) {
            Copy-Item $GlobalMcpSrc $GlobalMcpDst
            Write-Host "    ✓ Global MCP config (~/.claude/.mcp.json) — Serena + Playwright enabled" -ForegroundColor Green
        } else {
            Write-Host "    ℹ  ~/.claude/.mcp.json exists — skipping (edit manually to add Serena/Playwright)" -ForegroundColor Gray
        }
    }

    # Status line — install statusline.sh if Git Bash is available, otherwise note it
    if ($isGlobal -and (Test-Path "$REPO_DIR\src\settings\statusline.sh")) {
        $StatuslineDst = "$TARGET\statusline.sh"
        Copy-Item "$REPO_DIR\src\settings\statusline.sh" $StatuslineDst -Force
        # Find Git Bash and note path for settings
        $GitBashPath = $null
        $GitBashCandidates = @(
            "C:\Program Files\Git\bin\bash.exe",
            "C:\Program Files (x86)\Git\bin\bash.exe",
            "$env:LOCALAPPDATA\Programs\Git\bin\bash.exe",
            "$env:USERPROFILE\scoop\apps\git\current\bin\bash.exe"
        )
        foreach ($c in $GitBashCandidates) {
            if (Test-Path $c) { $GitBashPath = $c; break }
        }
        if ($GitBashPath) {
            Write-Host "    ✓ statusline.sh installed (Git Bash found: $GitBashPath)" -ForegroundColor Green
        } else {
            Write-Host "    ✓ statusline.sh installed (requires Git Bash or WSL bash in PATH)" -ForegroundColor Green
        }
    }

    # uv (Python package manager — required for Serena MCP)
    if ($isGlobal) {
        if (-not (Get-Command uv -ErrorAction SilentlyContinue)) {
            Write-Host "    Installing uv (required for Serena MCP)..." -ForegroundColor Gray
            try {
                powershell -ExecutionPolicy ByPass -Command "irm https://astral.sh/uv/install.ps1 | iex" 2>&1 | Out-Null
                # Refresh PATH so uv is available in this session
                $env:PATH = [System.Environment]::GetEnvironmentVariable("PATH", "User") + ";" + $env:PATH
                $uvVer = (uv --version 2>$null)
                if ($uvVer) {
                    Write-Host "    ✓ uv installed ($uvVer)" -ForegroundColor Green
                } else {
                    Write-Host "    ✓ uv installed (restart shell to use)" -ForegroundColor Green
                }
            } catch {
                Write-Host "    ⚠  uv install failed — install manually: winget install astral-sh.uv" -ForegroundColor Yellow
            }
        } else {
            $uvVer = (uv --version 2>$null)
            Write-Host "    ✓ uv already installed ($uvVer)" -ForegroundColor Green
        }
    }

    # claude-code-cache-fix — install npm package then install wrapper
    if ($isGlobal -and (Test-Path "$REPO_DIR\src\bin\claude")) {
        $NpmPrefix = (npm config get prefix 2>$null).Trim()
        if (-not $NpmPrefix) { $NpmPrefix = "$env:APPDATA\npm" }
        $CacheFixPkg = "$NpmPrefix\node_modules\claude-code-cache-fix\preload.mjs"
        if (-not (Test-Path $CacheFixPkg)) {
            Write-Host "    Installing claude-code-cache-fix..." -ForegroundColor Gray
            npm install -g claude-code-cache-fix 2>&1 | Select-String "added|error|warn" | ForEach-Object { Write-Host "      $_" -ForegroundColor Gray }
            # Recompute after install
            $CacheFixPkg = "$(npm config get prefix)\node_modules\claude-code-cache-fix\preload.mjs"
        }
        if (Test-Path $CacheFixPkg) {
            $WrapperDir = "$env:USERPROFILE\.local\bin"
            New-Item -ItemType Directory -Force -Path $WrapperDir | Out-Null

            $WrapperPaths = @(
                "$WrapperDir\claude",
                "$WrapperDir\claude.cmd",
                "$WrapperDir\claude.ps1"
            )
            $BackupSuffix = ".bak-" + (Get-Date -Format "yyyyMMdd-HHmmss")
            foreach ($WrapperPath in $WrapperPaths) {
                if (Test-Path $WrapperPath) {
                    Move-Item -LiteralPath $WrapperPath -Destination ($WrapperPath + $BackupSuffix) -Force
                }
            }

            Copy-Item "$REPO_DIR\src\bin\claude" "$WrapperDir\claude" -Force
            if (Test-Path "$REPO_DIR\src\bin\claude.ps1") {
                Copy-Item "$REPO_DIR\src\bin\claude.ps1" "$WrapperDir\claude.ps1" -Force
            }
            if (Test-Path "$REPO_DIR\src\bin\claude.cmd") {
                Copy-Item "$REPO_DIR\src\bin\claude.cmd" "$WrapperDir\claude.cmd" -Force
            }
            Write-Host "    ✓ claude-code-cache-fix installed + wrappers (~/.local/bin/claude{,.cmd,.ps1})" -ForegroundColor Green
        } else {
            Write-Host "    ⚠  claude-code-cache-fix install failed — wrapper skipped" -ForegroundColor Yellow
            Write-Host "       Run manually: npm install -g claude-code-cache-fix" -ForegroundColor Gray
        }
    }

    # settings.json (merge — add missing keys, never overwrite user values)
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

    # Merge top-level keys that don't exist yet (never overwrite user values)
    foreach ($key in @("model","effortLevel","statusLine","permissions","worktree")) {
        if (-not $existing_settings.PSObject.Properties[$key] -and $OUR_SETTINGS.PSObject.Properties[$key]) {
            $existing_settings | Add-Member -MemberType NoteProperty -Name $key -Value $OUR_SETTINGS.$key
        }
    }

    # Merge hooks: add event keys that don't exist yet
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

    $isGlobal = ($TARGET -eq $GLOBAL_DIR)

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

    # Remove installed agents
    Get-ChildItem "$REPO_DIR\src\agents\*.md" -ErrorAction SilentlyContinue | ForEach-Object {
        $target_file = "$TARGET\agents\$($_.Name)"
        if (Test-Path $target_file) {
            Remove-Item $target_file -Force
            Write-Host "    ✓ Removed agent: $($_.Name)" -ForegroundColor Green
        }
    }

    # Remove installed commands
    Get-ChildItem "$REPO_DIR\src\commands\mm\*.md" -ErrorAction SilentlyContinue | ForEach-Object {
        $target_file = "$TARGET\commands\mm\$($_.Name)"
        if (Test-Path $target_file) {
            Remove-Item $target_file -Force
            Write-Host "    ✓ Removed command: $($_.Name)" -ForegroundColor Green
        }
    }

    # Remove installed hooks (global only)
    if ($isGlobal) {
        # Remove .js hooks
        Get-ChildItem "$REPO_DIR\src\hooks\*.js" -ErrorAction SilentlyContinue | ForEach-Object {
            $target_file = "$TARGET\hooks\$($_.Name)"
            if (Test-Path $target_file) { Remove-Item $target_file -Force; Write-Host "    ✓ Removed hook: $($_.Name)" -ForegroundColor Green }
        }
        # Remove .cjs hooks
        Get-ChildItem "$REPO_DIR\src\hooks\*.cjs" -ErrorAction SilentlyContinue | ForEach-Object {
            $target_file = "$TARGET\hooks\$($_.Name)"
            if (Test-Path $target_file) { Remove-Item $target_file -Force; Write-Host "    ✓ Removed hook: $($_.Name)" -ForegroundColor Green }
        }
        # Remove lib/ helpers
        Get-ChildItem "$REPO_DIR\src\hooks\lib\*" -ErrorAction SilentlyContinue | ForEach-Object {
            $target_file = "$TARGET\hooks\lib\$($_.Name)"
            if (Test-Path $target_file) { Remove-Item $target_file -Force }
        }
        # Remove swarm hooks
        Get-ChildItem "$REPO_DIR\src\hooks\swarm\*.js" -ErrorAction SilentlyContinue | ForEach-Object {
            $target_file = "$TARGET\hooks\swarm\$($_.Name)"
            if (Test-Path $target_file) { Remove-Item $target_file -Force }
        }
        if (Test-Path "$TARGET\hooks\package.json") { Remove-Item "$TARGET\hooks\package.json" -Force }
        if (Test-Path "$TARGET\.claude-solo-source") { Remove-Item "$TARGET\.claude-solo-source" -Force }
        if (Test-Path "$TARGET\settings-safe.json") { Remove-Item "$TARGET\settings-safe.json" -Force }
        Write-Host "    ✓ Removed hooks, .claude-solo-source, settings-safe.json" -ForegroundColor Green
    }

    Write-Host "    ✓ Done. Your customized files (rules, mcp.json, custom agents) are untouched." -ForegroundColor Green
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
Write-Host "  /mm:brief  /mm:plan  /mm:build  /mm:review  /mm:test  /mm:verify  /mm:ship  /mm:retro"
Write-Host ""
Write-Host "Power:   /mm:handoff  /mm:release  /mm:incident  /mm:docsync  /mm:doctor" -ForegroundColor Gray
Write-Host "New:     /mm:map  /mm:deps  /mm:a11y  /mm:migrate  /mm:onboard  /mm:stale" -ForegroundColor Gray
Write-Host ""

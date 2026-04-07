param(
    [switch]$project,
    [switch]$both,
    [switch]$uninstall
)

$ErrorActionPreference = "Stop"

$REPO_DIR = $PSScriptRoot
$GLOBAL_DIR = "$env:USERPROFILE\.codex"
$PROJECT_DIR = "$((Get-Location).Path)\.codex"

function Strip-Block($filePath) {
    if (-not (Test-Path $filePath)) { return }
    $content = Get-Content $filePath -Raw
    $content = [regex]::Replace($content, '<!-- claude-solo-codex:start -->[\s\S]*?<!-- claude-solo-codex:end -->\r?\n?', '')
    Set-Content -Path $filePath -Value ($content.TrimEnd() + "`n") -Encoding UTF8
}

function Install-To($TARGET) {
    Write-Host ""
    Write-Host "  Installing Codex to: $TARGET" -ForegroundColor Cyan

    node "$REPO_DIR\scripts\render-providers.mjs" | Out-Null

    New-Item -ItemType Directory -Force -Path "$TARGET\skills" | Out-Null
    New-Item -ItemType Directory -Force -Path "$TARGET\agents" | Out-Null
    New-Item -ItemType Directory -Force -Path "$TARGET\hooks" | Out-Null

    Get-ChildItem "$TARGET\skills\mm-*" -Directory -ErrorAction SilentlyContinue | Remove-Item -Recurse -Force
    Get-ChildItem "$REPO_DIR\src\codex\agents\*.toml" -ErrorAction SilentlyContinue | ForEach-Object {
        Remove-Item "$TARGET\agents\$($_.Name)" -Force -ErrorAction SilentlyContinue
    }
    Copy-Item "$REPO_DIR\src\codex\skills\*" "$TARGET\skills" -Recurse -Force
    Copy-Item "$REPO_DIR\src\codex\agents\*.toml" "$TARGET\agents" -Force
    Copy-Item "$REPO_DIR\src\codex\hooks\mm-hook.js" "$TARGET\hooks\mm-hook.js" -Force

    $agentsFile = "$TARGET\AGENTS.md"
    if (-not (Test-Path $agentsFile)) { New-Item -Path $agentsFile -ItemType File | Out-Null }
    Strip-Block $agentsFile
    $block = Get-Content "$REPO_DIR\src\codex\AGENTS.md" -Raw
    Add-Content -Path $agentsFile -Value $block

    if (Test-Path "$TARGET\config.toml") {
        Copy-Item "$REPO_DIR\src\codex\config.toml" "$TARGET\config.claude-solo.toml" -Force
        Write-Host "    ✓ Wrote config sidecar: $TARGET\config.claude-solo.toml" -ForegroundColor Green
    } else {
        Copy-Item "$REPO_DIR\src\codex\config.toml" "$TARGET\config.toml" -Force
        Write-Host "    ✓ Wrote config: $TARGET\config.toml" -ForegroundColor Green
    }

    if (-not (Test-Path "$TARGET\mcp.json")) {
        Copy-Item "$REPO_DIR\src\codex\mcp.json" "$TARGET\mcp.json" -Force
    }

    Set-Content -Path "$TARGET\.claude-solo-source" -Value $REPO_DIR -Encoding UTF8
    Write-Host "    ✓ Installed Codex skills, agents, wrappers" -ForegroundColor Green
}

function Uninstall-From($TARGET) {
    Write-Host ""
    Write-Host "  Uninstalling Codex from: $TARGET" -ForegroundColor Yellow

    Strip-Block "$TARGET\AGENTS.md"
    Get-ChildItem "$TARGET\skills\mm-*" -Directory -ErrorAction SilentlyContinue | Remove-Item -Recurse -Force
    Get-ChildItem "$REPO_DIR\src\codex\agents\*.toml" -ErrorAction SilentlyContinue | ForEach-Object {
        Remove-Item "$TARGET\agents\$($_.Name)" -Force -ErrorAction SilentlyContinue
    }
    Remove-Item "$TARGET\hooks\mm-hook.js" -ErrorAction SilentlyContinue
    Remove-Item "$TARGET\config.claude-solo.toml" -ErrorAction SilentlyContinue
    Remove-Item "$TARGET\.claude-solo-source" -ErrorAction SilentlyContinue

    Write-Host "    ✓ Done" -ForegroundColor Green
}

$scope = "global"
if ($project) { $scope = "project" }
if ($both) { $scope = "both" }

Write-Host ""
Write-Host "claude-solo codex setup" -ForegroundColor Cyan

if ($uninstall) {
    if ($scope -eq "project") {
        Uninstall-From $PROJECT_DIR
    } elseif ($scope -eq "both") {
        Uninstall-From $GLOBAL_DIR
        Uninstall-From $PROJECT_DIR
    } else {
        Uninstall-From $GLOBAL_DIR
    }
} else {
    if ($scope -eq "project") {
        Install-To $PROJECT_DIR
    } elseif ($scope -eq "both") {
        Install-To $GLOBAL_DIR
        Install-To $PROJECT_DIR
    } else {
        Install-To $GLOBAL_DIR
    }
}

Write-Host ""
Write-Host 'Use generated Codex skills: $mm-brief, $mm-plan, ...' -ForegroundColor Gray
Write-Host 'Hook wrapper: node .codex/hooks/mm-hook.js <event>' -ForegroundColor Gray

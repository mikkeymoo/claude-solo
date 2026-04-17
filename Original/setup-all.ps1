param(
    [switch]$project,
    [switch]$both,
    [switch]$uninstall,
    [switch]$nobackup
)

$REPO_DIR = $PSScriptRoot

$argsForClaude = @()
if ($project) { $argsForClaude += '--project' }
if ($both) { $argsForClaude += '--both' }
if ($uninstall) { $argsForClaude += '--uninstall' }
if ($nobackup) { $argsForClaude += '-nobackup' }

& "$REPO_DIR\setup.ps1" @argsForClaude

$argsForCodex = @()
if ($project) { $argsForCodex += '--project' }
if ($both) { $argsForCodex += '--both' }
if ($uninstall) { $argsForCodex += '--uninstall' }

& "$REPO_DIR\setup-codex.ps1" @argsForCodex

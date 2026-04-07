# claude-solo auto-mode (ralph pattern) — Windows PowerShell
#
# Runs Claude Code autonomously in a loop until the task is complete.
# Uses --dangerouslySkipPermissions — Claude acts without confirmation prompts.
#
# Usage:
#   .\run-auto.ps1                       # runs from .planning/PLAN.md
#   .\run-auto.ps1 "fix the login bug"   # one-shot task
#   .\run-auto.ps1 --max 5              # max 5 iterations (default: 10)

param(
    [string]$Task = "",
    [int]$Max = 10
)

$ErrorActionPreference = "Stop"

# Build task prompt
if (-not $Task) {
    if (Test-Path ".planning/PLAN.md") {
        $Task = Get-Content ".planning/PLAN.md" -Raw
        Write-Host "  Using .planning/PLAN.md as task" -ForegroundColor Gray
    } elseif (Test-Path ".planning/BRIEF.md") {
        $Task = Get-Content ".planning/BRIEF.md" -Raw
        Write-Host "  Using .planning/BRIEF.md as task" -ForegroundColor Gray
    } else {
        Write-Host "Error: no task provided and no .planning/PLAN.md found." -ForegroundColor Red
        Write-Host 'Usage: .\run-auto.ps1 "your task"  OR create .planning/PLAN.md first'
        exit 1
    }
}

$ContinuePrompt = "Continue working on the task. Check git log to see what's been done. Keep going until all tasks are complete and tests pass. When fully done, output exactly: TASK_COMPLETE"

Write-Host ""
Write-Host "claude-solo auto-mode" -ForegroundColor Cyan
Write-Host "  Max iterations: $Max" -ForegroundColor Gray
Write-Host "  Task: $($Task.Substring(0, [Math]::Min(80, $Task.Length)))..." -ForegroundColor Gray
Write-Host ""
Write-Host "  ⚠️  Running with --dangerouslySkipPermissions" -ForegroundColor Yellow
Write-Host "  Press Ctrl+C to stop at any time." -ForegroundColor Gray
Write-Host ""

$iter = 0
$initial = $true

while ($iter -lt $Max) {
    $iter++
    Write-Host "── Iteration $iter / $Max ──────────────────────────────────" -ForegroundColor Cyan

    if ($initial) {
        $prompt = "$Task`n`nWhen you are fully done and all tests pass, output exactly on its own line: TASK_COMPLETE"
        $initial = $false
    } else {
        $prompt = $ContinuePrompt
    }

    $output = claude --model claude-sonnet-4-6 --dangerouslySkipPermissions -p $prompt 2>&1
    Write-Host $output

    if ($output -match "TASK_COMPLETE") {
        Write-Host ""
        Write-Host "✅ Task complete after $iter iteration(s)." -ForegroundColor Green
        exit 0
    }

    Write-Host ""
}

Write-Host ""
Write-Host "⚠️  Reached max iterations ($Max) without TASK_COMPLETE signal." -ForegroundColor Yellow
Write-Host "Run again to continue, or check: rtk git log --oneline"
exit 1

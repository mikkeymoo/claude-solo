# claude-solo swarm launcher (Windows)
#
# Starts a Claude Code session configured for swarm-style parallel work
# with agent teams enabled and quality gate hooks active.
#
# Usage:
#   .\run-swarm.ps1                          # Interactive swarm session
#   .\run-swarm.ps1 "implement auth module"  # Swarm with initial task
#   .\run-swarm.ps1 -Teammates 5             # Specify team size hint
#   .\run-swarm.ps1 -Gate                    # Enable stop gate

param(
    [Parameter(Position=0)]
    [string]$Task = "",

    [int]$Teammates = 0,

    [switch]$Gate,

    [switch]$InProcess,

    [string]$Agent = "",

    [switch]$Help
)

if ($Help) {
    Write-Host "claude-solo swarm launcher"
    Write-Host ""
    Write-Host "Usage:"
    Write-Host "  .\run-swarm.ps1                          # Interactive swarm"
    Write-Host "  .\run-swarm.ps1 'task description'       # Swarm with task"
    Write-Host "  .\run-swarm.ps1 -Teammates 5             # Team size hint"
    Write-Host "  .\run-swarm.ps1 -Gate                    # Enable stop gate"
    Write-Host "  .\run-swarm.ps1 -InProcess               # Force in-process mode"
    Write-Host "  .\run-swarm.ps1 -Agent swarm-lead        # Use specific agent"
    exit 0
}

# Set environment
$env:CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS = "1"
$env:CLAUDE_SOLO_SWARM_GATE = if ($Gate) { "1" } else { "0" }

# Build prompt
$Prompt = $Task
if ($Teammates -gt 0 -and $Prompt) {
    $Prompt += "`n`nCreate an agent team with $Teammates teammates to work on this."
}

# Check for Claude Code
$claudePath = Get-Command claude -ErrorAction SilentlyContinue
if (-not $claudePath) {
    Write-Host "Error: 'claude' CLI not found. Install Claude Code first."
    Write-Host "  npm install -g @anthropic-ai/claude-code"
    exit 1
}

Write-Host "========================================"
Write-Host "  claude-solo swarm session"
Write-Host "========================================"
Write-Host "  Agent teams:  enabled"
Write-Host "  Stop gate:    $(if ($Gate) { 'ON' } else { 'off' })"
if ($Teammates -gt 0) { Write-Host "  Teammates:    ~$Teammates" }
if ($Agent) { Write-Host "  Agent:        $Agent" }
Write-Host "========================================"
Write-Host ""

# Build command
$args = @()
if ($InProcess) { $args += "--teammate-mode", "in-process" }
if ($Agent) { $args += "--agent", $Agent }

if ($Prompt) {
    $args += "-p", $Prompt
}

& claude @args

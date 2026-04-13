param(
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$CliArgs
)

$ErrorActionPreference = 'Stop'

function Get-NpmPrefix {
    try {
        $prefix = (& npm config get prefix 2>$null | Out-String).Trim()
        if ($prefix) { return $prefix }
    } catch {}

    return (Join-Path $HOME 'AppData\Roaming\npm')
}

function Find-NpmModulePath {
    param([string]$ModuleName)

    $npmPrefix = Get-NpmPrefix
    $candidates = @(
        (Join-Path $npmPrefix "node_modules\$ModuleName"),
        (Join-Path $npmPrefix "lib\node_modules\$ModuleName"),
        (Join-Path $HOME ".npm-global\lib\node_modules\$ModuleName"),
        (Join-Path $HOME ".npm\lib\node_modules\$ModuleName")
    )

    foreach ($candidate in $candidates) {
        if (Test-Path -LiteralPath $candidate) {
            return $candidate
        }
    }

    return $null
}

$claudePkg = Find-NpmModulePath '@anthropic-ai\claude-code'
if (-not $claudePkg) {
    Write-Error 'Claude Code npm package not found. Install with: npm install -g @anthropic-ai/claude-code'
}

$claudeCli = Join-Path $claudePkg 'cli.js'
if (-not (Test-Path -LiteralPath $claudeCli)) {
    Write-Error "Claude Code CLI entrypoint not found at '$claudeCli'."
}

$cacheFixPkg = Find-NpmModulePath 'claude-code-cache-fix'
if (-not $cacheFixPkg) {
    Write-Error 'claude-code-cache-fix not found. Install with: npm install -g claude-code-cache-fix'
}

$cacheFixPreload = Join-Path $cacheFixPkg 'preload.mjs'
if (-not (Test-Path -LiteralPath $cacheFixPreload)) {
    Write-Error "claude-code-cache-fix preload not found at '$cacheFixPreload'."
}
$cacheFixPreloadUrl = ([System.Uri] $cacheFixPreload).AbsoluteUri

if (-not $env:CACHE_FIX_IMAGE_KEEP_LAST) { $env:CACHE_FIX_IMAGE_KEEP_LAST = '3' }
if (-not $env:CACHE_FIX_DEBUG) { $env:CACHE_FIX_DEBUG = '0' }
if (-not $env:CACHE_FIX_USAGE_LOG) { $env:CACHE_FIX_USAGE_LOG = (Join-Path $HOME '.claude\usage.jsonl') }
if (-not $env:CACHE_FIX_DUMP_TOOLS) { $env:CACHE_FIX_DUMP_TOOLS = (Join-Path $HOME '.claude\cache-fix-tools.json') }
if (-not $env:CACHE_FIX_OUTPUT_EFFICIENCY_REPLACEMENT) {
    $env:CACHE_FIX_OUTPUT_EFFICIENCY_REPLACEMENT = @'
# Output efficiency

When sending user-facing text, write for a person, not a log file. Assume the user cannot see most tool calls or hidden reasoning - only your text output.

Keep user-facing text clear, direct, and reasonably concise. Lead with the answer or action. Skip filler, repetition, and unnecessary preamble.

Explain enough for the user to understand the reasoning, tradeoffs, or root cause when that would help them learn or make a decision, but do not turn simple answers into long writeups.

These instructions apply to user-facing text only. They do not apply to investigation, code reading, tool use, or verification.

Before making changes, read the relevant code and understand the surrounding context. Check types, signatures, call sites, and error causes before editing. Do not confuse brevity with rushing, and do not replace understanding with trial and error.

While working, give short updates at meaningful moments: when you find the root cause, when the plan changes, when you hit a blocker, or when a meaningful milestone is complete. Do not narrate every step.

When reporting results, be accurate and concrete. If you did not verify something, say so plainly. If a check failed, say that plainly too.
'@
}

$safeSettings = Join-Path $HOME '.claude\settings-safe.json'
$extraArgs = New-Object System.Collections.Generic.List[string]
$forwardArgs = New-Object System.Collections.Generic.List[string]

foreach ($arg in $CliArgs) {
    if ($arg -eq '--safe') {
        if (Test-Path -LiteralPath $safeSettings) {
            $extraArgs.Add('--settings')
            $extraArgs.Add($safeSettings)
            $extraArgs.Add('--setting-sources')
            $extraArgs.Add('user')
            Write-Warning 'Safe mode: no auto MCP, no additionalDirectories, read-only permissions need approval'
        } else {
            Write-Warning "Safe settings file not found at '$safeSettings' - running in normal mode"
        }
    } else {
        $forwardArgs.Add($arg)
    }
}

if ($env:NODE_OPTIONS) {
    $env:NODE_OPTIONS = "--import $cacheFixPreloadUrl $($env:NODE_OPTIONS)"
} else {
    $env:NODE_OPTIONS = "--import $cacheFixPreloadUrl"
}

& node $claudeCli @extraArgs @forwardArgs
exit $LASTEXITCODE

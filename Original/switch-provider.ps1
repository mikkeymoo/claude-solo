param(
    [ValidateSet('claude','codex','both')]
    [string]$provider = 'both',
    [Parameter(Mandatory=$true)]
    [string]$model,
    [string]$claudeDir = "$env:USERPROFILE\.claude",
    [string]$codexDir = "$env:USERPROFILE\.codex"
)

$ErrorActionPreference = "Stop"

function Set-ClaudeModel {
    New-Item -ItemType Directory -Force -Path $claudeDir | Out-Null
    $settingsPath = "$claudeDir\settings.json"
    if (Test-Path $settingsPath) {
        try {
            $json = Get-Content $settingsPath -Raw | ConvertFrom-Json
        } catch {
            $json = [PSCustomObject]@{}
        }
    } else {
        $json = [PSCustomObject]@{}
    }

    if ($json.PSObject.Properties['model']) {
        $json.model = $model
    } else {
        $json | Add-Member -MemberType NoteProperty -Name 'model' -Value $model
    }

    $json | ConvertTo-Json -Depth 20 | Set-Content $settingsPath -Encoding UTF8
    Write-Host "  Claude model -> $model"
}

function Set-CodexModel {
    New-Item -ItemType Directory -Force -Path $codexDir | Out-Null
    $configPath = "$codexDir\config.toml"
    if (-not (Test-Path $configPath)) {
        Set-Content $configPath "model = `"$model`"`n" -Encoding UTF8
        Write-Host "  Codex model -> $model"
        return
    }

    $content = Get-Content $configPath -Raw
    if ($content -match '(?m)^model\s*=\s*"[^"]*"\s*$') {
        $content = [regex]::Replace($content, '(?m)^model\s*=\s*"[^"]*"\s*$', "model = `"$model`"", 1)
    } else {
        $content = "model = `"$model`"`n" + $content
    }
    Set-Content $configPath $content -Encoding UTF8
    Write-Host "  Codex model -> $model"
}

Write-Host "Switching model to: $model"

switch ($provider) {
    'claude' { Set-ClaudeModel }
    'codex'  { Set-CodexModel }
    'both'   { Set-ClaudeModel; Set-CodexModel }
}

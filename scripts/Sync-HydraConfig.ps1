<#
.SYNOPSIS
    Synchronizes HYDRA config with Claude Code settings

.DESCRIPTION
    Reads hydra-config.json and applies settings to:
    - .claude/settings.local.json (permissions, hooks, MCP)
    - Environment variables
    - AI Handler configuration

.EXAMPLE
    .\Sync-HydraConfig.ps1
    .\Sync-HydraConfig.ps1 -Verbose
    .\Sync-HydraConfig.ps1 -WhatIf
#>

[CmdletBinding(SupportsShouldProcess)]
param(
    [switch]$Force
)

$ErrorActionPreference = 'Stop'
$root = $PSScriptRoot
$hydraConfigPath = Join-Path $root "hydra-config.json"
$settingsPath = Join-Path $root ".claude\settings.local.json"
$backupDir = Join-Path $root ".claude\config-backup"

# Helper function for PS 5.1 compatibility (no -AsHashtable in ConvertFrom-Json)
function ConvertTo-HashtableRecursive {
    param([object]$InputObject)
    if ($null -eq $InputObject) { return $null }
    if ($InputObject -is [System.Collections.IEnumerable] -and $InputObject -isnot [string] -and $InputObject -isnot [hashtable]) {
        return @($InputObject | ForEach-Object { ConvertTo-HashtableRecursive $_ })
    }
    if ($InputObject -is [System.Management.Automation.PSCustomObject]) {
        $ht = @{}
        foreach ($prop in $InputObject.PSObject.Properties) {
            $ht[$prop.Name] = ConvertTo-HashtableRecursive $prop.Value
        }
        return $ht
    }
    return $InputObject
}

# Ensure backup directory exists
if (-not (Test-Path $backupDir)) {
    New-Item -ItemType Directory -Path $backupDir -Force | Out-Null
}

Write-Host "`n=== HYDRA Config Sync ===" -ForegroundColor Cyan

# Load HYDRA config
if (-not (Test-Path $hydraConfigPath)) {
    Write-Error "hydra-config.json not found at $hydraConfigPath"
    exit 1
}

$hydraConfig = Get-Content $hydraConfigPath -Raw | ConvertFrom-Json
Write-Host "[OK] Loaded hydra-config.json v$($hydraConfig.version)" -ForegroundColor Green

# Load current settings
$currentSettings = @{}
if (Test-Path $settingsPath) {
    $currentSettings = ConvertTo-HashtableRecursive (Get-Content $settingsPath -Raw | ConvertFrom-Json)

    # Backup current settings
    $backupName = "settings.local-$(Get-Date -Format 'yyyyMMdd-HHmmss').json"
    Copy-Item $settingsPath (Join-Path $backupDir $backupName)
    Write-Host "[OK] Backed up current settings to $backupName" -ForegroundColor Yellow
}

# === 1. Sync Environment Variables ===
Write-Host "`n--- Environment Variables ---" -ForegroundColor Cyan

foreach ($prop in $hydraConfig.env.PSObject.Properties) {
    $varName = $prop.Name
    $varValue = $prop.Value

    if ($PSCmdlet.ShouldProcess($varName, "Set environment variable")) {
        [Environment]::SetEnvironmentVariable($varName, $varValue, 'Process')
        Write-Host "  $varName = $varValue" -ForegroundColor Gray
    }
}
Write-Host "[OK] Environment variables set" -ForegroundColor Green

# === 2. Sync Permissions ===
Write-Host "`n--- Permissions ---" -ForegroundColor Cyan

$newPermissions = @{
    allow = @($hydraConfig.permissions.allow)
    deny = @($hydraConfig.permissions.deny)
}

if (-not $currentSettings.permissions) {
    $currentSettings.permissions = @{}
}
$currentSettings.permissions = $newPermissions
Write-Host "[OK] Permissions synced ($($newPermissions.allow.Count) allow rules)" -ForegroundColor Green

# === 3. Sync MCP Servers ===
Write-Host "`n--- MCP Servers ---" -ForegroundColor Cyan

$mcpServers = @{}
foreach ($tool in $hydraConfig.mcp_tools.PSObject.Properties) {
    $name = $tool.Name
    $config = $tool.Value

    $mcpServers[$name] = @{
        command = $config.command
        args = @($config.args)
    }
    Write-Host "  $name -> $($config.command)" -ForegroundColor Gray
}

$currentSettings.mcpServers = $mcpServers
$currentSettings.enabledMcpjsonServers = @($hydraConfig.mcp_tools.PSObject.Properties.Name)
Write-Host "[OK] MCP servers synced ($($mcpServers.Count) servers)" -ForegroundColor Green

# === 4. Sync Hooks ===
Write-Host "`n--- Hooks ---" -ForegroundColor Cyan

$hooks = @{
    UserPromptSubmit = @(
        @{
            matcher = ""
            hooks = @(
                @{
                    type = "command"
                    command = "powershell -NoProfile -ExecutionPolicy Bypass -File .claude/hooks/ai-handler-integration.ps1"
                }
            )
        }
    )
    Notification = @(
        @{
            matcher = "permission_prompt"
            hooks = @(
                @{
                    type = "command"
                    command = "powershell -NoProfile -ExecutionPolicy Bypass -File .claude/hooks/permission-alert.ps1"
                }
            )
        }
    )
}

if ($hydraConfig.hooks.notification.audio_beep.enabled) {
    $hooks.Notification += @{
        matcher = ""
        hooks = @(
            @{
                type = "command"
                command = "powershell -Command `"[console]::beep(800,200)`""
            }
        )
    }
}

$currentSettings.hooks = $hooks
Write-Host "[OK] Hooks synced" -ForegroundColor Green

# === 5. Sync Statusline ===
Write-Host "`n--- Statusline ---" -ForegroundColor Cyan

if ($hydraConfig.statusline.enabled) {
    $currentSettings.statusLine = @{
        type = "command"
        command = $hydraConfig.statusline.script
    }
    Write-Host "[OK] Statusline enabled: $($hydraConfig.statusline.script)" -ForegroundColor Green
}

# === 6. Save Updated Settings ===
Write-Host "`n--- Saving ---" -ForegroundColor Cyan

if ($PSCmdlet.ShouldProcess($settingsPath, "Save updated settings")) {
    $json = $currentSettings | ConvertTo-Json -Depth 10
    Set-Content -Path $settingsPath -Value $json -Encoding UTF8
    Write-Host "[OK] Saved to $settingsPath" -ForegroundColor Green
}

# === 7. Sync AI Handler Config ===
Write-Host "`n--- AI Handler ---" -ForegroundColor Cyan

$aiConfigPath = Join-Path $root "ai-handler\ai-config.json"
if (Test-Path $aiConfigPath) {
    $aiConfig = Get-Content $aiConfigPath -Raw | ConvertFrom-Json

    # Update settings from hydra config
    if ($hydraConfig.advanced_ai.modules) {
        # Add or update advanced_ai section
        if (-not $aiConfig.PSObject.Properties['advanced_ai']) {
            $aiConfig | Add-Member -NotePropertyName 'advanced_ai' -NotePropertyValue $hydraConfig.advanced_ai.modules
        } else {
            $aiConfig.advanced_ai = $hydraConfig.advanced_ai.modules
        }
    }

    # Update fallback settings
    if ($hydraConfig.fallback_chain) {
        if (-not $aiConfig.settings) {
            $aiConfig | Add-Member -NotePropertyName 'settings' -NotePropertyValue @{}
        }
        $aiConfig.settings.autoFallback = $hydraConfig.fallback_chain.auto_fallback
        $aiConfig.settings.maxRetries = $hydraConfig.fallback_chain.max_retries
        $aiConfig.settings.retryDelayMs = $hydraConfig.fallback_chain.retry_delay_ms
    }

    if ($PSCmdlet.ShouldProcess($aiConfigPath, "Update AI config")) {
        $aiConfig | ConvertTo-Json -Depth 10 | Set-Content $aiConfigPath -Encoding UTF8
        Write-Host "[OK] AI Handler config updated" -ForegroundColor Green
    }
}

# === Summary ===
Write-Host "`n=== Sync Complete ===" -ForegroundColor Cyan
Write-Host @"

HYDRA $($hydraConfig.version) Configuration Applied:
  - Environment: $($hydraConfig.env.PSObject.Properties.Count) variables
  - Permissions: $($newPermissions.allow.Count) allow rules
  - MCP Servers: $($mcpServers.Count) servers
  - Hooks: UserPromptSubmit, Notification
  - Statusline: $($hydraConfig.statusline.enabled)
  - Advanced AI: $($hydraConfig.advanced_ai.modules.PSObject.Properties.Count) modules

Restart Claude Code to apply all changes.

"@ -ForegroundColor White

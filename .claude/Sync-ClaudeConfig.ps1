<#
.SYNOPSIS
    Synchronizacja konfiguracji Claude CLI między lokalnym projektem a globalnym katalogiem.

.DESCRIPTION
    Skrypt pozwala na synchronizację konfiguracji w obu kierunkach:
    - Local -> Global: Kopiuje konfigurację z projektu do ~/.claude
    - Global -> Local: Kopiuje konfigurację z ~/.claude do projektu

.PARAMETER Direction
    Kierunek synchronizacji: ToGlobal lub ToLocal

.PARAMETER Force
    Wymusza nadpisanie bez pytania

.EXAMPLE
    .\Sync-ClaudeConfig.ps1 -Direction ToGlobal
    .\Sync-ClaudeConfig.ps1 -Direction ToLocal -Force
#>

param(
    [Parameter(Mandatory = $true)]
    [ValidateSet("ToGlobal", "ToLocal")]
    [string]$Direction,
    
    [switch]$Force
)

$ErrorActionPreference = "Stop"

# Paths
$LocalPath = "C:\Users\BIURODOM\Desktop\ClaudeHYDRA\.claude"
$GlobalPath = "$env:USERPROFILE\.claude"
$DesktopPath = "$env:APPDATA\Claude"

# Files to sync
$ConfigFiles = @(
    "settings.local.json",
    "statusline.js"
)

$Directories = @(
    "commands",
    "hooks", 
    "skills"
)

function Write-ColorOutput {
    param([string]$Message, [string]$Color = "White")
    Write-Host $Message -ForegroundColor $Color
}

function Sync-ToGlobal {
    Write-ColorOutput "`n=== Synchronizing Local -> Global ===" "Cyan"
    
    # Sync settings.local.json to global settings.json
    $localSettings = Join-Path $LocalPath "settings.local.json"
    $globalSettings = Join-Path $GlobalPath "settings.json"
    
    if (Test-Path $localSettings) {
        Write-ColorOutput "  [SYNC] settings.local.json -> settings.json" "Yellow"
        Copy-Item -Path $localSettings -Destination $globalSettings -Force
    }
    
    # Sync statusline.js
    $localStatusline = Join-Path $LocalPath "statusline.js"
    $globalStatusline = Join-Path $GlobalPath "statusline.js"
    
    if (Test-Path $localStatusline) {
        Write-ColorOutput "  [SYNC] statusline.js" "Yellow"
        Copy-Item -Path $localStatusline -Destination $globalStatusline -Force
    }
    
    # Sync directories
    foreach ($dir in $Directories) {
        $localDir = Join-Path $LocalPath $dir
        $globalDir = Join-Path $GlobalPath $dir
        
        if (Test-Path $localDir) {
            Write-ColorOutput "  [SYNC] $dir/" "Yellow"
            if (-not (Test-Path $globalDir)) {
                New-Item -ItemType Directory -Path $globalDir -Force | Out-Null
            }
            Copy-Item -Path "$localDir\*" -Destination $globalDir -Recurse -Force
        }
    }
    
    Write-ColorOutput "`n[OK] Synchronization complete!" "Green"
}

function Sync-ToLocal {
    Write-ColorOutput "`n=== Synchronizing Global -> Local ===" "Cyan"
    
    # Backup current local config
    $backupDir = Join-Path $LocalPath "config-backup"
    if (-not (Test-Path $backupDir)) {
        New-Item -ItemType Directory -Path $backupDir -Force | Out-Null
    }
    
    $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
    
    # Sync global settings.json to local
    $globalSettings = Join-Path $GlobalPath "settings.json"
    $localSettings = Join-Path $LocalPath "settings.local.json"
    
    if (Test-Path $globalSettings) {
        # Backup current local
        if (Test-Path $localSettings) {
            $backupFile = Join-Path $backupDir "settings.local-$timestamp.json"
            Copy-Item -Path $localSettings -Destination $backupFile
            Write-ColorOutput "  [BACKUP] settings.local.json -> $backupFile" "DarkGray"
        }
        
        Write-ColorOutput "  [SYNC] settings.json -> settings.local.json" "Yellow"
        Copy-Item -Path $globalSettings -Destination $localSettings -Force
    }
    
    # Sync statusline.js
    $globalStatusline = Join-Path $GlobalPath "statusline.js"
    $localStatusline = Join-Path $LocalPath "statusline.js"
    
    if (Test-Path $globalStatusline) {
        Write-ColorOutput "  [SYNC] statusline.js" "Yellow"
        Copy-Item -Path $globalStatusline -Destination $localStatusline -Force
    }
    
    # Sync Claude Desktop config
    $desktopConfig = Join-Path $DesktopPath "claude_desktop_config.json"
    $localDesktopConfig = Join-Path $backupDir "claude-desktop-config.json"
    
    if (Test-Path $desktopConfig) {
        Write-ColorOutput "  [SYNC] claude_desktop_config.json" "Yellow"
        Copy-Item -Path $desktopConfig -Destination $localDesktopConfig -Force
    }
    
    Write-ColorOutput "`n[OK] Synchronization complete!" "Green"
}

# Main
Write-ColorOutput @"

  Claude Config Sync
  ==================
  Local:   $LocalPath
  Global:  $GlobalPath
  Desktop: $DesktopPath
  
"@ "Cyan"

if (-not $Force) {
    $confirm = Read-Host "Sync direction: $Direction. Continue? (Y/N)"
    if ($confirm -ne "Y" -and $confirm -ne "y") {
        Write-ColorOutput "Cancelled." "Red"
        exit 0
    }
}

switch ($Direction) {
    "ToGlobal" { Sync-ToGlobal }
    "ToLocal"  { Sync-ToLocal }
}

Write-ColorOutput "`nDone!`n" "Green"

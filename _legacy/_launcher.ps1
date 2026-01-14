<#
.SYNOPSIS
    HYDRA LAUNCHER v5.1 (Stable Witcher Edition)
    Orchestrates Gemini CLI with advanced telemetry, parallelism, and self-maintenance.
    FIX: Removed UTF-8 Emojis to prevent parsing errors in older PowerShell versions.

.PARAMETER Turbo
    Enables Turbo Mode (Parallel Processing Pre-warm).
.PARAMETER Theme
    Sets the UI Color Scheme. Options: 'Geralt' (Default), 'Yennefer', 'Triss'.
#> 
[CmdletBinding()]
Param(
    [switch]$Turbo,
    [ValidateSet('Geralt', 'Yennefer', 'Triss')]
    [string]$Theme = 'Geralt'
)

# ═══════════════════════════════════════════════════════════════════════════════
# CONFIGURATION & CONSTANTS
# ═══════════════════════════════════════════════════════════════════════════════
$ErrorActionPreference = "Stop"
# Force correct encoding for output
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$script:ProjectRoot = if ($PSScriptRoot) { $PSScriptRoot } else { Get-Location }
$env:GEMINI_HOME = Join-Path $script:ProjectRoot '.gemini'
$env:HYDRA_LOGS = Join-Path $script:ProjectRoot 'logs'

# --- 1. FUNKCJE POMOCNICZE (Witcher Signs) ---

function Write-Log ($Message, $Color="Gray", $NoNewLine=$false) {
    Write-Host ($Message) -ForegroundColor $Color -NoNewline:$NoNewLine
}

function Invoke-GitUpdate {
    # [FEATURE 1] Auto-Updater
    if (Test-Path (Join-Path $script:ProjectRoot ".git")) {
        Write-Log "[GIT] Sprawdzam aktualizacje w cechu... " "DarkGray" $true
        try {
            $gitOutput = git pull 2>&1 | Out-String
            if ($gitOutput -match "Already up to date") {
                Write-Log "[AKTUALNY]" "Green"
            } elseif ($gitOutput -match "error|fatal|conflict|unstaged") {
                Write-Log "[POMINIETO]" "DarkGray"
            } else {
                Write-Log "[ZAKTUALIZOWANO]" "Yellow"
                Write-Log "`n[!] Wymagany restart." "Yellow"
                Start-Sleep 2
            }
        } catch {
            Write-Log "[OFFLINE]" "DarkGray"
        }
    }
}

function Set-HydraTheme {
    # [FEATURE 3] Theme Switcher
    param([string]$Name)
    try {
        switch ($Name) {
            'Yennefer' { 
                $Host.UI.RawUI.BackgroundColor = "Black"; $Host.UI.RawUI.ForegroundColor = "Magenta" 
                $env:HYDRA_THEME_ACCENT = "Magenta"
            }
            'Triss' { 
                $Host.UI.RawUI.BackgroundColor = "Black"; $Host.UI.RawUI.ForegroundColor = "DarkRed" 
                $env:HYDRA_THEME_ACCENT = "Gold"
            }
            Default { 
                $Host.UI.RawUI.BackgroundColor = "Black"; $Host.UI.RawUI.ForegroundColor = "Gray" 
                $env:HYDRA_THEME_ACCENT = "Cyan"
            }
        }
        Clear-Host
    } catch { 
        # Ignoruj bledy w terminalach bez obslugi kolorow
    }
}

function Show-HydraHistory {
    # [FEATURE 10] Session History
    $histFile = Join-Path $env:GEMINI_HOME "cache\success_history.json"
    if (Test-Path $histFile) {
        try {
            $history = Get-Content $histFile -Raw | ConvertFrom-Json
            if ($history) {
                Write-Log "`n[HISTORIA] Ostatnie zlecenia:" $env:HYDRA_THEME_ACCENT
                $history | Select-Object -Last 3 | ForEach-Object {
                    Write-Log "   * $($_.timestamp): $($_.prompt)" "DarkGray"
                }
                Write-Log ""
            }
        } catch {}
    }
}

function Write-CrashLog {
    # [FEATURE 5] Telemetry
    param($Exception)
    if (-not (Test-Path $env:HYDRA_LOGS)) { New-Item -ItemType Directory -Path $env:HYDRA_LOGS -Force | Out-Null }
    
    $crashFile = Join-Path $env:HYDRA_LOGS "crash_report_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"
    $logContent = @"
TIMESTAMP: $(Get-Date)
ERROR: $($Exception.Message)
STACK TRACE:
$($Exception.ScriptStackTrace)
USER: $env:USERNAME
MODE: Turbo=$Turbo | Theme=$Theme
"@
    Set-Content -Path $crashFile -Value $logContent
    Write-Log "`n[!] CRITICAL ERROR ZAPISANY W KRONIKACH: $crashFile" "Red"
}

function Invoke-HydraCleanup {
    # [FEATURE 8] Auto-Cleanup
    Write-Log "`n[CLEANUP] Sprzatam po walce..." "DarkGray"
    
    # 1. Kill Status Monitor
    Get-Process | Where-Object { $_.MainWindowTitle -like "*HYDRA Monitor*" } | Stop-Process -Force -ErrorAction SilentlyContinue
    
    # 2. Clear Temp Vars
    Remove-Item env:\HYDRA_* -ErrorAction SilentlyContinue
    
    Write-Log " [CZYSTO]" "Green"
}

function Initialize-HydraEnv {
    # Ladowanie .env
    $envFile = Join-Path $script:ProjectRoot '.env'
    if (Test-Path $envFile) {
        Get-Content $envFile | Where-Object { $_ -match '=' -and $_ -notmatch '^\s*#' } | ForEach-Object { # Fixed regex to ignore lines starting with whitespace and then '#'
            $k,$v = $_.split('=',2)
            [Environment]::SetEnvironmentVariable($k.Trim(), $v.Trim().Trim('"').Trim("'"), 'Process')
        }
    }
    
    # [FEATURE 9] Turbo Mode Logic
    if ($Turbo) {
        $env:HYDRA_TURBO_MODE = '1'
        Write-Log "[TURBO] Mode: Aktywny. Eliksiry wypite." "Red"
    }

    # Import modulu
    $modPath = Join-Path $script:ProjectRoot 'modules\HYDRA-Interactive.psm1'
    if (Test-Path $modPath) { Import-Module $modPath -Force -Global -ErrorAction Stop } # Changed from "SilentlyContinue" to "Stop" to ensure module import failures are caught.
    
    # Auto-Resume
    $resumeFile = Join-Path $env:GEMINI_HOME "resume.flag"
    if (Test-Path $resumeFile) {
        Write-Log "`n[RESUME] Wznawianie przerwanej medytacji..." "Yellow"
        Remove-Item $resumeFile -Force -ErrorAction SilentlyContinue
    }
}

# --- 2. GLOWNA PETLA (The Path) ---

try {
    Set-HydraTheme -Name $Theme
    Invoke-GitUpdate

    Write-Log "`n[HYDRA] CLI v5.1 (Grandmaster Safe)" $env:HYDRA_THEME_ACCENT
    Write-Log " | " "DarkGray"
    Write-Log "Theme: $Theme" "DarkGray"
    
    Initialize-HydraEnv
    Show-HydraHistory
    
    # Neural Core Check (Fast)
    $ollamaUrl = "http://localhost:11434"
    try { $null = Invoke-WebRequest -Uri $ollamaUrl -Method Head -TimeoutSec 1 -ErrorAction Stop } 
    catch { 
        Write-Log "`n[OLLAMA] Spi. Budze bestie..." "Yellow" # Added a newline for better readability
        $ollamaPath = "$env:LOCALAPPDATA\Programs\Ollama\ollama.exe"
        if (Test-Path $ollamaPath) {
            Start-Process -FilePath $ollamaPath -ArgumentList "serve" -WindowStyle Hidden
            Start-Sleep 2 
        } else {
            Write-Log "`n[OLLAMA] Nie znaleziono pliku wykonywalnego!" "Red"
        }
    }

    # Status Monitor
    $mon = Join-Path $script:ProjectRoot 'Start-StatusMonitor.ps1'
    if ((Test-Path $mon) -and -not (Get-Process | Where-Object MainWindowTitle -like "*HYDRA Monitor*")) {
        Start-Process powershell -ArgumentList "-NoExit", "-File", "`"$mon`"" -WindowStyle Normal
    }

    # Initialize AI Handler (ensure commands are loaded)
    $aiInit = Join-Path $script:ProjectRoot 'ai-handler\Initialize-AIHandler.ps1'
    if (Test-Path $aiInit) {
        . $aiInit -Quiet -SkipAdvanced
    }

    # --- INTERACTIVE LOOP ---
    Write-Log "`n[READY] Gotowy do walki. (Ctrl+C to exit)" "Green"
    
    if (Get-Command "Start-HydraChat" -ErrorAction SilentlyContinue) {
        Start-HydraChat
    } elseif (Get-Command "Invoke-AI" -ErrorAction SilentlyContinue) {
        # Fallback REPL
        while ($true) {
            Write-Host "`n[HYDRA::$Theme] " -NoNewline -ForegroundColor $env:HYDRA_THEME_ACCENT
            $in = Read-Host
            if ($in -in 'exit','quit') { break }
            if ($in) { Invoke-AI -Prompt $in }
        }
    } else {
        # Minimal Fallback if modules fail
        Write-Host "`n[ERROR] Modul HydraChat niezaladowany. Sprawdz sciezki." -ForegroundColor Red
    }

} catch {
    # [FEATURE 5] Log error before dying
    $msg = $_.Exception.Message
    Write-Log "`n[FATAL] $msg" "Red"
    Write-CrashLog -Exception $_
    Start-Sleep 5
} finally {
    # [FEATURE 8] Cleanup regardless of exit reason
    Invoke-HydraCleanup
}
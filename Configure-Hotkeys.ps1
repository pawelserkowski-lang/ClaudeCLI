#Requires -Version 5.1
#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Configure keyboard shortcuts for ClaudeHYDRA
.DESCRIPTION
    1. Disables Win+C (Cortana/Copilot) in Windows
    2. Configures Escape as alternative interrupt in PowerShell
.NOTES
    Author: HYDRA System
    Requires: Administrator privileges
#>

param(
    [switch]$DisableWinC,
    [switch]$EnableEscapeInterrupt,
    [switch]$Revert,
    [switch]$All
)

$ErrorActionPreference = "Stop"

function Write-Status {
    param([string]$Message, [string]$Status = "INFO", [string]$Color = "White")
    $icon = switch ($Status) {
        "OK" { "[OK]"; $Color = "Green" }
        "WARN" { "[!!]"; $Color = "Yellow" }
        "ERR" { "[XX]"; $Color = "Red" }
        "INFO" { "[--]"; $Color = "Cyan" }
        default { "[--]" }
    }
    Write-Host "$icon " -NoNewline -ForegroundColor $Color
    Write-Host $Message
}

function Disable-WinCHotkey {
    <#
    .SYNOPSIS
        Disables Win+C hotkey in Windows via Registry
    #>
    Write-Host "`n=== Disabling Win+C Hotkey ===" -ForegroundColor Cyan

    $regPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"
    $regName = "DisabledHotkeys"

    try {
        # Get current disabled hotkeys
        $current = Get-ItemProperty -Path $regPath -Name $regName -ErrorAction SilentlyContinue

        if ($current -and $current.DisabledHotkeys -match "C") {
            Write-Status "Win+C already disabled" "OK"
            return
        }

        # Add 'C' to disabled hotkeys
        $newValue = if ($current) { $current.DisabledHotkeys + "C" } else { "C" }

        Set-ItemProperty -Path $regPath -Name $regName -Value $newValue -Type String
        Write-Status "Win+C disabled in registry" "OK"
        Write-Status "Restart Explorer or log out to apply" "WARN"

        # Offer to restart Explorer
        $restart = Read-Host "Restart Explorer now? (y/N)"
        if ($restart -eq "y") {
            Stop-Process -Name explorer -Force
            Start-Sleep -Seconds 2
            Start-Process explorer
            Write-Status "Explorer restarted" "OK"
        }

    } catch {
        Write-Status "Failed to disable Win+C: $_" "ERR"
    }
}

function Enable-WinCHotkey {
    <#
    .SYNOPSIS
        Re-enables Win+C hotkey
    #>
    Write-Host "`n=== Re-enabling Win+C Hotkey ===" -ForegroundColor Cyan

    $regPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"
    $regName = "DisabledHotkeys"

    try {
        $current = Get-ItemProperty -Path $regPath -Name $regName -ErrorAction SilentlyContinue

        if (-not $current -or -not ($current.DisabledHotkeys -match "C")) {
            Write-Status "Win+C is not disabled" "INFO"
            return
        }

        # Remove 'C' from disabled hotkeys
        $newValue = $current.DisabledHotkeys -replace "C", ""

        if ($newValue -eq "") {
            Remove-ItemProperty -Path $regPath -Name $regName -ErrorAction SilentlyContinue
        } else {
            Set-ItemProperty -Path $regPath -Name $regName -Value $newValue -Type String
        }

        Write-Status "Win+C re-enabled" "OK"
        Write-Status "Restart Explorer or log out to apply" "WARN"

    } catch {
        Write-Status "Failed to enable Win+C: $_" "ERR"
    }
}

function Install-EscapeInterrupt {
    <#
    .SYNOPSIS
        Configures Escape as interrupt key in PowerShell profile
    #>
    Write-Host "`n=== Configuring Escape as Interrupt ===" -ForegroundColor Cyan

    $profilePath = $PROFILE.CurrentUserAllHosts
    $profileDir = Split-Path $profilePath -Parent

    # Ensure profile directory exists
    if (-not (Test-Path $profileDir)) {
        New-Item -ItemType Directory -Path $profileDir -Force | Out-Null
    }

    $escapeHandler = @'

# === ClaudeHYDRA: Escape as Interrupt ===
# Pressing Escape sends Ctrl+C signal
Set-PSReadLineKeyHandler -Key Escape -Function CancelLine

# Double-Escape to send actual interrupt (like Ctrl+C)
$script:lastEscapeTime = [DateTime]::MinValue
Set-PSReadLineKeyHandler -Key Escape -ScriptBlock {
    $now = [DateTime]::Now
    $timeSinceLastEscape = ($now - $script:lastEscapeTime).TotalMilliseconds

    if ($timeSinceLastEscape -lt 500) {
        # Double-Escape: Send Ctrl+C interrupt
        [Microsoft.PowerShell.PSConsoleReadLine]::CancelLine()
        [Console]::TreatControlCAsInput = $false
        # Simulate Ctrl+C
        $host.UI.RawUI.FlushInputBuffer()
        throw "UserInterrupt"
    } else {
        # Single Escape: Cancel current line
        [Microsoft.PowerShell.PSConsoleReadLine]::CancelLine()
    }

    $script:lastEscapeTime = $now
}
# === End ClaudeHYDRA Escape Handler ===

'@

    try {
        # Check if already installed
        if (Test-Path $profilePath) {
            $content = Get-Content $profilePath -Raw -ErrorAction SilentlyContinue
            if ($content -match "ClaudeHYDRA: Escape as Interrupt") {
                Write-Status "Escape interrupt already configured" "OK"
                return
            }
        }

        # Append to profile
        Add-Content -Path $profilePath -Value $escapeHandler
        Write-Status "Escape interrupt added to PowerShell profile" "OK"
        Write-Status "Profile: $profilePath" "INFO"
        Write-Status "Reload PowerShell to apply" "WARN"

    } catch {
        Write-Status "Failed to configure Escape: $_" "ERR"
    }
}

function Remove-EscapeInterrupt {
    <#
    .SYNOPSIS
        Removes Escape interrupt handler from profile
    #>
    Write-Host "`n=== Removing Escape Interrupt ===" -ForegroundColor Cyan

    $profilePath = $PROFILE.CurrentUserAllHosts

    if (-not (Test-Path $profilePath)) {
        Write-Status "No PowerShell profile found" "INFO"
        return
    }

    try {
        $content = Get-Content $profilePath -Raw

        if (-not ($content -match "ClaudeHYDRA: Escape as Interrupt")) {
            Write-Status "Escape interrupt not configured" "INFO"
            return
        }

        # Remove the block
        $pattern = "(?s)# === ClaudeHYDRA: Escape as Interrupt ===.*?# === End ClaudeHYDRA Escape Handler ===\r?\n?"
        $newContent = $content -replace $pattern, ""

        Set-Content -Path $profilePath -Value $newContent.TrimEnd()
        Write-Status "Escape interrupt removed" "OK"

    } catch {
        Write-Status "Failed to remove Escape handler: $_" "ERR"
    }
}

# === Main Execution ===

Write-Host ""
Write-Host "============================================" -ForegroundColor Cyan
Write-Host "    HYDRA - Keyboard Configuration         " -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan

if ($All -or ($DisableWinC -and $EnableEscapeInterrupt)) {
    Disable-WinCHotkey
    Install-EscapeInterrupt
} elseif ($Revert) {
    Enable-WinCHotkey
    Remove-EscapeInterrupt
} elseif ($DisableWinC) {
    Disable-WinCHotkey
} elseif ($EnableEscapeInterrupt) {
    Install-EscapeInterrupt
} else {
    # Interactive mode
    Write-Host "`nOptions:" -ForegroundColor Yellow
    Write-Host "  1. Disable Win+C (free it from Cortana/Copilot)"
    Write-Host "  2. Enable Escape as interrupt (double-Escape = Ctrl+C)"
    Write-Host "  3. Both (recommended)"
    Write-Host "  4. Revert all changes"
    Write-Host "  5. Exit"
    Write-Host ""

    $choice = Read-Host "Select option (1-5)"

    switch ($choice) {
        "1" { Disable-WinCHotkey }
        "2" { Install-EscapeInterrupt }
        "3" { Disable-WinCHotkey; Install-EscapeInterrupt }
        "4" { Enable-WinCHotkey; Remove-EscapeInterrupt }
        "5" { Write-Host "Cancelled" -ForegroundColor Yellow; exit }
        default { Write-Host "Invalid option" -ForegroundColor Red; exit 1 }
    }
}

Write-Host "`n=== Summary ===" -ForegroundColor Cyan
Write-Host "  Win+C: Check registry HKCU:\...\Explorer\Advanced\DisabledHotkeys"
Write-Host "  Escape: Check `$PROFILE.CurrentUserAllHosts"
Write-Host ""

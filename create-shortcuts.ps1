# HYDRA 10.0 - Shortcut Creator
# Creates desktop shortcuts for ClaudeCLI
# Path: C:\Users\BIURODOM\Desktop\ClaudeCLI\create-shortcuts.ps1

#Requires -Version 5.1

# Error handling zgodnie z Protocols (CLAUDE.md sekcja 6)
$ErrorActionPreference = "Stop"

# Absolute paths zgodnie z Best Practices (CLAUDE.md sekcja 7)
$ProjectRoot = "C:\Users\BIURODOM\Desktop\ClaudeCLI"
$DesktopPath = [Environment]::GetFolderPath("Desktop")

function Write-ColorLog {
    param([string]$Message, [string]$Color = "White")
    Write-Host $Message -ForegroundColor $Color
}

try {
    Write-Host ""
    Write-ColorLog "============================================" "Cyan"
    Write-ColorLog "    HYDRA 10.0 - Shortcut Creator          " "Cyan"
    Write-ColorLog "============================================" "Cyan"
    Write-Host ""

    $WS = New-Object -ComObject WScript.Shell

    # Claude CLI shortcut
    Write-ColorLog "Creating Claude CLI shortcut..." "Cyan"

    $shortcutPath = Join-Path $DesktopPath "Claude CLI.lnk"
    $SC = $WS.CreateShortcut($shortcutPath)
    $SC.TargetPath = Join-Path $ProjectRoot "ClaudeCLI.vbs"
    $SC.WorkingDirectory = $ProjectRoot
    $SC.IconLocation = Join-Path $ProjectRoot "icon.ico,0"
    $SC.Description = "HYDRA 10.0 - ClaudeCLI Maximum Autonomy Mode"
    $SC.Save()

    Write-ColorLog "  [OK] Shortcut created: $shortcutPath" "Green"
    Write-Host ""
    Write-ColorLog "Desktop shortcut successfully created!" "Green"
    Write-Host ""

} catch {
    Write-Host ""
    Write-ColorLog "ERROR: $($_.Exception.Message)" "Red"
    Write-ColorLog "Stack Trace: $($_.ScriptStackTrace)" "Gray"
    Write-Host ""
    exit 1
}

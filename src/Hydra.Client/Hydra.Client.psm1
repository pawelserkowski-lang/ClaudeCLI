#Requires -Version 5.1

$script:ModuleRoot = $PSScriptRoot

# Import UI Components
Import-Module (Join-Path $script:ModuleRoot "GUI-Utils.psm1") -Force -Global
Import-Module (Join-Path $script:ModuleRoot "ConsoleUI.psm1") -Force -Global
Import-Module (Join-Path $script:ModuleRoot "HYDRA-GUI.psm1") -Force -Global
Import-Module (Join-Path $script:ModuleRoot "HYDRA-Interactive.psm1") -Force -Global

# Import Core (Parent Directory -> Hydra.Core)
$corePath = Join-Path (Split-Path $script:ModuleRoot -Parent) "Hydra.Core\Hydra.Core.psd1"
if (Test-Path $corePath) {
    Import-Module $corePath -Force -Global
} else {
    Write-Warning "Hydra.Core not found at $corePath"
}

function Start-HydraChat {
    <#
    .SYNOPSIS
        Starts the interactive Hydra Chat session.
    #>
    [CmdletBinding()]
    param()

    # Initialize
    Clear-Host
    try {
        Show-AnimatedLogo -Logo "hydra" -Speed 10
    } catch {
        Write-Host "HYDRA CLI" -ForegroundColor Cyan
    }
    
    $status = Initialize-AISystem
    if ($status.Status -ne "Initialized" -and $status.Status -ne "AlreadyLoaded") {
        Write-Host "AI System Failed to Initialize" -ForegroundColor Red
        return
    }

    if (Get-Command Show-StatusBadge -ErrorAction SilentlyContinue) {
        Show-StatusBadge -Text "Hydra Ready" -Status success
    } else {
        Write-Host "[READY]" -ForegroundColor Green
    }
    
    Write-Host ""
    if (Get-Command Show-QuickActions -ErrorAction SilentlyContinue) {
        Show-QuickActions
    }

    # Main Loop
    while ($true) {
        # Custom Read-Host with prompt
        Write-Host "`n┌─ " -NoNewline -ForegroundColor DarkCyan
        Write-Host "USER" -NoNewline -ForegroundColor Cyan
        Write-Host " ──────────────────────────────────────────────────" -ForegroundColor DarkCyan
        
        $input = Read-Host "└─>"
        
        if ([string]::IsNullOrWhiteSpace($input)) { continue }
        
        # Commands
        switch ($input.ToLower()) {
            "/exit" { return }
            "/quit" { return }
            "/clear" { Clear-Host; if (Get-Command Show-QuickActions -ErrorAction SilentlyContinue) { Show-QuickActions }; continue }
            "/history" { if (Get-Command Show-HistoryBrowser -ErrorAction SilentlyContinue) { Show-HistoryBrowser }; continue }
            "/settings" { if (Get-Command Show-SettingsTUI -ErrorAction SilentlyContinue) { Show-SettingsTUI }; continue }
            "/help" { 
                Write-Host "Commands: /exit, /clear, /history, /settings, /help" -ForegroundColor Yellow
                continue 
            }
        }

        # AI Processing
        try {
            Write-Host "`n┌─ " -NoNewline -ForegroundColor DarkMagenta
            Write-Host "HYDRA" -NoNewline -ForegroundColor Magenta
            Write-Host " ─────────────────────────────────────────────────" -ForegroundColor DarkMagenta
            Write-Host "│" -ForegroundColor DarkMagenta

            if (Get-Command Show-ThinkingIndicator -ErrorAction SilentlyContinue) {
                # Show-ThinkingIndicator -DurationMs 1000
            }

            $response = Invoke-AI -Prompt $input -Mode auto
            
            # Extract content
            $content = if ($response.content) { $response.content } else { $response }
            if ($response.Response.content) { $content = $response.Response.content } # Handle parallel wrapper if applicable

            # Display
            if ($content -is [string]) {
                $lines = $content -split "`n"
                foreach ($line in $lines) {
                    Write-Host "│ " -NoNewline -ForegroundColor DarkMagenta
                    
                    # Basic markdown highlighting (very basic)
                    if ($line -match '^```') {
                        Write-Host $line -ForegroundColor Yellow
                    } elseif ($line -match '^#') {
                        Write-Host $line -ForegroundColor Cyan
                    } else {
                        Write-Host $line -ForegroundColor White
                    }
                }
            } else {
                Write-Host "│ " -NoNewline -ForegroundColor DarkMagenta
                Write-Host ($content | Out-String) -ForegroundColor White
            }
            
            Write-Host "└──────────────────────────────────────────────────────" -ForegroundColor DarkMagenta
            
            # History
            if (Get-Command Add-ToHistory -ErrorAction SilentlyContinue) {
                Add-ToHistory -Command $input -Result "success"
            }

        } catch {
            Write-Host "`n[ERROR] $($_.Exception.Message)" -ForegroundColor Red
            if (Get-Command Add-ToHistory -ErrorAction SilentlyContinue) {
                Add-ToHistory -Command $input -Result "error"
            }
        }
    }
}

Export-ModuleMember -Function Start-HydraChat
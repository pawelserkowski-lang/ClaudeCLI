<#
.SYNOPSIS
    HYDRA LAUNCHER v10.1
    Initializes the ClaudeCLI environment with Maximum Autonomy and AI Orchestration.
#>

$ErrorActionPreference = "Stop"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

# Set project root
$script:Root = $PSScriptRoot
$env:CLAUDECLI_ROOT = $script:Root

# === UTILITIES ===
function Write-Banner {
    Clear-Host
    Write-Host @"
 _   ___   ______  ____   ___
| | | \ \ / /  _ \|  _ \ / \ \
| |_| |\ V /| | | | |_) / _ \ \
|  _  | | | | |_| |  _ / ___ \ \
|_| |_| |_| |____/|_| /_/   \_\_\

HYDRA 10.1 - Maximum Autonomy Mode
Three Heads, One Goal. Hydra Executes In Parallel.
"@ -ForegroundColor Cyan
}

function Check-Requirements {
    Write-Host "Checking requirements..." -ForegroundColor Gray

    # Check PowerShell version
    if ($PSVersionTable.PSVersion.Major -lt 7) {
        Write-Host "[WARN] PowerShell 7+ recommended for full parallel features." -ForegroundColor Yellow
    }

    # Check Environment Variables
    if (-not $env:ANTHROPIC_API_KEY) {
        Write-Host "[WARN] ANTHROPIC_API_KEY not set. Cloud features will fail." -ForegroundColor Yellow
    }
}

# === AI HANDLER ===
function Initialize-AI {
    Write-Host "Initializing AI Handler..." -ForegroundColor Gray
    $aiInit = Join-Path $script:Root "ai-handler\Initialize-AIHandler.ps1"

    if (Test-Path $aiInit) {
        . $aiInit -Quiet
        # Initialize-AIHandler.ps1 loads AIFacade globally
    } else {
        Write-Host "[ERROR] AI Handler init script not found at $aiInit" -ForegroundColor Red
    }
}

# === STARTUP SEQUENCE ===
try {
    Write-Banner
    Check-Requirements
    Initialize-AI

    Write-Host "`n[READY] System initialized." -ForegroundColor Green
    Write-Host "Type 'ai <query>' to use the AI assistant." -ForegroundColor Gray
    Write-Host "Type 'exit' to quit." -ForegroundColor Gray

    # Enter interactive mode if not run from another script
    if ($MyInvocation.InvocationName -notmatch "\\.") {
        # Being dot-sourced, do nothing
    } else {
        # Running directly
        # Optional: Start Hydra Interactive Mode if available
        # Or just exit and let user type commands
    }
}
catch {
    Write-Host "[FATAL] Startup failed: $_" -ForegroundColor Red
    exit 1
}

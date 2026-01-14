<#
.SYNOPSIS
    Initialize AI Handler and integrate with existing systems
.DESCRIPTION
    Sets up the AI System via AIFacade module which manages all AI modules
    in the correct loading order to prevent circular dependencies.
    Provides integration with the api-usage-tracker for unified usage tracking.
.PARAMETER SkipAdvanced
    Skip loading advanced AI modules (SelfCorrection, FewShot, Speculative, etc.)
    Use this for faster startup when advanced features are not needed.
.PARAMETER Force
    Force reinitialization even if system is already loaded.
.PARAMETER Quiet
    Suppress banner and detailed output. Only show errors.
.EXAMPLE
    . .\Initialize-AIHandler.ps1
    # Full initialization with all modules
.EXAMPLE
    . .\Initialize-AIHandler.ps1 -SkipAdvanced
    # Quick initialization without advanced AI modules
.EXAMPLE
    . .\Initialize-AIHandler.ps1 -Force -Quiet
    # Force reload with minimal output
#>

[CmdletBinding()]
param(
    [Parameter()]
    [switch]$SkipAdvanced,

    [Parameter()]
    [switch]$Force,

    [Parameter()]
    [switch]$Quiet
)

$ErrorActionPreference = "Stop"
$script:AIHandlerRoot = $PSScriptRoot

# Show banner unless quiet mode
if (-not $Quiet) {
    $advancedNote = if ($SkipAdvanced) { " (Core Only)" } else { "" }
    Write-Host @"

  +=================================================================+
  |     AI MODEL HANDLER v2.0 - Modular Architecture$advancedNote               |
  +=================================================================+
  |  Features:                                                      |
  |    - Phased module loading (prevents circular dependencies)     |
  |    - Auto-retry with model downgrade (Opus->Sonnet->Haiku)      |
  |    - Rate limit aware switching                                 |
  |    - Cost optimizer for model selection                         |
  |    - Multi-provider fallback (Anthropic->OpenAI->Ollama)        |
  +=================================================================+

"@ -ForegroundColor Cyan
}

# Import the AIFacade module (entry point for entire AI system)
$facadePath = Join-Path $script:AIHandlerRoot "AIFacade.psm1"
if (Test-Path $facadePath) {
    Import-Module $facadePath -Force -Global
    if (-not $Quiet) {
        Write-Host "[OK] AIFacade module loaded" -ForegroundColor Green
    }
} else {
    Write-Host "[ERROR] AIFacade module not found: $facadePath" -ForegroundColor Red
    Write-Host "        Falling back to legacy AIModelHandler..." -ForegroundColor Yellow

    # Fallback to legacy module if facade doesn't exist
    $legacyPath = Join-Path $script:AIHandlerRoot "AIModelHandler.psm1"
    if (Test-Path $legacyPath) {
        Import-Module $legacyPath -Force -Global
        Initialize-AIState | Out-Null
        Write-Host "[OK] Legacy AIModelHandler loaded" -ForegroundColor Green
    } else {
        Write-Host "[ERROR] No AI module found!" -ForegroundColor Red
        return
    }
}

# Initialize the AI system using the facade
$initParams = @{}
if ($Force) { $initParams.Force = $true }
if ($SkipAdvanced) { $initParams.SkipAdvanced = $true }

$initResult = Initialize-AISystem @initParams

if (-not $Quiet) {
    if ($initResult.Status -eq "Initialized" -or $initResult.Status -eq "AlreadyLoaded") {
        Write-Host "[OK] AI System initialized ($($initResult.TotalLoaded) modules loaded)" -ForegroundColor Green

        if ($initResult.TotalFailed -gt 0) {
            Write-Host "[!]  $($initResult.TotalFailed) optional module(s) failed to load" -ForegroundColor Yellow
        }
    } else {
        Write-Host "[ERROR] AI System initialization failed" -ForegroundColor Red
        return
    }
}

# Get detailed system status
$systemStatus = Get-AISystemStatus -CheckProviders

# Display provider status
if (-not $Quiet) {
    Write-Host "`nProvider Status:" -ForegroundColor Cyan

    # Ollama (local)
    if ($systemStatus.ProviderStatus.Ollama.Available) {
        $modelCount = $systemStatus.ProviderStatus.Ollama.Models.Count
        Write-Host "[OK] Ollama (local) - $modelCount model(s) available" -ForegroundColor Green
    } else {
        Write-Host "[--] Ollama (local) - not running" -ForegroundColor Yellow
    }

    # Anthropic
    if ($systemStatus.ProviderStatus.Anthropic.Available) {
        Write-Host "[OK] Anthropic (cloud) - API key configured" -ForegroundColor Green
    } else {
        Write-Host "[--] Anthropic (cloud) - ANTHROPIC_API_KEY not set" -ForegroundColor Yellow
    }

    # OpenAI
    if ($systemStatus.ProviderStatus.OpenAI.Available) {
        Write-Host "[OK] OpenAI (cloud) - API key configured" -ForegroundColor Green
    } else {
        Write-Host "[--] OpenAI (cloud) - OPENAI_API_KEY not set" -ForegroundColor Yellow
    }

    # Count available providers
    $availableCount = 0
    if ($systemStatus.ProviderStatus.Ollama.Available) { $availableCount++ }
    if ($systemStatus.ProviderStatus.Anthropic.Available) { $availableCount++ }
    if ($systemStatus.ProviderStatus.OpenAI.Available) { $availableCount++ }

    if ($availableCount -eq 0) {
        Write-Host "`n[WARNING] No providers available!" -ForegroundColor Red
        Write-Host "          - Start Ollama for local inference" -ForegroundColor Yellow
        Write-Host "          - Or set ANTHROPIC_API_KEY for cloud" -ForegroundColor Yellow
    } else {
        Write-Host "`n[READY] $availableCount provider(s) available" -ForegroundColor Cyan
    }
}

# Create convenience aliases
Set-Alias -Name ai -Value (Join-Path $script:AIHandlerRoot "Invoke-AI.ps1") -Scope Global -Force
Set-Alias -Name aistat -Value "Get-AIStatus" -Scope Global -Force
Set-Alias -Name aihealth -Value (Join-Path $script:AIHandlerRoot "Invoke-AIHealth.ps1") -Scope Global -Force
Set-Alias -Name aisys -Value "Get-AISystemStatus" -Scope Global -Force

if (-not $Quiet) {
    Write-Host @"

Quick Commands:
  Get-AISystemStatus    - View loaded modules and provider status
  Get-AIStatus          - View rate limits and usage
  Get-AIHealth          - Health dashboard (status, tokens, cost)
  Test-AIProviders      - Test connectivity to all providers
  Invoke-AI             - Unified AI request (auto mode selection)
  Invoke-AIRequest      - Direct AI request with auto-fallback
  Reset-AISystem        - Reset and reload all modules

"@ -ForegroundColor Gray

    # Show advanced module commands if loaded
    if (-not $SkipAdvanced -and $systemStatus.Categories.Advanced -gt 0) {
        Write-Host "Advanced AI Commands:" -ForegroundColor Cyan
        Write-Host @"
  Invoke-AdvancedAI     - Unified advanced AI interface
  New-AICode            - Code generation with self-correction
  Get-AIQuick           - Fastest response (model racing)
  Get-AIAnalysis        - Analysis with speculative decoding
  Invoke-SemanticQuery  - Query with file context (Deep RAG)

"@ -ForegroundColor Gray
    }

    Write-Host @"
Invoke-AI Examples:
  Invoke-AI "Hello"                           # Auto mode
  Invoke-AI "Write code" -Mode code           # Code with validation
  Invoke-AI "Quick question" -Mode fast       # Fastest response
  Invoke-AI "Explain X" -Mode analysis        # Thorough analysis

"@ -ForegroundColor Gray
}

# Integration with existing api-usage-tracker (legacy support)
$trackerPath = Join-Path (Split-Path $script:AIHandlerRoot) "api-usage-tracker.ps1"
if (Test-Path $trackerPath) {
    if (-not $Quiet) {
        Write-Host "[OK] Legacy api-usage-tracker.ps1 found - compatible mode enabled" -ForegroundColor Green
    }

    # Create unified logging function
    function global:Log-AIUsage {
        param(
            [int]$InputTokens,
            [int]$OutputTokens,
            [string]$Model,
            [string]$Provider = "anthropic",
            [string]$Operation = "chat"
        )

        # Log to new system (if function exists)
        $updateCmd = Get-Command "Update-UsageTracking" -ErrorAction SilentlyContinue
        if ($updateCmd) {
            Update-UsageTracking -Provider $Provider -Model $Model `
                -InputTokens $InputTokens -OutputTokens $OutputTokens
        }

        # Log to legacy system
        & $trackerPath -Command log -InputTokens $InputTokens `
            -OutputTokens $OutputTokens -Model $Model -Operation $Operation
    }

    if (-not $Quiet) {
        Write-Host "[OK] Unified Log-AIUsage function created" -ForegroundColor Green
    }
}

if (-not $Quiet) {
    # Show initialization summary
    $duration = if ($initResult.Duration) { "$([math]::Round($initResult.Duration, 2))s" } else { "cached" }
    Write-Host "`n[INIT] Complete in $duration | Modules: $($initResult.TotalLoaded) | Advanced: $(if ($SkipAdvanced) { 'Skipped' } else { 'Loaded' })" -ForegroundColor DarkGray
    Write-Host ""
}

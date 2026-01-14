#Requires -Version 5.1
<#
.SYNOPSIS
    AI Facade - Unified Entry Point for Hydra AI System
    Implements Dependency Injection and Phased Loading.
#>

$script:AIHandlerRoot = $PSScriptRoot

# ============================================================================
# PHASED LOADING SYSTEM
# ============================================================================

function Initialize-AISystem {
    [CmdletBinding()]
    param(
        [switch]$Force,
        [switch]$SkipAdvanced
    )

    $loadedCount = 0
    $failedCount = 0
    $status = "Initialized"
    $sw = [System.Diagnostics.Stopwatch]::StartNew()

    if ($global:HydraAI_Initialized -and -not $Force) {
        return @{ Status = "AlreadyLoaded"; Duration = 0; TotalLoaded = $global:HydraAI_Modules.Count }
    }

    $global:HydraAI_Modules = @{}

    # === Phase 1: Utilities (No Dependencies) ===
    $utils = @("AIUtil-JsonIO", "AIUtil-Health", "AIUtil-Validation", "AIErrorHandler")
    foreach ($mod in $utils) {
        if (Import-AIModule -Name $mod -Category "utils") { $loadedCount++ } else { $failedCount++ }
    }

    # === Phase 2: Core (Depends on Utils) ===
    $core = @("AIConstants", "AIConfig", "AIState")
    foreach ($mod in $core) {
        if (Import-AIModule -Name $mod -Category "core") { $loadedCount++ } else { $failedCount++ }
    }

    # === Phase 3: Infrastructure ===
    $infra = @("RateLimiter", "ModelSelector")
    if (Import-AIModule -Name "RateLimiter" -Category "rate-limiting") { $loadedCount++ }
    if (Import-AIModule -Name "ModelSelector" -Category "model-selection") { $loadedCount++ }

    # === Phase 4: Providers ===
    $providers = @("OllamaProvider", "AnthropicProvider", "OpenAIProvider")
    foreach ($mod in $providers) {
        if (Import-AIModule -Name $mod -Category "providers") { $loadedCount++ } else { $failedCount++ }
    }

    # === Phase 5: Fallback ===
    $fallback = @("ProviderFallback", "ApiKeyRotation")
    foreach ($mod in $fallback) {
        if (Import-AIModule -Name $mod -Category "fallback") { $loadedCount++ } else { $failedCount++ }
    }

    # === Phase 6: Legacy/Main Handler ===
    # We load AIModelHandler (formerly AIOrchestrator) to provide the implementation for Invoke-AIRequest
    if (Import-AIModule -Name "AIModelHandler" -Category ".") { $loadedCount++ } else { $failedCount++ }

    # === Phase 7: Advanced Modules (Optional) ===
    if (-not $SkipAdvanced) {
        $advanced = @(
            "SelfCorrection", "FewShotLearning", "SpeculativeDecoding",
            "LoadBalancer", "SemanticFileMapping", "AdvancedAI",
            "PromptOptimizer", "ContextOptimizer", "ModelDiscovery",
            "ErrorLogger", "SecureStorage"
        )
        foreach ($mod in $advanced) {
            if (Import-AIModule -Name $mod -Category "modules") { $loadedCount++ } else { $failedCount++ }
        }
    }

    $global:HydraAI_Initialized = $true
    $sw.Stop()

    return @{
        Status = $status
        Duration = $sw.Elapsed.TotalSeconds
        TotalLoaded = $loadedCount
        TotalFailed = $failedCount
    }
}

function Import-AIModule {
    param($Name, $Category)

    try {
        $path = if ($Category -eq ".") {
            Join-Path $script:AIHandlerRoot "$Name.psm1"
        } else {
            Join-Path $script:AIHandlerRoot "$Category\$Name.psm1"
        }

        if (Test-Path $path) {
            Import-Module $path -Force -Global -ErrorAction Stop
            $global:HydraAI_Modules[$Name] = $true
            # Write-Verbose "Loaded $Name from $Category"
            return $true
        } else {
            Write-Warning "Module not found: $path"
            return $false
        }
    }
    catch {
        Write-Error "Failed to load module $Name`: $_"
        return $false
    }
}

function Get-AISystemStatus {
    [CmdletBinding()]
    param(
        [switch]$Detailed,
        [switch]$CheckProviders
    )

    $status = @{
        Initialized = $global:HydraAI_Initialized
        ModulesLoaded = $global:HydraAI_Modules.Keys.Count
        Modules = $global:HydraAI_Modules
    }

    if ($CheckProviders) {
        $status.ProviderStatus = @{
            Ollama = if (Get-Command Test-OllamaAvailable -ErrorAction SilentlyContinue) { Test-OllamaAvailable -IncludeModels } else { @{ Available = $false } }
            Anthropic = if (Get-Command Test-AnthropicAvailable -ErrorAction SilentlyContinue) { Test-AnthropicAvailable } else { @{ Available = $false } }
            OpenAI = if (Get-Command Test-OpenAIAvailable -ErrorAction SilentlyContinue) { Test-OpenAIAvailable } else { @{ Available = $false } }
        }
    }

    # Count categories
    $categories = @{
        Utils = 0; Core = 0; Providers = 0; Advanced = 0
    }

    # Simple heuristic for counting (can be improved)
    $global:HydraAI_Modules.Keys | ForEach-Object {
        if ($_ -match "AIUtil") { $categories.Utils++ }
        elseif ($_ -match "AIConfig|AIState|AIConstants") { $categories.Core++ }
        elseif ($_ -match "Provider") { $categories.Providers++ }
        elseif ($_ -match "SelfCorrection|FewShot|Speculative|Advanced|LoadBalancer") { $categories.Advanced++ }
    }
    $status.Categories = $categories

    return $status
}

function Reset-AISystem {
    param([switch]$Reinitialize)
    $global:HydraAI_Initialized = $false
    $global:HydraAI_Modules = @{}

    # Remove modules from session (best effort)
    Get-Module | Where-Object { $_.Path -like "$script:AIHandlerRoot*" } | Remove-Module -Force -ErrorAction SilentlyContinue

    if ($Reinitialize) {
        Initialize-AISystem -Force
    }
}

# ============================================================================
# UNIFIED INTERFACE
# ============================================================================

function Invoke-AI {
    <#
    .SYNOPSIS
        Unified entry point for AI operations with mode selection.
    .DESCRIPTION
        Route requests to appropriate specialized functions based on -Mode.
    .PARAMETER Prompt
        The user query or task.
    .PARAMETER Mode
        auto: Detect intent (Default)
        fast: Model racing (Speculative Decoding)
        code: Self-Correction + Validation
        analysis: Deep analysis
        chat: Standard conversation
    #>
    [CmdletBinding(DefaultParameterSetName="Auto")]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [string]$Prompt,

        [Parameter()]
        [ValidateSet("auto", "fast", "code", "analysis", "chat", "consensus")]
        [string]$Mode = "auto",

        [Parameter()]
        [hashtable]$Options = @{}
    )

    if (-not $global:HydraAI_Initialized) {
        Initialize-AISystem
    }

    if ($Mode -eq "auto") {
        # Simple heuristic for mode detection
        if ($Prompt -match "write|implement|function|code|script") { $Mode = "code" }
        elseif ($Prompt -match "analyze|compare|evaluate|study") { $Mode = "analysis" }
        elseif ($Prompt -match "^(what|who|when|where|is) ") { $Mode = "fast" }
        else { $Mode = "chat" }

        Write-Verbose "Auto-detected mode: $Mode"
    }

    switch ($Mode) {
        "fast" {
            if (Get-Command Get-AIQuick -ErrorAction SilentlyContinue) {
                return Get-AIQuick -Prompt $Prompt
            } else {
                return Invoke-AIRequest -Messages @(@{role="user"; content=$Prompt}) -Model "llama3.2:1b"
            }
        }
        "code" {
            if (Get-Command New-AICode -ErrorAction SilentlyContinue) {
                return New-AICode -Prompt $Prompt
            } else {
                return Invoke-AIRequest -Messages @(@{role="user"; content=$Prompt}) -Task "code"
            }
        }
        "analysis" {
            if (Get-Command Get-AIAnalysis -ErrorAction SilentlyContinue) {
                return Get-AIAnalysis -Prompt $Prompt
            } else {
                return Invoke-AIRequest -Messages @(@{role="user"; content=$Prompt}) -Task "complex"
            }
        }
        "consensus" {
            if (Get-Command Invoke-ConsensusGeneration -ErrorAction SilentlyContinue) {
                return Invoke-ConsensusGeneration -Prompt $Prompt
            } else {
                Write-Warning "Consensus mode not available, falling back to chat"
                return Invoke-AIRequest -Messages @(@{role="user"; content=$Prompt})
            }
        }
        "chat" {
            return Invoke-AIRequest -Messages @(@{role="user"; content=$Prompt})
        }
    }
}

function Get-AIDependencies {
    param([string]$Category)
    # Helper to inspect loaded modules
    if ($Category) {
        return $global:HydraAI_Modules.Keys | Where-Object { $_ -like "*$Category*" }
    }
    return $global:HydraAI_Modules
}

# Export Functions
Export-ModuleMember -Function Initialize-AISystem, Get-AISystemStatus, Reset-AISystem, Invoke-AI, Get-AIDependencies

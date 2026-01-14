#Requires -Version 5.1
<#
.SYNOPSIS
    AI System Facade - Single entry point with dependency injection for HYDRA AI Handler.

.DESCRIPTION
    AIFacade.psm1 provides a unified interface for the entire AI Handler system.
    It manages module loading order to prevent circular dependencies and provides
    a dependency injection container for loose coupling between components.

    Loading Phases:
    - Phase 1: Utils (JSON I/O, Health checks, Validation)
    - Phase 2: Core (Constants, Configuration, State management)
    - Phase 3: Infrastructure (Rate limiting, Model selection)
    - Phase 4: Providers (Anthropic, OpenAI, Ollama)
    - Phase 5: Advanced modules (Self-correction, Few-shot, etc.)

.NOTES
    Module:     AIFacade
    Author:     HYDRA System
    Version:    1.0.0
    Requires:   PowerShell 5.1+
#>

# ============================================================================
# MODULE STATE
# ============================================================================

# Flag indicating whether modules have been loaded
$script:ModulesLoaded = $false

# Dependency injection container
$script:Dependencies = @{
    Utils          = @{}
    Core           = @{}
    Infrastructure = @{}
    Providers      = @{}
    Advanced       = @{}
    LoadedModules  = @()
    FailedModules  = @()
    InitTime       = $null
}

# Module base path
$script:ModuleBasePath = $PSScriptRoot

# ============================================================================
# PRIVATE HELPER FUNCTIONS
# ============================================================================

function Import-AIModule {
    <#
    .SYNOPSIS
        Safely imports a module with error handling.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path,

        [Parameter(Mandatory)]
        [string]$Name,

        [Parameter()]
        [string]$Category = "Unknown",

        [Parameter()]
        [switch]$Optional
    )

    $fullPath = Join-Path $script:ModuleBasePath $Path

    if (-not (Test-Path $fullPath)) {
        if ($Optional) {
            Write-Verbose "Optional module not found: $Name ($fullPath)"
            return $false
        }
        throw "Required module not found: $Name ($fullPath)"
    }

    try {
        Import-Module $fullPath -Force -Global -ErrorAction Stop
        $script:Dependencies.LoadedModules += $Name
        Write-Verbose "Loaded module: $Name"
        return $true
    }
    catch {
        if ($Optional) {
            $script:Dependencies.FailedModules += @{
                Name    = $Name
                Path    = $fullPath
                Error   = $_.Exception.Message
                Category = $Category
            }
            Write-Verbose "Failed to load optional module: $Name - $($_.Exception.Message)"
            return $false
        }
        throw "Failed to load required module: $Name - $($_.Exception.Message)"
    }
}

function Register-Dependency {
    <#
    .SYNOPSIS
        Registers a function or object in the dependency container.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Category,

        [Parameter(Mandatory)]
        [string]$Name,

        [Parameter(Mandatory)]
        $Value
    )

    if (-not $script:Dependencies.ContainsKey($Category)) {
        $script:Dependencies[$Category] = @{}
    }

    $script:Dependencies[$Category][$Name] = $Value
}

# ============================================================================
# PUBLIC FUNCTIONS
# ============================================================================

function Initialize-AISystem {
    <#
    .SYNOPSIS
        Initializes the AI system by loading all modules in correct order.

    .DESCRIPTION
        Loads all AI Handler modules in a specific order to prevent circular
        dependencies. Uses a phased approach:

        Phase 1: Utils - Basic utilities with no dependencies
        Phase 2: Core - Configuration and state management
        Phase 3: Infrastructure - Rate limiting, model selection
        Phase 4: Providers - API integrations
        Phase 5: Advanced - Optional advanced AI features

    .PARAMETER Force
        Forces reload of all modules even if already loaded.

    .PARAMETER SkipAdvanced
        Skips loading of advanced modules (Phase 5).

    .PARAMETER Verbose
        Shows detailed loading information.

    .EXAMPLE
        Initialize-AISystem
        # Loads all modules in correct order

    .EXAMPLE
        Initialize-AISystem -Force
        # Forces reload of all modules

    .EXAMPLE
        Initialize-AISystem -SkipAdvanced
        # Loads only core modules, skips advanced features

    .OUTPUTS
        [hashtable] Status of initialization including loaded and failed modules.
    #>
    [CmdletBinding()]
    param(
        [Parameter()]
        [switch]$Force,

        [Parameter()]
        [switch]$SkipAdvanced
    )

    # Check if already loaded
    if ($script:ModulesLoaded -and -not $Force) {
        Write-Verbose "AI System already initialized. Use -Force to reload."
        return @{
            Status        = "AlreadyLoaded"
            LoadedModules = $script:Dependencies.LoadedModules
            InitTime      = $script:Dependencies.InitTime
        }
    }

    # Reset state if forcing reload
    if ($Force) {
        $script:ModulesLoaded = $false
        $script:Dependencies = @{
            Utils          = @{}
            Core           = @{}
            Infrastructure = @{}
            Providers      = @{}
            Advanced       = @{}
            LoadedModules  = @()
            FailedModules  = @()
            InitTime       = $null
        }
    }

    $startTime = Get-Date
    $phaseResults = @{}

    Write-Verbose "Starting AI System initialization..."

    # ========================================================================
    # PHASE 1: UTILS (No dependencies)
    # ========================================================================
    Write-Verbose "Phase 1: Loading utility modules..."
    $phaseResults.Phase1 = @{ Success = @(); Failed = @() }

    $utilModules = @(
        @{ Path = "utils\AIUtil-JsonIO.psm1"; Name = "AIUtil-JsonIO" }
        @{ Path = "utils\AIUtil-Health.psm1"; Name = "AIUtil-Health" }
        @{ Path = "utils\AIUtil-Validation.psm1"; Name = "AIUtil-Validation" }
    )

    foreach ($mod in $utilModules) {
        try {
            if (Import-AIModule -Path $mod.Path -Name $mod.Name -Category "Utils" -Optional) {
                $phaseResults.Phase1.Success += $mod.Name

                # Register utility functions in container
                $exportedFunctions = (Get-Module $mod.Name).ExportedFunctions.Keys
                foreach ($func in $exportedFunctions) {
                    Register-Dependency -Category "Utils" -Name $func -Value (Get-Command $func -ErrorAction SilentlyContinue)
                }
            }
        }
        catch {
            $phaseResults.Phase1.Failed += @{ Name = $mod.Name; Error = $_.Exception.Message }
        }
    }

    # ========================================================================
    # PHASE 2: CORE (Depends on Utils)
    # ========================================================================
    Write-Verbose "Phase 2: Loading core modules..."
    $phaseResults.Phase2 = @{ Success = @(); Failed = @() }

    $coreModules = @(
        @{ Path = "core\AIConstants.psm1"; Name = "AIConstants" }
        @{ Path = "core\AIConfig.psm1"; Name = "AIConfig" }
        @{ Path = "core\AIState.psm1"; Name = "AIState" }
    )

    foreach ($mod in $coreModules) {
        try {
            if (Import-AIModule -Path $mod.Path -Name $mod.Name -Category "Core" -Optional) {
                $phaseResults.Phase2.Success += $mod.Name

                # Register core functions
                $exportedFunctions = (Get-Module $mod.Name).ExportedFunctions.Keys
                foreach ($func in $exportedFunctions) {
                    Register-Dependency -Category "Core" -Name $func -Value (Get-Command $func -ErrorAction SilentlyContinue)
                }
            }
        }
        catch {
            $phaseResults.Phase2.Failed += @{ Name = $mod.Name; Error = $_.Exception.Message }
        }
    }

    # ========================================================================
    # PHASE 3: INFRASTRUCTURE (Depends on Core)
    # ========================================================================
    Write-Verbose "Phase 3: Loading infrastructure modules..."
    $phaseResults.Phase3 = @{ Success = @(); Failed = @() }

    $infraModules = @(
        @{ Path = "rate-limiting\RateLimiter.psm1"; Name = "RateLimiter" }
        @{ Path = "model-selection\ModelSelector.psm1"; Name = "ModelSelector" }
        @{ Path = "modules\ErrorLogger.psm1"; Name = "ErrorLogger" }
        @{ Path = "modules\SecureStorage.psm1"; Name = "SecureStorage" }
    )

    foreach ($mod in $infraModules) {
        try {
            if (Import-AIModule -Path $mod.Path -Name $mod.Name -Category "Infrastructure" -Optional) {
                $phaseResults.Phase3.Success += $mod.Name

                # Register infrastructure functions
                $exportedFunctions = (Get-Module $mod.Name).ExportedFunctions.Keys
                foreach ($func in $exportedFunctions) {
                    Register-Dependency -Category "Infrastructure" -Name $func -Value (Get-Command $func -ErrorAction SilentlyContinue)
                }
            }
        }
        catch {
            $phaseResults.Phase3.Failed += @{ Name = $mod.Name; Error = $_.Exception.Message }
        }
    }

    # ========================================================================
    # PHASE 4: PROVIDERS (Depends on Infrastructure)
    # ========================================================================
    Write-Verbose "Phase 4: Loading provider modules..."
    $phaseResults.Phase4 = @{ Success = @(); Failed = @() }

    $providerModules = @(
        @{ Path = "providers\OllamaProvider.psm1"; Name = "OllamaProvider" }
        @{ Path = "providers\AnthropicProvider.psm1"; Name = "AnthropicProvider" }
        @{ Path = "providers\OpenAIProvider.psm1"; Name = "OpenAIProvider" }
    )

    foreach ($mod in $providerModules) {
        try {
            if (Import-AIModule -Path $mod.Path -Name $mod.Name -Category "Providers" -Optional) {
                $phaseResults.Phase4.Success += $mod.Name

                # Register provider functions
                $exportedFunctions = (Get-Module $mod.Name).ExportedFunctions.Keys
                foreach ($func in $exportedFunctions) {
                    Register-Dependency -Category "Providers" -Name $func -Value (Get-Command $func -ErrorAction SilentlyContinue)
                }
            }
        }
        catch {
            $phaseResults.Phase4.Failed += @{ Name = $mod.Name; Error = $_.Exception.Message }
        }
    }

    # ========================================================================
    # PHASE 4.5: FALLBACK MODULES (API Key Rotation, Provider Fallback)
    # ========================================================================
    Write-Verbose "Phase 4.5: Loading fallback modules..."
    $phaseResults.Phase45 = @{ Success = @(); Failed = @() }

    $fallbackModules = @(
        @{ Path = "fallback\ApiKeyRotation.psm1"; Name = "ApiKeyRotation" }
        @{ Path = "fallback\ProviderFallback.psm1"; Name = "ProviderFallback" }
    )

    foreach ($mod in $fallbackModules) {
        try {
            if (Import-AIModule -Path $mod.Path -Name $mod.Name -Category "Infrastructure" -Optional) {
                $phaseResults.Phase45.Success += $mod.Name

                # Register fallback functions
                $loadedMod = Get-Module $mod.Name -ErrorAction SilentlyContinue
                if ($loadedMod) {
                    foreach ($func in $loadedMod.ExportedFunctions.Keys) {
                        Register-Dependency -Category "Infrastructure" -Name $func -Value (Get-Command $func -ErrorAction SilentlyContinue)
                    }
                }
            }
        }
        catch {
            $phaseResults.Phase45.Failed += @{ Name = $mod.Name; Error = $_.Exception.Message }
            Write-Verbose "Fallback module $($mod.Name) failed to load: $($_.Exception.Message)"
        }
    }

    # ========================================================================
    # PHASE 5: ADVANCED MODULES (Optional, with try/catch)
    # ========================================================================
    if (-not $SkipAdvanced) {
        Write-Verbose "Phase 5: Loading advanced modules..."
        $phaseResults.Phase5 = @{ Success = @(); Failed = @() }

        $advancedModules = @(
            @{ Path = "modules\SelfCorrection.psm1"; Name = "SelfCorrection" }
            @{ Path = "modules\FewShotLearning.psm1"; Name = "FewShotLearning" }
            @{ Path = "modules\SpeculativeDecoding.psm1"; Name = "SpeculativeDecoding" }
            @{ Path = "modules\LoadBalancer.psm1"; Name = "LoadBalancer" }
            @{ Path = "modules\SemanticFileMapping.psm1"; Name = "SemanticFileMapping" }
            @{ Path = "modules\PromptOptimizer.psm1"; Name = "PromptOptimizer" }
            @{ Path = "modules\AdvancedAI.psm1"; Name = "AdvancedAI" }
            @{ Path = "modules\ModelDiscovery.psm1"; Name = "ModelDiscovery" }
            @{ Path = "modules\ContextOptimizer.psm1"; Name = "ContextOptimizer" }
        )

        foreach ($mod in $advancedModules) {
            try {
                if (Import-AIModule -Path $mod.Path -Name $mod.Name -Category "Advanced" -Optional) {
                    $phaseResults.Phase5.Success += $mod.Name

                    # Register advanced functions
                    $loadedMod = Get-Module $mod.Name -ErrorAction SilentlyContinue
                    if ($loadedMod) {
                        foreach ($func in $loadedMod.ExportedFunctions.Keys) {
                            Register-Dependency -Category "Advanced" -Name $func -Value (Get-Command $func -ErrorAction SilentlyContinue)
                        }
                    }
                }
            }
            catch {
                $phaseResults.Phase5.Failed += @{ Name = $mod.Name; Error = $_.Exception.Message }
                Write-Verbose "Optional module $($mod.Name) failed to load: $($_.Exception.Message)"
            }
        }
    }
    else {
        Write-Verbose "Phase 5: Skipped (SkipAdvanced flag set)"
        $phaseResults.Phase5 = @{ Success = @(); Failed = @(); Skipped = $true }
    }

    # ========================================================================
    # PHASE 6: ORCHESTRATION (The Core Logic)
    # ========================================================================
    Write-Verbose "Phase 6: Loading orchestration module..."
    $phaseResults.Phase6 = @{ Success = @(); Failed = @() }
    
    try {
        if (Import-AIModule -Path "AIOrchestrator.psm1" -Name "AIOrchestrator" -Category "Core") {
            $phaseResults.Phase6.Success += "AIOrchestrator"
            $script:Dependencies.LoadedModules += "AIOrchestrator"
            
            # Register orchestrator functions
            $orchMod = Get-Module "AIOrchestrator" -ErrorAction SilentlyContinue
            if ($orchMod) {
                foreach ($func in $orchMod.ExportedFunctions.Keys) {
                    Register-Dependency -Category "Core" -Name $func -Value (Get-Command $func -ErrorAction SilentlyContinue)
                }
            }
        }
    }
    catch {
        $phaseResults.Phase6.Failed += @{ Name = "AIOrchestrator"; Error = $_.Exception.Message }
        Write-Error "Failed to load AIOrchestrator: $($_.Exception.Message)"
    }

    # ========================================================================
    # FINALIZE
    # ========================================================================
    $endTime = Get-Date
    $script:Dependencies.InitTime = $endTime - $startTime
    $script:ModulesLoaded = $true

    # Build summary
    $summary = @{
        Status         = "Initialized"
        Duration       = $script:Dependencies.InitTime.TotalSeconds
        LoadedModules  = $script:Dependencies.LoadedModules
        FailedModules  = $script:Dependencies.FailedModules
        PhaseResults   = $phaseResults
        TotalLoaded    = $script:Dependencies.LoadedModules.Count
        TotalFailed    = $script:Dependencies.FailedModules.Count
    }

    Write-Verbose "AI System initialized in $($summary.Duration) seconds"
    Write-Verbose "Loaded: $($summary.TotalLoaded) modules, Failed: $($summary.TotalFailed) modules"

    return $summary
}

function Get-AIDependencies {
    <#
    .SYNOPSIS
        Returns the dependency injection container.

    .DESCRIPTION
        Provides access to the dependency container which holds references
        to all loaded modules, functions, and their relationships.

    .PARAMETER Category
        Optional. Filter dependencies by category (Utils, Core, Infrastructure, Providers, Advanced).

    .PARAMETER Name
        Optional. Get a specific dependency by name.

    .EXAMPLE
        Get-AIDependencies
        # Returns entire dependency container

    .EXAMPLE
        Get-AIDependencies -Category "Providers"
        # Returns only provider dependencies

    .EXAMPLE
        Get-AIDependencies -Category "Core" -Name "Invoke-AIRequest"
        # Returns specific function reference

    .OUTPUTS
        [hashtable] Dependency container or specific dependency.
    #>
    [CmdletBinding()]
    param(
        [Parameter()]
        [ValidateSet("Utils", "Core", "Infrastructure", "Providers", "Advanced")]
        [string]$Category,

        [Parameter()]
        [string]$Name
    )

    # Auto-initialize if not loaded
    if (-not $script:ModulesLoaded) {
        Write-Verbose "AI System not initialized. Initializing now..."
        Initialize-AISystem | Out-Null
    }

    if ($Category -and $Name) {
        if ($script:Dependencies.ContainsKey($Category) -and
            $script:Dependencies[$Category].ContainsKey($Name)) {
            return $script:Dependencies[$Category][$Name]
        }
        return $null
    }

    if ($Category) {
        if ($script:Dependencies.ContainsKey($Category)) {
            return $script:Dependencies[$Category]
        }
        return @{}
    }

    return $script:Dependencies
}

function Invoke-AI {
    <#
    .SYNOPSIS
        Unified AI invocation - single entry point for all AI requests.

    .DESCRIPTION
        Provides a simplified interface for AI requests. Automatically initializes
        the system if needed and delegates to the appropriate handler based on
        the specified mode.

        Modes:
        - auto: Automatic mode selection based on prompt analysis
        - simple: Direct API call via Invoke-AIRequest
        - code: Code generation with self-correction
        - analysis: Analysis with speculative decoding
        - fast: Model racing for fastest response
        - fewshot: Few-shot learning with historical examples
        - consensus: Multi-model consensus generation

    .PARAMETER Prompt
        The prompt or question to send to the AI.

    .PARAMETER Mode
        Processing mode. Default is 'auto' which analyzes the prompt to select optimal mode.

    .PARAMETER Model
        Specific model to use. If not specified, uses automatic model selection.

    .PARAMETER Provider
        Specific provider to use (ollama, anthropic, openai).

    .PARAMETER MaxTokens
        Maximum tokens for the response. Default is 2048.

    .PARAMETER Temperature
        Sampling temperature. Default is 0.7.

    .PARAMETER SystemPrompt
        Optional system prompt to prepend.

    .PARAMETER Stream
        Enable streaming response (if supported by provider).

    .PARAMETER Raw
        Return raw response without processing.

    .EXAMPLE
        Invoke-AI "What is the capital of France?"
        # Quick answer using auto mode

    .EXAMPLE
        Invoke-AI "Write a Python function to sort a list" -Mode code
        # Code generation with self-correction

    .EXAMPLE
        Invoke-AI "Compare REST vs GraphQL" -Mode analysis
        # Detailed analysis with speculative decoding

    .EXAMPLE
        Invoke-AI "2+2?" -Mode fast
        # Fastest response via model racing

    .OUTPUTS
        [string] or [hashtable] AI response, format depends on -Raw flag.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position = 0, ValueFromPipeline)]
        [string]$Prompt,

        [Parameter()]
        [ValidateSet("auto", "simple", "code", "analysis", "fast", "fewshot", "consensus")]
        [string]$Mode = "auto",

        [Parameter()]
        [string]$Model,

        [Parameter()]
        [ValidateSet("ollama", "anthropic", "openai")]
        [string]$Provider,

        [Parameter()]
        [int]$MaxTokens = 2048,

        [Parameter()]
        [double]$Temperature = 0.7,

        [Parameter()]
        [string]$SystemPrompt,

        [Parameter()]
        [switch]$Stream,

        [Parameter()]
        [switch]$Raw
    )

    # Auto-initialize if needed
    if (-not $script:ModulesLoaded) {
        Write-Verbose "AI System not initialized. Initializing now..."
        $initResult = Initialize-AISystem
        if ($initResult.Status -ne "Initialized" -and $initResult.Status -ne "AlreadyLoaded") {
            throw "Failed to initialize AI System: $($initResult | ConvertTo-Json -Compress)"
        }
    }

    # Build messages array
    $messages = @()
    if ($SystemPrompt) {
        $messages += @{ role = "system"; content = $SystemPrompt }
    }
    $messages += @{ role = "user"; content = $Prompt }

    # Check if advanced AI is available
    $hasAdvancedAI = Get-Command "Invoke-AdvancedAI" -ErrorAction SilentlyContinue
    $hasAIRequest = Get-Command "Invoke-AIRequest" -ErrorAction SilentlyContinue

    # Route based on mode
    switch ($Mode) {
        "auto" {
            if ($hasAdvancedAI) {
                $params = @{
                    Prompt    = $Prompt
                    Mode      = "auto"
                    MaxTokens = $MaxTokens
                }
                if ($Model) { $params.Model = $Model }
                return Invoke-AdvancedAI @params
            }
            elseif ($hasAIRequest) {
                $params = @{
                    Messages    = $messages
                    MaxTokens   = $MaxTokens
                    Temperature = $Temperature
                }
                if ($Model) { $params.Model = $Model }
                if ($Provider) { $params.Provider = $Provider }
                return Invoke-AIRequest @params
            }
            else {
                throw "No AI handler available. Ensure AIModelHandler or AdvancedAI is loaded."
            }
        }

        "simple" {
            if ($hasAIRequest) {
                $params = @{
                    Messages    = $messages
                    MaxTokens   = $MaxTokens
                    Temperature = $Temperature
                }
                if ($Model) { $params.Model = $Model }
                if ($Provider) { $params.Provider = $Provider }
                return Invoke-AIRequest @params
            }
            throw "Invoke-AIRequest not available"
        }

        "code" {
            $hasCodeFunc = Get-Command "Invoke-CodeWithSelfCorrection" -ErrorAction SilentlyContinue
            if ($hasCodeFunc) {
                return Invoke-CodeWithSelfCorrection -Prompt $Prompt -MaxTokens $MaxTokens
            }
            elseif ($hasAdvancedAI) {
                return Invoke-AdvancedAI -Prompt $Prompt -Mode code -MaxTokens $MaxTokens
            }
            throw "Code generation module not available"
        }

        "analysis" {
            $hasSpeculative = Get-Command "Invoke-SpeculativeDecoding" -ErrorAction SilentlyContinue
            if ($hasSpeculative) {
                return Invoke-SpeculativeDecoding -Prompt $Prompt -MaxTokens $MaxTokens
            }
            elseif ($hasAdvancedAI) {
                return Invoke-AdvancedAI -Prompt $Prompt -Mode analysis -MaxTokens $MaxTokens
            }
            throw "Analysis module not available"
        }

        "fast" {
            $hasRace = Get-Command "Invoke-ModelRace" -ErrorAction SilentlyContinue
            if ($hasRace) {
                return Invoke-ModelRace -Prompt $Prompt -MaxTokens $MaxTokens
            }
            elseif ($hasAdvancedAI) {
                return Invoke-AdvancedAI -Prompt $Prompt -Mode fast -MaxTokens $MaxTokens
            }
            throw "Fast mode (model racing) not available"
        }

        "fewshot" {
            $hasFewShot = Get-Command "Invoke-AIWithFewShot" -ErrorAction SilentlyContinue
            if ($hasFewShot) {
                $params = @{
                    Prompt    = $Prompt
                    MaxTokens = $MaxTokens
                }
                if ($Model) { $params.Model = $Model }
                return Invoke-AIWithFewShot @params
            }
            elseif ($hasAdvancedAI) {
                return Invoke-AdvancedAI -Prompt $Prompt -Mode fewshot -MaxTokens $MaxTokens
            }
            throw "Few-shot learning module not available"
        }

        "consensus" {
            $hasConsensus = Get-Command "Invoke-ConsensusGeneration" -ErrorAction SilentlyContinue
            if ($hasConsensus) {
                return Invoke-ConsensusGeneration -Prompt $Prompt -MaxTokens $MaxTokens
            }
            elseif ($hasAdvancedAI) {
                return Invoke-AdvancedAI -Prompt $Prompt -Mode consensus -MaxTokens $MaxTokens
            }
            throw "Consensus generation not available"
        }
    }
}

function Get-AISystemStatus {
    <#
    .SYNOPSIS
        Returns the status of all loaded AI modules.

    .DESCRIPTION
        Provides a comprehensive status report of the AI system including:
        - Initialization state
        - Loaded modules by category
        - Failed modules with error details
        - Available functions
        - Provider connectivity status

    .PARAMETER Detailed
        Include detailed information about each module.

    .PARAMETER CheckProviders
        Test connectivity to AI providers.

    .EXAMPLE
        Get-AISystemStatus
        # Returns basic status

    .EXAMPLE
        Get-AISystemStatus -Detailed -CheckProviders
        # Returns detailed status with provider connectivity tests

    .OUTPUTS
        [hashtable] System status information.
    #>
    [CmdletBinding()]
    param(
        [Parameter()]
        [switch]$Detailed,

        [Parameter()]
        [switch]$CheckProviders
    )

    $status = @{
        Initialized    = $script:ModulesLoaded
        InitTime       = $script:Dependencies.InitTime
        LoadedModules  = $script:Dependencies.LoadedModules
        FailedModules  = $script:Dependencies.FailedModules
        TotalLoaded    = $script:Dependencies.LoadedModules.Count
        TotalFailed    = $script:Dependencies.FailedModules.Count
        Categories     = @{
            Utils          = $script:Dependencies.Utils.Keys.Count
            Core           = $script:Dependencies.Core.Keys.Count
            Infrastructure = $script:Dependencies.Infrastructure.Keys.Count
            Providers      = $script:Dependencies.Providers.Keys.Count
            Advanced       = $script:Dependencies.Advanced.Keys.Count
        }
    }

    if ($Detailed) {
        $status.FunctionsByCategory = @{
            Utils          = @($script:Dependencies.Utils.Keys)
            Core           = @($script:Dependencies.Core.Keys)
            Infrastructure = @($script:Dependencies.Infrastructure.Keys)
            Providers      = @($script:Dependencies.Providers.Keys)
            Advanced       = @($script:Dependencies.Advanced.Keys)
        }

        $status.ModuleBasePath = $script:ModuleBasePath
    }

    if ($CheckProviders) {
        $status.ProviderStatus = @{}

        # Check Ollama
        try {
            $ollamaTest = Invoke-RestMethod -Uri "http://localhost:11434/api/tags" -Method Get -TimeoutSec 5 -ErrorAction Stop
            $status.ProviderStatus.Ollama = @{
                Available = $true
                Models    = @($ollamaTest.models | ForEach-Object { $_.name })
            }
        }
        catch {
            $status.ProviderStatus.Ollama = @{
                Available = $false
                Error     = $_.Exception.Message
            }
        }

        # Check Anthropic
        $status.ProviderStatus.Anthropic = @{
            Available = (-not [string]::IsNullOrEmpty($env:ANTHROPIC_API_KEY))
            KeySet    = (-not [string]::IsNullOrEmpty($env:ANTHROPIC_API_KEY))
        }

        # Check OpenAI
        $status.ProviderStatus.OpenAI = @{
            Available = (-not [string]::IsNullOrEmpty($env:OPENAI_API_KEY))
            KeySet    = (-not [string]::IsNullOrEmpty($env:OPENAI_API_KEY))
        }
    }

    return $status
}

function Reset-AISystem {
    <#
    .SYNOPSIS
        Resets the AI system state and forces reinitialization.

    .DESCRIPTION
        Clears all loaded modules and dependency registrations,
        then optionally reinitializes the system.

    .PARAMETER Reinitialize
        Automatically reinitialize after reset.

    .EXAMPLE
        Reset-AISystem
        # Resets state without reinitialization

    .EXAMPLE
        Reset-AISystem -Reinitialize
        # Resets and immediately reinitializes

    .OUTPUTS
        [hashtable] Reset status.
    #>
    [CmdletBinding()]
    param(
        [Parameter()]
        [switch]$Reinitialize
    )

    Write-Verbose "Resetting AI System..."

    # Remove loaded modules
    foreach ($modName in $script:Dependencies.LoadedModules) {
        try {
            Remove-Module $modName -Force -ErrorAction SilentlyContinue
        }
        catch {
            Write-Verbose "Could not remove module: $modName"
        }
    }

    # Reset state
    $script:ModulesLoaded = $false
    $script:Dependencies = @{
        Utils          = @{}
        Core           = @{}
        Infrastructure = @{}
        Providers      = @{}
        Advanced       = @{}
        LoadedModules  = @()
        FailedModules  = @()
        InitTime       = $null
    }

    $result = @{
        Status = "Reset"
        Time   = Get-Date
    }

    if ($Reinitialize) {
        $result.Reinitialization = Initialize-AISystem
    }

    return $result
}

# ============================================================================
# MODULE EXPORTS
# ============================================================================

Export-ModuleMember -Function @(
    'Initialize-AISystem',
    'Get-AIDependencies',
    'Invoke-AI',
    'Get-AISystemStatus',
    'Reset-AISystem',
    
    # Orchestrator Functions
    'Invoke-AIRequest',
    'Invoke-AIRequestParallel',
    'Invoke-AIBatch',
    'Get-AIStatus',
    'Get-AIHealth',
    'Test-AIProviders',
    'Sync-AIModels',
    'Get-DiscoveredModels',
    'Get-ModelInfo',
    'Get-LocalModels'
)

# ============================================================================
# MODULE INITIALIZATION MESSAGE
# ============================================================================

Write-Verbose "Hydra Core module loaded. Use Initialize-AISystem to load all AI modules."

#Requires -Version 5.1
<#
.SYNOPSIS
    Model Selection Module for AI Handler - Intelligent model selection with fallback support
.DESCRIPTION
    Provides intelligent model selection based on task requirements, cost optimization,
    and automatic fallback chains. Features include:
    - Task-based model tier mapping
    - Cost-aware model selection
    - Automatic fallback chains (same-provider and cross-provider)
    - Capability matching
    - Rate limit awareness
.VERSION
    1.0.0
.AUTHOR
    HYDRA System
.NOTES
    Part of the ClaudeCLI AI Handler system
#>

# Module paths
$script:ModuleRoot = Split-Path $PSScriptRoot -Parent
$script:ConfigPath = Join-Path $script:ModuleRoot "ai-config.json"
$script:StatePath = Join-Path $script:ModuleRoot "ai-state.json"

#region Task Tier Mapping

# Maps task types to preferred model tiers (in priority order)
$script:TaskTierMap = @{
    "simple"   = @("lite", "standard", "pro")      # Simple tasks prefer cheaper models
    "code"     = @("standard", "lite", "pro")      # Code tasks need decent quality
    "analysis" = @("standard", "pro", "lite")      # Analysis benefits from standard tier
    "complex"  = @("pro", "standard")              # Complex tasks need top tier
    "creative" = @("pro", "standard")              # Creative tasks benefit from pro
    "vision"   = @("pro", "standard")              # Vision requires capable models
}

#endregion

#region Helper Functions

function ConvertTo-Hashtable {
    <#
    .SYNOPSIS
        Converts PSCustomObject to Hashtable recursively
    #>
    param([Parameter(ValueFromPipeline)]$InputObject)
    process {
        if ($null -eq $InputObject) { return $null }
        if ($InputObject -is [System.Collections.IEnumerable] -and $InputObject -isnot [string]) {
            $collection = @(foreach ($item in $InputObject) { ConvertTo-Hashtable $item })
            return $collection
        }
        if ($InputObject -is [PSObject]) {
            $hash = @{}
            foreach ($prop in $InputObject.PSObject.Properties) {
                $hash[$prop.Name] = ConvertTo-Hashtable $prop.Value
            }
            return $hash
        }
        return $InputObject
    }
}

function Get-AIConfig {
    <#
    .SYNOPSIS
        Loads AI configuration from config file
    .DESCRIPTION
        Reads the ai-config.json file and returns it as a hashtable.
        Returns default configuration if file is not found or invalid.
    #>
    [CmdletBinding()]
    param()

    if (Test-Path $script:ConfigPath) {
        try {
            $config = Get-Content $script:ConfigPath -Raw | ConvertFrom-Json | ConvertTo-Hashtable
            return $config
        } catch {
            Write-Warning "[ModelSelector] Failed to load config: $_"
        }
    }

    # Return minimal default config
    return @{
        settings = @{
            costOptimization = $true
            rateLimitThreshold = 0.85
            outputTokenRatio = 0.5
        }
        providerFallbackOrder = @("ollama", "anthropic", "openai")
        providers = @{}
        fallbackChain = @{}
    }
}

function Get-AIState {
    <#
    .SYNOPSIS
        Loads AI runtime state from state file
    #>
    [CmdletBinding()]
    param()

    if (Test-Path $script:StatePath) {
        try {
            return Get-Content $script:StatePath -Raw | ConvertFrom-Json | ConvertTo-Hashtable
        } catch {
            Write-Warning "[ModelSelector] Failed to load state"
        }
    }

    return @{ usage = @{} }
}

function Get-RateLimitStatus {
    <#
    .SYNOPSIS
        Gets the rate limit status for a specific provider/model combination
    .PARAMETER Provider
        The provider name (anthropic, openai, ollama, etc.)
    .PARAMETER Model
        The model identifier
    .OUTPUTS
        Hashtable with: available (bool), tokensPercent, requestsPercent, tokensRemaining, requestsRemaining
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Provider,

        [Parameter(Mandatory)]
        [string]$Model
    )

    $config = Get-AIConfig
    $state = Get-AIState

    # Check if provider/model exists in config
    if (-not $config.providers -or -not $config.providers[$Provider]) {
        return @{ available = $false; reason = "Provider not found" }
    }

    $modelConfig = $config.providers[$Provider].models[$Model]
    if (-not $modelConfig) {
        return @{ available = $false; reason = "Model not found" }
    }

    # Check usage state
    $usage = $null
    if ($state.usage -and $state.usage[$Provider]) {
        $usage = $state.usage[$Provider][$Model]
    }

    if (-not $usage) {
        return @{ available = $true; tokensPercent = 0; requestsPercent = 0 }
    }

    # Check if minute has reset
    $now = Get-Date
    try {
        $lastReset = [DateTime]::Parse($usage.lastMinuteReset)
        if (($now - $lastReset).TotalMinutes -ge 1) {
            return @{ available = $true; tokensPercent = 0; requestsPercent = 0 }
        }
    } catch {
        return @{ available = $true; tokensPercent = 0; requestsPercent = 0 }
    }

    # Calculate usage percentages
    $tokensPercent = if ($modelConfig.tokensPerMinute -gt 0) {
        ($usage.tokensThisMinute / $modelConfig.tokensPerMinute) * 100
    } else { 0 }

    $requestsPercent = if ($modelConfig.requestsPerMinute -gt 0) {
        ($usage.requestsThisMinute / $modelConfig.requestsPerMinute) * 100
    } else { 0 }

    $threshold = $config.settings.rateLimitThreshold * 100

    return @{
        available = ($tokensPercent -lt $threshold) -and ($requestsPercent -lt $threshold)
        tokensPercent = [math]::Round($tokensPercent, 1)
        requestsPercent = [math]::Round($requestsPercent, 1)
        tokensRemaining = $modelConfig.tokensPerMinute - $usage.tokensThisMinute
        requestsRemaining = $modelConfig.requestsPerMinute - $usage.requestsThisMinute
        threshold = $threshold
    }
}

#endregion

#region Model Selection Functions

function Get-OptimalModel {
    <#
    .SYNOPSIS
        Selects the optimal model based on task requirements and constraints
    .DESCRIPTION
        Analyzes available models across all configured providers and selects
        the best match based on task type, token estimates, required capabilities,
        and cost preferences. Respects rate limits and API key availability.
    .PARAMETER Task
        Type of task: "simple", "complex", "creative", "code", "vision", "analysis"
    .PARAMETER EstimatedTokens
        Estimated input tokens for cost calculation (default: 1000)
    .PARAMETER EstimatedOutputTokens
        Estimated output tokens. If 0, calculated from outputTokenRatio setting
    .PARAMETER RequiredCapabilities
        Array of required capabilities (e.g., "vision", "function_calling")
    .PARAMETER PreferCheapest
        Force selection of cheapest suitable model regardless of tier preference
    .PARAMETER PreferredProvider
        Preferred provider to prioritize in selection (default: "anthropic")
    .OUTPUTS
        Hashtable with: provider, model, tier, cost, tierScore, tierPreference, providerPreference, rateStatus
        Returns $null if no suitable model is available
    .EXAMPLE
        Get-OptimalModel -Task "code" -EstimatedTokens 2000
        # Selects best model for code generation with ~2000 input tokens
    .EXAMPLE
        Get-OptimalModel -Task "simple" -PreferCheapest
        # Selects cheapest available model for simple task
    .EXAMPLE
        Get-OptimalModel -Task "vision" -RequiredCapabilities @("vision")
        # Selects model with vision capability
    #>
    [CmdletBinding()]
    param(
        [ValidateSet("simple", "complex", "creative", "code", "vision", "analysis")]
        [string]$Task = "simple",

        [ValidateRange(1, [int]::MaxValue)]
        [int]$EstimatedTokens = 1000,

        [ValidateRange(0, [int]::MaxValue)]
        [int]$EstimatedOutputTokens = 0,

        [string[]]$RequiredCapabilities = @(),

        [switch]$PreferCheapest,

        [string]$PreferredProvider = "anthropic"
    )

    $config = Get-AIConfig
    $candidates = @()

    # Get preferred tiers for this task
    $preferredTiers = $script:TaskTierMap[$Task]
    if (-not $preferredTiers) {
        $preferredTiers = @("standard", "lite", "pro")
    }

    # Build candidate list from all providers
    foreach ($providerName in $config.providerFallbackOrder) {
        $provider = $config.providers[$providerName]
        if (-not $provider -or -not $provider.enabled) { continue }

        # Check API key availability
        if ($provider.apiKeyEnv -and -not [Environment]::GetEnvironmentVariable($provider.apiKeyEnv)) {
            continue
        }

        if (-not $provider.models) { continue }

        foreach ($modelName in $provider.models.Keys) {
            $model = $provider.models[$modelName]

            # Skip embedding, image, and non-chat models
            if ($modelName -match 'embedding|imagen|tts|whisper|dall-e|moderation') {
                continue
            }

            # Check capabilities
            $hasCapabilities = $true
            foreach ($cap in $RequiredCapabilities) {
                if ($model.capabilities -and $cap -notin $model.capabilities) {
                    $hasCapabilities = $false
                    break
                }
            }
            if (-not $hasCapabilities) { continue }

            # Check rate limits
            $rateStatus = Get-RateLimitStatus -Provider $providerName -Model $modelName
            if (-not $rateStatus.available) { continue }

            # Calculate estimated cost
            $outputTokens = if ($EstimatedOutputTokens -gt 0) {
                $EstimatedOutputTokens
            } else {
                [math]::Round($EstimatedTokens * $config.settings.outputTokenRatio)
            }

            $inputCost = if ($model.inputCost) { $model.inputCost } else { 0 }
            $outputCost = if ($model.outputCost) { $model.outputCost } else { 0 }

            $estimatedCost = ($EstimatedTokens / 1000000) * $inputCost +
                            ($outputTokens / 1000000) * $outputCost

            # Calculate tier score
            $tierScore = switch ($model.tier) {
                "pro" { 3 }
                "standard" { 2 }
                "lite" { 1 }
                default { 1 }
            }

            # Calculate tier preference (lower is better)
            $tierPreference = $preferredTiers.IndexOf($model.tier)
            if ($tierPreference -eq -1) { $tierPreference = 99 }

            # Calculate provider preference (lower is better)
            $providerPreference = $config.providerFallbackOrder.IndexOf($providerName)
            if ($providerName -eq $PreferredProvider) {
                $providerPreference = -1
            }

            $candidates += @{
                provider = $providerName
                model = $modelName
                tier = $model.tier
                cost = $estimatedCost
                tierScore = $tierScore
                tierPreference = $tierPreference
                providerPreference = $providerPreference
                rateStatus = $rateStatus
            }
        }
    }

    if ($candidates.Count -eq 0) {
        Write-Warning "[ModelSelector] No suitable models available"
        return $null
    }

    # Sort candidates based on preference
    if ($PreferCheapest -or $config.settings.costOptimization) {
        $sorted = $candidates | Sort-Object cost, tierPreference, providerPreference
    } else {
        $sorted = $candidates | Sort-Object tierPreference, providerPreference, cost
    }

    $selected = $sorted[0]

    Write-Host "[ModelSelector] Selected: $($selected.provider)/$($selected.model) " -NoNewline -ForegroundColor Cyan
    Write-Host "(tier: $($selected.tier), est. cost: `$$([math]::Round($selected.cost, 4)))" -ForegroundColor Gray

    return $selected
}

function Get-FallbackModel {
    <#
    .SYNOPSIS
        Gets the next fallback model in the chain
    .DESCRIPTION
        When a model fails or hits rate limits, this function returns the next
        model in the fallback chain. Can stay within the same provider or
        switch to a different provider if CrossProvider is specified.
    .PARAMETER CurrentProvider
        The current provider name
    .PARAMETER CurrentModel
        The current model identifier
    .PARAMETER CrossProvider
        If specified, allows switching to a different provider when current
        provider's fallback chain is exhausted
    .OUTPUTS
        Hashtable with: provider, model
        Returns $null if no fallback is available
    .EXAMPLE
        Get-FallbackModel -CurrentProvider "anthropic" -CurrentModel "claude-sonnet-4-5-20250929"
        # Gets next model in Anthropic's fallback chain
    .EXAMPLE
        Get-FallbackModel -CurrentProvider "anthropic" -CurrentModel "claude-3-5-haiku-latest" -CrossProvider
        # Tries other providers if Anthropic chain is exhausted
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$CurrentProvider,

        [Parameter(Mandatory)]
        [string]$CurrentModel,

        [switch]$CrossProvider
    )

    $config = Get-AIConfig

    # Try same provider first
    $chain = $config.fallbackChain[$CurrentProvider]
    if ($chain) {
        $currentIndex = $chain.IndexOf($CurrentModel)
        if ($currentIndex -ge 0 -and $currentIndex -lt ($chain.Count - 1)) {
            $nextModel = $chain[$currentIndex + 1]
            $rateStatus = Get-RateLimitStatus -Provider $CurrentProvider -Model $nextModel
            if ($rateStatus.available) {
                Write-Host "[ModelSelector] Falling back to: $CurrentProvider/$nextModel" -ForegroundColor Yellow
                return @{ provider = $CurrentProvider; model = $nextModel }
            }
        }
    }

    # Try other providers if allowed
    if ($CrossProvider) {
        foreach ($providerName in $config.providerFallbackOrder) {
            if ($providerName -eq $CurrentProvider) { continue }

            $provider = $config.providers[$providerName]
            if (-not $provider -or -not $provider.enabled) { continue }

            # Check API key
            if ($provider.apiKeyEnv -and -not [Environment]::GetEnvironmentVariable($provider.apiKeyEnv)) {
                continue
            }

            $providerChain = $config.fallbackChain[$providerName]
            if ($providerChain -and $providerChain.Count -gt 0) {
                $firstModel = $providerChain[0]
                $rateStatus = Get-RateLimitStatus -Provider $providerName -Model $firstModel
                if ($rateStatus.available) {
                    Write-Host "[ModelSelector] Switching to provider: $providerName/$firstModel" -ForegroundColor Yellow
                    return @{ provider = $providerName; model = $firstModel }
                }
            }
        }
    }

    Write-Warning "[ModelSelector] No fallback model available"
    return $null
}

function Get-ModelCapabilities {
    <#
    .SYNOPSIS
        Gets the capabilities for a specific model
    .DESCRIPTION
        Returns the list of capabilities configured for a model, such as
        "vision", "function_calling", "code_interpreter", etc.
    .PARAMETER Provider
        The provider name
    .PARAMETER Model
        The model identifier
    .OUTPUTS
        Array of capability strings, or empty array if model not found
    .EXAMPLE
        Get-ModelCapabilities -Provider "anthropic" -Model "claude-sonnet-4-5-20250929"
        # Returns: @("chat", "vision", "function_calling")
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Provider,

        [Parameter(Mandatory)]
        [string]$Model
    )

    $config = Get-AIConfig

    if (-not $config.providers -or -not $config.providers[$Provider]) {
        Write-Warning "[ModelSelector] Provider '$Provider' not found"
        return @()
    }

    $modelConfig = $config.providers[$Provider].models[$Model]
    if (-not $modelConfig) {
        Write-Warning "[ModelSelector] Model '$Model' not found in provider '$Provider'"
        return @()
    }

    if ($modelConfig.capabilities) {
        return $modelConfig.capabilities
    }

    return @()
}

function Test-ModelAvailable {
    <#
    .SYNOPSIS
        Tests if a specific model is available for use
    .DESCRIPTION
        Checks multiple conditions to determine if a model can be used:
        - Provider is enabled
        - API key is available (if required)
        - Model is not rate limited
    .PARAMETER Provider
        The provider name
    .PARAMETER Model
        The model identifier
    .OUTPUTS
        Boolean indicating whether the model is available
    .EXAMPLE
        if (Test-ModelAvailable -Provider "anthropic" -Model "claude-sonnet-4-5-20250929") {
            # Use the model
        }
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Provider,

        [Parameter(Mandatory)]
        [string]$Model
    )

    $config = Get-AIConfig

    # Check provider exists and is enabled
    if (-not $config.providers -or -not $config.providers[$Provider]) {
        Write-Verbose "[ModelSelector] Provider '$Provider' not found"
        return $false
    }

    $providerConfig = $config.providers[$Provider]
    if (-not $providerConfig.enabled) {
        Write-Verbose "[ModelSelector] Provider '$Provider' is disabled"
        return $false
    }

    # Check API key availability
    if ($providerConfig.apiKeyEnv) {
        $apiKey = [Environment]::GetEnvironmentVariable($providerConfig.apiKeyEnv)
        if (-not $apiKey) {
            Write-Verbose "[ModelSelector] API key '$($providerConfig.apiKeyEnv)' not found"
            return $false
        }
    }

    # Check model exists
    if (-not $providerConfig.models -or -not $providerConfig.models[$Model]) {
        Write-Verbose "[ModelSelector] Model '$Model' not found in provider '$Provider'"
        return $false
    }

    # Check rate limits
    $rateStatus = Get-RateLimitStatus -Provider $Provider -Model $Model
    if (-not $rateStatus.available) {
        Write-Verbose "[ModelSelector] Model '$Model' is rate limited"
        return $false
    }

    return $true
}

#endregion

#region Exports

Export-ModuleMember -Function @(
    'Get-OptimalModel',
    'Get-FallbackModel',
    'Get-ModelCapabilities',
    'Test-ModelAvailable',
    'Get-RateLimitStatus'
) -Variable @(
    'TaskTierMap'
)

#endregion

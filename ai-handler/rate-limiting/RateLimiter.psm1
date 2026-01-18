#Requires -Version 5.1
<#
.SYNOPSIS
    Rate Limiting Module for AI Handler
.DESCRIPTION
    Provides rate limiting functionality for AI providers and models.
    Tracks token and request usage per minute with automatic reset.
    Calculates costs based on model pricing configuration.
.NOTES
    Author: HYDRA AI Handler
    Version: 1.0.0
    Part of ClaudeHYDRA AI Handler system
#>

#region Module Initialization

# Import dependencies
$ModuleRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$AIHandlerRoot = Split-Path -Parent $PSScriptRoot

# Import AI Config and State modules if not already loaded
if (-not (Get-Command -Name 'Get-AIConfig' -ErrorAction SilentlyContinue)) {
    . "$AIHandlerRoot\AIModelHandler.psm1" -ErrorAction SilentlyContinue
}

# Module-level state cache
$script:RateLimitState = $null

#endregion

#region Rate Limiting Functions

function Update-UsageTracking {
    <#
    .SYNOPSIS
        Track tokens and requests per provider/model with minute-based reset
    .DESCRIPTION
        Updates usage tracking for a specific provider and model combination.
        Tracks tokens per minute, requests per minute, totals, and calculates costs.
        Automatically resets minute counters when a minute has passed.
    .PARAMETER Provider
        The AI provider name (e.g., "anthropic", "openai", "ollama")
    .PARAMETER Model
        The model identifier (e.g., "claude-sonnet-4-5-20250929", "gpt-4o")
    .PARAMETER InputTokens
        Number of input tokens used in the request
    .PARAMETER OutputTokens
        Number of output tokens generated in the response
    .PARAMETER IsError
        Whether the request resulted in an error
    .EXAMPLE
        Update-UsageTracking -Provider "anthropic" -Model "claude-sonnet-4-5-20250929" -InputTokens 500 -OutputTokens 1200
    .EXAMPLE
        Update-UsageTracking -Provider "openai" -Model "gpt-4o-mini" -InputTokens 100 -OutputTokens 50 -IsError $true
    .OUTPUTS
        Hashtable containing updated usage statistics for the model
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Provider,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Model,

        [Parameter()]
        [ValidateRange(0, [int]::MaxValue)]
        [int]$InputTokens = 0,

        [Parameter()]
        [ValidateRange(0, [int]::MaxValue)]
        [int]$OutputTokens = 0,

        [Parameter()]
        [bool]$IsError = $false
    )

    $config = Get-AIConfig
    $state = Get-AIState
    $now = Get-Date

    # Ensure nested hashtables exist
    if (-not $state.usage[$Provider]) {
        $state.usage[$Provider] = @{}
    }
    if (-not $state.usage[$Provider][$Model]) {
        $state.usage[$Provider][$Model] = @{
            tokensThisMinute = 0
            requestsThisMinute = 0
            lastMinuteReset = $now.ToString("o")
            totalTokens = 0
            totalRequests = 0
            totalCost = 0.0
            errors = 0
        }
    }

    $usage = $state.usage[$Provider][$Model]
    $lastReset = [DateTime]::Parse($usage.lastMinuteReset)

    # Reset minute counters if a minute has passed
    if (($now - $lastReset).TotalMinutes -ge 1) {
        $usage.tokensThisMinute = 0
        $usage.requestsThisMinute = 0
        $usage.lastMinuteReset = $now.ToString("o")
    }

    # Update counters
    $totalTokens = $InputTokens + $OutputTokens
    $usage.tokensThisMinute += $totalTokens
    $usage.requestsThisMinute += 1
    $usage.totalTokens += $totalTokens
    $usage.totalRequests += 1

    if ($IsError) {
        $usage.errors += 1
    }

    # Calculate cost based on model pricing
    $modelConfig = $config.providers[$Provider].models[$Model]
    if ($modelConfig) {
        $cost = (($InputTokens / 1000000) * $modelConfig.inputCost) +
                (($OutputTokens / 1000000) * $modelConfig.outputCost)
        $usage.totalCost += $cost
    }

    $state.usage[$Provider][$Model] = $usage
    $script:RateLimitState = $state
    Save-AIState $state

    return $usage
}

function Get-RateLimitStatus {
    <#
    .SYNOPSIS
        Check if provider/model is available based on rate limits
    .DESCRIPTION
        Returns detailed rate limit status for a specific provider and model.
        Includes current usage percentages, remaining capacity, and availability.
        Automatically considers minute reset when calculating status.
    .PARAMETER Provider
        The AI provider name (e.g., "anthropic", "openai", "ollama")
    .PARAMETER Model
        The model identifier (e.g., "claude-sonnet-4-5-20250929", "gpt-4o")
    .EXAMPLE
        Get-RateLimitStatus -Provider "anthropic" -Model "claude-sonnet-4-5-20250929"
        # Returns: @{ available = $true; tokensPercent = 15.5; requestsPercent = 8.2; ... }
    .EXAMPLE
        $status = Get-RateLimitStatus -Provider "openai" -Model "gpt-4o"
        if (-not $status.available) { Write-Warning "Rate limit approaching" }
    .OUTPUTS
        Hashtable with keys:
        - available: Boolean indicating if model can be used
        - tokensPercent: Percentage of token limit used this minute
        - requestsPercent: Percentage of request limit used this minute
        - tokensRemaining: Tokens remaining in current minute window
        - requestsRemaining: Requests remaining in current minute window
        - threshold: Configured rate limit threshold percentage
        - reason: (Only if not available) Reason why model is unavailable
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Provider,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Model
    )

    $config = Get-AIConfig
    $state = Get-AIState

    $modelConfig = $config.providers[$Provider].models[$Model]
    if (-not $modelConfig) {
        return @{ available = $false; reason = "Model not found in configuration" }
    }

    $usage = $state.usage[$Provider][$Model]
    if (-not $usage) {
        return @{
            available = $true
            tokensPercent = 0
            requestsPercent = 0
            tokensRemaining = $modelConfig.tokensPerMinute
            requestsRemaining = $modelConfig.requestsPerMinute
            threshold = $config.settings.rateLimitThreshold * 100
        }
    }

    # Check if minute has reset
    $now = Get-Date
    $lastReset = [DateTime]::Parse($usage.lastMinuteReset)
    if (($now - $lastReset).TotalMinutes -ge 1) {
        return @{
            available = $true
            tokensPercent = 0
            requestsPercent = 0
            tokensRemaining = $modelConfig.tokensPerMinute
            requestsRemaining = $modelConfig.requestsPerMinute
            threshold = $config.settings.rateLimitThreshold * 100
        }
    }

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

function Test-RateLimitAvailable {
    <#
    .SYNOPSIS
        Quick boolean check for rate limit availability
    .DESCRIPTION
        Returns a simple boolean indicating whether a provider/model
        combination is available for use based on current rate limits.
        This is a convenience wrapper around Get-RateLimitStatus.
    .PARAMETER Provider
        The AI provider name (e.g., "anthropic", "openai", "ollama")
    .PARAMETER Model
        The model identifier (e.g., "claude-sonnet-4-5-20250929", "gpt-4o")
    .EXAMPLE
        if (Test-RateLimitAvailable -Provider "anthropic" -Model "claude-sonnet-4-5-20250929") {
            # Proceed with API call
        }
    .EXAMPLE
        # Quick check before batch processing
        $available = Test-RateLimitAvailable -Provider "openai" -Model "gpt-4o-mini"
    .OUTPUTS
        Boolean - $true if model is available, $false if rate limited
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Provider,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Model
    )

    $status = Get-RateLimitStatus -Provider $Provider -Model $Model
    return $status.available
}

function Reset-RateLimitCounters {
    <#
    .SYNOPSIS
        Reset minute counters for a specific model
    .DESCRIPTION
        Resets the per-minute token and request counters for a specific
        provider/model combination. Useful for manual reset or testing.
        Does not affect total counters or cost tracking.
    .PARAMETER Provider
        The AI provider name (e.g., "anthropic", "openai", "ollama")
    .PARAMETER Model
        The model identifier (e.g., "claude-sonnet-4-5-20250929", "gpt-4o")
    .PARAMETER ResetAll
        If specified, resets counters for all models of the provider
    .EXAMPLE
        Reset-RateLimitCounters -Provider "anthropic" -Model "claude-sonnet-4-5-20250929"
    .EXAMPLE
        Reset-RateLimitCounters -Provider "openai" -ResetAll
    .OUTPUTS
        Hashtable containing the reset usage data, or $null if no data existed
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Provider,

        [Parameter(Mandatory = $true, ParameterSetName = "SingleModel")]
        [ValidateNotNullOrEmpty()]
        [string]$Model,

        [Parameter(ParameterSetName = "AllModels")]
        [switch]$ResetAll
    )

    $state = Get-AIState
    $now = Get-Date

    if ($ResetAll) {
        # Reset all models for this provider
        if ($state.usage[$Provider]) {
            foreach ($modelName in $state.usage[$Provider].Keys) {
                if ($PSCmdlet.ShouldProcess("$Provider/$modelName", "Reset rate limit counters")) {
                    $state.usage[$Provider][$modelName].tokensThisMinute = 0
                    $state.usage[$Provider][$modelName].requestsThisMinute = 0
                    $state.usage[$Provider][$modelName].lastMinuteReset = $now.ToString("o")
                }
            }
        }
    }
    else {
        # Reset single model
        if ($state.usage[$Provider] -and $state.usage[$Provider][$Model]) {
            if ($PSCmdlet.ShouldProcess("$Provider/$Model", "Reset rate limit counters")) {
                $state.usage[$Provider][$Model].tokensThisMinute = 0
                $state.usage[$Provider][$Model].requestsThisMinute = 0
                $state.usage[$Provider][$Model].lastMinuteReset = $now.ToString("o")
            }
        }
        else {
            Write-Verbose "No usage data found for $Provider/$Model"
            return $null
        }
    }

    $script:RateLimitState = $state
    Save-AIState $state

    if ($ResetAll) {
        return $state.usage[$Provider]
    }
    else {
        return $state.usage[$Provider][$Model]
    }
}

function Get-RateLimitSummary {
    <#
    .SYNOPSIS
        Get a summary of rate limit status for all providers
    .DESCRIPTION
        Returns a comprehensive summary of rate limit usage across
        all configured providers and models. Useful for monitoring
        and dashboard displays.
    .PARAMETER Provider
        Optional. If specified, returns summary only for this provider.
    .EXAMPLE
        Get-RateLimitSummary
        # Returns summary for all providers
    .EXAMPLE
        Get-RateLimitSummary -Provider "anthropic"
        # Returns summary only for Anthropic models
    .OUTPUTS
        Array of hashtables with rate limit information per model
    #>
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]$Provider
    )

    $config = Get-AIConfig
    $state = Get-AIState
    $summary = @()

    $providers = if ($Provider) { @($Provider) } else { $config.providers.Keys }

    foreach ($prov in $providers) {
        if (-not $config.providers[$prov]) { continue }

        foreach ($model in $config.providers[$prov].models.Keys) {
            $status = Get-RateLimitStatus -Provider $prov -Model $model
            $usage = $state.usage[$prov][$model]

            $summary += @{
                Provider = $prov
                Model = $model
                Available = $status.available
                TokensPercent = $status.tokensPercent
                RequestsPercent = $status.requestsPercent
                TokensRemaining = $status.tokensRemaining
                RequestsRemaining = $status.requestsRemaining
                TotalTokens = if ($usage) { $usage.totalTokens } else { 0 }
                TotalRequests = if ($usage) { $usage.totalRequests } else { 0 }
                TotalCost = if ($usage) { [math]::Round($usage.totalCost, 4) } else { 0 }
                Errors = if ($usage) { $usage.errors } else { 0 }
            }
        }
    }

    return $summary
}

#endregion

#region Module Export

Export-ModuleMember -Function @(
    'Update-UsageTracking',
    'Get-RateLimitStatus',
    'Test-RateLimitAvailable',
    'Reset-RateLimitCounters',
    'Get-RateLimitSummary'
)

#endregion

#Requires -Version 5.1
<#
.SYNOPSIS
    Provider Fallback Module for AI Handler - Intelligent fallback chain management

.DESCRIPTION
    Provides comprehensive fallback chain logic for AI requests including:
    - API KEY ROTATION as FIRST fallback option (same model, different key)
    - Automatic retry with exponential backoff
    - Same-provider model downgrade (e.g., Opus -> Sonnet -> Haiku)
    - Cross-provider fallback when current provider fails
    - Error categorization-based fallback decisions
    - Rate limit awareness for fallback selection
    - Streaming support with fallback handling

    FALLBACK PRIORITY ORDER:
    1. Switch to alternate API key (same provider, same model)
    2. Switch to lower tier model (same provider)
    3. Switch to different provider

.VERSION
    1.1.0

.AUTHOR
    HYDRA System

.NOTES
    Part of the ClaudeCLI AI Handler system
    Dependencies:
    - utils/AIErrorHandler.psm1
    - rate-limiting/RateLimiter.psm1
    - model-selection/ModelSelector.psm1
    - core/AIConfig.psm1

.EXAMPLE
    # Basic request with automatic fallback
    $result = Invoke-AIRequestWithFallback -Messages @(@{role="user";content="Hello"})

.EXAMPLE
    # Request with cross-provider fallback enabled
    $result = Invoke-AIRequestWithFallback -Messages $msgs -AutoFallback -CrossProvider
#>

# ============================================================================
# MODULE INITIALIZATION
# ============================================================================

$script:ModuleRoot = Split-Path $PSScriptRoot -Parent
$script:FallbackAttempts = @()

# Import dependencies
$dependencies = @(
    @{ Path = "$script:ModuleRoot\utils\AIErrorHandler.psm1"; Required = $true },
    @{ Path = "$script:ModuleRoot\rate-limiting\RateLimiter.psm1"; Required = $true },
    @{ Path = "$script:ModuleRoot\model-selection\ModelSelector.psm1"; Required = $true },
    @{ Path = "$script:ModuleRoot\core\AIConfig.psm1"; Required = $true },
    @{ Path = "$PSScriptRoot\ApiKeyRotation.psm1"; Required = $false }  # API Key Rotation (optional but recommended)
)

# Track current API key index per provider
$script:CurrentApiKeyIndex = @{}

foreach ($dep in $dependencies) {
    if (Test-Path $dep.Path) {
        try {
            # Check if module is already loaded globally - don't reimport if so
            $modName = [System.IO.Path]::GetFileNameWithoutExtension($dep.Path)
            $existingMod = Get-Module $modName -ErrorAction SilentlyContinue

            if (-not $existingMod) {
                # Import with -Global to maintain visibility from AIFacade
                Import-Module $dep.Path -Force -Global -ErrorAction Stop
                Write-Verbose "[ProviderFallback] Loaded dependency: $modName"
            }
            else {
                Write-Verbose "[ProviderFallback] Dependency already loaded: $modName"
            }
        }
        catch {
            if ($dep.Required) {
                throw "Failed to load required dependency: $($dep.Path) - $($_.Exception.Message)"
            }
            else {
                Write-Warning "Optional dependency not loaded: $($dep.Path)"
            }
        }
    }
    elseif ($dep.Required) {
        throw "Required dependency not found: $($dep.Path)"
    }
}

# ============================================================================
# FALLBACK DECISION FUNCTIONS
# ============================================================================

function Test-ShouldFallback {
    <#
    .SYNOPSIS
        Determines if an error warrants a fallback attempt

    .DESCRIPTION
        Analyzes the error category and context to decide whether to:
        - Retry the same model
        - Fall back to a different model (same provider)
        - Fall back to a different provider
        - Abort with error

    .PARAMETER ErrorInfo
        The structured AI error object from New-AIError or Get-ErrorCategory

    .PARAMETER CurrentAttempt
        Current retry attempt number (1-based)

    .PARAMETER MaxAttempts
        Maximum allowed retry attempts

    .PARAMETER AllowCrossProvider
        Whether cross-provider fallback is permitted

    .OUTPUTS
        PSCustomObject with:
        - ShouldFallback: Boolean indicating if fallback should be attempted
        - FallbackType: "Retry", "SwitchModel", "SwitchProvider", or "None"
        - WaitMs: Milliseconds to wait before fallback
        - Reason: Explanation of the decision

    .EXAMPLE
        $decision = Test-ShouldFallback -ErrorInfo $error -CurrentAttempt 1 -MaxAttempts 3
        if ($decision.ShouldFallback) {
            Start-Sleep -Milliseconds $decision.WaitMs
            # Perform fallback based on $decision.FallbackType
        }
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory)]
        [PSCustomObject]$ErrorInfo,

        [Parameter()]
        [int]$CurrentAttempt = 1,

        [Parameter()]
        [int]$MaxAttempts = 3,

        [Parameter()]
        [switch]$AllowCrossProvider,

        [Parameter()]
        [string]$CurrentProvider = "",

        [Parameter()]
        [switch]$AlreadyTriedKeyRotation
    )

    # Default: no fallback
    $result = [PSCustomObject]@{
        ShouldFallback = $false
        FallbackType   = "None"
        WaitMs         = 0
        Reason         = "Unknown error, no fallback"
    }

    # Check if we've exhausted retries
    if ($CurrentAttempt -ge $MaxAttempts) {
        $result.Reason = "Maximum retry attempts ($MaxAttempts) reached"
        return $result
    }

    # Non-recoverable errors don't warrant retry
    if (-not $ErrorInfo.Recoverable) {
        # But auth errors can try alternate API key first
        if ($ErrorInfo.Category -eq 'AuthError') {
            # Try alternate key before switching provider
            if (-not $AlreadyTriedKeyRotation -and (Get-Command Test-AlternateKeyAvailable -ErrorAction SilentlyContinue)) {
                if ($CurrentProvider -and (Test-AlternateKeyAvailable -Provider $CurrentProvider)) {
                    $result.ShouldFallback = $true
                    $result.FallbackType = "SwitchApiKey"
                    $result.WaitMs = 0
                    $result.Reason = "Authentication failed, trying alternate API key"
                    return $result
                }
            }
            # No alternate key, try switching provider
            if ($AllowCrossProvider) {
                $result.ShouldFallback = $true
                $result.FallbackType = "SwitchProvider"
                $result.WaitMs = 0
                $result.Reason = "Authentication failed, switching provider"
            }
        }
        elseif ($ErrorInfo.Category -eq 'ValidationError') {
            $result.Reason = "Validation error - request malformed, no fallback"
        }
        else {
            $result.Reason = "Non-recoverable error ($($ErrorInfo.Category)), no fallback"
        }
        return $result
    }

    # Recoverable errors - determine fallback strategy
    # PRIORITY: SwitchApiKey > SwitchModel > SwitchProvider
    switch ($ErrorInfo.Category) {
        'RateLimit' {
            $result.ShouldFallback = $true

            # FIRST: Try alternate API key (same model, different key)
            if (-not $AlreadyTriedKeyRotation -and (Get-Command Test-AlternateKeyAvailable -ErrorAction SilentlyContinue)) {
                if ($CurrentProvider -and (Test-AlternateKeyAvailable -Provider $CurrentProvider)) {
                    $result.FallbackType = "SwitchApiKey"
                    $result.WaitMs = 1000  # Brief pause before switching key
                    $result.Reason = "Rate limit hit, switching to alternate API key (same model)"
                    return $result
                }
            }

            # SECOND: Switch model or provider
            $result.FallbackType = if ($AllowCrossProvider) { "SwitchProvider" } else { "SwitchModel" }
            $result.WaitMs = [Math]::Min($ErrorInfo.RetryAfter, 60000)
            $result.Reason = "Rate limit hit, no alternate keys - switching to alternative model"
        }

        'Overloaded' {
            $result.ShouldFallback = $true

            # Try alternate key first for overloaded errors too
            if (-not $AlreadyTriedKeyRotation -and (Get-Command Test-AlternateKeyAvailable -ErrorAction SilentlyContinue)) {
                if ($CurrentProvider -and (Test-AlternateKeyAvailable -Provider $CurrentProvider)) {
                    $result.FallbackType = "SwitchApiKey"
                    $result.WaitMs = 2000
                    $result.Reason = "Service overloaded, trying alternate API key"
                    return $result
                }
            }

            $result.FallbackType = "SwitchModel"
            $result.WaitMs = [Math]::Min($ErrorInfo.RetryAfter, 30000)
            $result.Reason = "Service overloaded, trying alternative model"
        }

        'ServerError' {
            $result.ShouldFallback = $true
            $result.FallbackType = "Retry"
            # Exponential backoff for server errors
            $result.WaitMs = [Math]::Min($ErrorInfo.RetryAfter * [Math]::Pow(1.5, $CurrentAttempt), 30000)
            $result.Reason = "Server error, retrying with backoff"
        }

        'NetworkError' {
            $result.ShouldFallback = $true
            $result.FallbackType = "Retry"
            $result.WaitMs = [Math]::Min($ErrorInfo.RetryAfter * $CurrentAttempt, 15000)
            $result.Reason = "Network error, retrying"
        }

        default {
            # Unknown but recoverable - simple retry
            $result.ShouldFallback = $true
            $result.FallbackType = "Retry"
            $result.WaitMs = 1000 * $CurrentAttempt
            $result.Reason = "Unknown recoverable error, retrying"
        }
    }

    return $result
}

function Get-NextFallback {
    <#
    .SYNOPSIS
        Gets the next provider/model combination in the fallback chain

    .DESCRIPTION
        Determines the next available provider and model based on:
        - Current provider's fallback chain
        - Cross-provider fallback order (if enabled)
        - Rate limit availability
        - API key availability

    .PARAMETER CurrentProvider
        The current provider name (e.g., "anthropic", "openai")

    .PARAMETER CurrentModel
        The current model identifier

    .PARAMETER FallbackType
        Type of fallback: "Retry", "SwitchApiKey", "SwitchModel", "SwitchProvider"

    .PARAMETER CrossProvider
        Allow switching to a different provider

    .PARAMETER TriedCombinations
        Hashtable of already-tried provider/model combinations to avoid loops

    .OUTPUTS
        Hashtable with: provider, model, isNewProvider, newApiKeyIndex (if SwitchApiKey)
        Returns $null if no fallback is available

    .EXAMPLE
        $next = Get-NextFallback -CurrentProvider "anthropic" -CurrentModel "claude-opus-4-5-20251101" -FallbackType "SwitchModel"
        # Returns: @{ provider = "anthropic"; model = "claude-sonnet-4-5-20250929"; isNewProvider = $false }

    .EXAMPLE
        $next = Get-NextFallback -CurrentProvider "anthropic" -CurrentModel "claude-haiku-4-20250604" -FallbackType "SwitchProvider" -CrossProvider
        # Returns: @{ provider = "openai"; model = "gpt-4o"; isNewProvider = $true }
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$CurrentProvider,

        [Parameter(Mandatory)]
        [string]$CurrentModel,

        [Parameter()]
        [ValidateSet("Retry", "SwitchApiKey", "SwitchModel", "SwitchProvider", "None")]
        [string]$FallbackType = "SwitchModel",

        [Parameter()]
        [switch]$CrossProvider,

        [Parameter()]
        [hashtable]$TriedCombinations = @{}
    )

    # For simple retry, return same provider/model
    if ($FallbackType -eq "Retry") {
        return @{
            provider      = $CurrentProvider
            model         = $CurrentModel
            isNewProvider = $false
        }
    }

    # API KEY ROTATION - same model, different key
    if ($FallbackType -eq "SwitchApiKey") {
        if (Get-Command Switch-ToNextApiKey -ErrorAction SilentlyContinue) {
            $nextKey = Switch-ToNextApiKey -Provider $CurrentProvider -MarkCurrentAsRateLimited

            if ($nextKey) {
                Write-Host "[ProviderFallback] Rotated to API key index $($nextKey.Index) for $CurrentProvider" -ForegroundColor Green
                return @{
                    provider       = $CurrentProvider
                    model          = $CurrentModel
                    isNewProvider  = $false
                    newApiKeyIndex = $nextKey.Index
                    apiKey         = $nextKey.Key
                }
            }
            else {
                Write-Warning "[ProviderFallback] No alternate API keys available for $CurrentProvider"
            }
        }
        else {
            Write-Verbose "[ProviderFallback] ApiKeyRotation module not loaded"
        }

        # No alternate key available, fall through to SwitchModel
        $FallbackType = "SwitchModel"
    }

    # Use ModelSelector's Get-FallbackModel if available
    if (Get-Command Get-FallbackModel -ErrorAction SilentlyContinue) {
        $fallback = Get-FallbackModel -CurrentProvider $CurrentProvider -CurrentModel $CurrentModel -CrossProvider:$CrossProvider

        if ($fallback) {
            $key = "$($fallback.provider)/$($fallback.model)"
            if (-not $TriedCombinations.ContainsKey($key)) {
                return @{
                    provider      = $fallback.provider
                    model         = $fallback.model
                    isNewProvider = ($fallback.provider -ne $CurrentProvider)
                }
            }
        }
    }

    # Manual fallback logic if ModelSelector unavailable
    $config = Get-AIConfig

    # Try same provider first (SwitchModel)
    if ($FallbackType -eq "SwitchModel" -or ($FallbackType -eq "SwitchProvider" -and -not $CrossProvider)) {
        $chain = $config.fallbackChain[$CurrentProvider]
        if ($chain) {
            $currentIndex = [array]::IndexOf($chain, $CurrentModel)

            for ($i = $currentIndex + 1; $i -lt $chain.Count; $i++) {
                $nextModel = $chain[$i]
                $key = "$CurrentProvider/$nextModel"

                if ($TriedCombinations.ContainsKey($key)) { continue }

                # Check rate limits
                if (Get-Command Test-RateLimitAvailable -ErrorAction SilentlyContinue) {
                    if (-not (Test-RateLimitAvailable -Provider $CurrentProvider -Model $nextModel)) {
                        continue
                    }
                }

                return @{
                    provider      = $CurrentProvider
                    model         = $nextModel
                    isNewProvider = $false
                }
            }
        }
    }

    # Cross-provider fallback
    if ($CrossProvider -or $FallbackType -eq "SwitchProvider") {
        foreach ($providerName in $config.providerFallbackOrder) {
            if ($providerName -eq $CurrentProvider) { continue }

            $provider = $config.providers[$providerName]
            if (-not $provider -or -not $provider.enabled) { continue }

            # Check API key
            if ($provider.apiKeyEnv -and -not [Environment]::GetEnvironmentVariable($provider.apiKeyEnv)) {
                continue
            }

            $providerChain = $config.fallbackChain[$providerName]
            if (-not $providerChain -or $providerChain.Count -eq 0) { continue }

            foreach ($model in $providerChain) {
                $key = "$providerName/$model"
                if ($TriedCombinations.ContainsKey($key)) { continue }

                # Check rate limits
                if (Get-Command Test-RateLimitAvailable -ErrorAction SilentlyContinue) {
                    if (-not (Test-RateLimitAvailable -Provider $providerName -Model $model)) {
                        continue
                    }
                }

                return @{
                    provider      = $providerName
                    model         = $model
                    isNewProvider = $true
                }
            }
        }
    }

    # No fallback available
    Write-Warning "[ProviderFallback] No fallback available for $CurrentProvider/$CurrentModel"
    return $null
}

# ============================================================================
# MAIN REQUEST FUNCTION
# ============================================================================

function Invoke-AIRequestWithFallback {
    <#
    .SYNOPSIS
        Main AI request function with comprehensive retry and fallback support

    .DESCRIPTION
        Executes an AI request with:
        - Automatic retry on recoverable errors
        - Exponential backoff between retries
        - Same-provider model fallback (e.g., Opus -> Sonnet -> Haiku)
        - Cross-provider fallback when enabled
        - Error categorization for intelligent fallback decisions
        - Rate limit checking before requests
        - Usage tracking for successful and failed requests

    .PARAMETER Messages
        Array of message objects with 'role' and 'content' properties

    .PARAMETER Provider
        Initial provider name (default: from config or "anthropic")

    .PARAMETER Model
        Initial model identifier (auto-selected if not specified)

    .PARAMETER MaxTokens
        Maximum tokens in response (default: 4096)

    .PARAMETER Temperature
        Sampling temperature 0.0-2.0 (default: 0.7)

    .PARAMETER AutoFallback
        Enable automatic fallback on errors (default: from config)

    .PARAMETER CrossProvider
        Allow falling back to different providers

    .PARAMETER Stream
        Enable streaming response

    .PARAMETER MaxRetries
        Maximum retry attempts (default: from config or 3)

    .PARAMETER RetryDelayMs
        Base delay between retries in milliseconds (default: from config or 1000)

    .OUTPUTS
        PSCustomObject with:
        - Success: Boolean indicating if request succeeded
        - Content: Response content (if successful)
        - Usage: Token usage information
        - Provider: Provider that handled the request
        - Model: Model that generated the response
        - Attempts: Number of attempts made
        - FallbackPath: Array of provider/model combinations tried
        - Error: Error information (if failed)

    .EXAMPLE
        # Simple request with auto-fallback
        $result = Invoke-AIRequestWithFallback -Messages @(
            @{ role = "user"; content = "Hello, world!" }
        )

    .EXAMPLE
        # Request with specific model and cross-provider fallback
        $result = Invoke-AIRequestWithFallback -Messages $msgs `
            -Provider "anthropic" -Model "claude-opus-4-5-20251101" `
            -AutoFallback -CrossProvider

    .EXAMPLE
        # Streaming request
        $result = Invoke-AIRequestWithFallback -Messages $msgs -Stream
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory)]
        [array]$Messages,

        [Parameter()]
        [string]$Provider,

        [Parameter()]
        [string]$Model,

        [Parameter()]
        [int]$MaxTokens = 4096,

        [Parameter()]
        [float]$Temperature = 0.7,

        [Parameter()]
        [switch]$AutoFallback,

        [Parameter()]
        [switch]$CrossProvider,

        [Parameter()]
        [switch]$Stream,

        [Parameter()]
        [int]$MaxRetries,

        [Parameter()]
        [int]$RetryDelayMs
    )

    # Load configuration
    $config = Get-AIConfig

    # Set defaults from config
    if (-not $MaxRetries) {
        $MaxRetries = if ($config.settings.maxRetries) { $config.settings.maxRetries } else { 3 }
    }
    if (-not $RetryDelayMs) {
        $RetryDelayMs = if ($config.settings.retryDelayMs) { $config.settings.retryDelayMs } else { 1000 }
    }

    $enableFallback = $AutoFallback -or $config.settings.autoFallback

    # Auto-select initial provider/model if not specified
    if (-not $Provider -or -not $Model) {
        if (Get-Command Get-OptimalModel -ErrorAction SilentlyContinue) {
            $estimated = ($Messages | ConvertTo-Json -Compress).Length / 4  # Rough token estimate
            $optimal = Get-OptimalModel -Task "simple" -EstimatedTokens ([Math]::Max(100, $estimated))

            if ($optimal) {
                if (-not $Provider) { $Provider = $optimal.provider }
                if (-not $Model) { $Model = $optimal.model }
            }
        }

        # Final fallback to defaults
        if (-not $Provider) { $Provider = $config.providerFallbackOrder[0] }
        if (-not $Model) { $Model = $config.fallbackChain[$Provider][0] }
    }

    # Initialize tracking
    $currentProvider = $Provider
    $currentModel = $Model
    $currentApiKey = $null  # Will use default from env if null
    $attempt = 0
    $triedCombinations = @{}
    $triedKeyRotation = $false  # Track if we already tried rotating API key for this provider
    $fallbackPath = @()
    $lastError = $null

    # Main retry loop
    while ($attempt -lt $MaxRetries) {
        $attempt++
        $combinationKey = "$currentProvider/$currentModel"
        $keyInfo = if ($currentApiKey) { " [key rotated]" } else { "" }
        $triedCombinations[$combinationKey] = $true
        $fallbackPath += $combinationKey

        Write-Host "[ProviderFallback] Attempt $attempt/$MaxRetries -> $combinationKey$keyInfo" -ForegroundColor Cyan

        try {
            # Check rate limits before request
            if (Get-Command Get-RateLimitStatus -ErrorAction SilentlyContinue) {
                $rateStatus = Get-RateLimitStatus -Provider $currentProvider -Model $currentModel

                if (-not $rateStatus.available) {
                    Write-Warning "[ProviderFallback] Rate limit threshold reached for $combinationKey"

                    if ($enableFallback) {
                        $errorInfo = [PSCustomObject]@{
                            Category    = 'RateLimit'
                            Recoverable = $true
                            RetryAfter  = 60000
                            Fallback    = 'SwitchProvider'
                        }

                        $decision = Test-ShouldFallback -ErrorInfo $errorInfo -CurrentAttempt $attempt `
                            -MaxAttempts $MaxRetries -AllowCrossProvider:$CrossProvider `
                            -CurrentProvider $currentProvider -AlreadyTriedKeyRotation:$triedKeyRotation

                        if ($decision.ShouldFallback) {
                            $nextFallback = Get-NextFallback -CurrentProvider $currentProvider `
                                -CurrentModel $currentModel -FallbackType $decision.FallbackType `
                                -CrossProvider:$CrossProvider -TriedCombinations $triedCombinations

                            if ($nextFallback) {
                                # Handle API key rotation
                                if ($decision.FallbackType -eq "SwitchApiKey" -and $nextFallback.apiKey) {
                                    $currentApiKey = $nextFallback.apiKey
                                    $triedKeyRotation = $true
                                    Write-Host "[ProviderFallback] Using alternate API key (index $($nextFallback.newApiKeyIndex))" -ForegroundColor Green
                                }
                                else {
                                    $currentProvider = $nextFallback.provider
                                    $currentModel = $nextFallback.model
                                    $currentApiKey = $null  # Reset to default for new provider/model
                                    $triedKeyRotation = $false  # Reset for new provider
                                }

                                if ($decision.WaitMs -gt 0) {
                                    Write-Host "[ProviderFallback] Waiting $($decision.WaitMs)ms before fallback..." -ForegroundColor Yellow
                                    Start-Sleep -Milliseconds $decision.WaitMs
                                }
                                continue
                            }
                        }
                    }

                    throw "Rate limit exceeded and no fallback available"
                }
            }

            # Make the actual API call (pass custom API key if rotated)
            $apiParams = @{
                Provider = $currentProvider
                Model = $currentModel
                Messages = $Messages
                MaxTokens = $MaxTokens
                Temperature = $Temperature
                Stream = $Stream
            }
            if ($currentApiKey) {
                $apiParams['ApiKey'] = $currentApiKey
            }
            $response = Invoke-ProviderAPIInternal @apiParams

            # Update usage tracking
            if (Get-Command Update-UsageTracking -ErrorAction SilentlyContinue) {
                $inputTokens = if ($response.usage) { $response.usage.input_tokens } else { 0 }
                $outputTokens = if ($response.usage) { $response.usage.output_tokens } else { 0 }

                Update-UsageTracking -Provider $currentProvider -Model $currentModel `
                    -InputTokens $inputTokens -OutputTokens $outputTokens
            }

            # Success - return result
            return [PSCustomObject]@{
                Success      = $true
                Content      = $response.content
                Usage        = $response.usage
                Provider     = $currentProvider
                Model        = $currentModel
                Attempts     = $attempt
                FallbackPath = $fallbackPath
                Error        = $null
            }

        }
        catch {
            $lastError = $_
            Write-Warning "[ProviderFallback] Error on attempt $attempt`: $($_.Exception.Message)"

            # Categorize the error
            $errorInfo = if (Get-Command Get-ErrorCategory -ErrorAction SilentlyContinue) {
                Get-ErrorCategory -Exception $_.Exception
            }
            else {
                # Basic error categorization
                $msg = $_.Exception.Message.ToLower()
                [PSCustomObject]@{
                    Category    = if ($msg -match 'rate.?limit|429') { 'RateLimit' }
                                 elseif ($msg -match 'overload|503') { 'Overloaded' }
                                 elseif ($msg -match '401|403|auth') { 'AuthError' }
                                 elseif ($msg -match '500|502|504') { 'ServerError' }
                                 else { 'Unknown' }
                    Recoverable = $msg -notmatch '401|403|auth|invalid'
                    RetryAfter  = 1000
                    Fallback    = 'Retry'
                }
            }

            # Update error tracking
            if (Get-Command Update-UsageTracking -ErrorAction SilentlyContinue) {
                Update-UsageTracking -Provider $currentProvider -Model $currentModel -IsError $true
            }

            # Log the error
            if (Get-Command New-AIError -ErrorAction SilentlyContinue) {
                $aiError = New-AIError -Message $_.Exception.Message `
                    -Operation "Invoke-AIRequestWithFallback" `
                    -Provider $currentProvider -Model $currentModel `
                    -Exception $_.Exception -Context @{ Attempt = $attempt }

                if (Get-Command Write-ErrorContext -ErrorAction SilentlyContinue) {
                    Write-ErrorContext -AIError $aiError -LogToFile:$false
                }
            }

            # Determine fallback action
            if (-not $enableFallback) {
                # No fallback enabled - just retry with delay
                if ($attempt -lt $MaxRetries -and $errorInfo.Recoverable) {
                    $delay = [Math]::Min($RetryDelayMs * [Math]::Pow(1.5, $attempt), 30000)
                    Write-Host "[ProviderFallback] Retrying in $($delay)ms..." -ForegroundColor Yellow
                    Start-Sleep -Milliseconds $delay
                    continue
                }
            }
            else {
                # Fallback enabled - make decision
                $decision = Test-ShouldFallback -ErrorInfo $errorInfo -CurrentAttempt $attempt `
                    -MaxAttempts $MaxRetries -AllowCrossProvider:$CrossProvider `
                    -CurrentProvider $currentProvider -AlreadyTriedKeyRotation:$triedKeyRotation

                if ($decision.ShouldFallback) {
                    $nextFallback = Get-NextFallback -CurrentProvider $currentProvider `
                        -CurrentModel $currentModel -FallbackType $decision.FallbackType `
                        -CrossProvider:$CrossProvider -TriedCombinations $triedCombinations

                    if ($nextFallback) {
                        Write-Host "[ProviderFallback] $($decision.Reason)" -ForegroundColor Yellow

                        # Handle API key rotation
                        if ($decision.FallbackType -eq "SwitchApiKey" -and $nextFallback.apiKey) {
                            $currentApiKey = $nextFallback.apiKey
                            $triedKeyRotation = $true
                            Write-Host "[ProviderFallback] Using alternate API key (index $($nextFallback.newApiKeyIndex))" -ForegroundColor Green
                        }
                        else {
                            $currentProvider = $nextFallback.provider
                            $currentModel = $nextFallback.model
                            $currentApiKey = $null  # Reset to default

                            if ($nextFallback.isNewProvider) {
                                $triedKeyRotation = $false  # Reset for new provider
                                Write-Host "[ProviderFallback] Switching to provider: $currentProvider" -ForegroundColor Yellow
                            }
                            else {
                                Write-Host "[ProviderFallback] Falling back to: $currentModel" -ForegroundColor Yellow
                            }
                        }

                        if ($decision.WaitMs -gt 0) {
                            Write-Host "[ProviderFallback] Waiting $($decision.WaitMs)ms..." -ForegroundColor Gray
                            Start-Sleep -Milliseconds $decision.WaitMs
                        }
                        continue
                    }
                    else {
                        Write-Warning "[ProviderFallback] No fallback available, exhausting retries"
                    }
                }
            }
        }
    }

    # All attempts exhausted
    return [PSCustomObject]@{
        Success      = $false
        Content      = $null
        Usage        = $null
        Provider     = $currentProvider
        Model        = $currentModel
        Attempts     = $attempt
        FallbackPath = $fallbackPath
        Error        = @{
            Message   = $lastError.Exception.Message
            Type      = $lastError.Exception.GetType().Name
            Details   = $lastError.ToString()
        }
    }
}

# ============================================================================
# INTERNAL PROVIDER API WRAPPER
# ============================================================================

function Invoke-ProviderAPIInternal {
    <#
    .SYNOPSIS
        Internal wrapper for provider-specific API calls

    .DESCRIPTION
        Routes requests to the appropriate provider API implementation.
        This is an internal function used by Invoke-AIRequestWithFallback.
        Supports custom API key for key rotation scenarios.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Provider,

        [Parameter(Mandatory)]
        [string]$Model,

        [Parameter(Mandatory)]
        [array]$Messages,

        [int]$MaxTokens = 4096,
        [float]$Temperature = 0.7,
        [switch]$Stream,

        [Parameter()]
        [string]$ApiKey  # Optional custom API key (for key rotation)
    )

    # Build parameters for provider API
    $apiParams = @{
        Provider = $Provider
        Model = $Model
        Messages = $Messages
        MaxTokens = $MaxTokens
        Temperature = $Temperature
        Stream = $Stream
    }

    # Add custom API key if provided (for key rotation)
    if ($ApiKey) {
        $apiParams['ApiKey'] = $ApiKey
    }

    # Check if main module's Invoke-ProviderAPI is available
    if (Get-Command Invoke-ProviderAPI -ErrorAction SilentlyContinue) {
        return Invoke-ProviderAPI @apiParams
    }

    # Fallback: Load main module and try again
    $mainModule = Join-Path $script:ModuleRoot "AIModelHandler.psm1"
    if (Test-Path $mainModule) {
        Import-Module $mainModule -Force -ErrorAction SilentlyContinue

        if (Get-Command Invoke-ProviderAPI -ErrorAction SilentlyContinue) {
            return Invoke-ProviderAPI @apiParams
        }
    }

    throw "Provider API implementation not available. Ensure AIModelHandler.psm1 is loaded."
}

# ============================================================================
# UTILITY FUNCTIONS
# ============================================================================

function Get-FallbackChainStatus {
    <#
    .SYNOPSIS
        Gets the current status of all models in the fallback chain

    .DESCRIPTION
        Returns availability status for each provider and model in the
        configured fallback chain, including rate limit information.

    .OUTPUTS
        Array of status objects for each provider/model combination

    .EXAMPLE
        Get-FallbackChainStatus | Format-Table Provider, Model, Available, RateStatus
    #>
    [CmdletBinding()]
    param()

    $config = Get-AIConfig
    $results = @()

    foreach ($providerName in $config.providerFallbackOrder) {
        $provider = $config.providers[$providerName]
        $hasKey = -not $provider.apiKeyEnv -or [Environment]::GetEnvironmentVariable($provider.apiKeyEnv)

        $chain = $config.fallbackChain[$providerName]
        if (-not $chain) { continue }

        foreach ($model in $chain) {
            $rateStatus = if (Get-Command Get-RateLimitStatus -ErrorAction SilentlyContinue) {
                Get-RateLimitStatus -Provider $providerName -Model $model
            }
            else {
                @{ available = $true; tokensPercent = 0; requestsPercent = 0 }
            }

            $results += [PSCustomObject]@{
                Provider       = $providerName
                Model          = $model
                HasAPIKey      = $hasKey
                Enabled        = $provider.enabled
                Available      = ($hasKey -and $provider.enabled -and $rateStatus.available)
                TokensPercent  = $rateStatus.tokensPercent
                RequestsPercent = $rateStatus.requestsPercent
            }
        }
    }

    return $results
}

function Clear-FallbackHistory {
    <#
    .SYNOPSIS
        Clears the fallback attempt history

    .DESCRIPTION
        Resets the internal tracking of fallback attempts.
        Useful for testing or after resolving provider issues.
    #>
    [CmdletBinding()]
    param()

    $script:FallbackAttempts = @()
    Write-Host "[ProviderFallback] Fallback history cleared" -ForegroundColor Green
}

function Get-FallbackHistory {
    <#
    .SYNOPSIS
        Gets the recent fallback attempt history

    .DESCRIPTION
        Returns information about recent fallback attempts for debugging
        and monitoring purposes.

    .OUTPUTS
        Array of fallback attempt records
    #>
    [CmdletBinding()]
    param()

    return $script:FallbackAttempts
}

# ============================================================================
# MODULE EXPORTS
# ============================================================================

Export-ModuleMember -Function @(
    # Main functions
    'Invoke-AIRequestWithFallback',
    'Get-NextFallback',
    'Test-ShouldFallback',

    # Utility functions
    'Get-FallbackChainStatus',
    'Clear-FallbackHistory',
    'Get-FallbackHistory'
)

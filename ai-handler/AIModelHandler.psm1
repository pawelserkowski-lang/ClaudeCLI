#Requires -Version 5.1
<#
.SYNOPSIS
    AI Model Handler Facade - Unified entry point for the modular AI Handler system.

.DESCRIPTION
    This module serves as a FACADE that imports and re-exports all functions from the
    modular AI Handler components:
    - Utils: JSON I/O, Health checks, Validation
    - Core: Constants, Configuration, State management
    - Rate Limiting: Usage tracking, rate limit checks
    - Model Selection: Optimal model selection, fallback chains
    - Providers: Anthropic, OpenAI, Ollama

    DEPRECATION NOTICE:
    For new integrations, consider using the individual modules directly or
    the AIFacade.psm1 module which provides a cleaner, more explicit interface.

.VERSION
    2.0.0 (Modular Facade)

.AUTHOR
    HYDRA System

.NOTES
    Breaking changes from v1.x:
    - Internal implementation moved to dedicated modules
    - All public functions remain backward compatible
    - Import order matters for module dependencies

.EXAMPLE
    Import-Module .\AIModelHandler.psm1
    $response = Invoke-AIRequest -Messages @(@{role="user"; content="Hello"})

.LINK
    See also: AIFacade.psm1 for the recommended modern interface
#>

# Show deprecation warning only when loaded directly (not via AIFacade)
if (-not $global:AIFacadeLoading) {
    Write-Warning @"
[DEPRECATION] AIModelHandler.psm1 is deprecated and will be removed in v11.0.
Please use AIFacade.psm1 instead:
  Import-Module AIFacade.psm1
  Initialize-AISystem
"@
}

# ============================================================================
# MODULE PATHS
# ============================================================================

$script:ModuleRoot = $PSScriptRoot

# Submodule paths
$script:Paths = @{
    # Utilities (load first - no dependencies)
    JsonIO     = Join-Path $script:ModuleRoot "utils\AIUtil-JsonIO.psm1"
    Health     = Join-Path $script:ModuleRoot "utils\AIUtil-Health.psm1"

    # Core modules (depend on utils)
    Constants  = Join-Path $script:ModuleRoot "core\AIConstants.psm1"
    Config     = Join-Path $script:ModuleRoot "core\AIConfig.psm1"
    State      = Join-Path $script:ModuleRoot "core\AIState.psm1"

    # Rate Limiting (depends on core)
    RateLimiter = Join-Path $script:ModuleRoot "rate-limiting\RateLimiter.psm1"

    # Model Selection (depends on core, rate limiting)
    ModelSelector = Join-Path $script:ModuleRoot "model-selection\ModelSelector.psm1"

    # Providers (depend on utils)
    Anthropic  = Join-Path $script:ModuleRoot "providers\AnthropicProvider.psm1"
    OpenAI     = Join-Path $script:ModuleRoot "providers\OpenAIProvider.psm1"
    Ollama     = Join-Path $script:ModuleRoot "providers\OllamaProvider.psm1"

    # Legacy modules (optional)
    PromptOptimizer = Join-Path $script:ModuleRoot "modules\PromptOptimizer.psm1"
    ModelDiscovery  = Join-Path $script:ModuleRoot "modules\ModelDiscovery.psm1"
    SecureStorage   = Join-Path $script:ModuleRoot "modules\SecureStorage.psm1"
}

# ============================================================================
# MODULE IMPORTS (Order matters!)
# ============================================================================

# Track loaded modules for export
$script:LoadedModules = @()

function Import-SubModule {
    param([string]$Path, [string]$Name)

    if (Test-Path $Path) {
        try {
            Import-Module $Path -Force -Global -ErrorAction Stop

            # Re-export functions to global scope
            $moduleName = [System.IO.Path]::GetFileNameWithoutExtension($Path)
            $loadedMod = Get-Module -Name $moduleName -ErrorAction SilentlyContinue
            if ($loadedMod -and $loadedMod.ExportedFunctions) {
                foreach ($funcName in $loadedMod.ExportedFunctions.Keys) {
                    $funcDef = $loadedMod.ExportedFunctions[$funcName]
                    if ($funcDef.ScriptBlock) {
                        Set-Item -Path "function:global:$funcName" -Value $funcDef.ScriptBlock -Force -ErrorAction SilentlyContinue
                    }
                }
            }

            $script:LoadedModules += $Name
            Write-Verbose "[AIHandler] Loaded: $Name"
            return $true
        }
        catch {
            Write-Warning "[AIHandler] Failed to load $Name`: $($_.Exception.Message)"
            return $false
        }
    }
    else {
        Write-Verbose "[AIHandler] Module not found: $Name at $Path"
        return $false
    }
}

# === Stage 1: Utilities (no dependencies) ===
Import-SubModule $script:Paths.JsonIO "JsonIO" | Out-Null
Import-SubModule $script:Paths.Health "Health" | Out-Null

# === Stage 2: Core (depend on utils) ===
Import-SubModule $script:Paths.Constants "Constants" | Out-Null
Import-SubModule $script:Paths.Config "Config" | Out-Null
Import-SubModule $script:Paths.State "State" | Out-Null

# === Stage 3: Rate Limiting (depend on core) ===
Import-SubModule $script:Paths.RateLimiter "RateLimiter" | Out-Null

# === Stage 4: Model Selection (depend on core + rate limiting) ===
Import-SubModule $script:Paths.ModelSelector "ModelSelector" | Out-Null

# === Stage 5: Providers (depend on utils) ===
Import-SubModule $script:Paths.Anthropic "Anthropic" | Out-Null
Import-SubModule $script:Paths.OpenAI "OpenAI" | Out-Null
Import-SubModule $script:Paths.Ollama "Ollama" | Out-Null

# === Stage 6: Legacy/Optional modules ===
Import-SubModule $script:Paths.PromptOptimizer "PromptOptimizer" | Out-Null
Import-SubModule $script:Paths.ModelDiscovery "ModelDiscovery" | Out-Null
Import-SubModule $script:Paths.SecureStorage "SecureStorage" | Out-Null

# ============================================================================
# DISCOVERED MODELS CACHE
# ============================================================================

$script:DiscoveredModels = $null

# ============================================================================
# MAIN API INVOCATION
# ============================================================================

function Invoke-AIRequest {
    <#
    .SYNOPSIS
        Invokes an AI request with automatic retry, fallback, and prompt optimization.
    .DESCRIPTION
        Main entry point for AI requests. Supports:
        - Automatic model selection if not specified
        - Rate limit checking with automatic fallback
        - Prompt optimization (optional)
        - Streaming responses
        - Cross-provider fallback
    .PARAMETER Messages
        Array of message objects with 'role' and 'content' properties.
    .PARAMETER Provider
        Provider name: anthropic, openai, ollama
    .PARAMETER Model
        Model identifier. Auto-selected if not specified.
    .PARAMETER MaxTokens
        Maximum output tokens (default: 4096)
    .PARAMETER Temperature
        Sampling temperature 0.0-1.0 (default: 0.7)
    .PARAMETER AutoFallback
        Enable automatic fallback on errors
    .PARAMETER Stream
        Enable streaming response
    .PARAMETER OptimizePrompt
        Enhance prompts before sending
    .PARAMETER ShowOptimization
        Display optimization details
    .PARAMETER NoOptimize
        Disable auto-optimization
    .OUTPUTS
        Hashtable with: content, usage, model, stop_reason, _meta
    .EXAMPLE
        $response = Invoke-AIRequest -Messages @(@{role="user"; content="Hello"})
    .EXAMPLE
        $response = Invoke-AIRequest -Provider "ollama" -Model "llama3.2:3b" `
            -Messages @(@{role="user"; content="Explain X"}) -Stream
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [array]$Messages,

        [string]$Provider = "anthropic",
        [string]$Model,
        [int]$MaxTokens = 4096,
        [float]$Temperature = 0.7,
        [switch]$AutoFallback,
        [switch]$Stream,
        [switch]$OptimizePrompt,
        [switch]$ShowOptimization,
        [switch]$NoOptimize
    )

    $config = Get-AIConfig
    $maxRetries = $config.settings.maxRetries
    $retryDelay = $config.settings.retryDelayMs

    # === Prompt Optimization ===
    $optimizationResult = $null
    $autoOptimize = $config.settings.advancedAI.promptOptimizer.autoOptimize -eq $true
    $shouldOptimize = (-not $NoOptimize) -and ($OptimizePrompt -or $autoOptimize)
    $showOpt = $ShowOptimization -or ($config.settings.advancedAI.promptOptimizer.showEnhancements -eq $true)

    if ($shouldOptimize -and (Get-Command Optimize-Prompt -ErrorAction SilentlyContinue)) {
        for ($i = 0; $i -lt $Messages.Count; $i++) {
            if ($Messages[$i].role -eq "user") {
                $originalContent = $Messages[$i].content
                $optimizationResult = Optimize-Prompt -Prompt $originalContent -Model $Model -Detailed

                if ($optimizationResult.WasEnhanced) {
                    $Messages[$i].content = $optimizationResult.OptimizedPrompt

                    if ($showOpt) {
                        Write-Host "`n[Prompt Optimizer]" -ForegroundColor Cyan
                        Write-Host "Category: $($optimizationResult.Category)" -ForegroundColor Gray
                        Write-Host "Clarity: $($optimizationResult.ClarityScore)/100" -ForegroundColor Gray
                        Write-Host "Enhancements: $($optimizationResult.Enhancements -join ', ')" -ForegroundColor Gray
                        Write-Host ""
                    }
                }
                break
            }
        }
    }

    # === Auto-select Model if not specified ===
    if (-not $Model) {
        $tokenEstimate = ($Messages | ConvertTo-Json | Measure-Object -Character).Characters
        $optimal = Get-OptimalModel -Task "simple" -EstimatedTokens $tokenEstimate
        if ($optimal) {
            $Provider = $optimal.provider
            $Model = $optimal.model
        }
        else {
            throw "No available models found."
        }
    }

    $currentProvider = $Provider
    $currentModel = $Model
    $attempt = 0
    $lastError = $null

    # === Retry Loop with Fallback ===
    while ($attempt -lt $maxRetries) {
        $attempt++

        try {
            Write-Host "[AI] Request #$attempt to $currentProvider/$currentModel" -ForegroundColor Cyan

            # Check rate limits
            $rateStatus = Get-RateLimitStatus -Provider $currentProvider -Model $currentModel
            if (-not $rateStatus.available) {
                Write-Warning "[AI] Rate limit threshold reached"

                if ($AutoFallback -or $config.settings.autoFallback) {
                    $fallback = Get-FallbackModel -CurrentProvider $currentProvider -CurrentModel $currentModel -CrossProvider
                    if ($fallback) {
                        $currentProvider = $fallback.provider
                        $currentModel = $fallback.model
                        continue
                    }
                }
                throw "Rate limit exceeded and no fallback available."
            }

            # === Call Provider API ===
            $result = Invoke-ProviderAPI -Provider $currentProvider -Model $currentModel `
                -Messages $Messages -MaxTokens $MaxTokens -Temperature $Temperature -Stream:$Stream

            # Update usage tracking
            $inputTokens = if ($result.usage) { $result.usage.input_tokens } else { 0 }
            $outputTokens = if ($result.usage) { $result.usage.output_tokens } else { 0 }
            Update-UsageTracking -Provider $currentProvider -Model $currentModel `
                -InputTokens $inputTokens -OutputTokens $outputTokens

            # Add metadata
            $metaData = @{
                provider = $currentProvider
                model = $currentModel
                attempt = $attempt
                timestamp = (Get-Date).ToString("o")
            }

            if ($optimizationResult -and $optimizationResult.WasEnhanced) {
                $metaData.promptOptimization = @{
                    category = $optimizationResult.Category
                    clarityScore = $optimizationResult.ClarityScore
                    enhancements = $optimizationResult.Enhancements
                }
            }

            $result | Add-Member -NotePropertyName "_meta" -NotePropertyValue $metaData -Force
            return $result

        }
        catch {
            $lastError = $_
            Write-Warning "[AI] Error on attempt $attempt`: $($_.Exception.Message)"

            Update-UsageTracking -Provider $currentProvider -Model $currentModel -IsError $true

            $errorType = Get-ErrorType $_.Exception

            if ($errorType -in @("RateLimit", "Overloaded", "ServerError")) {
                if ($AutoFallback -or $config.settings.autoFallback) {
                    $fallback = Get-FallbackModel -CurrentProvider $currentProvider -CurrentModel $currentModel -CrossProvider
                    if ($fallback) {
                        $currentProvider = $fallback.provider
                        $currentModel = $fallback.model
                        continue
                    }
                }
                Start-Sleep -Milliseconds ($retryDelay * $attempt)
            }
            elseif ($errorType -eq "AuthError") {
                if ($AutoFallback -or $config.settings.autoFallback) {
                    $fallback = Get-FallbackModel -CurrentProvider $currentProvider -CurrentModel $currentModel -CrossProvider
                    if ($fallback) {
                        $currentProvider = $fallback.provider
                        $currentModel = $fallback.model
                        continue
                    }
                }
                throw "Authentication failed for $currentProvider and no fallback available."
            }
            else {
                Start-Sleep -Milliseconds ($retryDelay * $attempt)
            }
        }
    }

    throw "All attempts failed. Last error: $lastError"
}

function Get-ErrorType {
    param($Exception)

    $message = $Exception.Message.ToLower()

    if ($message -match "rate.?limit|429|too many requests") { return "RateLimit" }
    if ($message -match "overloaded|503|capacity") { return "Overloaded" }
    if ($message -match "401|403|unauthorized|forbidden|invalid.*key") { return "AuthError" }
    if ($message -match "500|502|504|server error") { return "ServerError" }
    return "Unknown"
}

function Invoke-ProviderAPI {
    [CmdletBinding()]
    param(
        [string]$Provider,
        [string]$Model,
        [array]$Messages,
        [int]$MaxTokens,
        [float]$Temperature,
        [switch]$Stream
    )

    switch ($Provider) {
        "anthropic" {
            return Invoke-AnthropicAPI -Model $Model -Messages $Messages `
                -MaxTokens $MaxTokens -Temperature $Temperature -Stream:$Stream
        }
        "openai" {
            return Invoke-OpenAIAPI -Model $Model -Messages $Messages `
                -MaxTokens $MaxTokens -Temperature $Temperature -Stream:$Stream
        }
        "ollama" {
            return Invoke-OllamaAPI -Model $Model -Messages $Messages `
                -MaxTokens $MaxTokens -Temperature $Temperature -Stream:$Stream
        }
        default {
            throw "Unknown provider: $Provider"
        }
    }
}

# ============================================================================
# PARALLEL EXECUTION
# ============================================================================

function Invoke-AIRequestParallel {
    <#
    .SYNOPSIS
        Execute multiple AI requests in parallel using runspaces.
    .PARAMETER Requests
        Array of request objects with: Messages, Provider, Model, MaxTokens, Temperature
    .PARAMETER MaxConcurrent
        Maximum concurrent requests (default: from config or 4)
    .PARAMETER TimeoutMs
        Timeout per request in milliseconds (default: 30000)
    .OUTPUTS
        Array of results sorted by original index
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [array]$Requests,
        [int]$MaxConcurrent,
        [int]$TimeoutMs
    )

    $config = Get-AIConfig
    $parallelConfig = $config.settings.parallelExecution

    if (-not $MaxConcurrent) {
        $MaxConcurrent = if ($parallelConfig.maxConcurrent) { $parallelConfig.maxConcurrent } else { 4 }
    }
    if (-not $TimeoutMs) {
        $TimeoutMs = if ($parallelConfig.timeoutMs) { $parallelConfig.timeoutMs } else { 30000 }
    }

    Write-Host "[AI] Executing $($Requests.Count) requests in parallel (max: $MaxConcurrent)..." -ForegroundColor Cyan

    $modulePath = Join-Path $PSScriptRoot "AIModelHandler.psm1"
    $iss = [System.Management.Automation.Runspaces.InitialSessionState]::CreateDefault()
    $iss.ImportPSModule($modulePath)

    $runspacePool = [runspacefactory]::CreateRunspacePool(1, $MaxConcurrent, $iss, $Host)
    $runspacePool.Open()

    $jobs = @()
    $results = @()

    foreach ($i in 0..($Requests.Count - 1)) {
        $request = $Requests[$i]

        $powershell = [powershell]::Create()
        $powershell.RunspacePool = $runspacePool

        [void]$powershell.AddScript({
            param($Request, $Index)
            try {
                $params = @{
                    Messages = $Request.Messages
                    MaxTokens = if ($Request.MaxTokens) { $Request.MaxTokens } else { 1024 }
                    Temperature = if ($Request.Temperature) { $Request.Temperature } else { 0.7 }
                }
                if ($Request.Provider) { $params.Provider = $Request.Provider }
                if ($Request.Model) { $params.Model = $Request.Model }

                $response = Invoke-AIRequest @params
                return @{ Index = $Index; Success = $true; Response = $response; Error = $null }
            }
            catch {
                return @{ Index = $Index; Success = $false; Response = $null; Error = $_.Exception.Message }
            }
        })

        [void]$powershell.AddArgument($request)
        [void]$powershell.AddArgument($i)

        $jobs += @{ PowerShell = $powershell; Handle = $powershell.BeginInvoke(); Index = $i }
    }

    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

    foreach ($job in $jobs) {
        $remainingTime = $TimeoutMs - $stopwatch.ElapsedMilliseconds
        if ($remainingTime -lt 0) { $remainingTime = 0 }

        try {
            if ($job.Handle.AsyncWaitHandle.WaitOne($remainingTime)) {
                $result = $job.PowerShell.EndInvoke($job.Handle)
                $results += $result
            }
            else {
                $results += @{ Index = $job.Index; Success = $false; Response = $null; Error = "Timeout after ${TimeoutMs}ms" }
            }
        }
        catch {
            $results += @{ Index = $job.Index; Success = $false; Response = $null; Error = $_.Exception.Message }
        }
        finally {
            $job.PowerShell.Dispose()
        }
    }

    $runspacePool.Close()
    $runspacePool.Dispose()

    $results = $results | Sort-Object { $_.Index }
    $successCount = ($results | Where-Object { $_.Success }).Count
    Write-Host "[AI] Completed: $successCount/$($Requests.Count) successful in $($stopwatch.ElapsedMilliseconds)ms" -ForegroundColor $(if ($successCount -eq $Requests.Count) { "Green" } else { "Yellow" })

    return $results
}

function Invoke-AIBatch {
    <#
    .SYNOPSIS
        Process a batch of prompts with the same settings.
    .PARAMETER Prompts
        Array of prompt strings
    .PARAMETER SystemPrompt
        Optional system prompt for all requests
    .PARAMETER Model
        Model to use (auto-selected if not specified)
    .PARAMETER MaxConcurrent
        Max concurrent requests
    .OUTPUTS
        Array of results with Prompt, Success, Content, Error, Tokens
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string[]]$Prompts,
        [string]$SystemPrompt,
        [string]$Model,
        [string]$Provider,
        [int]$MaxTokens = 1024,
        [int]$MaxConcurrent
    )

    $config = Get-AIConfig

    if (-not $Provider) {
        if ($config.settings.preferLocal -and (Test-OllamaAvailable)) {
            $Provider = "ollama"
            if (-not $Model) { $Model = $config.settings.ollamaDefaultModel }
        }
        else {
            $Provider = $config.providerFallbackOrder[0]
            if (-not $Model) { $Model = $config.fallbackChain[$Provider][0] }
        }
    }

    Write-Host "[AI] Batch processing $($Prompts.Count) prompts with $Provider/$Model" -ForegroundColor Cyan

    $requests = @()
    foreach ($prompt in $Prompts) {
        $messages = @()
        if ($SystemPrompt) { $messages += @{ role = "system"; content = $SystemPrompt } }
        $messages += @{ role = "user"; content = $prompt }
        $requests += @{ Messages = $messages; Provider = $Provider; Model = $Model; MaxTokens = $MaxTokens }
    }

    $results = Invoke-AIRequestParallel -Requests $requests -MaxConcurrent $MaxConcurrent

    return $results | ForEach-Object {
        @{
            Prompt = $Prompts[$_.Index]
            Success = $_.Success
            Content = if ($_.Success) { $_.Response.content } else { $null }
            Error = $_.Error
            Tokens = if ($_.Success) { $_.Response.usage } else { $null }
        }
    }
}

# ============================================================================
# STATUS AND HEALTH
# ============================================================================

function Get-AIStatus {
    <#
    .SYNOPSIS
        Gets current AI system status including all providers and rate limits.
    #>
    [CmdletBinding()]
    param()

    $config = Get-AIConfig
    $state = Get-AIState

    Write-Host "`n=== AI Model Handler Status ===" -ForegroundColor Cyan

    foreach ($providerName in $config.providerFallbackOrder) {
        $provider = $config.providers[$providerName]
        $hasKey = -not $provider.apiKeyEnv -or [Environment]::GetEnvironmentVariable($provider.apiKeyEnv)
        $keyStatus = if ($hasKey) { "[OK]" } else { "[NO KEY]" }
        $enabledStatus = if ($provider.enabled) { "Enabled" } else { "Disabled" }

        $color = if ($hasKey -and $provider.enabled) { "Green" } else { "Yellow" }
        Write-Host "`n[$providerName] $keyStatus $enabledStatus" -ForegroundColor $color

        foreach ($modelName in $provider.models.Keys) {
            $model = $provider.models[$modelName]
            $rateStatus = Get-RateLimitStatus -Provider $providerName -Model $modelName
            $usage = $state.usage[$providerName][$modelName]

            $statusIcon = if ($rateStatus.available) { "+" } else { "!" }
            $tierLabel = $model.tier.ToUpper().PadRight(8)

            Write-Host "  $statusIcon $modelName" -ForegroundColor White -NoNewline
            Write-Host " [$tierLabel] " -ForegroundColor Gray -NoNewline
            Write-Host "Tokens: $($rateStatus.tokensPercent)% " -NoNewline -ForegroundColor $(if ($rateStatus.tokensPercent -gt 85) { "Red" } else { "Green" })
            Write-Host "Reqs: $($rateStatus.requestsPercent)%" -ForegroundColor $(if ($rateStatus.requestsPercent -gt 85) { "Red" } else { "Green" })

            if ($usage -and $usage.totalCost -gt 0) {
                Write-Host "    Total: $($usage.totalRequests) requests, `$$([math]::Round($usage.totalCost, 4))" -ForegroundColor Gray
            }
        }
    }

    Write-Host "`n=== Settings ===" -ForegroundColor Cyan
    Write-Host "  Auto Fallback: $($config.settings.autoFallback)" -ForegroundColor Gray
    Write-Host "  Cost Optimization: $($config.settings.costOptimization)" -ForegroundColor Gray
    Write-Host "  Rate Limit Threshold: $($config.settings.rateLimitThreshold * 100)%" -ForegroundColor Gray
    Write-Host "  Max Retries: $($config.settings.maxRetries)" -ForegroundColor Gray
}

function Get-AIHealth {
    <#
    .SYNOPSIS
        Returns a health dashboard snapshot with status, tokens, and cost.
    #>
    [CmdletBinding()]
    param()

    $config = Get-AIConfig
    $state = Get-AIState
    $providers = @()

    foreach ($providerName in $config.providerFallbackOrder) {
        $provider = $config.providers[$providerName]
        $hasKey = -not $provider.apiKeyEnv -or [Environment]::GetEnvironmentVariable($provider.apiKeyEnv)

        $models = @()
        foreach ($modelName in $provider.models.Keys) {
            $usage = $state.usage[$providerName][$modelName]
            $rate = Get-RateLimitStatus -Provider $providerName -Model $modelName
            $models += @{
                name = $modelName
                tier = $provider.models[$modelName].tier
                status = if ($rate.available) { "ok" } else { "limited" }
                tokens = @{ percent = $rate.tokensPercent; remaining = $rate.tokensRemaining }
                requests = @{ percent = $rate.requestsPercent; remaining = $rate.requestsRemaining }
                usage = @{ totalRequests = $usage.totalRequests; totalTokens = $usage.totalTokens; totalCost = [math]::Round($usage.totalCost, 4) }
            }
        }

        $providers += @{ name = $providerName; enabled = $provider.enabled; hasKey = $hasKey; models = $models }
    }

    return @{ timestamp = (Get-Date).ToString("o"); providers = $providers }
}

function Test-AIProviders {
    <#
    .SYNOPSIS
        Tests connectivity to all configured providers.
    #>
    [CmdletBinding()]
    param()

    $config = Get-AIConfig
    $results = @()

    Write-Host "`nTesting AI Providers..." -ForegroundColor Cyan

    foreach ($providerName in $config.providerFallbackOrder) {
        $provider = $config.providers[$providerName]

        Write-Host "`n[$providerName] " -NoNewline

        if (-not $provider.enabled) {
            Write-Host "DISABLED" -ForegroundColor Gray
            $results += @{ provider = $providerName; status = "disabled" }
            continue
        }

        if ($provider.apiKeyEnv) {
            $key = [Environment]::GetEnvironmentVariable($provider.apiKeyEnv)
            if (-not $key) {
                Write-Host "NO API KEY ($($provider.apiKeyEnv))" -ForegroundColor Red
                $results += @{ provider = $providerName; status = "no_key" }
                continue
            }
        }

        try {
            $testMessages = @(@{ role = "user"; content = "Say 'OK' and nothing else." })
            $firstModel = $config.fallbackChain[$providerName][0]
            $response = Invoke-ProviderAPI -Provider $providerName -Model $firstModel `
                -Messages $testMessages -MaxTokens 10 -Temperature 0

            Write-Host "OK " -ForegroundColor Green -NoNewline
            Write-Host "($firstModel responded)" -ForegroundColor Gray
            $results += @{ provider = $providerName; status = "ok"; model = $firstModel }
        }
        catch {
            Write-Host "FAILED: $($_.Exception.Message)" -ForegroundColor Red
            $results += @{ provider = $providerName; status = "error"; error = $_.Exception.Message }
        }
    }

    return $results
}

# ============================================================================
# MODEL DISCOVERY
# ============================================================================

function Sync-AIModels {
    <#
    .SYNOPSIS
        Synchronize available models from all providers.
    #>
    [CmdletBinding()]
    param([switch]$Force, [switch]$UpdateConfig, [switch]$Silent)

    if (-not (Get-Command 'Get-AllAvailableModels' -ErrorAction SilentlyContinue)) {
        Write-Warning "ModelDiscovery module not loaded"
        return $null
    }

    if (-not $Silent) {
        Write-Host "[AI] Synchronizing models from providers..." -ForegroundColor Cyan
    }

    $config = Get-AIConfig
    $script:DiscoveredModels = Get-AllAvailableModels -Force:$Force `
        -Parallel:$config.settings.modelDiscovery.parallel `
        -SkipValidation:$config.settings.modelDiscovery.skipValidation

    if (-not $Silent) {
        foreach ($p in $script:DiscoveredModels.Summary.GetEnumerator()) {
            $icon = if ($p.Value.Success) { "+" } else { "-" }
            $color = if ($p.Value.Success) { "Green" } else { "Yellow" }
            Write-Host "  [$icon] $($p.Key): $($p.Value.ModelCount) models" -ForegroundColor $color
        }
        Write-Host "  Total: $($script:DiscoveredModels.TotalModels) models in $($script:DiscoveredModels.FetchDurationMs)ms" -ForegroundColor Gray
    }

    if ($UpdateConfig) {
        Update-ModelConfig | Out-Null
        if (-not $Silent) { Write-Host "[AI] Config updated with discovered models" -ForegroundColor Green }
    }

    return $script:DiscoveredModels
}

function Get-DiscoveredModels {
    [CmdletBinding()]
    param(
        [ValidateSet("anthropic", "openai", "ollama", "all")]
        [string]$Provider = "all",
        [switch]$Refresh
    )

    if ($Refresh -or -not $script:DiscoveredModels) {
        $script:DiscoveredModels = Sync-AIModels -Silent
    }

    if (-not $script:DiscoveredModels) { return @() }

    $models = $script:DiscoveredModels.Models
    if ($Provider -ne "all") { $models = $models | Where-Object { $_.provider -eq $Provider } }

    return $models
}

function Get-ModelInfo {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$ModelId)

    $models = Get-DiscoveredModels
    $model = $models | Where-Object { $_.id -eq $ModelId } | Select-Object -First 1
    if (-not $model) { $model = $models | Where-Object { $_.id -like "*$ModelId*" } | Select-Object -First 1 }

    return $model
}

function Get-LocalModels {
    <#
    .SYNOPSIS
        Get list of available local Ollama models.
    #>
    [CmdletBinding()]
    param()

    if (-not (Test-OllamaAvailable)) {
        Write-Warning "Ollama is not running"
        return @()
    }

    return Get-OllamaModels
}

# ============================================================================
# MODULE EXPORTS
# ============================================================================

# Re-export all functions from submodules + facade functions
Export-ModuleMember -Function @(
    # === From utils/AIUtil-JsonIO.psm1 ===
    'Read-JsonFile',
    'Write-JsonFile',
    'ConvertTo-Hashtable',

    # === From utils/AIUtil-Health.psm1 ===
    'Test-OllamaAvailable',
    'Get-SystemMetrics',
    'Test-ProviderConnectivity',
    'Test-ApiKeyPresent',
    'Clear-HealthCache',
    'Get-HealthCacheStatus',
    'Set-HealthCacheTTL',

    # === From core/AIConfig.psm1 ===
    'Get-AIConfig',
    'Save-AIConfig',
    'Get-DefaultConfig',
    'Merge-Config',
    'Test-ConfigValid',
    'Get-ConfigPath',
    'Set-ConfigPath',
    'Reset-ConfigToDefaults',

    # === From core/AIState.psm1 ===
    'Get-AIState',
    'Save-AIState',
    'Initialize-AIState',
    'Reset-AIState',
    'Update-AIState',

    # === From rate-limiting/RateLimiter.psm1 ===
    'Update-UsageTracking',
    'Get-RateLimitStatus',
    'Test-RateLimitAvailable',
    'Reset-RateLimitCounters',
    'Get-RateLimitSummary',

    # === From model-selection/ModelSelector.psm1 ===
    'Get-OptimalModel',
    'Get-FallbackModel',
    'Get-ModelCapabilities',
    'Test-ModelAvailable',

    # === From providers/AnthropicProvider.psm1 ===
    'Invoke-AnthropicAPI',
    'Test-AnthropicAvailable',
    'Get-AnthropicApiKey',

    # === From providers/OpenAIProvider.psm1 ===
    'Invoke-OpenAIAPI',
    'Test-OpenAIAvailable',
    'Invoke-OpenAICompatibleStream',

    # === From providers/OllamaProvider.psm1 ===
    'Invoke-OllamaAPI',
    'Install-OllamaAuto',
    'Get-OllamaModels',

    # === Facade Functions (this module) ===
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
# NOTE: Auto-initialization removed - use AIFacade.psm1 instead
# ============================================================================

Write-Verbose "[AIModelHandler] Facade loaded. Modules: $($script:LoadedModules -join ', ')"

#Requires -Version 5.1
<#
.SYNOPSIS
    AI Handler Health Utilities - Consolidated system and provider health checks.

.DESCRIPTION
    This module consolidates all health check functionality for the AI Handler system:
    - Ollama availability testing (TCP socket-based, PS 5.1 compatible)
    - System metrics collection (CPU, Memory via WMI)
    - Cloud provider connectivity testing
    - API key presence validation

    Features script-level caching with configurable TTL to reduce redundant checks.

.VERSION
    1.0.0

.AUTHOR
    HYDRA System

.NOTES
    Replaces duplicate Ollama/system check implementations across:
    - AIModelHandler.psm1
    - LoadBalancer.psm1
    - AdvancedAI.psm1
    - Initialize-AdvancedAI.ps1
    - _launcher.ps1
#>

#region Script-Level Cache

# Cache configuration
$script:CacheConfig = @{
    OllamaTTLSeconds    = 30      # How long to cache Ollama availability
    SystemMetricsTTLSeconds = 10  # How long to cache system metrics
    ProviderTTLSeconds  = 60      # How long to cache provider connectivity
}

# Cache storage
$script:Cache = @{
    Ollama = @{
        Available = $null
        LastCheck = [datetime]::MinValue
        Models    = @()
    }
    SystemMetrics = @{
        Data      = $null
        LastCheck = [datetime]::MinValue
    }
    Providers = @{}
}

#endregion

#region Ollama Health Check

function Test-OllamaAvailable {
    <#
    .SYNOPSIS
        Check if Ollama is running on localhost:11434.

    .DESCRIPTION
        Tests Ollama availability using TCP socket connection for PS 5.1 compatibility.
        Results are cached to avoid redundant network calls.

    .PARAMETER Port
        Port number to check (default: 11434).

    .PARAMETER TimeoutMs
        Connection timeout in milliseconds (default: 2000).

    .PARAMETER NoCache
        Bypass cache and perform fresh check.

    .PARAMETER IncludeModels
        Also fetch list of available models (slower, requires HTTP call).

    .OUTPUTS
        Hashtable with:
        - Available: [bool] Whether Ollama is running
        - Port: [int] Port checked
        - ResponseTimeMs: [int] Time taken for check
        - Models: [array] Available models (if -IncludeModels)
        - Cached: [bool] Whether result came from cache

    .EXAMPLE
        Test-OllamaAvailable
        # Returns: @{ Available = $true; Port = 11434; ResponseTimeMs = 15; Cached = $false }

    .EXAMPLE
        Test-OllamaAvailable -IncludeModels
        # Returns: @{ Available = $true; Models = @('llama3.2:3b', 'qwen2.5-coder:1.5b'); ... }

    .EXAMPLE
        Test-OllamaAvailable -NoCache
        # Forces fresh check, bypassing cache
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter()]
        [int]$Port = 11434,

        [Parameter()]
        [int]$TimeoutMs = 2000,

        [Parameter()]
        [switch]$NoCache,

        [Parameter()]
        [switch]$IncludeModels
    )

    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

    # Check cache validity
    $cacheAge = ((Get-Date) - $script:Cache.Ollama.LastCheck).TotalSeconds
    $cacheValid = (-not $NoCache) -and ($cacheAge -lt $script:CacheConfig.OllamaTTLSeconds)

    if ($cacheValid -and ($null -ne $script:Cache.Ollama.Available)) {
        $stopwatch.Stop()
        $result = @{
            Available      = $script:Cache.Ollama.Available
            Port           = $Port
            ResponseTimeMs = $stopwatch.ElapsedMilliseconds
            Cached         = $true
            CacheAgeSeconds = [math]::Round($cacheAge, 1)
        }
        if ($IncludeModels -and $script:Cache.Ollama.Models.Count -gt 0) {
            $result.Models = $script:Cache.Ollama.Models
        }
        return $result
    }

    # Perform TCP socket check (PS 5.1 compatible)
    $available = $false
    $tcp = $null

    try {
        $tcp = New-Object System.Net.Sockets.TcpClient
        $asyncResult = $tcp.BeginConnect('localhost', $Port, $null, $null)
        $success = $asyncResult.AsyncWaitHandle.WaitOne($TimeoutMs, $false)

        if ($success -and $tcp.Connected) {
            $available = $true
            $tcp.EndConnect($asyncResult)
        }
    }
    catch {
        $available = $false
    }
    finally {
        if ($tcp) {
            $tcp.Close()
            $tcp.Dispose()
        }
    }

    $stopwatch.Stop()

    # Update cache
    $script:Cache.Ollama.Available = $available
    $script:Cache.Ollama.LastCheck = Get-Date

    $result = @{
        Available      = $available
        Port           = $Port
        ResponseTimeMs = $stopwatch.ElapsedMilliseconds
        Cached         = $false
    }

    # Optionally fetch models (requires HTTP call)
    if ($IncludeModels -and $available) {
        try {
            $modelsResponse = Invoke-RestMethod -Uri "http://localhost:$Port/api/tags" `
                -Method Get -TimeoutSec 3 -ErrorAction Stop

            if ($modelsResponse.models) {
                $modelNames = $modelsResponse.models | ForEach-Object { $_.name }
                $result.Models = $modelNames
                $script:Cache.Ollama.Models = $modelNames
            }
            else {
                $result.Models = @()
                $script:Cache.Ollama.Models = @()
            }
        }
        catch {
            $result.Models = @()
            $result.ModelsError = $_.Exception.Message
        }
    }

    return $result
}

#endregion

#region System Metrics

function Get-SystemMetrics {
    <#
    .SYNOPSIS
        Get current system resource metrics.

    .DESCRIPTION
        Collects CPU and memory utilization using WMI for PS 5.1 compatibility.
        Returns a recommendation (local/hybrid/cloud) based on resource usage.
        Results are cached to reduce WMI query overhead.

    .PARAMETER CpuThresholdHigh
        CPU percentage above which 'cloud' is recommended (default: 90).

    .PARAMETER CpuThresholdMedium
        CPU percentage above which 'hybrid' is recommended (default: 70).

    .PARAMETER MemoryThreshold
        Memory percentage above which 'cloud' is recommended (default: 85).

    .PARAMETER NoCache
        Bypass cache and perform fresh measurement.

    .OUTPUTS
        Hashtable with:
        - CpuPercent: [float] Current CPU utilization
        - MemoryPercent: [float] Current memory utilization
        - MemoryAvailableGB: [float] Available memory in GB
        - MemoryTotalGB: [float] Total memory in GB
        - Recommendation: [string] 'local', 'hybrid', or 'cloud'
        - Timestamp: [datetime] When metrics were collected
        - Cached: [bool] Whether result came from cache

    .EXAMPLE
        Get-SystemMetrics
        # Returns: @{ CpuPercent = 25.5; MemoryPercent = 62.3; Recommendation = 'local'; ... }

    .EXAMPLE
        Get-SystemMetrics -CpuThresholdHigh 80 -NoCache
        # Forces fresh check with custom threshold
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter()]
        [int]$CpuThresholdHigh = 90,

        [Parameter()]
        [int]$CpuThresholdMedium = 70,

        [Parameter()]
        [int]$MemoryThreshold = 85,

        [Parameter()]
        [switch]$NoCache
    )

    # Check cache validity
    $cacheAge = ((Get-Date) - $script:Cache.SystemMetrics.LastCheck).TotalSeconds
    $cacheValid = (-not $NoCache) -and ($cacheAge -lt $script:CacheConfig.SystemMetricsTTLSeconds)

    if ($cacheValid -and ($null -ne $script:Cache.SystemMetrics.Data)) {
        $cached = $script:Cache.SystemMetrics.Data.Clone()
        $cached.Cached = $true
        $cached.CacheAgeSeconds = [math]::Round($cacheAge, 1)
        return $cached
    }

    $metrics = @{
        Timestamp        = Get-Date
        CpuPercent       = 0
        MemoryPercent    = 0
        MemoryAvailableGB = 0
        MemoryTotalGB    = 0
        Recommendation   = "local"
        Cached           = $false
        Errors           = @{}
    }

    # CPU utilization via WMI
    try {
        $cpu = Get-WmiObject Win32_Processor -ErrorAction Stop |
            Measure-Object -Property LoadPercentage -Average
        $metrics.CpuPercent = [math]::Round($cpu.Average, 1)
    }
    catch {
        $metrics.CpuPercent = 50  # Default assumption on error
        $metrics.Errors.Cpu = $_.Exception.Message
    }

    # Memory utilization via WMI
    try {
        $os = Get-WmiObject Win32_OperatingSystem -ErrorAction Stop
        $totalMemoryGB = $os.TotalVisibleMemorySize / 1MB
        $freeMemoryGB = $os.FreePhysicalMemory / 1MB
        $usedMemoryGB = $totalMemoryGB - $freeMemoryGB

        $metrics.MemoryPercent = [math]::Round(($usedMemoryGB / $totalMemoryGB) * 100, 1)
        $metrics.MemoryAvailableGB = [math]::Round($freeMemoryGB, 2)
        $metrics.MemoryTotalGB = [math]::Round($totalMemoryGB, 2)
    }
    catch {
        $metrics.MemoryPercent = 50  # Default assumption on error
        $metrics.Errors.Memory = $_.Exception.Message
    }

    # Determine recommendation
    if ($metrics.CpuPercent -gt $CpuThresholdHigh -or $metrics.MemoryPercent -gt $MemoryThreshold) {
        $metrics.Recommendation = "cloud"
    }
    elseif ($metrics.CpuPercent -gt $CpuThresholdMedium) {
        $metrics.Recommendation = "hybrid"
    }
    else {
        $metrics.Recommendation = "local"
    }

    # Clean up errors if empty
    if ($metrics.Errors.Count -eq 0) {
        $metrics.Remove('Errors')
    }

    # Update cache
    $script:Cache.SystemMetrics.Data = $metrics.Clone()
    $script:Cache.SystemMetrics.LastCheck = Get-Date

    return $metrics
}

#endregion

#region Provider Connectivity

function Test-ProviderConnectivity {
    <#
    .SYNOPSIS
        Test if a cloud provider API endpoint is reachable.

    .DESCRIPTION
        Performs a lightweight connectivity test to cloud provider API endpoints.
        Does not validate API keys, only tests network reachability.
        Results are cached to reduce network overhead.

    .PARAMETER Provider
        Provider to test: anthropic, openai, google, mistral, groq.

    .PARAMETER TimeoutSeconds
        Connection timeout in seconds (default: 5).

    .PARAMETER NoCache
        Bypass cache and perform fresh check.

    .OUTPUTS
        Hashtable with:
        - Provider: [string] Provider name
        - Reachable: [bool] Whether endpoint is reachable
        - StatusCode: [int] HTTP status code (if available)
        - ResponseTimeMs: [int] Time taken for check
        - Endpoint: [string] Endpoint URL tested
        - Cached: [bool] Whether result came from cache

    .EXAMPLE
        Test-ProviderConnectivity -Provider "anthropic"
        # Returns: @{ Provider = 'anthropic'; Reachable = $true; StatusCode = 200; ... }

    .EXAMPLE
        Test-ProviderConnectivity -Provider "openai" -NoCache
        # Forces fresh connectivity check
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory)]
        [ValidateSet("anthropic", "openai", "google", "mistral", "groq")]
        [string]$Provider,

        [Parameter()]
        [int]$TimeoutSeconds = 5,

        [Parameter()]
        [switch]$NoCache
    )

    # Provider endpoint mapping (lightweight health check endpoints)
    $endpoints = @{
        anthropic = "https://api.anthropic.com/"
        openai    = "https://api.openai.com/v1/models"
        google    = "https://generativelanguage.googleapis.com/"
        mistral   = "https://api.mistral.ai/"
        groq      = "https://api.groq.com/"
    }

    $endpoint = $endpoints[$Provider]

    # Check cache validity
    if (-not $script:Cache.Providers.ContainsKey($Provider)) {
        $script:Cache.Providers[$Provider] = @{
            Reachable = $null
            LastCheck = [datetime]::MinValue
        }
    }

    $cacheAge = ((Get-Date) - $script:Cache.Providers[$Provider].LastCheck).TotalSeconds
    $cacheValid = (-not $NoCache) -and ($cacheAge -lt $script:CacheConfig.ProviderTTLSeconds)

    if ($cacheValid -and ($null -ne $script:Cache.Providers[$Provider].Reachable)) {
        return @{
            Provider        = $Provider
            Reachable       = $script:Cache.Providers[$Provider].Reachable
            StatusCode      = $script:Cache.Providers[$Provider].StatusCode
            Endpoint        = $endpoint
            ResponseTimeMs  = 0
            Cached          = $true
            CacheAgeSeconds = [math]::Round($cacheAge, 1)
        }
    }

    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
    $reachable = $false
    $statusCode = 0
    $errorMessage = $null

    try {
        # Use HEAD request for lightweight check where possible
        $response = Invoke-WebRequest -Uri $endpoint -Method Head `
            -TimeoutSec $TimeoutSeconds -UseBasicParsing -ErrorAction Stop

        $reachable = $true
        $statusCode = $response.StatusCode
    }
    catch [System.Net.WebException] {
        $webEx = $_.Exception
        if ($webEx.Response) {
            # Got a response (even if error), so endpoint is reachable
            $statusCode = [int]$webEx.Response.StatusCode

            # 401/403 means reachable but auth required (expected for API)
            if ($statusCode -in @(401, 403, 404, 405)) {
                $reachable = $true
            }
        }
        else {
            $errorMessage = $webEx.Message
        }
    }
    catch {
        $errorMessage = $_.Exception.Message
    }

    $stopwatch.Stop()

    # Update cache
    $script:Cache.Providers[$Provider].Reachable = $reachable
    $script:Cache.Providers[$Provider].StatusCode = $statusCode
    $script:Cache.Providers[$Provider].LastCheck = Get-Date

    $result = @{
        Provider       = $Provider
        Reachable      = $reachable
        StatusCode     = $statusCode
        Endpoint       = $endpoint
        ResponseTimeMs = $stopwatch.ElapsedMilliseconds
        Cached         = $false
    }

    if ($errorMessage) {
        $result.Error = $errorMessage
    }

    return $result
}

#endregion

#region API Key Validation

function Test-ApiKeyPresent {
    <#
    .SYNOPSIS
        Check if an API key environment variable exists.

    .DESCRIPTION
        Tests whether the specified API key environment variable is set.
        Does not validate the key itself, only checks presence.

    .PARAMETER Provider
        Provider to check: anthropic, openai, google, mistral, groq.

    .PARAMETER EnvVarName
        Custom environment variable name (overrides default mapping).

    .PARAMETER MaskKey
        Return masked key value (first 10 chars + '...').

    .OUTPUTS
        Hashtable with:
        - Provider: [string] Provider name
        - Present: [bool] Whether key is set
        - EnvVar: [string] Environment variable name
        - MaskedKey: [string] Masked key value (if -MaskKey and key exists)

    .EXAMPLE
        Test-ApiKeyPresent -Provider "anthropic"
        # Returns: @{ Provider = 'anthropic'; Present = $true; EnvVar = 'ANTHROPIC_API_KEY' }

    .EXAMPLE
        Test-ApiKeyPresent -Provider "openai" -MaskKey
        # Returns: @{ Provider = 'openai'; Present = $true; MaskedKey = 'sk-proj-ab...' }
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory, ParameterSetName = 'Provider')]
        [ValidateSet("anthropic", "openai", "google", "mistral", "groq")]
        [string]$Provider,

        [Parameter(ParameterSetName = 'Custom')]
        [string]$EnvVarName,

        [Parameter()]
        [switch]$MaskKey
    )

    # Default environment variable mapping
    $envVarMap = @{
        anthropic = "ANTHROPIC_API_KEY"
        openai    = "OPENAI_API_KEY"
        google    = "GOOGLE_API_KEY"
        mistral   = "MISTRAL_API_KEY"
        groq      = "GROQ_API_KEY"
    }

    if ($EnvVarName) {
        $varName = $EnvVarName
        $providerName = "custom"
    }
    else {
        $varName = $envVarMap[$Provider]
        $providerName = $Provider
    }

    $keyValue = [Environment]::GetEnvironmentVariable($varName)
    $present = (-not [string]::IsNullOrWhiteSpace($keyValue))

    $result = @{
        Provider = $providerName
        Present  = $present
        EnvVar   = $varName
    }

    if ($MaskKey -and $present -and $keyValue.Length -gt 10) {
        $result.MaskedKey = $keyValue.Substring(0, 10) + "..."
    }
    elseif ($MaskKey -and $present) {
        $result.MaskedKey = "***"
    }

    return $result
}

#endregion

#region Cache Management

function Clear-HealthCache {
    <#
    .SYNOPSIS
        Clear all or specific health check caches.

    .DESCRIPTION
        Resets the cached health check data, forcing fresh checks on next call.

    .PARAMETER Target
        Which cache to clear: All, Ollama, SystemMetrics, Providers.

    .EXAMPLE
        Clear-HealthCache
        # Clears all caches

    .EXAMPLE
        Clear-HealthCache -Target Ollama
        # Clears only Ollama cache
    #>
    [CmdletBinding()]
    param(
        [Parameter()]
        [ValidateSet("All", "Ollama", "SystemMetrics", "Providers")]
        [string]$Target = "All"
    )

    switch ($Target) {
        "Ollama" {
            $script:Cache.Ollama.Available = $null
            $script:Cache.Ollama.LastCheck = [datetime]::MinValue
            $script:Cache.Ollama.Models = @()
        }
        "SystemMetrics" {
            $script:Cache.SystemMetrics.Data = $null
            $script:Cache.SystemMetrics.LastCheck = [datetime]::MinValue
        }
        "Providers" {
            $script:Cache.Providers = @{}
        }
        default {
            $script:Cache.Ollama.Available = $null
            $script:Cache.Ollama.LastCheck = [datetime]::MinValue
            $script:Cache.Ollama.Models = @()
            $script:Cache.SystemMetrics.Data = $null
            $script:Cache.SystemMetrics.LastCheck = [datetime]::MinValue
            $script:Cache.Providers = @{}
        }
    }

    Write-Verbose "Health cache cleared: $Target"
}

function Get-HealthCacheStatus {
    <#
    .SYNOPSIS
        Get current cache status and configuration.

    .DESCRIPTION
        Returns information about cache state and TTL configuration.

    .OUTPUTS
        Hashtable with cache configuration and current state.

    .EXAMPLE
        Get-HealthCacheStatus
        # Returns cache configuration and state information
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param()

    $now = Get-Date

    return @{
        Configuration = $script:CacheConfig
        State = @{
            Ollama = @{
                HasData    = ($null -ne $script:Cache.Ollama.Available)
                AgeSeconds = if ($script:Cache.Ollama.LastCheck -ne [datetime]::MinValue) {
                    [math]::Round(($now - $script:Cache.Ollama.LastCheck).TotalSeconds, 1)
                } else { $null }
                Expired    = (($now - $script:Cache.Ollama.LastCheck).TotalSeconds -gt $script:CacheConfig.OllamaTTLSeconds)
            }
            SystemMetrics = @{
                HasData    = ($null -ne $script:Cache.SystemMetrics.Data)
                AgeSeconds = if ($script:Cache.SystemMetrics.LastCheck -ne [datetime]::MinValue) {
                    [math]::Round(($now - $script:Cache.SystemMetrics.LastCheck).TotalSeconds, 1)
                } else { $null }
                Expired    = (($now - $script:Cache.SystemMetrics.LastCheck).TotalSeconds -gt $script:CacheConfig.SystemMetricsTTLSeconds)
            }
            Providers = @{
                CachedProviders = $script:Cache.Providers.Keys
                Count           = $script:Cache.Providers.Count
            }
        }
    }
}

function Set-HealthCacheTTL {
    <#
    .SYNOPSIS
        Configure cache TTL values.

    .DESCRIPTION
        Updates the time-to-live settings for health check caches.

    .PARAMETER OllamaTTLSeconds
        TTL for Ollama availability cache.

    .PARAMETER SystemMetricsTTLSeconds
        TTL for system metrics cache.

    .PARAMETER ProviderTTLSeconds
        TTL for provider connectivity cache.

    .EXAMPLE
        Set-HealthCacheTTL -OllamaTTLSeconds 60
        # Sets Ollama cache TTL to 60 seconds
    #>
    [CmdletBinding()]
    param(
        [Parameter()]
        [ValidateRange(1, 300)]
        [int]$OllamaTTLSeconds,

        [Parameter()]
        [ValidateRange(1, 60)]
        [int]$SystemMetricsTTLSeconds,

        [Parameter()]
        [ValidateRange(1, 300)]
        [int]$ProviderTTLSeconds
    )

    if ($PSBoundParameters.ContainsKey('OllamaTTLSeconds')) {
        $script:CacheConfig.OllamaTTLSeconds = $OllamaTTLSeconds
    }
    if ($PSBoundParameters.ContainsKey('SystemMetricsTTLSeconds')) {
        $script:CacheConfig.SystemMetricsTTLSeconds = $SystemMetricsTTLSeconds
    }
    if ($PSBoundParameters.ContainsKey('ProviderTTLSeconds')) {
        $script:CacheConfig.ProviderTTLSeconds = $ProviderTTLSeconds
    }

    Write-Verbose "Cache TTL updated: Ollama=$($script:CacheConfig.OllamaTTLSeconds)s, System=$($script:CacheConfig.SystemMetricsTTLSeconds)s, Provider=$($script:CacheConfig.ProviderTTLSeconds)s"

    return $script:CacheConfig
}

#endregion

#region Exports

Export-ModuleMember -Function @(
    # Health checks
    'Test-OllamaAvailable',
    'Get-SystemMetrics',
    'Test-ProviderConnectivity',
    'Test-ApiKeyPresent',

    # Cache management
    'Clear-HealthCache',
    'Get-HealthCacheStatus',
    'Set-HealthCacheTTL'
)

#endregion

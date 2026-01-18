#Requires -Version 5.1
<#
.SYNOPSIS
    API Key Rotation Module for AI Handler - Manages multiple API keys per provider

.DESCRIPTION
    Provides intelligent API key rotation as the FIRST fallback option before
    switching to a different model. Supports:
    - Multiple API keys per provider (primary + alternates)
    - Automatic rotation on rate limit errors
    - Key health tracking (failures, last used, cooldown)
    - Seamless integration with ProviderFallback

.VERSION
    1.0.0

.AUTHOR
    HYDRA System

.NOTES
    Part of the ClaudeHYDRA AI Handler system

    Fallback Priority:
    1. Switch to alternate API key (same model) <- THIS MODULE
    2. Switch to lower tier model (same provider)
    3. Switch to different provider

.EXAMPLE
    # Get next available API key
    $key = Get-NextApiKey -Provider "anthropic"

.EXAMPLE
    # Mark key as rate limited
    Set-ApiKeyStatus -Provider "anthropic" -KeyIndex 0 -Status "RateLimited"
#>

# ============================================================================
# MODULE INITIALIZATION
# ============================================================================

$script:ModuleRoot = Split-Path $PSScriptRoot -Parent
$script:KeyStateFile = Join-Path $script:ModuleRoot "api-key-state.json"

# In-memory key state (persisted to file)
$script:KeyState = @{
    anthropic = @{
        currentKeyIndex = 0
        keys = @(
            @{ envVar = "ANTHROPIC_API_KEY"; status = "active"; failures = 0; lastUsed = $null; cooldownUntil = $null }
            @{ envVar = "ANTHROPIC_API_KEY_2"; status = "active"; failures = 0; lastUsed = $null; cooldownUntil = $null }
            @{ envVar = "ANTHROPIC_API_KEY_3"; status = "active"; failures = 0; lastUsed = $null; cooldownUntil = $null }
        )
    }
    openai = @{
        currentKeyIndex = 0
        keys = @(
            @{ envVar = "OPENAI_API_KEY"; status = "active"; failures = 0; lastUsed = $null; cooldownUntil = $null }
            @{ envVar = "OPENAI_API_KEY_2"; status = "active"; failures = 0; lastUsed = $null; cooldownUntil = $null }
        )
    }
    google = @{
        currentKeyIndex = 0
        keys = @(
            @{ envVar = "GOOGLE_API_KEY"; status = "active"; failures = 0; lastUsed = $null; cooldownUntil = $null }
            @{ envVar = "GOOGLE_API_KEY_2"; status = "active"; failures = 0; lastUsed = $null; cooldownUntil = $null }
        )
    }
}

# ============================================================================
# STATE PERSISTENCE
# ============================================================================

function Save-KeyState {
    <#
    .SYNOPSIS
        Persists key state to disk
    #>
    [CmdletBinding()]
    param()

    try {
        $script:KeyState | ConvertTo-Json -Depth 10 | Set-Content -Path $script:KeyStateFile -Encoding UTF8
    }
    catch {
        Write-Warning "[ApiKeyRotation] Failed to save key state: $($_.Exception.Message)"
    }
}

function Load-KeyState {
    <#
    .SYNOPSIS
        Loads key state from disk
    #>
    [CmdletBinding()]
    param()

    if (Test-Path $script:KeyStateFile) {
        try {
            $loaded = Get-Content -Path $script:KeyStateFile -Raw | ConvertFrom-Json

            # Merge with default structure (in case new providers added)
            foreach ($provider in $loaded.PSObject.Properties.Name) {
                if ($script:KeyState.ContainsKey($provider)) {
                    $script:KeyState[$provider].currentKeyIndex = $loaded.$provider.currentKeyIndex

                    for ($i = 0; $i -lt $loaded.$provider.keys.Count -and $i -lt $script:KeyState[$provider].keys.Count; $i++) {
                        $script:KeyState[$provider].keys[$i].status = $loaded.$provider.keys[$i].status
                        $script:KeyState[$provider].keys[$i].failures = $loaded.$provider.keys[$i].failures
                        $script:KeyState[$provider].keys[$i].lastUsed = $loaded.$provider.keys[$i].lastUsed
                        $script:KeyState[$provider].keys[$i].cooldownUntil = $loaded.$provider.keys[$i].cooldownUntil
                    }
                }
            }
        }
        catch {
            Write-Warning "[ApiKeyRotation] Failed to load key state: $($_.Exception.Message)"
        }
    }
}

# Load state on module import
Load-KeyState

# ============================================================================
# KEY MANAGEMENT FUNCTIONS
# ============================================================================

function Get-AvailableApiKeys {
    <#
    .SYNOPSIS
        Gets all available (configured) API keys for a provider

    .PARAMETER Provider
        Provider name (anthropic, openai, google)

    .OUTPUTS
        Array of available key configurations with their actual values (masked)
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateSet("anthropic", "openai", "google")]
        [string]$Provider
    )

    $providerState = $script:KeyState[$Provider]
    if (-not $providerState) {
        return @()
    }

    $available = @()

    for ($i = 0; $i -lt $providerState.keys.Count; $i++) {
        $keyConfig = $providerState.keys[$i]
        $envVar = $keyConfig.envVar
        $actualKey = [Environment]::GetEnvironmentVariable($envVar)

        if ($actualKey) {
            $maskedKey = if ($actualKey.Length -gt 15) {
                "$($actualKey.Substring(0, 15))..."
            } else {
                "$($actualKey.Substring(0, [Math]::Min(4, $actualKey.Length)))..."
            }

            $available += [PSCustomObject]@{
                Index = $i
                EnvVar = $envVar
                MaskedKey = $maskedKey
                Status = $keyConfig.status
                Failures = $keyConfig.failures
                LastUsed = $keyConfig.lastUsed
                CooldownUntil = $keyConfig.cooldownUntil
                IsAvailable = ($keyConfig.status -eq "active") -and
                              (-not $keyConfig.cooldownUntil -or (Get-Date) -gt [DateTime]::Parse($keyConfig.cooldownUntil))
            }
        }
    }

    return $available
}

function Get-CurrentApiKey {
    <#
    .SYNOPSIS
        Gets the currently active API key for a provider

    .PARAMETER Provider
        Provider name

    .OUTPUTS
        Hashtable with: Key (actual value), Index, EnvVar, or $null if none available
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateSet("anthropic", "openai", "google")]
        [string]$Provider
    )

    $providerState = $script:KeyState[$Provider]
    if (-not $providerState) {
        return $null
    }

    $currentIndex = $providerState.currentKeyIndex
    $keyConfig = $providerState.keys[$currentIndex]

    if (-not $keyConfig) {
        return $null
    }

    $actualKey = [Environment]::GetEnvironmentVariable($keyConfig.envVar)

    if (-not $actualKey) {
        # Current key not set, try to find any available
        $next = Get-NextApiKey -Provider $Provider
        return $next
    }

    return @{
        Key = $actualKey
        Index = $currentIndex
        EnvVar = $keyConfig.envVar
        Status = $keyConfig.status
    }
}

function Get-NextApiKey {
    <#
    .SYNOPSIS
        Gets the next available API key (for rotation/fallback)

    .DESCRIPTION
        Returns the next usable API key, skipping:
        - Keys that are not configured (env var not set)
        - Keys that are rate limited (status = "RateLimited")
        - Keys that are in cooldown period

    .PARAMETER Provider
        Provider name

    .PARAMETER ExcludeCurrentKey
        Skip the current key (useful when current key just failed)

    .OUTPUTS
        Hashtable with: Key, Index, EnvVar, or $null if no keys available
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateSet("anthropic", "openai", "google")]
        [string]$Provider,

        [switch]$ExcludeCurrentKey
    )

    $providerState = $script:KeyState[$Provider]
    if (-not $providerState) {
        Write-Warning "[ApiKeyRotation] Unknown provider: $Provider"
        return $null
    }

    $currentIndex = $providerState.currentKeyIndex
    $keyCount = $providerState.keys.Count
    $now = Get-Date

    # Try each key starting from current+1 (or current if not excluding)
    $startOffset = if ($ExcludeCurrentKey) { 1 } else { 0 }

    for ($offset = $startOffset; $offset -lt $keyCount; $offset++) {
        $tryIndex = ($currentIndex + $offset) % $keyCount
        $keyConfig = $providerState.keys[$tryIndex]

        # Check if key is in cooldown
        if ($keyConfig.cooldownUntil) {
            try {
                $cooldownEnd = [DateTime]::Parse($keyConfig.cooldownUntil)
                if ($now -lt $cooldownEnd) {
                    Write-Verbose "[ApiKeyRotation] Key $tryIndex in cooldown until $cooldownEnd"
                    continue
                }
                else {
                    # Cooldown expired, reset status
                    $keyConfig.status = "active"
                    $keyConfig.cooldownUntil = $null
                }
            }
            catch {
                # Invalid date, reset
                $keyConfig.cooldownUntil = $null
            }
        }

        # Check if key is active
        if ($keyConfig.status -ne "active") {
            Write-Verbose "[ApiKeyRotation] Key $tryIndex status is $($keyConfig.status), skipping"
            continue
        }

        # Check if env var is set
        $actualKey = [Environment]::GetEnvironmentVariable($keyConfig.envVar)
        if (-not $actualKey) {
            Write-Verbose "[ApiKeyRotation] Key $tryIndex ($($keyConfig.envVar)) not configured"
            continue
        }

        # Found a valid key!
        return @{
            Key = $actualKey
            Index = $tryIndex
            EnvVar = $keyConfig.envVar
            Status = $keyConfig.status
        }
    }

    Write-Warning "[ApiKeyRotation] No available API keys for $Provider"
    return $null
}

function Set-ApiKeyStatus {
    <#
    .SYNOPSIS
        Updates the status of an API key

    .PARAMETER Provider
        Provider name

    .PARAMETER KeyIndex
        Index of the key (0-based)

    .PARAMETER Status
        New status: "active", "RateLimited", "Invalid", "Disabled"

    .PARAMETER CooldownMinutes
        If rate limited, how long to wait before retrying (default: 60)
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateSet("anthropic", "openai", "google")]
        [string]$Provider,

        [Parameter(Mandatory)]
        [int]$KeyIndex,

        [Parameter(Mandatory)]
        [ValidateSet("active", "RateLimited", "Invalid", "Disabled")]
        [string]$Status,

        [int]$CooldownMinutes = 60
    )

    $providerState = $script:KeyState[$Provider]
    if (-not $providerState -or $KeyIndex -ge $providerState.keys.Count) {
        Write-Warning "[ApiKeyRotation] Invalid provider or key index"
        return
    }

    $keyConfig = $providerState.keys[$KeyIndex]
    $keyConfig.status = $Status
    $keyConfig.lastUsed = (Get-Date).ToString("o")

    if ($Status -eq "RateLimited") {
        $keyConfig.failures++
        $keyConfig.cooldownUntil = (Get-Date).AddMinutes($CooldownMinutes).ToString("o")
        Write-Host "[ApiKeyRotation] Key $KeyIndex for $Provider rate limited, cooldown until $($keyConfig.cooldownUntil)" -ForegroundColor Yellow
    }
    elseif ($Status -eq "active") {
        $keyConfig.cooldownUntil = $null
    }

    Save-KeyState
}

function Switch-ToNextApiKey {
    <#
    .SYNOPSIS
        Switches to the next available API key

    .DESCRIPTION
        Called when current key hits rate limit. Updates currentKeyIndex
        and returns the new key. This is the PRIMARY fallback action.

    .PARAMETER Provider
        Provider name

    .PARAMETER MarkCurrentAsRateLimited
        If true, marks the current key as rate limited with cooldown

    .PARAMETER CooldownMinutes
        Cooldown duration for rate limited key

    .OUTPUTS
        Hashtable with new key info, or $null if no alternates available
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateSet("anthropic", "openai", "google")]
        [string]$Provider,

        [switch]$MarkCurrentAsRateLimited,

        [int]$CooldownMinutes = 60
    )

    $providerState = $script:KeyState[$Provider]
    if (-not $providerState) {
        return $null
    }

    $currentIndex = $providerState.currentKeyIndex

    # Mark current as rate limited if requested
    if ($MarkCurrentAsRateLimited) {
        Set-ApiKeyStatus -Provider $Provider -KeyIndex $currentIndex -Status "RateLimited" -CooldownMinutes $CooldownMinutes
    }

    # Get next available key
    $nextKey = Get-NextApiKey -Provider $Provider -ExcludeCurrentKey

    if ($nextKey) {
        # Update current index
        $providerState.currentKeyIndex = $nextKey.Index
        Save-KeyState

        Write-Host "[ApiKeyRotation] Switched $Provider from key $currentIndex to key $($nextKey.Index)" -ForegroundColor Green
        return $nextKey
    }

    return $null
}

function Test-AlternateKeyAvailable {
    <#
    .SYNOPSIS
        Checks if there's an alternate API key available for fallback

    .DESCRIPTION
        Quick check to determine if key rotation is possible before
        falling back to model switching.

    .PARAMETER Provider
        Provider name

    .OUTPUTS
        Boolean - true if at least one alternate key is available
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory)]
        [ValidateSet("anthropic", "openai", "google")]
        [string]$Provider
    )

    $available = Get-AvailableApiKeys -Provider $Provider
    $activeCount = ($available | Where-Object { $_.IsAvailable }).Count

    return $activeCount -gt 1
}

function Reset-ApiKeyState {
    <#
    .SYNOPSIS
        Resets all API key states to active

    .DESCRIPTION
        Clears all rate limits, cooldowns, and failure counts.
        Useful after rate limit windows expire or for testing.

    .PARAMETER Provider
        Specific provider to reset, or all if not specified
    #>
    [CmdletBinding()]
    param(
        [ValidateSet("anthropic", "openai", "google")]
        [string]$Provider
    )

    $providers = if ($Provider) { @($Provider) } else { $script:KeyState.Keys }

    foreach ($p in $providers) {
        $providerState = $script:KeyState[$p]
        if ($providerState) {
            $providerState.currentKeyIndex = 0
            foreach ($key in $providerState.keys) {
                $key.status = "active"
                $key.failures = 0
                $key.cooldownUntil = $null
            }
        }
    }

    Save-KeyState
    Write-Host "[ApiKeyRotation] Reset API key state for: $($providers -join ', ')" -ForegroundColor Green
}

function Get-ApiKeyRotationStatus {
    <#
    .SYNOPSIS
        Gets comprehensive status of all API keys

    .OUTPUTS
        Formatted status table
    #>
    [CmdletBinding()]
    param()

    Write-Host "`n=== API Key Rotation Status ===" -ForegroundColor Cyan

    foreach ($provider in $script:KeyState.Keys) {
        $available = Get-AvailableApiKeys -Provider $provider
        $current = $script:KeyState[$provider].currentKeyIndex

        Write-Host "`n[$provider] Current Index: $current" -ForegroundColor Yellow

        if ($available.Count -eq 0) {
            Write-Host "  No keys configured" -ForegroundColor DarkGray
            continue
        }

        foreach ($key in $available) {
            $marker = if ($key.Index -eq $current) { " <- ACTIVE" } else { "" }
            $statusColor = switch ($key.Status) {
                "active" { if ($key.IsAvailable) { "Green" } else { "Yellow" } }
                "RateLimited" { "Red" }
                "Invalid" { "DarkRed" }
                default { "Gray" }
            }

            Write-Host ("  [{0}] {1} = {2} | Status: {3} | Failures: {4}{5}" -f
                $key.Index,
                $key.EnvVar,
                $key.MaskedKey,
                $key.Status,
                $key.Failures,
                $marker
            ) -ForegroundColor $statusColor

            if ($key.CooldownUntil) {
                Write-Host "      Cooldown until: $($key.CooldownUntil)" -ForegroundColor DarkGray
            }
        }
    }

    Write-Host ""
}

# ============================================================================
# MODULE EXPORTS
# ============================================================================

Export-ModuleMember -Function @(
    # Query functions
    'Get-AvailableApiKeys',
    'Get-CurrentApiKey',
    'Get-NextApiKey',
    'Test-AlternateKeyAvailable',
    'Get-ApiKeyRotationStatus',

    # Mutation functions
    'Set-ApiKeyStatus',
    'Switch-ToNextApiKey',
    'Reset-ApiKeyState'
)

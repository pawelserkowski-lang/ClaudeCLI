#Requires -Version 5.1
<#
.SYNOPSIS
    AI Handler State Management Module.

.DESCRIPTION
    Provides centralized state management for the AI Handler system including:
    - Runtime state tracking (current provider, model, usage, errors)
    - Persistent state storage to JSON file
    - Usage tracking initialization per provider/model
    - State reset and update operations

    This module extracts state management logic from AIModelHandler.psm1 into
    a dedicated core module for better separation of concerns.

.NOTES
    Module: AIState
    Author: HYDRA AI Handler
    Version: 1.0.0
    Requires: AIUtil-JsonIO.psm1

.EXAMPLE
    Import-Module .\core\AIState.psm1
    Initialize-AIState
    $state = Get-AIState
#>

# Import JSON utilities
$script:JsonIOPath = Join-Path (Split-Path $PSScriptRoot -Parent) "utils\AIUtil-JsonIO.psm1"
if (Test-Path $script:JsonIOPath) {
    Import-Module $script:JsonIOPath -Force -ErrorAction SilentlyContinue
}

# State file path - located in ai-handler root directory
$script:StatePath = Join-Path (Split-Path $PSScriptRoot -Parent) "ai-state.json"

# Runtime state - in-memory state for current session
$script:RuntimeState = @{
    currentProvider = "anthropic"
    currentModel    = "claude-sonnet-4-5-20250929"
    usage           = @{}
    errors          = @()
    lastRequest     = $null
}

function Get-AIState {
    <#
    .SYNOPSIS
        Retrieves the current AI Handler state.

    .DESCRIPTION
        Loads state from the persistent JSON file if it exists, otherwise
        returns the current runtime state. Supports both encrypted and
        plain JSON storage when SecureStorage module is available.

    .PARAMETER FromFile
        Forces reading from the state file even if runtime state exists.

    .EXAMPLE
        $state = Get-AIState

    .EXAMPLE
        $state = Get-AIState -FromFile

    .OUTPUTS
        System.Collections.Hashtable
        Returns a hashtable containing:
        - currentProvider: The active AI provider name
        - currentModel: The active model identifier
        - usage: Nested hashtable of usage stats per provider/model
        - errors: Array of recent error records
        - lastRequest: Timestamp of most recent API request
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory = $false)]
        [switch]$FromFile
    )

    if ($FromFile -or (Test-Path $script:StatePath)) {
        try {
            # Try encrypted storage if available
            if (Get-Command Read-EncryptedJson -ErrorAction SilentlyContinue) {
                $state = Read-EncryptedJson -Path $script:StatePath
                if ($state) { return $state }
            }

            # Fall back to plain JSON via AIUtil-JsonIO
            if (Get-Command Read-JsonFile -ErrorAction SilentlyContinue) {
                $state = Read-JsonFile -Path $script:StatePath -Default $null
                if ($state) {
                    # Convert PSObject to hashtable for PS 5.1 compatibility
                    if (Get-Command ConvertTo-Hashtable -ErrorAction SilentlyContinue) {
                        return ConvertTo-Hashtable -InputObject $state
                    }
                    return $state
                }
            }

            # Direct JSON read as last resort
            if (Test-Path $script:StatePath) {
                $content = Get-Content $script:StatePath -Raw -Encoding UTF8
                $parsed = $content | ConvertFrom-Json
                # Manual hashtable conversion for PS 5.1
                return ConvertPSObjectToHashtable $parsed
            }
        }
        catch {
            Write-Warning "Failed to load state from file, using runtime state: $($_.Exception.Message)"
        }
    }

    return $script:RuntimeState
}

function Save-AIState {
    <#
    .SYNOPSIS
        Persists the AI Handler state to the JSON file.

    .DESCRIPTION
        Saves the provided state hashtable to the persistent JSON file.
        Uses encrypted storage when SecureStorage module is available,
        otherwise falls back to atomic JSON writes via AIUtil-JsonIO.

    .PARAMETER State
        The state hashtable to persist. If not provided, saves the current
        runtime state.

    .EXAMPLE
        Save-AIState -State $state

    .EXAMPLE
        # Save current runtime state
        Save-AIState

    .OUTPUTS
        System.Boolean
        Returns $true on success, $false on failure.
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory = $false, Position = 0)]
        [hashtable]$State
    )

    if (-not $State) {
        $State = $script:RuntimeState
    }

    try {
        # Try encrypted storage if available
        if (Get-Command Write-EncryptedJson -ErrorAction SilentlyContinue) {
            Write-EncryptedJson -Data $State -Path $script:StatePath
            return $true
        }

        # Use AIUtil-JsonIO for atomic writes
        if (Get-Command Write-JsonFile -ErrorAction SilentlyContinue) {
            return Write-JsonFile -Path $script:StatePath -Data $State -Depth 10
        }

        # Direct JSON write as fallback
        $State | ConvertTo-Json -Depth 10 | Set-Content $script:StatePath -Encoding UTF8
        return $true
    }
    catch {
        Write-Warning "Failed to save AI state: $($_.Exception.Message)"
        return $false
    }
}

function Initialize-AIState {
    <#
    .SYNOPSIS
        Initializes usage tracking for all configured providers and models.

    .DESCRIPTION
        Loads the current state and ensures usage tracking structures exist
        for every provider and model defined in the AI configuration.
        Creates default usage counters for any missing entries including:
        - tokensThisMinute / requestsThisMinute: Rate limit tracking
        - lastMinuteReset: Timestamp for rate limit window
        - totalTokens / totalRequests / totalCost: Cumulative usage
        - errors: Error count per model

        Also triggers model discovery if enabled in configuration.

    .PARAMETER ConfigGetter
        Optional scriptblock that returns the AI configuration hashtable.
        Used for dependency injection during testing.

    .EXAMPLE
        Initialize-AIState

    .EXAMPLE
        # With custom config getter
        Initialize-AIState -ConfigGetter { Get-MyAIConfig }

    .OUTPUTS
        System.Collections.Hashtable
        Returns the initialized state hashtable.
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory = $false)]
        [scriptblock]$ConfigGetter
    )

    # Get configuration
    $config = if ($ConfigGetter) {
        & $ConfigGetter
    }
    elseif (Get-Command Get-AIConfig -ErrorAction SilentlyContinue) {
        Get-AIConfig
    }
    else {
        Write-Warning "No AI configuration available - using empty config"
        @{ providers = @{}; settings = @{ modelDiscovery = @{ enabled = $false } } }
    }

    # Run model discovery if enabled
    if ($config.settings.modelDiscovery.enabled -and (Get-Command Initialize-ModelDiscovery -ErrorAction SilentlyContinue)) {
        try {
            $discoveryParams = @{
                UpdateConfig   = $config.settings.modelDiscovery.updateConfigOnStart
                Silent         = $true
                SkipValidation = $config.settings.modelDiscovery.skipValidation
                Parallel       = $config.settings.modelDiscovery.parallel
                ErrorAction    = 'SilentlyContinue'
            }
            $discovery = Initialize-ModelDiscovery @discoveryParams
            if ($discovery) {
                $script:DiscoveredModels = $discovery
            }
        }
        catch {
            Write-Warning "Model discovery failed: $($_.Exception.Message)"
        }
    }

    # Load current state
    $state = Get-AIState

    # Ensure usage hashtable exists
    if (-not $state.usage -or $state.usage -isnot [hashtable]) {
        $state.usage = @{}
    }

    # Initialize usage tracking per provider/model
    foreach ($providerName in $config.providers.Keys) {
        if (-not $state.usage[$providerName]) {
            $state.usage[$providerName] = @{}
        }

        $provider = $config.providers[$providerName]
        if ($provider.models -and $provider.models -is [hashtable]) {
            foreach ($modelName in $provider.models.Keys) {
                if (-not $state.usage[$providerName][$modelName]) {
                    $state.usage[$providerName][$modelName] = @{
                        tokensThisMinute   = 0
                        requestsThisMinute = 0
                        lastMinuteReset    = (Get-Date).ToString("o")
                        totalTokens        = 0
                        totalRequests      = 0
                        totalCost          = 0.0
                        errors             = 0
                    }
                }
            }
        }
    }

    # Update runtime state and persist
    $script:RuntimeState = $state
    Save-AIState $state

    return $state
}

function Reset-AIState {
    <#
    .SYNOPSIS
        Resets all usage tracking and error counts.

    .DESCRIPTION
        Clears all usage data, error counts, and resets the runtime state
        to default values. Requires confirmation unless -Force is specified.

    .PARAMETER Force
        Skips the confirmation prompt and resets immediately.

    .EXAMPLE
        Reset-AIState

    .EXAMPLE
        Reset-AIState -Force

    .OUTPUTS
        None. Displays confirmation message on completion.
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory = $false)]
        [switch]$Force
    )

    if (-not $Force) {
        $confirm = Read-Host "Reset all AI usage data? (y/N)"
        if ($confirm -ne "y") {
            Write-Host "Cancelled" -ForegroundColor Yellow
            return
        }
    }

    $script:RuntimeState = @{
        currentProvider = "anthropic"
        currentModel    = "claude-sonnet-4-5-20250929"
        usage           = @{}
        errors          = @()
        lastRequest     = $null
    }

    Initialize-AIState
    Write-Host "[AI] State reset complete" -ForegroundColor Green
}

function Update-AIState {
    <#
    .SYNOPSIS
        Updates specific properties of the AI Handler state.

    .DESCRIPTION
        Allows partial updates to the runtime state without replacing
        the entire state object. Supports updating individual properties
        or nested usage data.

    .PARAMETER Property
        The name of the top-level property to update.
        Valid values: currentProvider, currentModel, usage, errors, lastRequest

    .PARAMETER Value
        The new value for the specified property.

    .PARAMETER Provider
        When updating usage data, the provider name.

    .PARAMETER Model
        When updating usage data, the model name.

    .PARAMETER UsageData
        When updating usage data, a hashtable of usage properties to update.

    .PARAMETER Persist
        If specified, immediately saves the state to the JSON file.

    .EXAMPLE
        Update-AIState -Property currentProvider -Value "openai" -Persist

    .EXAMPLE
        Update-AIState -Property currentModel -Value "gpt-4o-mini"

    .EXAMPLE
        Update-AIState -Provider "anthropic" -Model "claude-3-5-haiku" `
            -UsageData @{ totalRequests = 100; totalTokens = 50000 } -Persist

    .OUTPUTS
        System.Collections.Hashtable
        Returns the updated state hashtable.
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory = $false, ParameterSetName = "Property")]
        [ValidateSet("currentProvider", "currentModel", "usage", "errors", "lastRequest")]
        [string]$Property,

        [Parameter(Mandatory = $false, ParameterSetName = "Property")]
        [object]$Value,

        [Parameter(Mandatory = $false, ParameterSetName = "Usage")]
        [string]$Provider,

        [Parameter(Mandatory = $false, ParameterSetName = "Usage")]
        [string]$Model,

        [Parameter(Mandatory = $false, ParameterSetName = "Usage")]
        [hashtable]$UsageData,

        [Parameter(Mandatory = $false)]
        [switch]$Persist
    )

    $state = $script:RuntimeState

    if ($PSCmdlet.ParameterSetName -eq "Property" -and $Property) {
        $state[$Property] = $Value
    }
    elseif ($PSCmdlet.ParameterSetName -eq "Usage" -and $Provider -and $Model -and $UsageData) {
        # Ensure nested structure exists
        if (-not $state.usage[$Provider]) {
            $state.usage[$Provider] = @{}
        }
        if (-not $state.usage[$Provider][$Model]) {
            $state.usage[$Provider][$Model] = @{
                tokensThisMinute   = 0
                requestsThisMinute = 0
                lastMinuteReset    = (Get-Date).ToString("o")
                totalTokens        = 0
                totalRequests      = 0
                totalCost          = 0.0
                errors             = 0
            }
        }

        # Update specified usage properties
        foreach ($key in $UsageData.Keys) {
            $state.usage[$Provider][$Model][$key] = $UsageData[$key]
        }
    }

    $script:RuntimeState = $state

    if ($Persist) {
        Save-AIState $state
    }

    return $state
}

#region Internal Helpers

function ConvertPSObjectToHashtable {
    <#
    .SYNOPSIS
        Internal helper to convert PSObject to hashtable.
    #>
    [CmdletBinding()]
    param([object]$InputObject)

    if ($null -eq $InputObject) { return $null }

    if ($InputObject -is [System.Management.Automation.PSCustomObject]) {
        $hash = @{}
        foreach ($prop in $InputObject.PSObject.Properties) {
            $hash[$prop.Name] = ConvertPSObjectToHashtable $prop.Value
        }
        return $hash
    }

    if ($InputObject -is [System.Collections.IEnumerable] -and $InputObject -isnot [string]) {
        $arr = @()
        foreach ($item in $InputObject) {
            $arr += ConvertPSObjectToHashtable $item
        }
        return $arr
    }

    return $InputObject
}

#endregion

# Export module members
Export-ModuleMember -Function @(
    'Get-AIState',
    'Save-AIState',
    'Initialize-AIState',
    'Reset-AIState',
    'Update-AIState'
) -Variable @(
    'StatePath',
    'RuntimeState'
)

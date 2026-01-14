#Requires -Version 5.1
<#
.SYNOPSIS
    AI Configuration Management Module for AI Handler
.DESCRIPTION
    Centralized configuration management for the AI Handler system including:
    - Provider configurations (Anthropic, OpenAI, Google, Mistral, Groq, Ollama)
    - Model definitions with pricing, capabilities, and rate limits
    - Fallback chains and provider ordering
    - System settings for retry, rate limiting, and cost optimization
.VERSION
    1.0.0
.AUTHOR
    HYDRA System
.NOTES
    Extracted from AIModelHandler.psm1 for modular architecture
#>

# Import JSON I/O utilities
$script:JsonIOPath = Join-Path (Split-Path $PSScriptRoot -Parent) "utils\AIUtil-JsonIO.psm1"
if (Test-Path $script:JsonIOPath) {
    Import-Module $script:JsonIOPath -Force -ErrorAction Stop
}
else {
    throw "Required module AIUtil-JsonIO.psm1 not found at: $script:JsonIOPath"
}

#region Configuration Paths

$script:ConfigPath = Join-Path (Split-Path $PSScriptRoot -Parent) "ai-config.json"

#endregion

#region Default Configuration

$script:DefaultConfig = @{
    providers = @{
        anthropic = @{
            name         = "Anthropic"
            baseUrl      = "https://api.anthropic.com/v1"
            apiKeyEnv    = "ANTHROPIC_API_KEY"
            priority     = 1
            enabled      = $true
            models       = @{
                "claude-opus-4-5-20251101"   = @{
                    tier              = "pro"
                    contextWindow     = 200000
                    maxOutput         = 32000
                    inputCost         = 15.00
                    outputCost        = 75.00
                    tokensPerMinute   = 40000
                    requestsPerMinute = 50
                    capabilities      = @("vision", "code", "analysis", "creative")
                }
                "claude-sonnet-4-5-20250929" = @{
                    tier              = "standard"
                    contextWindow     = 200000
                    maxOutput         = 16000
                    inputCost         = 3.00
                    outputCost        = 15.00
                    tokensPerMinute   = 80000
                    requestsPerMinute = 100
                    capabilities      = @("vision", "code", "analysis")
                }
                "claude-haiku-4-20250604"    = @{
                    tier              = "lite"
                    contextWindow     = 200000
                    maxOutput         = 8000
                    inputCost         = 0.80
                    outputCost        = 4.00
                    tokensPerMinute   = 100000
                    requestsPerMinute = 200
                    capabilities      = @("code", "analysis")
                }
            }
        }
        openai    = @{
            name         = "OpenAI"
            baseUrl      = "https://api.openai.com/v1"
            apiKeyEnv    = "OPENAI_API_KEY"
            priority     = 2
            enabled      = $true
            models       = @{
                "gpt-4o"      = @{
                    tier              = "pro"
                    contextWindow     = 128000
                    maxOutput         = 16384
                    inputCost         = 2.50
                    outputCost        = 10.00
                    tokensPerMinute   = 30000
                    requestsPerMinute = 500
                    capabilities      = @("vision", "code", "analysis")
                }
                "gpt-4o-mini" = @{
                    tier              = "lite"
                    contextWindow     = 128000
                    maxOutput         = 16384
                    inputCost         = 0.15
                    outputCost        = 0.60
                    tokensPerMinute   = 200000
                    requestsPerMinute = 500
                    capabilities      = @("code", "analysis")
                }
            }
        }
        google    = @{
            name         = "Google"
            baseUrl      = "https://generativelanguage.googleapis.com/v1beta"
            apiKeyEnv    = "GOOGLE_API_KEY"
            priority     = 3
            enabled      = $true
            models       = @{
                "gemini-1.5-pro"   = @{
                    tier              = "pro"
                    contextWindow     = 128000
                    maxOutput         = 8192
                    inputCost         = 3.50
                    outputCost        = 10.50
                    tokensPerMinute   = 60000
                    requestsPerMinute = 60
                    capabilities      = @("vision", "code", "analysis")
                }
                "gemini-1.5-flash" = @{
                    tier              = "lite"
                    contextWindow     = 128000
                    maxOutput         = 8192
                    inputCost         = 0.35
                    outputCost        = 1.05
                    tokensPerMinute   = 120000
                    requestsPerMinute = 120
                    capabilities      = @("vision", "code", "analysis")
                }
            }
        }
        mistral   = @{
            name         = "Mistral"
            baseUrl      = "https://api.mistral.ai/v1"
            apiKeyEnv    = "MISTRAL_API_KEY"
            priority     = 4
            enabled      = $true
            models       = @{
                "mistral-large-latest" = @{
                    tier              = "pro"
                    contextWindow     = 128000
                    maxOutput         = 8192
                    inputCost         = 2.00
                    outputCost        = 6.00
                    tokensPerMinute   = 60000
                    requestsPerMinute = 60
                    capabilities      = @("code", "analysis")
                }
                "mistral-small-latest" = @{
                    tier              = "lite"
                    contextWindow     = 32000
                    maxOutput         = 8192
                    inputCost         = 0.20
                    outputCost        = 0.60
                    tokensPerMinute   = 120000
                    requestsPerMinute = 120
                    capabilities      = @("code", "analysis")
                }
            }
        }
        groq      = @{
            name         = "Groq"
            baseUrl      = "https://api.groq.com/openai/v1"
            apiKeyEnv    = "GROQ_API_KEY"
            priority     = 5
            enabled      = $true
            models       = @{
                "llama-3.1-70b-versatile" = @{
                    tier              = "pro"
                    contextWindow     = 128000
                    maxOutput         = 8192
                    inputCost         = 0.59
                    outputCost        = 0.79
                    tokensPerMinute   = 70000
                    requestsPerMinute = 120
                    capabilities      = @("code", "analysis")
                }
                "llama-3.1-8b-instant"    = @{
                    tier              = "lite"
                    contextWindow     = 128000
                    maxOutput         = 8192
                    inputCost         = 0.05
                    outputCost        = 0.08
                    tokensPerMinute   = 120000
                    requestsPerMinute = 300
                    capabilities      = @("code", "analysis")
                }
            }
        }
        ollama    = @{
            name         = "Ollama (Local)"
            baseUrl      = "http://localhost:11434/api"
            apiKeyEnv    = $null
            priority     = 6
            enabled      = $true
            models       = @{
                "llama3.3:70b"       = @{
                    tier              = "standard"
                    contextWindow     = 128000
                    maxOutput         = 8000
                    inputCost         = 0.00
                    outputCost        = 0.00
                    tokensPerMinute   = 999999
                    requestsPerMinute = 999999
                    capabilities      = @("code", "analysis")
                }
                "qwen2.5-coder:32b" = @{
                    tier              = "lite"
                    contextWindow     = 32000
                    maxOutput         = 8000
                    inputCost         = 0.00
                    outputCost        = 0.00
                    tokensPerMinute   = 999999
                    requestsPerMinute = 999999
                    capabilities      = @("code")
                }
            }
        }
    }

    fallbackChain         = @{
        anthropic = @("claude-opus-4-5-20251101", "claude-sonnet-4-5-20250929", "claude-haiku-4-20250604")
        openai    = @("gpt-4o", "gpt-4o-mini")
        google    = @("gemini-1.5-pro", "gemini-1.5-flash")
        mistral   = @("mistral-large-latest", "mistral-small-latest")
        groq      = @("llama-3.1-70b-versatile", "llama-3.1-8b-instant")
        ollama    = @("llama3.3:70b", "qwen2.5-coder:32b")
    }

    providerFallbackOrder = @("anthropic", "openai", "google", "mistral", "groq", "ollama")

    settings              = @{
        maxRetries         = 3
        retryDelayMs       = 1000
        rateLimitThreshold = 0.85
        costOptimization   = $true
        autoFallback       = $true
        logLevel           = "info"
        logFormat          = "json"
        streamResponses    = $true
        outputTokenRatio   = 0.5
        modelDiscovery     = @{
            enabled             = $true
            updateConfigOnStart = $true
            parallel            = $true
            skipValidation      = $false
        }
    }
}

#endregion

#region Configuration Functions

function Get-AIConfig {
    <#
    .SYNOPSIS
        Loads AI configuration from JSON file or returns defaults
    .DESCRIPTION
        Attempts to load configuration from ai-config.json.
        If file doesn't exist or parsing fails, returns default configuration.
        Merges loaded config with defaults to ensure all required keys exist.
    .OUTPUTS
        Hashtable containing AI configuration
    .EXAMPLE
        $config = Get-AIConfig
        $config.providers.anthropic.models
    .NOTES
        Configuration path: ai-handler/ai-config.json
    #>
    [CmdletBinding()]
    param()

    if (Test-Path $script:ConfigPath) {
        try {
            $config = Read-JsonFile -Path $script:ConfigPath -AsHashtable
            if ($config) {
                # Merge with defaults to ensure all keys exist
                return Merge-Config -UserConfig $config -DefaultConfig $script:DefaultConfig
            }
        }
        catch {
            Write-Warning "Failed to load config from $script:ConfigPath, using defaults: $($_.Exception.Message)"
        }
    }

    return $script:DefaultConfig.Clone()
}

function Save-AIConfig {
    <#
    .SYNOPSIS
        Saves AI configuration to JSON file
    .DESCRIPTION
        Serializes the configuration hashtable to JSON and writes to ai-config.json
        using atomic write operations to prevent data corruption.
    .PARAMETER Config
        Configuration hashtable to save
    .EXAMPLE
        $config = Get-AIConfig
        $config.settings.maxRetries = 5
        Save-AIConfig -Config $config
    .NOTES
        Uses atomic file write for safety
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [hashtable]$Config
    )

    if (-not (Test-ConfigValid -Config $Config)) {
        Write-Warning "Configuration validation failed. Config not saved."
        return $false
    }

    $success = Write-JsonFileAtomic -Path $script:ConfigPath -Data $Config -Depth 10

    if ($success) {
        Write-Host "[AI] Config saved to $script:ConfigPath" -ForegroundColor Green
    }
    else {
        Write-Warning "[AI] Failed to save config to $script:ConfigPath"
    }

    return $success
}

function Get-DefaultConfig {
    <#
    .SYNOPSIS
        Returns the default AI configuration
    .DESCRIPTION
        Returns a clone of the default configuration hashtable.
        Useful for resetting configuration or comparing with current config.
    .OUTPUTS
        Hashtable containing default AI configuration
    .EXAMPLE
        $defaults = Get-DefaultConfig
    #>
    [CmdletBinding()]
    param()

    return $script:DefaultConfig.Clone()
}

function Merge-Config {
    <#
    .SYNOPSIS
        Merges user configuration with defaults
    .DESCRIPTION
        Deep merges user configuration with default configuration.
        User values take precedence, but missing keys are filled from defaults.
        This ensures configuration completeness after updates.
    .PARAMETER UserConfig
        User's configuration hashtable (partial or complete)
    .PARAMETER DefaultConfig
        Default configuration hashtable (complete)
    .OUTPUTS
        Merged hashtable with all required keys
    .EXAMPLE
        $merged = Merge-Config -UserConfig $loaded -DefaultConfig $defaults
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [hashtable]$UserConfig,

        [Parameter(Mandatory)]
        [hashtable]$DefaultConfig
    )

    $result = @{}

    # Start with all default keys
    foreach ($key in $DefaultConfig.Keys) {
        $defaultValue = $DefaultConfig[$key]
        $userValue = $UserConfig[$key]

        if ($null -eq $userValue) {
            # User doesn't have this key, use default
            if ($defaultValue -is [hashtable]) {
                $result[$key] = $defaultValue.Clone()
            }
            elseif ($defaultValue -is [array]) {
                $result[$key] = @() + $defaultValue
            }
            else {
                $result[$key] = $defaultValue
            }
        }
        elseif ($defaultValue -is [hashtable] -and $userValue -is [hashtable]) {
            # Both are hashtables, merge recursively
            $result[$key] = Merge-Config -UserConfig $userValue -DefaultConfig $defaultValue
        }
        else {
            # Use user's value
            $result[$key] = $userValue
        }
    }

    # Add any user keys not in defaults (preserve custom additions)
    foreach ($key in $UserConfig.Keys) {
        if (-not $result.ContainsKey($key)) {
            $result[$key] = $UserConfig[$key]
        }
    }

    return $result
}

function Test-ConfigValid {
    <#
    .SYNOPSIS
        Validates configuration structure
    .DESCRIPTION
        Checks that the configuration has all required top-level keys
        and that the structure is valid for the AI Handler system.
    .PARAMETER Config
        Configuration hashtable to validate
    .OUTPUTS
        Boolean indicating validity
    .EXAMPLE
        if (Test-ConfigValid -Config $config) { Save-AIConfig -Config $config }
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [hashtable]$Config
    )

    $requiredKeys = @('providers', 'fallbackChain', 'providerFallbackOrder', 'settings')
    $valid = $true
    $errors = @()

    # Check required top-level keys
    foreach ($key in $requiredKeys) {
        if (-not $Config.ContainsKey($key)) {
            $errors += "Missing required key: $key"
            $valid = $false
        }
    }

    # Validate providers structure
    if ($Config.providers) {
        foreach ($providerName in $Config.providers.Keys) {
            $provider = $Config.providers[$providerName]

            if (-not ($provider -is [hashtable])) {
                $errors += "Provider '$providerName' is not a hashtable"
                $valid = $false
                continue
            }

            $requiredProviderKeys = @('name', 'baseUrl', 'enabled', 'models')
            foreach ($pKey in $requiredProviderKeys) {
                if (-not $provider.ContainsKey($pKey)) {
                    $errors += "Provider '$providerName' missing key: $pKey"
                    $valid = $false
                }
            }
        }
    }

    # Validate settings structure
    if ($Config.settings) {
        $requiredSettings = @('maxRetries', 'rateLimitThreshold', 'autoFallback')
        foreach ($sKey in $requiredSettings) {
            if (-not $Config.settings.ContainsKey($sKey)) {
                $errors += "Settings missing key: $sKey"
                $valid = $false
            }
        }
    }

    # Validate fallbackChain matches providers
    if ($Config.fallbackChain -and $Config.providers) {
        foreach ($chainProvider in $Config.fallbackChain.Keys) {
            if (-not $Config.providers.ContainsKey($chainProvider)) {
                $errors += "Fallback chain references unknown provider: $chainProvider"
                $valid = $false
            }
        }
    }

    # Validate providerFallbackOrder matches providers
    if ($Config.providerFallbackOrder -and $Config.providers) {
        foreach ($orderProvider in $Config.providerFallbackOrder) {
            if (-not $Config.providers.ContainsKey($orderProvider)) {
                $errors += "Provider fallback order references unknown provider: $orderProvider"
                $valid = $false
            }
        }
    }

    if (-not $valid -and $errors.Count -gt 0) {
        Write-Warning "Configuration validation errors:"
        foreach ($error in $errors) {
            Write-Warning "  - $error"
        }
    }

    return $valid
}

function Get-ConfigPath {
    <#
    .SYNOPSIS
        Returns the path to the configuration file
    .DESCRIPTION
        Returns the full path to ai-config.json for external reference.
    .OUTPUTS
        String path to configuration file
    .EXAMPLE
        $path = Get-ConfigPath
    #>
    [CmdletBinding()]
    param()

    return $script:ConfigPath
}

function Set-ConfigPath {
    <#
    .SYNOPSIS
        Sets a custom configuration file path
    .DESCRIPTION
        Allows overriding the default configuration file location.
        Useful for testing or alternative configurations.
    .PARAMETER Path
        Full path to the configuration JSON file
    .EXAMPLE
        Set-ConfigPath -Path "C:\custom\ai-config.json"
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    $script:ConfigPath = $Path
    Write-Verbose "Config path set to: $Path"
}

function Reset-ConfigToDefaults {
    <#
    .SYNOPSIS
        Resets configuration to defaults
    .DESCRIPTION
        Saves the default configuration to the config file,
        overwriting any custom settings.
    .PARAMETER Force
        Skip confirmation prompt
    .EXAMPLE
        Reset-ConfigToDefaults -Force
    #>
    [CmdletBinding()]
    param(
        [switch]$Force
    )

    if (-not $Force) {
        $confirm = Read-Host "Reset AI config to defaults? This will overwrite current config. (y/N)"
        if ($confirm -ne "y") {
            Write-Host "Cancelled" -ForegroundColor Yellow
            return $false
        }
    }

    $success = Save-AIConfig -Config $script:DefaultConfig
    if ($success) {
        Write-Host "[AI] Configuration reset to defaults" -ForegroundColor Green
    }

    return $success
}

#endregion

#region Exports

Export-ModuleMember -Function @(
    'Get-AIConfig',
    'Save-AIConfig',
    'Get-DefaultConfig',
    'Merge-Config',
    'Test-ConfigValid',
    'Get-ConfigPath',
    'Set-ConfigPath',
    'Reset-ConfigToDefaults'
)

#endregion

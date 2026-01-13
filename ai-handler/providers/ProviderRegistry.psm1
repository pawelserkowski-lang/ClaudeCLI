#Requires -Version 5.1
<#
.SYNOPSIS
    Provider Registry Module for AI Handler - Manages all AI provider modules.

.DESCRIPTION
    This module provides centralized management for AI provider modules including:
    - Provider registration and discovery
    - Unified API routing to appropriate providers
    - Provider availability checking
    - Auto-discovery of provider modules from the providers/ directory

.NOTES
    Author: HYDRA AI Handler
    Version: 1.0.0
    Requires: PowerShell 5.1+
#>

# === SCRIPT-LEVEL STATE ===
$script:Providers = @{}
$script:ProvidersPath = $PSScriptRoot
$script:Initialized = $false

# === PROVIDER REGISTRATION ===

function Register-AIProvider {
    <#
    .SYNOPSIS
        Register an AI provider with the registry.

    .DESCRIPTION
        Registers a provider module with the registry, making it available for API calls.
        The provider module must export an Invoke-<ProviderName>API function.

    .PARAMETER Name
        The unique name of the provider (e.g., 'ollama', 'anthropic', 'openai').

    .PARAMETER ModulePath
        The full path to the provider module (.psm1 file).

    .PARAMETER Force
        If specified, overwrites an existing provider registration.

    .EXAMPLE
        Register-AIProvider -Name "ollama" -ModulePath "C:\...\OllamaProvider.psm1"

    .EXAMPLE
        Register-AIProvider -Name "anthropic" -ModulePath "C:\...\AnthropicProvider.psm1" -Force

    .OUTPUTS
        [bool] True if registration succeeded, False otherwise.
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory = $true, Position = 0)]
        [ValidateNotNullOrEmpty()]
        [string]$Name,

        [Parameter(Mandatory = $true, Position = 1)]
        [ValidateScript({ Test-Path $_ -PathType Leaf })]
        [string]$ModulePath,

        [Parameter()]
        [switch]$Force
    )

    try {
        $Name = $Name.ToLower()

        # Check if already registered
        if ($script:Providers.ContainsKey($Name) -and -not $Force) {
            Write-Warning "Provider '$Name' is already registered. Use -Force to overwrite."
            return $false
        }

        # Import the provider module
        $module = Import-Module -Name $ModulePath -PassThru -Force -ErrorAction Stop

        # Verify the module exports required functions
        $invokeFunction = "Invoke-${Name}API"
        $exportedCommands = $module.ExportedCommands.Keys

        # Check for the invoke function (case-insensitive)
        $hasInvokeFunc = $exportedCommands | Where-Object { $_ -ieq $invokeFunction -or $_ -ieq "Invoke-$($Name)Request" }

        if (-not $hasInvokeFunc) {
            Write-Warning "Provider module '$Name' does not export '$invokeFunction' or 'Invoke-$($Name)Request' function."
        }

        # Register the provider
        $script:Providers[$Name] = @{
            Name       = $Name
            ModulePath = $ModulePath
            Module     = $module
            Commands   = $exportedCommands
            LoadedAt   = Get-Date
        }

        Write-Verbose "Registered provider: $Name from $ModulePath"
        return $true
    }
    catch {
        Write-Error "Failed to register provider '$Name': $_"
        return $false
    }
}

function Unregister-AIProvider {
    <#
    .SYNOPSIS
        Unregister an AI provider from the registry.

    .DESCRIPTION
        Removes a provider from the registry and optionally removes the module from memory.

    .PARAMETER Name
        The name of the provider to unregister.

    .PARAMETER RemoveModule
        If specified, also removes the module from memory.

    .EXAMPLE
        Unregister-AIProvider -Name "ollama"

    .OUTPUTS
        [bool] True if unregistration succeeded, False otherwise.
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory = $true, Position = 0)]
        [ValidateNotNullOrEmpty()]
        [string]$Name,

        [Parameter()]
        [switch]$RemoveModule
    )

    $Name = $Name.ToLower()

    if (-not $script:Providers.ContainsKey($Name)) {
        Write-Warning "Provider '$Name' is not registered."
        return $false
    }

    if ($RemoveModule -and $script:Providers[$Name].Module) {
        Remove-Module -Name $script:Providers[$Name].Module.Name -Force -ErrorAction SilentlyContinue
    }

    $script:Providers.Remove($Name)
    Write-Verbose "Unregistered provider: $Name"
    return $true
}

# === PROVIDER RETRIEVAL ===

function Get-AIProvider {
    <#
    .SYNOPSIS
        Get a registered AI provider by name.

    .DESCRIPTION
        Retrieves the provider registration information including module path,
        exported commands, and load time.

    .PARAMETER Name
        The name of the provider to retrieve.

    .EXAMPLE
        Get-AIProvider -Name "ollama"

    .EXAMPLE
        $provider = Get-AIProvider "anthropic"
        $provider.Commands

    .OUTPUTS
        [hashtable] Provider information or $null if not found.
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory = $true, Position = 0)]
        [ValidateNotNullOrEmpty()]
        [string]$Name
    )

    $Name = $Name.ToLower()

    if ($script:Providers.ContainsKey($Name)) {
        return $script:Providers[$Name]
    }

    Write-Verbose "Provider '$Name' not found in registry."
    return $null
}

function Get-AllAIProviders {
    <#
    .SYNOPSIS
        List all registered AI providers.

    .DESCRIPTION
        Returns a list of all registered providers with their status and capabilities.

    .PARAMETER IncludeDetails
        If specified, includes full provider details including exported commands.

    .EXAMPLE
        Get-AllAIProviders

    .EXAMPLE
        Get-AllAIProviders -IncludeDetails | Format-Table

    .OUTPUTS
        [PSCustomObject[]] Array of provider information objects.
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject[]])]
    param(
        [Parameter()]
        [switch]$IncludeDetails
    )

    $providers = @()

    foreach ($name in $script:Providers.Keys) {
        $provider = $script:Providers[$name]

        $obj = [PSCustomObject]@{
            Name       = $provider.Name
            ModulePath = $provider.ModulePath
            LoadedAt   = $provider.LoadedAt
            Available  = (Test-ProviderAvailable -Name $name)
        }

        if ($IncludeDetails) {
            $obj | Add-Member -NotePropertyName 'Commands' -NotePropertyValue $provider.Commands
            $obj | Add-Member -NotePropertyName 'Module' -NotePropertyValue $provider.Module.Name
        }

        $providers += $obj
    }

    return $providers
}

# === API ROUTING ===

function Invoke-ProviderAPI {
    <#
    .SYNOPSIS
        Route an API call to the correct provider.

    .DESCRIPTION
        Delegates API calls to the appropriate provider module based on the Provider parameter.
        Supports all common AI API parameters including streaming.

    .PARAMETER Provider
        The name of the provider to use (e.g., 'ollama', 'anthropic', 'openai').

    .PARAMETER Model
        The model identifier to use for the API call.

    .PARAMETER Messages
        Array of message objects with 'role' and 'content' properties.

    .PARAMETER MaxTokens
        Maximum number of tokens to generate.

    .PARAMETER Temperature
        Sampling temperature (0.0 to 2.0).

    .PARAMETER Stream
        If specified, enables streaming response.

    .PARAMETER SystemPrompt
        Optional system prompt to prepend to messages.

    .PARAMETER Options
        Additional provider-specific options as a hashtable.

    .EXAMPLE
        Invoke-ProviderAPI -Provider "ollama" -Model "llama3.2:3b" -Messages @(@{role="user"; content="Hello"})

    .EXAMPLE
        $response = Invoke-ProviderAPI -Provider "anthropic" -Model "claude-3-5-haiku-latest" `
            -Messages @(@{role="user"; content="Explain AI"}) -MaxTokens 1000

    .OUTPUTS
        [PSCustomObject] API response with Content, Model, Provider, Usage, and Metadata properties.
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory = $true, Position = 0)]
        [ValidateNotNullOrEmpty()]
        [string]$Provider,

        [Parameter(Mandatory = $true, Position = 1)]
        [ValidateNotNullOrEmpty()]
        [string]$Model,

        [Parameter(Mandatory = $true, Position = 2)]
        [ValidateNotNull()]
        [array]$Messages,

        [Parameter()]
        [ValidateRange(1, 128000)]
        [int]$MaxTokens = 4096,

        [Parameter()]
        [ValidateRange(0.0, 2.0)]
        [double]$Temperature = 0.7,

        [Parameter()]
        [switch]$Stream,

        [Parameter()]
        [string]$SystemPrompt,

        [Parameter()]
        [hashtable]$Options = @{}
    )

    $Provider = $Provider.ToLower()

    # Check if provider is registered
    if (-not $script:Providers.ContainsKey($Provider)) {
        throw "Provider '$Provider' is not registered. Available providers: $($script:Providers.Keys -join ', ')"
    }

    # Check provider availability
    if (-not (Test-ProviderAvailable -Name $Provider)) {
        throw "Provider '$Provider' is not available. Check API key or service status."
    }

    $providerInfo = $script:Providers[$Provider]

    # Build the invoke function name (try multiple patterns)
    $invokeFunctions = @(
        "Invoke-${Provider}API",
        "Invoke-${Provider}Request",
        "Invoke-${Provider}Chat"
    )

    $invokeFunc = $null
    foreach ($funcName in $invokeFunctions) {
        $match = $providerInfo.Commands | Where-Object { $_ -ieq $funcName }
        if ($match) {
            $invokeFunc = $match
            break
        }
    }

    if (-not $invokeFunc) {
        throw "Provider '$Provider' module does not export a recognized invoke function. Expected one of: $($invokeFunctions -join ', ')"
    }

    # Prepare parameters for the provider function
    $params = @{
        Model       = $Model
        Messages    = $Messages
        MaxTokens   = $MaxTokens
        Temperature = $Temperature
    }

    if ($Stream) {
        $params['Stream'] = $true
    }

    if ($SystemPrompt) {
        $params['SystemPrompt'] = $SystemPrompt
    }

    # Merge additional options
    foreach ($key in $Options.Keys) {
        if (-not $params.ContainsKey($key)) {
            $params[$key] = $Options[$key]
        }
    }

    # Invoke the provider function
    try {
        Write-Verbose "Routing API call to $Provider using $invokeFunc"
        $startTime = Get-Date

        $response = & $invokeFunc @params

        $endTime = Get-Date
        $duration = ($endTime - $startTime).TotalMilliseconds

        # Normalize response format
        if ($response -is [string]) {
            $response = [PSCustomObject]@{
                Content   = $response
                Model     = $Model
                Provider  = $Provider
                Usage     = @{ TotalTokens = 0 }
                Metadata  = @{ DurationMs = $duration }
            }
        }
        elseif ($response -is [hashtable]) {
            $response = [PSCustomObject]$response
        }

        # Ensure standard properties exist
        if (-not $response.PSObject.Properties['Provider']) {
            $response | Add-Member -NotePropertyName 'Provider' -NotePropertyValue $Provider -Force
        }
        if (-not $response.PSObject.Properties['Model']) {
            $response | Add-Member -NotePropertyName 'Model' -NotePropertyValue $Model -Force
        }

        return $response
    }
    catch {
        Write-Error "Provider '$Provider' API call failed: $_"
        throw
    }
}

# === AVAILABILITY CHECKING ===

function Test-ProviderAvailable {
    <#
    .SYNOPSIS
        Check if a provider is available for use.

    .DESCRIPTION
        Verifies that a provider is registered, has required credentials (if any),
        and the service is reachable.

    .PARAMETER Name
        The name of the provider to check.

    .PARAMETER Quick
        If specified, only checks registration and credentials, not service reachability.

    .EXAMPLE
        Test-ProviderAvailable -Name "ollama"

    .EXAMPLE
        if (Test-ProviderAvailable -Name "anthropic") { # use anthropic }

    .OUTPUTS
        [bool] True if the provider is available, False otherwise.
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory = $true, Position = 0)]
        [ValidateNotNullOrEmpty()]
        [string]$Name,

        [Parameter()]
        [switch]$Quick
    )

    $Name = $Name.ToLower()

    # Check if registered
    if (-not $script:Providers.ContainsKey($Name)) {
        Write-Verbose "Provider '$Name' is not registered."
        return $false
    }

    # Provider-specific availability checks
    switch ($Name) {
        'ollama' {
            # Check if Ollama is running
            if (-not $Quick) {
                try {
                    $null = Invoke-RestMethod -Uri "http://localhost:11434/api/tags" -Method Get -TimeoutSec 2 -ErrorAction Stop
                    return $true
                }
                catch {
                    Write-Verbose "Ollama service not reachable: $_"
                    return $false
                }
            }
            return $true
        }
        'anthropic' {
            # Check for API key
            $apiKey = $env:ANTHROPIC_API_KEY
            if ([string]::IsNullOrWhiteSpace($apiKey)) {
                Write-Verbose "ANTHROPIC_API_KEY environment variable not set."
                return $false
            }
            return $true
        }
        'openai' {
            # Check for API key
            $apiKey = $env:OPENAI_API_KEY
            if ([string]::IsNullOrWhiteSpace($apiKey)) {
                Write-Verbose "OPENAI_API_KEY environment variable not set."
                return $false
            }
            return $true
        }
        'google' {
            # Check for API key
            $apiKey = $env:GOOGLE_API_KEY
            if ([string]::IsNullOrWhiteSpace($apiKey)) {
                Write-Verbose "GOOGLE_API_KEY environment variable not set."
                return $false
            }
            return $true
        }
        'azure' {
            # Check for Azure OpenAI configuration
            $endpoint = $env:AZURE_OPENAI_ENDPOINT
            $apiKey = $env:AZURE_OPENAI_API_KEY
            if ([string]::IsNullOrWhiteSpace($endpoint) -or [string]::IsNullOrWhiteSpace($apiKey)) {
                Write-Verbose "Azure OpenAI configuration incomplete."
                return $false
            }
            return $true
        }
        default {
            # For unknown providers, check if they have a Test-<Provider>Available function
            $testFunc = "Test-${Name}Available"
            $providerInfo = $script:Providers[$Name]

            if ($providerInfo.Commands -contains $testFunc) {
                try {
                    return (& $testFunc)
                }
                catch {
                    Write-Verbose "Provider test function failed: $_"
                    return $false
                }
            }

            # Default to true if registered and no specific check
            return $true
        }
    }
}

function Get-ProviderStatus {
    <#
    .SYNOPSIS
        Get detailed status information for a provider.

    .DESCRIPTION
        Returns comprehensive status information including availability,
        configuration, and any error details.

    .PARAMETER Name
        The name of the provider to check.

    .EXAMPLE
        Get-ProviderStatus -Name "ollama"

    .OUTPUTS
        [PSCustomObject] Status information object.
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory = $true, Position = 0)]
        [ValidateNotNullOrEmpty()]
        [string]$Name
    )

    $Name = $Name.ToLower()
    $status = [PSCustomObject]@{
        Provider    = $Name
        Registered  = $false
        Available   = $false
        HasApiKey   = $false
        Reachable   = $false
        ErrorDetail = $null
        ModulePath  = $null
        LoadedAt    = $null
    }

    # Check registration
    if ($script:Providers.ContainsKey($Name)) {
        $status.Registered = $true
        $status.ModulePath = $script:Providers[$Name].ModulePath
        $status.LoadedAt = $script:Providers[$Name].LoadedAt
    }
    else {
        $status.ErrorDetail = "Provider not registered"
        return $status
    }

    # Check API key
    switch ($Name) {
        'ollama' {
            $status.HasApiKey = $true  # No API key needed
        }
        'anthropic' {
            $status.HasApiKey = -not [string]::IsNullOrWhiteSpace($env:ANTHROPIC_API_KEY)
        }
        'openai' {
            $status.HasApiKey = -not [string]::IsNullOrWhiteSpace($env:OPENAI_API_KEY)
        }
        'google' {
            $status.HasApiKey = -not [string]::IsNullOrWhiteSpace($env:GOOGLE_API_KEY)
        }
        'azure' {
            $status.HasApiKey = -not [string]::IsNullOrWhiteSpace($env:AZURE_OPENAI_API_KEY)
        }
        default {
            $status.HasApiKey = $true  # Assume OK for unknown providers
        }
    }

    if (-not $status.HasApiKey) {
        $status.ErrorDetail = "API key not configured"
        return $status
    }

    # Check reachability
    try {
        switch ($Name) {
            'ollama' {
                $null = Invoke-RestMethod -Uri "http://localhost:11434/api/tags" -Method Get -TimeoutSec 3 -ErrorAction Stop
                $status.Reachable = $true
            }
            'anthropic' {
                # Just check API key format, actual validation would cost tokens
                $status.Reachable = $env:ANTHROPIC_API_KEY -match '^sk-ant-'
                if (-not $status.Reachable) {
                    $status.ErrorDetail = "Invalid API key format"
                }
            }
            'openai' {
                # Just check API key format
                $status.Reachable = $env:OPENAI_API_KEY -match '^sk-'
                if (-not $status.Reachable) {
                    $status.ErrorDetail = "Invalid API key format"
                }
            }
            default {
                $status.Reachable = $true
            }
        }
    }
    catch {
        $status.ErrorDetail = $_.Exception.Message
    }

    $status.Available = $status.Registered -and $status.HasApiKey -and $status.Reachable
    return $status
}

# === INITIALIZATION ===

function Initialize-ProviderRegistry {
    <#
    .SYNOPSIS
        Initialize the provider registry by loading all provider modules.

    .DESCRIPTION
        Scans the providers/ directory for provider modules and registers them.
        Provider modules must follow the naming convention: <ProviderName>Provider.psm1

    .PARAMETER Path
        The path to scan for provider modules. Defaults to the providers/ directory.

    .PARAMETER Force
        If specified, re-initializes even if already initialized.

    .EXAMPLE
        Initialize-ProviderRegistry

    .EXAMPLE
        Initialize-ProviderRegistry -Force

    .OUTPUTS
        [PSCustomObject] Initialization result with counts and details.
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter()]
        [string]$Path = $script:ProvidersPath,

        [Parameter()]
        [switch]$Force
    )

    if ($script:Initialized -and -not $Force) {
        Write-Verbose "Provider registry already initialized. Use -Force to reinitialize."
        return [PSCustomObject]@{
            Success          = $true
            AlreadyInitialized = $true
            ProvidersLoaded  = $script:Providers.Count
            Providers        = $script:Providers.Keys
        }
    }

    Write-Verbose "Initializing provider registry from: $Path"

    $result = [PSCustomObject]@{
        Success         = $false
        ProvidersLoaded = 0
        ProvidersFound  = 0
        ProvidersFailed = 0
        Providers       = @()
        Errors          = @()
    }

    # Find all provider modules
    $providerPattern = "*Provider.psm1"
    $providerFiles = Get-ChildItem -Path $Path -Filter $providerPattern -File -ErrorAction SilentlyContinue

    if (-not $providerFiles) {
        Write-Warning "No provider modules found in: $Path"
        $result.Success = $true
        $script:Initialized = $true
        return $result
    }

    $result.ProvidersFound = $providerFiles.Count

    foreach ($file in $providerFiles) {
        # Extract provider name from filename (e.g., OllamaProvider.psm1 -> ollama)
        $providerName = $file.BaseName -replace 'Provider$', ''

        try {
            $registered = Register-AIProvider -Name $providerName -ModulePath $file.FullName -Force

            if ($registered) {
                $result.ProvidersLoaded++
                $result.Providers += $providerName
                Write-Verbose "Loaded provider: $providerName"
            }
            else {
                $result.ProvidersFailed++
                $result.Errors += "Failed to register: $providerName"
            }
        }
        catch {
            $result.ProvidersFailed++
            $result.Errors += "Error loading $providerName`: $_"
            Write-Warning "Failed to load provider $providerName`: $_"
        }
    }

    $result.Success = $result.ProvidersFailed -eq 0
    $script:Initialized = $true

    Write-Verbose "Provider registry initialized: $($result.ProvidersLoaded)/$($result.ProvidersFound) providers loaded"
    return $result
}

function Reset-ProviderRegistry {
    <#
    .SYNOPSIS
        Reset the provider registry to its initial state.

    .DESCRIPTION
        Clears all registered providers and resets the initialization flag.
        Optionally removes loaded modules from memory.

    .PARAMETER RemoveModules
        If specified, also removes provider modules from memory.

    .EXAMPLE
        Reset-ProviderRegistry

    .OUTPUTS
        [bool] True if reset succeeded.
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter()]
        [switch]$RemoveModules
    )

    if ($RemoveModules) {
        foreach ($name in $script:Providers.Keys) {
            $provider = $script:Providers[$name]
            if ($provider.Module) {
                Remove-Module -Name $provider.Module.Name -Force -ErrorAction SilentlyContinue
            }
        }
    }

    $script:Providers = @{}
    $script:Initialized = $false

    Write-Verbose "Provider registry reset"
    return $true
}

# === UTILITY FUNCTIONS ===

function Get-ProviderModels {
    <#
    .SYNOPSIS
        Get available models for a provider.

    .DESCRIPTION
        Queries the provider for its available models. For local providers like Ollama,
        this returns actually installed models.

    .PARAMETER Provider
        The name of the provider.

    .EXAMPLE
        Get-ProviderModels -Provider "ollama"

    .OUTPUTS
        [string[]] Array of available model names.
    #>
    [CmdletBinding()]
    [OutputType([string[]])]
    param(
        [Parameter(Mandatory = $true, Position = 0)]
        [ValidateNotNullOrEmpty()]
        [string]$Provider
    )

    $Provider = $Provider.ToLower()

    if (-not $script:Providers.ContainsKey($Provider)) {
        Write-Warning "Provider '$Provider' is not registered."
        return @()
    }

    $providerInfo = $script:Providers[$Provider]

    # Check for Get-<Provider>Models function
    $getModelsFunc = "Get-${Provider}Models"
    if ($providerInfo.Commands -contains $getModelsFunc) {
        try {
            return (& $getModelsFunc)
        }
        catch {
            Write-Warning "Failed to get models from $Provider`: $_"
        }
    }

    # Fallback: provider-specific implementations
    switch ($Provider) {
        'ollama' {
            try {
                $response = Invoke-RestMethod -Uri "http://localhost:11434/api/tags" -Method Get -TimeoutSec 5
                return $response.models.name
            }
            catch {
                Write-Warning "Failed to query Ollama models: $_"
                return @()
            }
        }
        'anthropic' {
            return @(
                'claude-opus-4-5-20251101',
                'claude-sonnet-4-5-20250929',
                'claude-3-5-haiku-latest',
                'claude-3-haiku-20240307'
            )
        }
        'openai' {
            return @(
                'gpt-4o',
                'gpt-4o-mini',
                'gpt-4-turbo',
                'gpt-3.5-turbo'
            )
        }
        default {
            return @()
        }
    }
}

function Find-BestProvider {
    <#
    .SYNOPSIS
        Find the best available provider for a task.

    .DESCRIPTION
        Evaluates registered providers and returns the best one available
        based on availability and optional task requirements.

    .PARAMETER Task
        Optional task type hint (code, analysis, simple, creative).

    .PARAMETER PreferLocal
        If specified, prefers local providers (like Ollama) over cloud providers.

    .EXAMPLE
        Find-BestProvider -PreferLocal

    .EXAMPLE
        Find-BestProvider -Task "code"

    .OUTPUTS
        [string] Name of the best available provider, or $null if none available.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter()]
        [ValidateSet('simple', 'code', 'analysis', 'creative', 'complex')]
        [string]$Task = 'simple',

        [Parameter()]
        [switch]$PreferLocal
    )

    # Define provider priority based on preferences
    $priorityOrder = if ($PreferLocal) {
        @('ollama', 'anthropic', 'openai', 'google', 'azure')
    }
    else {
        @('anthropic', 'openai', 'ollama', 'google', 'azure')
    }

    foreach ($provider in $priorityOrder) {
        if ($script:Providers.ContainsKey($provider)) {
            if (Test-ProviderAvailable -Name $provider -Quick) {
                Write-Verbose "Selected provider: $provider"
                return $provider
            }
        }
    }

    Write-Warning "No available providers found."
    return $null
}

# === MODULE EXPORT ===

Export-ModuleMember -Function @(
    # Registration
    'Register-AIProvider',
    'Unregister-AIProvider',

    # Retrieval
    'Get-AIProvider',
    'Get-AllAIProviders',

    # API Routing
    'Invoke-ProviderAPI',

    # Availability
    'Test-ProviderAvailable',
    'Get-ProviderStatus',

    # Initialization
    'Initialize-ProviderRegistry',
    'Reset-ProviderRegistry',

    # Utilities
    'Get-ProviderModels',
    'Find-BestProvider'
)

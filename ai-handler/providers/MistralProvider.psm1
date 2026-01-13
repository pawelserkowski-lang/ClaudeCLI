#Requires -Version 5.1
<#
.SYNOPSIS
    Mistral AI API Provider for AI Model Handler

.DESCRIPTION
    This module provides functions to interact with Mistral AI's API.
    Mistral uses an OpenAI-compatible API format, so this module leverages
    the Invoke-OpenAICompatibleStream function from OpenAIProvider for streaming.

    Includes support for streaming responses, API key validation, and connectivity testing.

.NOTES
    File Name      : MistralProvider.psm1
    Author         : HYDRA System
    Prerequisite   : PowerShell 5.1+
    Required ENV   : MISTRAL_API_KEY
    Dependencies   : OpenAIProvider.psm1 (for Invoke-OpenAICompatibleStream)

.EXAMPLE
    Import-Module .\MistralProvider.psm1

    # Test connectivity
    if (Test-MistralAvailable) {
        $response = Invoke-MistralAPI -Model "mistral-small-latest" -Messages @(
            @{ role = "user"; content = "Hello!" }
        ) -MaxTokens 100 -Temperature 0.7
        Write-Host $response.content
    }
#>

#region Configuration

$script:MistralBaseUri = "https://api.mistral.ai/v1/chat/completions"
$script:DefaultTimeout = 30000

#endregion

#region Dependencies

# Import OpenAIProvider for compatible stream function
$providerPath = Join-Path -Path $PSScriptRoot -ChildPath "OpenAIProvider.psm1"
if (Test-Path $providerPath) {
    Import-Module $providerPath -Force -ErrorAction SilentlyContinue
}

#endregion

#region Public Functions

function Test-MistralAvailable {
    <#
    .SYNOPSIS
        Tests if Mistral API is available and configured

    .DESCRIPTION
        Checks for the presence of MISTRAL_API_KEY environment variable
        and optionally tests API connectivity by making a lightweight request.

    .PARAMETER TestConnectivity
        If specified, performs an actual API call to verify connectivity

    .OUTPUTS
        Hashtable with availability status, message, and optional latency

    .EXAMPLE
        if ((Test-MistralAvailable).Available) {
            Write-Host "Mistral is ready"
        }

    .EXAMPLE
        # Full connectivity test
        $status = Test-MistralAvailable -TestConnectivity
        if ($status.Available) {
            Write-Host "Mistral API responding in $($status.LatencyMs)ms"
        }
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [switch]$TestConnectivity
    )

    $result = @{
        Available = $false
        HasApiKey = $false
        ApiKeyMasked = $null
        Message = ""
        LatencyMs = $null
    }

    $apiKey = $env:MISTRAL_API_KEY

    if (-not $apiKey) {
        $result.Message = "MISTRAL_API_KEY environment variable not set"
        Write-Verbose $result.Message
        return $result
    }

    $result.HasApiKey = $true
    $result.ApiKeyMasked = Get-MistralApiKey

    if (-not $TestConnectivity) {
        $result.Available = $true
        $result.Message = "API key configured"
        return $result
    }

    # Test actual connectivity with a minimal request
    try {
        $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

        $headers = @{
            "Authorization" = "Bearer $apiKey"
            "Content-Type" = "application/json"
        }

        # Make a minimal request to test connectivity
        $body = @{
            model = "mistral-small-latest"
            max_tokens = 1
            messages = @(
                @{ role = "user"; content = "hi" }
            )
        } | ConvertTo-Json -Depth 10

        $response = Invoke-RestMethod -Uri $script:MistralBaseUri `
            -Method Post -Headers $headers -Body $body `
            -TimeoutSec 15 -ErrorAction Stop

        $stopwatch.Stop()

        $result.Available = $true
        $result.LatencyMs = $stopwatch.ElapsedMilliseconds
        $result.Message = "API responding (latency: $($result.LatencyMs)ms)"
    }
    catch {
        $result.Available = $false
        $result.Message = "Connectivity test failed: $($_.Exception.Message)"
        Write-Verbose $result.Message
    }

    return $result
}

function Invoke-MistralAPI {
    <#
    .SYNOPSIS
        Calls the Mistral AI Chat Completions API

    .DESCRIPTION
        Makes a request to Mistral's chat completions endpoint with support for
        streaming and non-streaming responses. The Mistral API uses an OpenAI-compatible
        format, enabling interoperability with OpenAI tooling.

    .PARAMETER Model
        The model to use. Common options:
        - mistral-small-latest (fast, efficient)
        - mistral-medium-latest (balanced)
        - mistral-large-latest (most capable)
        - open-mistral-7b (open source)
        - open-mixtral-8x7b (mixture of experts)

    .PARAMETER Messages
        Array of message objects with 'role' and 'content' properties.
        Supported roles: system, user, assistant

    .PARAMETER MaxTokens
        Maximum number of tokens to generate (default: 1024)

    .PARAMETER Temperature
        Sampling temperature from 0.0 to 1.0 (default: 0.7)
        Lower values are more deterministic, higher values more creative

    .PARAMETER Stream
        If specified, enables streaming response with real-time output

    .OUTPUTS
        Hashtable with:
        - content: The generated text response
        - usage: Token usage (input_tokens, output_tokens)
        - model: The model that was used
        - stop_reason: Why generation stopped

    .EXAMPLE
        $response = Invoke-MistralAPI -Model "mistral-small-latest" -Messages @(
            @{ role = "system"; content = "You are a helpful assistant." },
            @{ role = "user"; content = "What is the capital of France?" }
        ) -MaxTokens 100 -Temperature 0.7

        Write-Host $response.content
        # Output: The capital of France is Paris.

    .EXAMPLE
        # Streaming response
        $response = Invoke-MistralAPI -Model "mistral-large-latest" -Messages @(
            @{ role = "user"; content = "Tell me a short story" }
        ) -MaxTokens 500 -Stream

    .EXAMPLE
        # Using with system prompt for code generation
        $response = Invoke-MistralAPI -Model "mistral-medium-latest" -Messages @(
            @{ role = "system"; content = "You are an expert Python programmer." },
            @{ role = "user"; content = "Write a function to calculate factorial" }
        ) -Temperature 0.3
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Model,

        [Parameter(Mandatory)]
        [array]$Messages,

        [int]$MaxTokens = 1024,

        [ValidateRange(0.0, 1.0)]
        [float]$Temperature = 0.7,

        [switch]$Stream
    )

    $apiKey = $env:MISTRAL_API_KEY
    if (-not $apiKey) {
        throw "MISTRAL_API_KEY environment variable is not set."
    }

    $body = @{
        model = $Model
        max_tokens = $MaxTokens
        temperature = $Temperature
        messages = @($Messages | ForEach-Object {
            @{ role = $_.role; content = $_.content }
        })
    }

    $headers = @{
        "Authorization" = "Bearer $apiKey"
        "Content-Type" = "application/json"
    }

    if ($Stream) {
        # Use OpenAI-compatible streaming function
        if (Get-Command -Name "Invoke-OpenAICompatibleStream" -ErrorAction SilentlyContinue) {
            return Invoke-OpenAICompatibleStream -Uri $script:MistralBaseUri `
                -Headers $headers -Body ($body | ConvertTo-Json -Depth 10) -Model $Model
        }
        else {
            Write-Warning "Invoke-OpenAICompatibleStream not available. Falling back to non-streaming."
        }
    }

    try {
        $response = Invoke-RestMethod -Uri $script:MistralBaseUri `
            -Method Post -Headers $headers -Body ($body | ConvertTo-Json -Depth 10)

        return @{
            content = $response.choices[0].message.content
            usage = @{
                input_tokens = $response.usage.prompt_tokens
                output_tokens = $response.usage.completion_tokens
            }
            model = $response.model
            stop_reason = $response.choices[0].finish_reason
        }
    }
    catch {
        $errorMessage = $_.Exception.Message
        if ($_.ErrorDetails.Message) {
            try {
                $errorJson = $_.ErrorDetails.Message | ConvertFrom-Json
                if ($errorJson.message) {
                    $errorMessage = $errorJson.message
                }
                elseif ($errorJson.error.message) {
                    $errorMessage = $errorJson.error.message
                }
            }
            catch { }
        }
        throw "Mistral API error: $errorMessage"
    }
}

function Get-MistralApiKey {
    <#
    .SYNOPSIS
        Gets a masked version of the Mistral API key for display.

    .DESCRIPTION
        Returns the first 15 characters of the API key followed by "..." for
        secure display in logs and status outputs. This prevents accidental
        exposure of the full API key while still allowing identification.

    .OUTPUTS
        String with masked API key, or $null if not set.

    .EXAMPLE
        $maskedKey = Get-MistralApiKey
        Write-Host "API Key: $maskedKey"
        # Output: API Key: abc123def456ghi...

    .EXAMPLE
        # Use in status display
        if ($key = Get-MistralApiKey) {
            Write-Host "Mistral configured: $key" -ForegroundColor Green
        } else {
            Write-Host "Mistral not configured" -ForegroundColor Yellow
        }
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param()

    $apiKey = $env:MISTRAL_API_KEY
    if (-not $apiKey) {
        return $null
    }

    if ($apiKey.Length -le 15) {
        return "$($apiKey.Substring(0, [Math]::Min(4, $apiKey.Length)))..."
    }

    return "$($apiKey.Substring(0, 15))..."
}

#endregion

#region Module Exports

Export-ModuleMember -Function @(
    'Test-MistralAvailable',
    'Invoke-MistralAPI',
    'Get-MistralApiKey'
)

#endregion

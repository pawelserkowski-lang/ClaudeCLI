#Requires -Version 5.1
<#
.SYNOPSIS
    Groq API Provider for AI Model Handler

.DESCRIPTION
    This module provides functions to interact with Groq's API, which is OpenAI-compatible.
    It leverages the OpenAIProvider module for streaming functionality and provides
    Groq-specific configuration and connectivity testing.

    Groq offers ultra-fast inference with models like Llama 3.3, Mixtral, and Gemma.

.NOTES
    File Name      : GroqProvider.psm1
    Author         : HYDRA System
    Prerequisite   : PowerShell 5.1+
    Required ENV   : GROQ_API_KEY
    Dependency     : OpenAIProvider.psm1 (for Invoke-OpenAICompatibleStream)

.EXAMPLE
    Import-Module .\GroqProvider.psm1

    # Test connectivity
    if (Test-GroqAvailable) {
        $response = Invoke-GroqAPI -Model "llama-3.3-70b-versatile" -Messages @(
            @{ role = "user"; content = "Hello!" }
        ) -MaxTokens 100 -Temperature 0.7
        Write-Host $response.content
    }

.LINK
    https://console.groq.com/docs/api-reference
#>

#region Configuration

$script:GroqBaseUri = "https://api.groq.com/openai/v1/chat/completions"
$script:DefaultTimeout = 30000

# Import OpenAIProvider for compatible streaming
$openAIProviderPath = Join-Path $PSScriptRoot "OpenAIProvider.psm1"
if (Test-Path $openAIProviderPath) {
    Import-Module $openAIProviderPath -Force -ErrorAction SilentlyContinue
}

#endregion

#region Public Functions

function Get-GroqApiKey {
    <#
    .SYNOPSIS
        Returns the Groq API key (masked for security)

    .DESCRIPTION
        Retrieves the GROQ_API_KEY from environment variables and returns it
        in a masked format suitable for display (shows first 8 characters only).

    .PARAMETER Unmasked
        If specified, returns the full unmasked API key (use with caution)

    .OUTPUTS
        String containing the API key (masked by default)

    .EXAMPLE
        $maskedKey = Get-GroqApiKey
        Write-Host "Using key: $maskedKey"
        # Output: Using key: gsk_abc1...

    .EXAMPLE
        # Get full key for API calls (internal use)
        $fullKey = Get-GroqApiKey -Unmasked
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [switch]$Unmasked
    )

    $apiKey = $env:GROQ_API_KEY

    if (-not $apiKey) {
        return $null
    }

    if ($Unmasked) {
        return $apiKey
    }

    # Return masked key (first 8 characters + ellipsis)
    if ($apiKey.Length -gt 8) {
        return "$($apiKey.Substring(0, 8))..."
    }

    return "***"
}

function Test-GroqAvailable {
    <#
    .SYNOPSIS
        Tests if Groq API is available and configured

    .DESCRIPTION
        Checks for the presence of GROQ_API_KEY environment variable
        and optionally tests API connectivity by making a lightweight request.

    .PARAMETER TestConnectivity
        If specified, performs an actual API call to verify connectivity

    .OUTPUTS
        Boolean indicating whether Groq is available

    .EXAMPLE
        if (Test-GroqAvailable) {
            Write-Host "Groq is ready"
        }

    .EXAMPLE
        # Full connectivity test
        if (Test-GroqAvailable -TestConnectivity) {
            Write-Host "Groq API is responding"
        }
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [switch]$TestConnectivity
    )

    $apiKey = $env:GROQ_API_KEY

    if (-not $apiKey) {
        Write-Verbose "GROQ_API_KEY environment variable not set"
        return $false
    }

    if (-not $TestConnectivity) {
        return $true
    }

    # Test actual connectivity
    try {
        $headers = @{
            "Authorization" = "Bearer $apiKey"
            "Content-Type" = "application/json"
        }

        # Make a minimal request to test connectivity
        $body = @{
            model = "llama-3.3-70b-versatile"
            max_tokens = 1
            messages = @(
                @{ role = "user"; content = "hi" }
            )
        } | ConvertTo-Json -Depth 10

        $response = Invoke-RestMethod -Uri $script:GroqBaseUri `
            -Method Post -Headers $headers -Body $body `
            -TimeoutSec 10 -ErrorAction Stop

        return $true
    }
    catch {
        Write-Verbose "Groq connectivity test failed: $($_.Exception.Message)"
        return $false
    }
}

function Invoke-GroqAPI {
    <#
    .SYNOPSIS
        Calls the Groq Chat Completions API

    .DESCRIPTION
        Makes a request to Groq's OpenAI-compatible chat completions endpoint with support for
        streaming and non-streaming responses. Groq offers ultra-fast inference speeds.

        Supported models include:
        - llama-3.3-70b-versatile (recommended for general use)
        - llama-3.1-8b-instant (fast)
        - mixtral-8x7b-32768 (good for longer context)
        - gemma2-9b-it (Google Gemma)

    .PARAMETER Model
        The model to use (e.g., "llama-3.3-70b-versatile", "mixtral-8x7b-32768")

    .PARAMETER Messages
        Array of message objects with 'role' and 'content' properties

    .PARAMETER MaxTokens
        Maximum number of tokens to generate (default: 1024)

    .PARAMETER Temperature
        Sampling temperature (0.0 to 2.0, default: 0.7)

    .PARAMETER Stream
        If specified, enables streaming response with real-time output

    .OUTPUTS
        Hashtable with content, usage, model, and stop_reason

    .EXAMPLE
        $response = Invoke-GroqAPI -Model "llama-3.3-70b-versatile" -Messages @(
            @{ role = "system"; content = "You are a helpful assistant." },
            @{ role = "user"; content = "What is 2+2?" }
        ) -MaxTokens 100 -Temperature 0.7

        Write-Host $response.content

    .EXAMPLE
        # Streaming response
        $response = Invoke-GroqAPI -Model "llama-3.3-70b-versatile" -Messages @(
            @{ role = "user"; content = "Tell me a story" }
        ) -MaxTokens 500 -Stream

    .EXAMPLE
        # Using the fast model for quick responses
        $response = Invoke-GroqAPI -Model "llama-3.1-8b-instant" -Messages @(
            @{ role = "user"; content = "Quick answer: capital of France?" }
        ) -MaxTokens 50

    .NOTES
        Requires GROQ_API_KEY environment variable to be set.
        Get your API key at https://console.groq.com/keys
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Model,

        [Parameter(Mandatory)]
        [array]$Messages,

        [int]$MaxTokens = 1024,

        [ValidateRange(0.0, 2.0)]
        [float]$Temperature = 0.7,

        [switch]$Stream
    )

    $apiKey = $env:GROQ_API_KEY
    if (-not $apiKey) {
        throw "GROQ_API_KEY environment variable is not set. Get your key at https://console.groq.com/keys"
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
        # Use OpenAI-compatible streaming from OpenAIProvider
        if (Get-Command -Name "Invoke-OpenAICompatibleStream" -ErrorAction SilentlyContinue) {
            return Invoke-OpenAICompatibleStream -Uri $script:GroqBaseUri `
                -Headers $headers -Body ($body | ConvertTo-Json -Depth 10) -Model $Model
        }
        else {
            Write-Warning "Streaming requires OpenAIProvider module. Falling back to non-streaming."
        }
    }

    try {
        $response = Invoke-RestMethod -Uri $script:GroqBaseUri `
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
                $errorMessage = $errorJson.error.message
            }
            catch { }
        }
        throw "Groq API error: $errorMessage"
    }
}

#endregion

#region Module Exports

Export-ModuleMember -Function @(
    'Get-GroqApiKey',
    'Test-GroqAvailable',
    'Invoke-GroqAPI'
)

#endregion

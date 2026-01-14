#Requires -Version 5.1

<#
.SYNOPSIS
    Anthropic Claude API Provider for HYDRA AI Handler.

.DESCRIPTION
    This module provides functions to interact with the Anthropic Claude API.
    It handles message formatting, streaming responses, and API key management.

    Supports all Claude models including:
    - claude-opus-4-5-20251101 (Claude Opus 4.5)
    - claude-sonnet-4-5-20250929 (Claude Sonnet 4.5)
    - claude-3-5-haiku-20241022 (Claude 3.5 Haiku)

.NOTES
    Author: HYDRA AI Handler
    Version: 1.0.0
    Requires: ANTHROPIC_API_KEY environment variable

.EXAMPLE
    Import-Module .\AnthropicProvider.psm1
    $response = Invoke-AnthropicAPI -Model "claude-3-5-haiku-20241022" -Messages @(@{role="user"; content="Hello"}) -MaxTokens 1024

.LINK
    https://docs.anthropic.com/claude/reference/messages_post
#>

# === Configuration ===
$script:AnthropicApiUrl = "https://api.anthropic.com/v1/messages"
$script:AnthropicApiVersion = "2023-06-01"

# === Streaming Support ===

function Invoke-StreamingRequest {
    <#
    .SYNOPSIS
        Handles Server-Sent Events (SSE) streaming for HTTP requests.

    .DESCRIPTION
        Creates an HTTP client that streams response data and processes each line
        through a callback scriptblock. Used for real-time streaming of AI responses.

    .PARAMETER Uri
        The API endpoint URL.

    .PARAMETER Body
        The JSON request body.

    .PARAMETER Headers
        Hashtable of HTTP headers to include in the request.

    .PARAMETER OnData
        Scriptblock to execute for each line of streamed data.

    .EXAMPLE
        Invoke-StreamingRequest -Uri "https://api.anthropic.com/v1/messages" `
            -Headers @{ "x-api-key" = $key } `
            -Body $jsonBody `
            -OnData { param($line) Write-Host $line }
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Uri,

        [Parameter(Mandatory)]
        [string]$Body,

        [hashtable]$Headers = @{},

        [Parameter(Mandatory)]
        [scriptblock]$OnData
    )

    $client = New-Object System.Net.Http.HttpClient
    $request = New-Object System.Net.Http.HttpRequestMessage([System.Net.Http.HttpMethod]::Post, $Uri)

    foreach ($header in $Headers.Keys) {
        $request.Headers.TryAddWithoutValidation($header, $Headers[$header]) | Out-Null
    }

    $request.Content = New-Object System.Net.Http.StringContent($Body, [System.Text.Encoding]::UTF8, "application/json")

    try {
        $response = $client.SendAsync($request, [System.Net.Http.HttpCompletionOption]::ResponseHeadersRead).Result
        $stream = $response.Content.ReadAsStreamAsync().Result
        $reader = New-Object System.IO.StreamReader($stream)

        while (-not $reader.EndOfStream) {
            $line = $reader.ReadLine()
            if (-not $line) { continue }
            & $OnData $line
        }
    }
    finally {
        if ($reader) { $reader.Dispose() }
        if ($stream) { $stream.Dispose() }
        if ($response) { $response.Dispose() }
        if ($client) { $client.Dispose() }
    }
}

# === API Functions ===

function Invoke-AnthropicAPI {
    <#
    .SYNOPSIS
        Calls the Anthropic Claude API with the specified parameters.

    .DESCRIPTION
        Sends a request to the Anthropic Messages API. Handles message format conversion
        (extracting system message separately), streaming responses, and error handling.
        Supports custom API key for key rotation scenarios.

    .PARAMETER Model
        The Claude model to use (e.g., "claude-3-5-haiku-20241022", "claude-sonnet-4-5-20250929").

    .PARAMETER Messages
        Array of message objects with 'role' and 'content' properties.
        Roles can be: "system", "user", "assistant".

    .PARAMETER MaxTokens
        Maximum number of tokens to generate. Default: 4096.

    .PARAMETER Temperature
        Sampling temperature (0.0 to 1.0). Lower = more deterministic. Default: 0.7.

    .PARAMETER Stream
        If specified, streams the response in real-time to the console.

    .PARAMETER ApiKey
        Optional custom API key. If not provided, uses ANTHROPIC_API_KEY environment variable.
        Useful for API key rotation when one key hits rate limits.

    .OUTPUTS
        Hashtable with keys:
        - content: The generated text response
        - usage: Token usage information (input_tokens, output_tokens)
        - model: The model that was used
        - stop_reason: Why generation stopped (end_turn, max_tokens, stream)

    .EXAMPLE
        $response = Invoke-AnthropicAPI -Model "claude-3-5-haiku-20241022" `
            -Messages @(@{role="user"; content="Explain quantum computing"}) `
            -MaxTokens 1024 -Temperature 0.5

    .EXAMPLE
        # With streaming
        Invoke-AnthropicAPI -Model "claude-sonnet-4-5-20250929" `
            -Messages @(@{role="system"; content="You are a helpful assistant"}, @{role="user"; content="Hello"}) `
            -Stream

    .EXAMPLE
        # With custom API key (for key rotation)
        Invoke-AnthropicAPI -Model "claude-3-5-haiku-20241022" `
            -Messages @(@{role="user"; content="Hello"}) `
            -ApiKey $alternateKey

    .NOTES
        Requires ANTHROPIC_API_KEY environment variable to be set (or ApiKey parameter).
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Model,

        [Parameter(Mandatory)]
        [array]$Messages,

        [int]$MaxTokens = 4096,

        [float]$Temperature = 0.7,

        [switch]$Stream,

        [Parameter()]
        [string]$ApiKey  # Optional custom API key for key rotation
    )

    # Use provided API key or fall back to environment variable
    $effectiveApiKey = if ($ApiKey) { $ApiKey } else { $env:ANTHROPIC_API_KEY }

    if (-not $effectiveApiKey) {
        throw "ANTHROPIC_API_KEY environment variable is not set and no ApiKey provided. Please set it with your Anthropic API key."
    }

    # Convert messages to Anthropic format (system message is separate)
    $systemMessage = ($Messages | Where-Object { $_.role -eq "system" } | Select-Object -First 1).content
    $chatMessages = $Messages | Where-Object { $_.role -ne "system" } | ForEach-Object {
        @{ role = $_.role; content = $_.content }
    }

    $body = @{
        model = $Model
        max_tokens = $MaxTokens
        temperature = $Temperature
        messages = @($chatMessages)
    }

    if ($systemMessage) {
        $body.system = $systemMessage
    }

    if ($Stream) {
        $body.stream = $true
    }

    $headers = @{
        "x-api-key" = $effectiveApiKey
        "anthropic-version" = $script:AnthropicApiVersion
        "content-type" = "application/json"
    }

    if ($Stream) {
        $contentBuffer = ""
        Invoke-StreamingRequest -Uri $script:AnthropicApiUrl `
            -Headers $headers -Body ($body | ConvertTo-Json -Depth 10) -OnData {
                param($line)
                if ($line -notmatch "^data:") { return }
                $payload = $line -replace "^data:\s*", ""
                if ($payload -eq "[DONE]") { return }
                try {
                    $json = $payload | ConvertFrom-Json
                    if ($json.delta -and $json.delta.text) {
                        $script:contentBuffer += $json.delta.text
                        Write-Host $json.delta.text -NoNewline
                    } elseif ($json.content_block -and $json.content_block.text) {
                        $script:contentBuffer += $json.content_block.text
                        Write-Host $json.content_block.text -NoNewline
                    } elseif ($json.message -and $json.message.content) {
                        $text = $json.message.content | Select-Object -First 1
                        if ($text.text) {
                            $script:contentBuffer += $text.text
                            Write-Host $text.text -NoNewline
                        }
                    }
                } catch { }
            }.GetNewClosure()

        Write-Host ""
        return @{
            content = $contentBuffer
            usage = @{ input_tokens = 0; output_tokens = 0 }
            model = $Model
            stop_reason = "stream"
        }
    }

    # Non-streaming request
    try {
        $response = Invoke-RestMethod -Uri $script:AnthropicApiUrl `
            -Method Post -Headers $headers -Body ($body | ConvertTo-Json -Depth 10) `
            -ErrorAction Stop

        return @{
            content = $response.content[0].text
            usage = @{
                input_tokens = $response.usage.input_tokens
                output_tokens = $response.usage.output_tokens
            }
            model = $response.model
            stop_reason = $response.stop_reason
        }
    }
    catch {
        $errorMessage = $_.Exception.Message
        if ($_.ErrorDetails.Message) {
            try {
                $errorJson = $_.ErrorDetails.Message | ConvertFrom-Json
                if ($errorJson.error.message) {
                    $errorMessage = $errorJson.error.message
                }
            } catch { }
        }
        throw "Anthropic API error: $errorMessage"
    }
}

function Test-AnthropicAvailable {
    <#
    .SYNOPSIS
        Checks if the Anthropic API is available and configured.

    .DESCRIPTION
        Verifies that the ANTHROPIC_API_KEY environment variable is set and
        optionally tests connectivity to the API endpoint.

    .PARAMETER TestConnectivity
        If specified, actually sends a minimal request to verify API access.

    .OUTPUTS
        Hashtable with keys:
        - Available: Boolean indicating if API is usable
        - HasApiKey: Boolean indicating if API key is set
        - ApiKeyMasked: Masked version of API key for display
        - Message: Status message
        - Latency: Response time in milliseconds (if TestConnectivity is used)

    .EXAMPLE
        $status = Test-AnthropicAvailable
        if ($status.Available) { Write-Host "Anthropic API ready" }

    .EXAMPLE
        $status = Test-AnthropicAvailable -TestConnectivity
        Write-Host "API latency: $($status.Latency)ms"
    #>
    [CmdletBinding()]
    param(
        [switch]$TestConnectivity
    )

    $result = @{
        Available = $false
        HasApiKey = $false
        ApiKeyMasked = $null
        Message = ""
        Latency = $null
    }

    $apiKey = $env:ANTHROPIC_API_KEY
    if (-not $apiKey) {
        $result.Message = "ANTHROPIC_API_KEY environment variable is not set"
        return $result
    }

    $result.HasApiKey = $true
    $result.ApiKeyMasked = Get-AnthropicApiKey

    if (-not $TestConnectivity) {
        $result.Available = $true
        $result.Message = "API key configured"
        return $result
    }

    # Test actual connectivity with a minimal request
    try {
        $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

        $headers = @{
            "x-api-key" = $apiKey
            "anthropic-version" = $script:AnthropicApiVersion
            "content-type" = "application/json"
        }

        $body = @{
            model = "claude-3-5-haiku-20241022"
            max_tokens = 1
            messages = @(@{ role = "user"; content = "." })
        } | ConvertTo-Json -Depth 10

        $null = Invoke-RestMethod -Uri $script:AnthropicApiUrl `
            -Method Post -Headers $headers -Body $body -ErrorAction Stop

        $stopwatch.Stop()
        $result.Available = $true
        $result.Latency = $stopwatch.ElapsedMilliseconds
        $result.Message = "API accessible (latency: $($result.Latency)ms)"
    }
    catch {
        $result.Available = $false
        $result.Message = "API connection failed: $($_.Exception.Message)"
    }

    return $result
}

function Get-AnthropicApiKey {
    <#
    .SYNOPSIS
        Gets a masked version of the Anthropic API key for display.

    .DESCRIPTION
        Returns the first 15 characters of the API key followed by "..." for
        secure display in logs and status outputs.

    .OUTPUTS
        String with masked API key, or $null if not set.

    .EXAMPLE
        $maskedKey = Get-AnthropicApiKey
        Write-Host "API Key: $maskedKey"
        # Output: API Key: sk-ant-api03-abc...
    #>
    [CmdletBinding()]
    param()

    $apiKey = $env:ANTHROPIC_API_KEY
    if (-not $apiKey) {
        return $null
    }

    if ($apiKey.Length -le 15) {
        return "$($apiKey.Substring(0, [Math]::Min(4, $apiKey.Length)))..."
    }

    return "$($apiKey.Substring(0, 15))..."
}

# === Module Export ===
Export-ModuleMember -Function @(
    'Invoke-AnthropicAPI',
    'Invoke-StreamingRequest',
    'Test-AnthropicAvailable',
    'Get-AnthropicApiKey'
)

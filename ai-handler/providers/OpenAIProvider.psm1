#Requires -Version 5.1
<#
.SYNOPSIS
    OpenAI API Provider for AI Model Handler

.DESCRIPTION
    This module provides functions to interact with OpenAI's API and OpenAI-compatible
    endpoints (Mistral, Groq, etc.). It includes support for streaming responses,
    API key validation, and connectivity testing.

.NOTES
    File Name      : OpenAIProvider.psm1
    Author         : HYDRA System
    Prerequisite   : PowerShell 5.1+
    Required ENV   : OPENAI_API_KEY

.EXAMPLE
    Import-Module .\OpenAIProvider.psm1

    # Test connectivity
    if (Test-OpenAIAvailable) {
        $response = Invoke-OpenAIAPI -Model "gpt-4o-mini" -Messages @(
            @{ role = "user"; content = "Hello!" }
        ) -MaxTokens 100 -Temperature 0.7
        Write-Host $response.content
    }
#>

#region Configuration

$script:OpenAIBaseUri = "https://api.openai.com/v1/chat/completions"
$script:DefaultTimeout = 30000

#endregion

#region Helper Functions

function Invoke-StreamingRequest {
    <#
    .SYNOPSIS
        Handles HTTP streaming requests for OpenAI-compatible APIs

    .DESCRIPTION
        Creates an HTTP client that processes streaming responses line by line,
        calling the OnData scriptblock for each received chunk.

    .PARAMETER Uri
        The API endpoint URI

    .PARAMETER Body
        JSON body to send with the request

    .PARAMETER Headers
        HTTP headers to include in the request

    .PARAMETER OnData
        Scriptblock to call for each line of data received

    .EXAMPLE
        Invoke-StreamingRequest -Uri "https://api.openai.com/v1/chat/completions" `
            -Headers @{ "Authorization" = "Bearer $key" } `
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

    $request.Content = New-Object System.Net.Http.StringContent(
        $Body,
        [System.Text.Encoding]::UTF8,
        "application/json"
    )

    try {
        $response = $client.SendAsync(
            $request,
            [System.Net.Http.HttpCompletionOption]::ResponseHeadersRead
        ).Result

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
        if ($client) { $client.Dispose() }
    }
}

#endregion

#region Public Functions

function Test-OpenAIAvailable {
    <#
    .SYNOPSIS
        Tests if OpenAI API is available and configured

    .DESCRIPTION
        Checks for the presence of OPENAI_API_KEY environment variable
        and optionally tests API connectivity by making a lightweight request.

    .PARAMETER TestConnectivity
        If specified, performs an actual API call to verify connectivity

    .OUTPUTS
        Boolean indicating whether OpenAI is available

    .EXAMPLE
        if (Test-OpenAIAvailable) {
            Write-Host "OpenAI is ready"
        }

    .EXAMPLE
        # Full connectivity test
        if (Test-OpenAIAvailable -TestConnectivity) {
            Write-Host "OpenAI API is responding"
        }
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [switch]$TestConnectivity
    )

    $apiKey = $env:OPENAI_API_KEY

    if (-not $apiKey) {
        Write-Verbose "OPENAI_API_KEY environment variable not set"
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
            model = "gpt-4o-mini"
            max_tokens = 1
            messages = @(
                @{ role = "user"; content = "hi" }
            )
        } | ConvertTo-Json -Depth 10

        $response = Invoke-RestMethod -Uri $script:OpenAIBaseUri `
            -Method Post -Headers $headers -Body $body `
            -TimeoutSec 10 -ErrorAction Stop

        return $true
    }
    catch {
        Write-Verbose "OpenAI connectivity test failed: $($_.Exception.Message)"
        return $false
    }
}

function Invoke-OpenAIAPI {
    <#
    .SYNOPSIS
        Calls the OpenAI Chat Completions API

    .DESCRIPTION
        Makes a request to OpenAI's chat completions endpoint with support for
        streaming and non-streaming responses. Handles message formatting and
        returns a standardized response object.

    .PARAMETER Model
        The model to use (e.g., "gpt-4o", "gpt-4o-mini")

    .PARAMETER Messages
        Array of message objects with 'role' and 'content' properties

    .PARAMETER MaxTokens
        Maximum number of tokens to generate

    .PARAMETER Temperature
        Sampling temperature (0.0 to 2.0)

    .PARAMETER Stream
        If specified, enables streaming response

    .OUTPUTS
        Hashtable with content, usage, model, and stop_reason

    .EXAMPLE
        $response = Invoke-OpenAIAPI -Model "gpt-4o-mini" -Messages @(
            @{ role = "system"; content = "You are a helpful assistant." },
            @{ role = "user"; content = "What is 2+2?" }
        ) -MaxTokens 100 -Temperature 0.7

        Write-Host $response.content

    .EXAMPLE
        # Streaming response
        $response = Invoke-OpenAIAPI -Model "gpt-4o" -Messages @(
            @{ role = "user"; content = "Tell me a story" }
        ) -MaxTokens 500 -Stream
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

    $apiKey = $env:OPENAI_API_KEY
    if (-not $apiKey) {
        throw "OPENAI_API_KEY environment variable is not set."
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
        return Invoke-OpenAICompatibleStream -Uri $script:OpenAIBaseUri `
            -Headers $headers -Body ($body | ConvertTo-Json -Depth 10) -Model $Model
    }

    try {
        $response = Invoke-RestMethod -Uri $script:OpenAIBaseUri `
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
        throw "OpenAI API error: $errorMessage"
    }
}

function Invoke-OpenAICompatibleStream {
    <#
    .SYNOPSIS
        Handles OpenAI-compatible streaming responses

    .DESCRIPTION
        Processes Server-Sent Events (SSE) from OpenAI-compatible APIs including
        OpenAI, Mistral, and Groq. Outputs content in real-time to the console
        and returns the complete response.

    .PARAMETER Uri
        The API endpoint URI

    .PARAMETER Headers
        HTTP headers including authorization

    .PARAMETER Body
        JSON request body (stream will be set to true automatically)

    .PARAMETER Model
        The model name for response metadata

    .OUTPUTS
        Hashtable with content, usage, model, and stop_reason

    .EXAMPLE
        $result = Invoke-OpenAICompatibleStream -Uri "https://api.openai.com/v1/chat/completions" `
            -Headers @{ "Authorization" = "Bearer $key" } `
            -Body $jsonBody `
            -Model "gpt-4o"
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Uri,

        [Parameter(Mandatory)]
        [hashtable]$Headers,

        [Parameter(Mandatory)]
        [string]$Body,

        [string]$Model
    )

    $streamBody = ($Body | ConvertFrom-Json)
    $streamBody.stream = $true
    $contentBuffer = ""

    Invoke-StreamingRequest -Uri $Uri -Headers $Headers -Body ($streamBody | ConvertTo-Json -Depth 10) -OnData {
        param($line)

        if ($line -notmatch "^data:") { return }

        $payload = $line -replace "^data:\s*", ""
        if ($payload -eq "[DONE]") { return }

        try {
            $json = $payload | ConvertFrom-Json
            $delta = $json.choices[0].delta.content
            if ($delta) {
                $contentBuffer += $delta
                Write-Host $delta -NoNewline
            }
        }
        catch {
            # Ignore parsing errors for malformed chunks
        }
    }

    Write-Host ""

    return @{
        content = $contentBuffer
        usage = @{ input_tokens = 0; output_tokens = 0 }
        model = $Model
        stop_reason = "stream"
    }
}

#endregion

#region Module Exports

Export-ModuleMember -Function @(
    'Test-OpenAIAvailable',
    'Invoke-OpenAIAPI',
    'Invoke-OpenAICompatibleStream',
    'Invoke-StreamingRequest'
)

#endregion

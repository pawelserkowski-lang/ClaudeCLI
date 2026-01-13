#Requires -Version 5.1
<#
.SYNOPSIS
    Google Gemini API Provider for AI Handler.

.DESCRIPTION
    Provides functions to interact with the Google Gemini API for AI completions.
    Supports message conversion to Google format, API key validation, and connectivity testing.

.NOTES
    Author: HYDRA AI Handler
    Version: 1.0.0
    Requires: GOOGLE_API_KEY environment variable
#>

function Invoke-GoogleAPI {
    <#
    .SYNOPSIS
        Invokes the Google Gemini API for text generation.

    .DESCRIPTION
        Sends a request to the Google Gemini API with the specified parameters.
        Converts standard chat messages to Google's contents format with parts.
        Handles system instructions separately as required by the API.

    .PARAMETER Model
        The Gemini model to use (e.g., 'gemini-1.5-flash', 'gemini-1.5-pro').

    .PARAMETER Messages
        Array of message objects with 'role' and 'content' properties.
        Roles can be 'system', 'user', or 'assistant' (converted to 'model').

    .PARAMETER MaxTokens
        Maximum number of tokens to generate in the response.

    .PARAMETER Temperature
        Sampling temperature (0.0 to 2.0). Higher values increase randomness.

    .PARAMETER Stream
        If specified, enables streaming mode (not fully implemented yet).

    .EXAMPLE
        $messages = @(
            @{ role = "system"; content = "You are a helpful assistant." }
            @{ role = "user"; content = "Hello, how are you?" }
        )
        $response = Invoke-GoogleAPI -Model "gemini-1.5-flash" -Messages $messages -MaxTokens 1024 -Temperature 0.7

    .OUTPUTS
        Hashtable with:
        - content: The generated text response
        - usage: Token usage information (input_tokens, output_tokens)
        - model: The model used
        - stop_reason: The reason generation stopped

    .NOTES
        Requires GOOGLE_API_KEY environment variable to be set.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Model,

        [Parameter(Mandatory = $true)]
        [array]$Messages,

        [Parameter()]
        [int]$MaxTokens = 1024,

        [Parameter()]
        [float]$Temperature = 0.7,

        [Parameter()]
        [switch]$Stream
    )

    $apiKey = $env:GOOGLE_API_KEY
    if (-not $apiKey) {
        throw "Missing GOOGLE_API_KEY environment variable."
    }

    # Extract system message (Google handles it separately)
    $systemMessage = ($Messages | Where-Object { $_.role -eq "system" } | Select-Object -First 1).content

    # Convert messages to Google format (contents with parts)
    # Google uses 'model' instead of 'assistant'
    $contents = @($Messages | Where-Object { $_.role -ne "system" } | ForEach-Object {
        $role = if ($_.role -eq "assistant") { "model" } else { $_.role }
        @{
            role = $role
            parts = @(@{ text = $_.content })
        }
    })

    # Build request body
    $body = @{
        contents = $contents
        generationConfig = @{
            maxOutputTokens = $MaxTokens
            temperature = $Temperature
        }
    }

    # Add system instruction if present
    if ($systemMessage) {
        $body.systemInstruction = @{
            parts = @(@{ text = $systemMessage })
        }
    }

    # Build URI with API key
    $uri = "https://generativelanguage.googleapis.com/v1beta/models/${Model}:generateContent?key=$apiKey"

    try {
        $response = Invoke-RestMethod -Uri $uri -Method Post `
            -Body ($body | ConvertTo-Json -Depth 10) `
            -ContentType "application/json" `
            -ErrorAction Stop

        # Extract response text
        $text = $response.candidates[0].content.parts[0].text

        return @{
            content = $text
            usage = @{
                input_tokens = $response.usageMetadata.promptTokenCount
                output_tokens = $response.usageMetadata.candidatesTokenCount
            }
            model = $Model
            stop_reason = $response.candidates[0].finishReason
        }
    }
    catch {
        $errorMessage = $_.Exception.Message
        if ($_.ErrorDetails.Message) {
            try {
                $errorJson = $_.ErrorDetails.Message | ConvertFrom-Json
                $errorMessage = $errorJson.error.message
            }
            catch {
                $errorMessage = $_.ErrorDetails.Message
            }
        }
        throw "Google API error: $errorMessage"
    }
}

function Test-GoogleAvailable {
    <#
    .SYNOPSIS
        Tests if Google Gemini API is available and configured.

    .DESCRIPTION
        Checks if the GOOGLE_API_KEY environment variable is set and optionally
        tests connectivity to the Google API endpoint.

    .PARAMETER TestConnectivity
        If specified, performs an actual API call to verify connectivity.

    .EXAMPLE
        if (Test-GoogleAvailable) {
            Write-Host "Google API is available"
        }

    .EXAMPLE
        $status = Test-GoogleAvailable -TestConnectivity
        if ($status.Available) {
            Write-Host "Connected: $($status.Model)"
        }

    .OUTPUTS
        If TestConnectivity is not specified: Boolean indicating if API key is present.
        If TestConnectivity is specified: Hashtable with Available, Model, and Error properties.
    #>
    [CmdletBinding()]
    param(
        [Parameter()]
        [switch]$TestConnectivity
    )

    $apiKey = $env:GOOGLE_API_KEY

    if (-not $apiKey) {
        if ($TestConnectivity) {
            return @{
                Available = $false
                Model = $null
                Error = "GOOGLE_API_KEY not set"
            }
        }
        return $false
    }

    if (-not $TestConnectivity) {
        return $true
    }

    # Test actual connectivity with a minimal request
    try {
        $testMessages = @(
            @{ role = "user"; content = "Hi" }
        )

        $response = Invoke-GoogleAPI -Model "gemini-1.5-flash" `
            -Messages $testMessages `
            -MaxTokens 10 `
            -Temperature 0

        return @{
            Available = $true
            Model = "gemini-1.5-flash"
            Error = $null
        }
    }
    catch {
        return @{
            Available = $false
            Model = $null
            Error = $_.Exception.Message
        }
    }
}

function Get-GoogleApiKey {
    <#
    .SYNOPSIS
        Returns the Google API key in masked format.

    .DESCRIPTION
        Retrieves the GOOGLE_API_KEY environment variable and returns it
        in a masked format showing only the first 8 and last 4 characters.

    .PARAMETER ShowFull
        If specified, returns the full unmasked API key.
        Use with caution - avoid logging or displaying the full key.

    .EXAMPLE
        Get-GoogleApiKey
        # Returns: AIzaSyBx...abcd

    .EXAMPLE
        $key = Get-GoogleApiKey -ShowFull
        # Returns the full API key (use with caution)

    .OUTPUTS
        String containing the masked (or full) API key, or $null if not set.
    #>
    [CmdletBinding()]
    param(
        [Parameter()]
        [switch]$ShowFull
    )

    $apiKey = $env:GOOGLE_API_KEY

    if (-not $apiKey) {
        return $null
    }

    if ($ShowFull) {
        return $apiKey
    }

    # Mask the key, showing first 8 and last 4 characters
    if ($apiKey.Length -gt 12) {
        $prefix = $apiKey.Substring(0, 8)
        $suffix = $apiKey.Substring($apiKey.Length - 4)
        return "${prefix}...${suffix}"
    }
    else {
        # Key is too short to mask properly, show first few chars only
        return "$($apiKey.Substring(0, [Math]::Min(4, $apiKey.Length)))..."
    }
}

# Export module members
Export-ModuleMember -Function @(
    'Invoke-GoogleAPI',
    'Test-GoogleAvailable',
    'Get-GoogleApiKey'
)

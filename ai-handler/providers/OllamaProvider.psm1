#Requires -Version 5.1
<#
.SYNOPSIS
    Ollama Local AI Provider for AI Model Handler

.DESCRIPTION
    This module provides functions to interact with local Ollama instances.
    It includes automatic service detection, auto-installation, model listing,
    and API calls with streaming support.

.NOTES
    File Name      : OllamaProvider.psm1
    Author         : HYDRA System
    Prerequisite   : PowerShell 5.1+
    Dependency     : Ollama (auto-installable)

.EXAMPLE
    Import-Module .\OllamaProvider.psm1

    # Check if Ollama is running
    if ((Test-OllamaAvailable).Available) {
        # List models
        Get-OllamaModels | Format-Table

        # Make a request
        $response = Invoke-OllamaAPI -Model "llama3.2:3b" -Messages @(
            @{ role = "user"; content = "Hello!" }
        )
        Write-Host $response.content
    }
#>

#region Configuration

$script:OllamaBaseUri = "http://localhost:11434"
$script:OllamaExePath = "$env:LOCALAPPDATA\Programs\Ollama\ollama.exe"
$script:DefaultTimeout = 3000

#endregion

#region Helper Functions

function Invoke-StreamingRequest {
    <#
    .SYNOPSIS
        Handles HTTP streaming requests for Ollama API

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

function Test-OllamaAvailable {
    <#
    .SYNOPSIS
        Tests if Ollama service is running and accessible

    .DESCRIPTION
        Performs a TCP connection test to localhost:11434 to check if the
        Ollama service is running and responding to requests.

    .PARAMETER NoCache
        Ignored - included for compatibility with AIUtil-Health version

    .PARAMETER IncludeModels
        If specified, also fetches available models (slower)

    .OUTPUTS
        Hashtable with Available, Port, ResponseTimeMs properties
        (Compatible with AIUtil-Health.psm1 version)

    .EXAMPLE
        if ((Test-OllamaAvailable).Available) {
            Write-Host "Ollama is running on port 11434"
        }
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [switch]$NoCache,
        [switch]$IncludeModels
    )

    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
    $available = $false
    $models = @()

    try {
        $request = [System.Net.WebRequest]::Create("$script:OllamaBaseUri/api/tags")
        $request.Method = "GET"
        $request.Timeout = $script:DefaultTimeout
        $response = $request.GetResponse()

        if ($IncludeModels) {
            $reader = [System.IO.StreamReader]::new($response.GetResponseStream())
            $json = $reader.ReadToEnd() | ConvertFrom-Json
            $models = @($json.models | ForEach-Object { $_.name })
            $reader.Close()
        }

        $response.Close()
        $available = $true
    }
    catch {
        Write-Verbose "Ollama not available: $($_.Exception.Message)"
        $available = $false
    }

    $stopwatch.Stop()

    $result = @{
        Available      = $available
        Port           = 11434
        ResponseTimeMs = $stopwatch.ElapsedMilliseconds
        Cached         = $false
    }

    if ($IncludeModels) {
        $result.Models = $models
    }

    return $result
}

function Install-OllamaAuto {
    <#
    .SYNOPSIS
        Automatically installs Ollama in silent mode

    .DESCRIPTION
        Downloads and installs Ollama silently without user interaction.
        Starts the Ollama service after installation and verifies it's running.

    .PARAMETER Force
        If specified, reinstalls even if Ollama is already installed

    .PARAMETER DefaultModel
        The default model to pull after installation (not pulled by default)

    .OUTPUTS
        Boolean indicating whether installation was successful

    .EXAMPLE
        if (Install-OllamaAuto) {
            Write-Host "Ollama installed successfully"
        }

    .EXAMPLE
        # Force reinstall
        Install-OllamaAuto -Force
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [switch]$Force,

        [string]$DefaultModel = "llama3.2:3b"
    )

    $installerScript = Join-Path $PSScriptRoot "..\Install-Ollama.ps1"

    if (Test-Path $installerScript) {
        Write-Host "[AI] Auto-installing Ollama via installer script..." -ForegroundColor Yellow
        & $installerScript -SkipModelPull
        return (Test-OllamaAvailable).Available
    }

    # Inline minimal installer
    Write-Host "[AI] Downloading and installing Ollama (silent)..." -ForegroundColor Yellow

    $tempInstaller = Join-Path $env:TEMP "OllamaSetup.exe"
    $downloadUrl = "https://ollama.com/download/OllamaSetup.exe"

    try {
        $ProgressPreference = "SilentlyContinue"
        Invoke-WebRequest -Uri $downloadUrl -OutFile $tempInstaller -UseBasicParsing

        $process = Start-Process -FilePath $tempInstaller `
            -ArgumentList "/SP- /VERYSILENT /NORESTART /SUPPRESSMSGBOXES" `
            -Wait -PassThru

        if ($process.ExitCode -eq 0) {
            Write-Host "[AI] Ollama installed successfully" -ForegroundColor Green

            # Start service
            if (Test-Path $script:OllamaExePath) {
                Start-Process -FilePath $script:OllamaExePath -ArgumentList "serve" -WindowStyle Hidden
                Start-Sleep -Seconds 5
            }

            Remove-Item $tempInstaller -Force -ErrorAction SilentlyContinue
            return (Test-OllamaAvailable).Available
        }
        else {
            Write-Warning "[AI] Ollama installer exited with code: $($process.ExitCode)"
        }
    }
    catch {
        Write-Warning "[AI] Ollama auto-install failed: $($_.Exception.Message)"
    }

    return $false
}

function Get-OllamaModels {
    <#
    .SYNOPSIS
        Gets list of installed Ollama models

    .DESCRIPTION
        Queries the local Ollama API to retrieve information about all
        installed models including name, size, and modification date.

    .OUTPUTS
        Array of model objects with Name, Size (GB), and Modified properties

    .EXAMPLE
        Get-OllamaModels | Format-Table

        Name              Size Modified
        ----              ---- --------
        llama3.2:3b       1.87 2024-01-15T10:30:00Z
        qwen2.5-coder:1.5b 0.98 2024-01-14T08:15:00Z

    .EXAMPLE
        # Get just model names
        (Get-OllamaModels).Name
    #>
    [CmdletBinding()]
    [OutputType([array])]
    param()

    if (-not (Test-OllamaAvailable).Available) {
        Write-Warning "Ollama is not running"
        return @()
    }

    try {
        $response = Invoke-RestMethod -Uri "$script:OllamaBaseUri/api/tags" -Method Get

        return $response.models | ForEach-Object {
            @{
                Name = $_.name
                Size = [math]::Round($_.size / 1GB, 2)
                Modified = $_.modified_at
                Digest = $_.digest
                Details = $_.details
            }
        }
    }
    catch {
        Write-Warning "Failed to get Ollama models: $($_.Exception.Message)"
        return @()
    }
}

function Invoke-OllamaAPI {
    <#
    .SYNOPSIS
        Calls the local Ollama Chat API

    .DESCRIPTION
        Makes a request to the local Ollama chat completions endpoint with support
        for streaming and non-streaming responses. Automatically attempts to start
        or install Ollama if not running.

    .PARAMETER Model
        The model to use (e.g., "llama3.2:3b", "qwen2.5-coder:1.5b")

    .PARAMETER Messages
        Array of message objects with 'role' and 'content' properties

    .PARAMETER MaxTokens
        Maximum number of tokens to generate (num_predict)

    .PARAMETER Temperature
        Sampling temperature (0.0 to 2.0)

    .PARAMETER Stream
        If specified, enables streaming response

    .PARAMETER AutoStart
        If specified, attempts to start Ollama if not running (default: $true)

    .PARAMETER AutoInstall
        If specified, attempts to install Ollama if not present

    .OUTPUTS
        Hashtable with content, usage, model, and stop_reason

    .EXAMPLE
        $response = Invoke-OllamaAPI -Model "llama3.2:3b" -Messages @(
            @{ role = "user"; content = "What is 2+2?" }
        ) -MaxTokens 100 -Temperature 0.7

        Write-Host $response.content

    .EXAMPLE
        # Streaming response
        $response = Invoke-OllamaAPI -Model "llama3.2:3b" -Messages @(
            @{ role = "user"; content = "Tell me a story" }
        ) -MaxTokens 500 -Stream

    .EXAMPLE
        # With auto-install enabled
        $response = Invoke-OllamaAPI -Model "llama3.2:3b" -Messages @(
            @{ role = "user"; content = "Hello" }
        ) -AutoInstall
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

        [switch]$Stream,

        [bool]$AutoStart = $true,

        [switch]$AutoInstall
    )

    # Check if Ollama is running, try to start or install if not
    if (-not (Test-OllamaAvailable).Available) {
        Write-Host "[AI] Ollama not running, attempting to start..." -ForegroundColor Yellow

        # Try to start existing installation
        if (Test-Path $script:OllamaExePath) {
            Start-Process -FilePath $script:OllamaExePath -ArgumentList "serve" -WindowStyle Hidden
            Start-Sleep -Seconds 3

            if (-not (Test-OllamaAvailable).Available) {
                throw "Ollama installed but failed to start"
            }
        }
        elseif ($AutoInstall) {
            # Auto-install
            if (Install-OllamaAuto) {
                Write-Host "[AI] Ollama auto-installed and running" -ForegroundColor Green
            }
            else {
                throw "Ollama auto-installation failed"
            }
        }
        else {
            throw "Ollama not installed. Run Install-Ollama.ps1 or use -AutoInstall"
        }
    }

    $body = @{
        model = $Model
        messages = @($Messages | ForEach-Object {
            @{ role = $_.role; content = $_.content }
        })
        options = @{
            num_predict = $MaxTokens
            temperature = $Temperature
        }
        stream = $Stream.IsPresent
    }

    $uri = "$script:OllamaBaseUri/api/chat"

    try {
        if ($Stream) {
            $contentBuffer = ""

            Invoke-StreamingRequest -Uri $uri `
                -Headers @{ "Content-Type" = "application/json" } `
                -Body ($body | ConvertTo-Json -Depth 10) `
                -OnData {
                    param($line)
                    try {
                        $json = $line | ConvertFrom-Json
                        if ($json.message -and $json.message.content) {
                            $contentBuffer += $json.message.content
                            Write-Host $json.message.content -NoNewline
                        }
                    }
                    catch {
                        # Ignore parsing errors
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

        $response = Invoke-RestMethod -Uri $uri `
            -Method Post -Body ($body | ConvertTo-Json -Depth 10) -ContentType "application/json"

        return @{
            content = $response.message.content
            usage = @{
                input_tokens = $response.prompt_eval_count
                output_tokens = $response.eval_count
            }
            model = $response.model
            stop_reason = "stop"
        }
    }
    catch {
        throw "Ollama API error: $($_.Exception.Message)"
    }
}

#endregion

#region Module Exports

Export-ModuleMember -Function @(
    'Test-OllamaAvailable',
    'Install-OllamaAuto',
    'Get-OllamaModels',
    'Invoke-OllamaAPI',
    'Invoke-StreamingRequest'
)

#endregion

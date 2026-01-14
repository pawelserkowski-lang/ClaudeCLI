#Requires -Version 5.1
# ===============================================================================
# ERROR LOGGER MODULE - Centralized error logging for HYDRA
# ===============================================================================
#
# SYNOPSIS:
#     Centralized logging module for errors, AI requests, and system events.
#
# DESCRIPTION:
#     Provides unified logging functionality with:
#     - Multi-level logging (DEBUG, INFO, WARN, ERROR, FATAL)
#     - AI request tracking with provider/model statistics
#     - Log rotation (size and age-based)
#     - Integration with AIErrorHandler for error categorization
#     - Atomic JSON writes via AIUtil-JsonIO
#
# VERSION: 2.0.0
# AUTHOR: HYDRA System
# ===============================================================================

# === Module Imports ===
$script:ModuleRoot = Split-Path -Path $PSScriptRoot -Parent
$script:UtilsPath = Join-Path $script:ModuleRoot 'utils'

# Import AIUtil-JsonIO for atomic JSON operations
$jsonIOPath = Join-Path $script:UtilsPath 'AIUtil-JsonIO.psm1'
if (Test-Path $jsonIOPath) {
    Import-Module $jsonIOPath -Force -ErrorAction SilentlyContinue
}

# Import AIErrorHandler for error categorization
$errorHandlerPath = Join-Path $script:UtilsPath 'AIErrorHandler.psm1'
if (Test-Path $errorHandlerPath) {
    Import-Module $errorHandlerPath -Force -ErrorAction SilentlyContinue
}

# === Configuration ===
$script:LogPath = Join-Path $PSScriptRoot '..\..\logs'
$script:ErrorLogFile = Join-Path $script:LogPath 'errors.log'
$script:AILogFile = Join-Path $script:LogPath 'ai-requests.log'
$script:StatsFile = Join-Path $script:LogPath 'stats.json'
$script:MaxLogSizeMB = 10
$script:MaxLogAgeDays = 30

# === Initialize Logging ===
function Initialize-ErrorLogger {
    <#
    .SYNOPSIS
        Initializes the error logger module.

    .DESCRIPTION
        Creates log directory if needed and performs log rotation.

    .OUTPUTS
        Hashtable with LogPath and Status.

    .EXAMPLE
        Initialize-ErrorLogger
    #>
    [CmdletBinding()]
    param()

    # Create logs directory if not exists
    if (-not (Test-Path $script:LogPath)) {
        New-Item -ItemType Directory -Path $script:LogPath -Force | Out-Null
    }

    # Rotate old logs
    Invoke-LogRotation

    Write-LogEntry -Level 'INFO' -Message "ErrorLogger initialized" -Source 'ErrorLogger'
    return @{ LogPath = $script:LogPath; Status = 'OK' }
}

# === Write Log Entry ===
function Write-LogEntry {
    <#
    .SYNOPSIS
        Writes a log entry to the specified log file.

    .DESCRIPTION
        Creates a timestamped, structured log entry with level, source, message, and optional data.

    .PARAMETER Level
        Log level: DEBUG, INFO, WARN, ERROR, or FATAL.

    .PARAMETER Message
        The log message.

    .PARAMETER Source
        Source component generating the log. Default: HYDRA.

    .PARAMETER Data
        Additional data to include as JSON.

    .PARAMETER LogFile
        Target log file. Default: errors.log.

    .OUTPUTS
        Hashtable representing the log entry.

    .EXAMPLE
        Write-LogEntry -Level 'INFO' -Message "Operation completed" -Source 'AI-Handler'

    .EXAMPLE
        Write-LogEntry -Level 'ERROR' -Message "Failed" -Data @{ code = 500 }
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateSet('DEBUG', 'INFO', 'WARN', 'ERROR', 'FATAL')]
        [string]$Level,

        [Parameter(Mandatory)]
        [string]$Message,

        [string]$Source = 'HYDRA',
        [hashtable]$Data = @{},
        [string]$LogFile = $script:ErrorLogFile
    )

    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss.fff"
    $entry = @{
        timestamp = $timestamp
        level = $Level
        source = $Source
        message = $Message
        data = $Data
    }

    # Format log line
    $logLine = "[$timestamp] [$Level] [$Source] $Message"
    if ($Data.Count -gt 0) {
        $dataJson = ($Data | ConvertTo-Json -Compress -Depth 3) -replace "`n", " "
        $logLine += " | $dataJson"
    }

    # Write to file
    try {
        # Ensure log directory exists
        $logDir = Split-Path -Path $LogFile -Parent
        if (-not (Test-Path $logDir)) {
            New-Item -ItemType Directory -Path $logDir -Force | Out-Null
        }
        Add-Content -Path $LogFile -Value $logLine -Encoding UTF8 -ErrorAction Stop
    } catch {
        Write-Warning "Failed to write log: $_"
    }

    return $entry
}

# === Log Error with Context ===
function Write-ErrorLog {
    <#
    .SYNOPSIS
        Logs an error with full context including exception details.

    .DESCRIPTION
        Creates a detailed error log entry with exception information,
        stack trace, and optional context data. Integrates with AIErrorHandler
        for error categorization when available.

    .PARAMETER Message
        The error message.

    .PARAMETER ErrorRecord
        PowerShell ErrorRecord object for extracting exception details.

    .PARAMETER Source
        Source component. Default: HYDRA.

    .PARAMETER Context
        Additional context hashtable.

    .OUTPUTS
        Hashtable representing the logged error entry.

    .EXAMPLE
        try { ... } catch { Write-ErrorLog -Message "Operation failed" -ErrorRecord $_ }

    .EXAMPLE
        Write-ErrorLog -Message "API error" -Context @{ provider = 'anthropic'; statusCode = 429 }
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Message,

        [System.Management.Automation.ErrorRecord]$ErrorRecord,
        [string]$Source = 'HYDRA',
        [hashtable]$Context = @{}
    )

    $data = $Context.Clone()

    if ($ErrorRecord) {
        $data['exception'] = $ErrorRecord.Exception.Message
        $data['category'] = $ErrorRecord.CategoryInfo.Category.ToString()
        $data['scriptLine'] = if ($ErrorRecord.InvocationInfo.Line) { $ErrorRecord.InvocationInfo.Line.Trim() } else { $null }
        $data['scriptPosition'] = $ErrorRecord.InvocationInfo.PositionMessage
        $data['stackTrace'] = $ErrorRecord.ScriptStackTrace

        # Integrate with AIErrorHandler for error categorization if available
        if (Get-Command -Name Get-ErrorCategory -ErrorAction SilentlyContinue) {
            try {
                $errorCategory = Get-ErrorCategory -Exception $ErrorRecord.Exception
                $data['aiCategory'] = $errorCategory.Category
                $data['recoverable'] = $errorCategory.Recoverable
                $data['retryAfter'] = $errorCategory.RetryAfter
                $data['fallback'] = $errorCategory.Fallback
            } catch {
                Write-Verbose "AIErrorHandler categorization failed: $_"
            }
        }
    }

    Write-LogEntry -Level 'ERROR' -Message $Message -Source $Source -Data $data
}

# === Log AI Error (Integration with AIErrorHandler) ===
function Write-AIErrorLog {
    <#
    .SYNOPSIS
        Logs an AI-specific error with categorization.

    .DESCRIPTION
        Specialized error logging for AI operations with category-based
        classification. Called by AIErrorHandler.Write-ErrorContext.

    .PARAMETER Category
        Error category from AIErrorHandler (RateLimit, Overloaded, AuthError, etc.).

    .PARAMETER Message
        The error message.

    .PARAMETER Provider
        AI provider name (ollama, anthropic, openai).

    .PARAMETER Model
        Model identifier.

    .PARAMETER Context
        Additional context hashtable.

    .OUTPUTS
        Hashtable representing the logged entry.

    .EXAMPLE
        Write-AIErrorLog -Category 'RateLimit' -Message "Too many requests" -Provider 'anthropic' -Model 'claude-3-5-haiku'
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Category,

        [Parameter(Mandatory)]
        [string]$Message,

        [string]$Provider = 'unknown',
        [string]$Model = 'unknown',
        [hashtable]$Context = @{}
    )

    $data = @{
        category = $Category
        provider = $Provider
        model = $Model
    }

    # Merge context
    foreach ($key in $Context.Keys) {
        $data[$key] = $Context[$key]
    }

    # Determine level based on category
    $level = switch ($Category) {
        'RateLimit'       { 'WARN' }
        'Overloaded'      { 'WARN' }
        'AuthError'       { 'ERROR' }
        'ServerError'     { 'ERROR' }
        'NetworkError'    { 'WARN' }
        'ValidationError' { 'ERROR' }
        default           { 'ERROR' }
    }

    Write-LogEntry -Level $level -Message "[$Category] $Message" -Source 'AI-Handler' -Data $data
}

# === Log AI Request ===
function Write-AIRequestLog {
    <#
    .SYNOPSIS
        Logs an AI request with timing and token metrics.

    .DESCRIPTION
        Creates a detailed log entry for AI API requests including
        provider, model, tokens, duration, and success status.

    .PARAMETER Provider
        AI provider name (ollama, anthropic, openai).

    .PARAMETER Model
        Model identifier.

    .PARAMETER Prompt
        The prompt text (truncated in logs).

    .PARAMETER InputTokens
        Number of input tokens.

    .PARAMETER OutputTokens
        Number of output tokens.

    .PARAMETER DurationMs
        Request duration in milliseconds.

    .PARAMETER Success
        Whether the request succeeded.

    .PARAMETER Error
        Error message if request failed.

    .OUTPUTS
        Hashtable representing the logged entry.

    .EXAMPLE
        Write-AIRequestLog -Provider 'ollama' -Model 'llama3.2:3b' -InputTokens 100 -OutputTokens 50 -DurationMs 1234 -Success $true
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Provider,

        [Parameter(Mandatory)]
        [string]$Model,

        [string]$Prompt,
        [int]$InputTokens = 0,
        [int]$OutputTokens = 0,
        [double]$DurationMs = 0,
        [bool]$Success = $true,
        [string]$Error = ''
    )

    $data = @{
        provider = $Provider
        model = $Model
        inputTokens = $InputTokens
        outputTokens = $OutputTokens
        durationMs = [math]::Round($DurationMs, 2)
        success = $Success
    }

    if ($Prompt) {
        $data['promptPreview'] = if ($Prompt.Length -gt 100) {
            $Prompt.Substring(0, 100) + "..."
        } else { $Prompt }
    }

    if ($Error) { $data['error'] = $Error }

    $level = if ($Success) { 'INFO' } else { 'ERROR' }
    $msg = "AI Request: $Provider/$Model - $(if($Success){'OK'}else{'FAILED'}) (${DurationMs}ms)"

    Write-LogEntry -Level $level -Message $msg -Source 'AI-Handler' -Data $data -LogFile $script:AILogFile

    # Update stats using atomic JSON write
    Update-AIStats -Provider $Provider -Model $Model -InputTokens $InputTokens -OutputTokens $OutputTokens -DurationMs $DurationMs -Success $Success
}

# === Update AI Statistics (Using AIUtil-JsonIO) ===
function Update-AIStats {
    <#
    .SYNOPSIS
        Updates AI usage statistics with atomic JSON writes.

    .DESCRIPTION
        Tracks cumulative AI usage statistics per provider/model
        using atomic file writes to prevent corruption.

    .PARAMETER Provider
        AI provider name.

    .PARAMETER Model
        Model identifier.

    .PARAMETER InputTokens
        Number of input tokens.

    .PARAMETER OutputTokens
        Number of output tokens.

    .PARAMETER DurationMs
        Request duration in milliseconds.

    .PARAMETER Success
        Whether the request succeeded.

    .EXAMPLE
        Update-AIStats -Provider 'ollama' -Model 'llama3.2:3b' -InputTokens 100 -OutputTokens 50 -DurationMs 1234 -Success $true
    #>
    [CmdletBinding()]
    param(
        [string]$Provider,
        [string]$Model,
        [int]$InputTokens = 0,
        [int]$OutputTokens = 0,
        [double]$DurationMs = 0,
        [bool]$Success = $true
    )

    # Check if Read-JsonFile is available (from AIUtil-JsonIO)
    if (-not (Get-Command -Name Read-JsonFile -ErrorAction SilentlyContinue)) {
        Write-Verbose "AIUtil-JsonIO not available, skipping stats update"
        return
    }

    try {
        # Read existing stats using AIUtil-JsonIO
        $stats = Read-JsonFile -Path $script:StatsFile -Default @{
            lastUpdated = $null
            providers = @{}
            totalRequests = 0
            totalSuccess = 0
            totalFailed = 0
            totalTokens = 0
            totalDurationMs = 0
        }

        # Ensure stats is a hashtable
        if ($stats -is [PSCustomObject]) {
            $stats = $stats | ConvertTo-Hashtable
        }

        # Initialize provider if not exists
        if (-not $stats.providers) {
            $stats.providers = @{}
        }
        if (-not $stats.providers[$Provider]) {
            $stats.providers[$Provider] = @{
                models = @{}
                requests = 0
                success = 0
                failed = 0
            }
        }

        # Initialize model if not exists
        if (-not $stats.providers[$Provider].models) {
            $stats.providers[$Provider].models = @{}
        }
        if (-not $stats.providers[$Provider].models[$Model]) {
            $stats.providers[$Provider].models[$Model] = @{
                requests = 0
                success = 0
                failed = 0
                inputTokens = 0
                outputTokens = 0
                totalDurationMs = 0
            }
        }

        # Update stats
        $stats.lastUpdated = (Get-Date).ToString('o')
        $stats.totalRequests++
        $stats.totalTokens += ($InputTokens + $OutputTokens)
        $stats.totalDurationMs += $DurationMs

        $stats.providers[$Provider].requests++
        $stats.providers[$Provider].models[$Model].requests++
        $stats.providers[$Provider].models[$Model].inputTokens += $InputTokens
        $stats.providers[$Provider].models[$Model].outputTokens += $OutputTokens
        $stats.providers[$Provider].models[$Model].totalDurationMs += $DurationMs

        if ($Success) {
            $stats.totalSuccess++
            $stats.providers[$Provider].success++
            $stats.providers[$Provider].models[$Model].success++
        } else {
            $stats.totalFailed++
            $stats.providers[$Provider].failed++
            $stats.providers[$Provider].models[$Model].failed++
        }

        # Write using atomic JSON write from AIUtil-JsonIO
        if (Get-Command -Name Write-JsonFileAtomic -ErrorAction SilentlyContinue) {
            Write-JsonFileAtomic -Path $script:StatsFile -Data $stats | Out-Null
        } elseif (Get-Command -Name Write-JsonFile -ErrorAction SilentlyContinue) {
            Write-JsonFile -Path $script:StatsFile -Data $stats | Out-Null
        }
    } catch {
        Write-Verbose "Failed to update stats: $_"
    }
}

# === Log Rotation ===
function Invoke-LogRotation {
    <#
    .SYNOPSIS
        Performs log rotation based on size and age.

    .DESCRIPTION
        Rotates logs when they exceed MaxLogSizeMB and cleans up
        logs older than MaxLogAgeDays.

    .EXAMPLE
        Invoke-LogRotation
    #>
    [CmdletBinding()]
    param()

    $logFiles = @($script:ErrorLogFile, $script:AILogFile)

    foreach ($logFile in $logFiles) {
        if (-not (Test-Path $logFile)) { continue }

        $fileInfo = Get-Item $logFile

        # Size-based rotation
        if ($fileInfo.Length -gt ($script:MaxLogSizeMB * 1MB)) {
            $rotatedName = $logFile -replace '\.log$', ".$(Get-Date -Format 'yyyyMMdd-HHmmss').log"
            Move-Item -Path $logFile -Destination $rotatedName -Force
            Write-LogEntry -Level 'INFO' -Message "Log rotated: $rotatedName" -Source 'ErrorLogger'
        }
    }

    # Clean old rotated logs
    Get-ChildItem -Path $script:LogPath -Filter "*.log" -ErrorAction SilentlyContinue |
        Where-Object { $_.LastWriteTime -lt (Get-Date).AddDays(-$script:MaxLogAgeDays) } |
        Remove-Item -Force -ErrorAction SilentlyContinue
}

# === Get Recent Errors ===
function Get-RecentErrors {
    <#
    .SYNOPSIS
        Retrieves recent error log entries.

    .DESCRIPTION
        Parses the error log file and returns recent entries
        matching the specified criteria.

    .PARAMETER Count
        Maximum number of entries to return. Default: 10.

    .PARAMETER Level
        Filter by log level. Default: ERROR.

    .PARAMETER Source
        Filter by source component.

    .OUTPUTS
        Array of log entry hashtables.

    .EXAMPLE
        Get-RecentErrors -Count 5 -Level 'ERROR'

    .EXAMPLE
        Get-RecentErrors -Source 'AI-Handler'
    #>
    [CmdletBinding()]
    param(
        [int]$Count = 10,
        [string]$Level = 'ERROR',
        [string]$Source = ''
    )

    if (-not (Test-Path $script:ErrorLogFile)) {
        return @()
    }

    $lines = Get-Content -Path $script:ErrorLogFile -Tail ($Count * 5) -ErrorAction SilentlyContinue

    $errors = @()
    foreach ($line in $lines) {
        if ($line -match "^\[([^\]]+)\] \[($Level)\] \[([^\]]+)\] (.+)$") {
            $entry = @{
                timestamp = $Matches[1]
                level = $Matches[2]
                source = $Matches[3]
                message = $Matches[4]
            }

            if (-not $Source -or $entry.source -eq $Source) {
                $errors += $entry
            }
        }
    }

    return $errors | Select-Object -Last $Count
}

# === Get AI Request Stats ===
function Get-AIRequestStats {
    <#
    .SYNOPSIS
        Retrieves AI request statistics.

    .DESCRIPTION
        Returns aggregated statistics about AI requests from the log file
        or from the JSON stats file if available.

    .PARAMETER Hours
        Time window in hours. Default: 24.

    .PARAMETER FromStatsFile
        Read from JSON stats file instead of parsing logs.

    .OUTPUTS
        Hashtable with request statistics.

    .EXAMPLE
        Get-AIRequestStats -Hours 24

    .EXAMPLE
        Get-AIRequestStats -FromStatsFile
    #>
    [CmdletBinding()]
    param(
        [int]$Hours = 24,
        [switch]$FromStatsFile
    )

    # Try to read from stats file first if available and requested
    if ($FromStatsFile -and (Get-Command -Name Read-JsonFile -ErrorAction SilentlyContinue)) {
        $stats = Read-JsonFile -Path $script:StatsFile -Default $null
        if ($stats) {
            return $stats
        }
    }

    # Fall back to parsing log file
    if (-not (Test-Path $script:AILogFile)) {
        return @{ requests = 0; success = 0; failed = 0; providers = @{} }
    }

    $cutoff = (Get-Date).AddHours(-$Hours)
    $lines = Get-Content -Path $script:AILogFile -ErrorAction SilentlyContinue

    $stats = @{
        requests = 0
        success = 0
        failed = 0
        totalTokens = 0
        totalDurationMs = 0
        providers = @{}
    }

    foreach ($line in $lines) {
        if ($line -match "^\[([^\]]+)\]") {
            try {
                $timestamp = [datetime]::ParseExact($Matches[1], "yyyy-MM-dd HH:mm:ss.fff", $null)
                if ($timestamp -lt $cutoff) { continue }
            } catch {
                continue
            }
        }

        if ($line -match '"provider":\s*"([^"]+)"') {
            $provider = $Matches[1]
            if (-not $stats.providers[$provider]) {
                $stats.providers[$provider] = @{ requests = 0; success = 0 }
            }
            $stats.providers[$provider].requests++
            $stats.requests++
        }

        if ($line -match '"success":\s*true') {
            $stats.success++
            if ($provider) { $stats.providers[$provider].success++ }
        } elseif ($line -match '"success":\s*false') {
            $stats.failed++
        }

        if ($line -match '"inputTokens":\s*(\d+)') {
            $stats.totalTokens += [int]$Matches[1]
        }
        if ($line -match '"outputTokens":\s*(\d+)') {
            $stats.totalTokens += [int]$Matches[1]
        }
        if ($line -match '"durationMs":\s*([\d.]+)') {
            $stats.totalDurationMs += [double]$Matches[1]
        }
    }

    return $stats
}

# === Get Error Log Path ===
function Get-ErrorLogPath {
    <#
    .SYNOPSIS
        Returns the path to the error log file.

    .OUTPUTS
        String path to the error log file.

    .EXAMPLE
        Get-ErrorLogPath
    #>
    [CmdletBinding()]
    param()

    return $script:ErrorLogFile
}

# === Get AI Log Path ===
function Get-AILogPath {
    <#
    .SYNOPSIS
        Returns the path to the AI requests log file.

    .OUTPUTS
        String path to the AI log file.

    .EXAMPLE
        Get-AILogPath
    #>
    [CmdletBinding()]
    param()

    return $script:AILogFile
}

# === Export ===
Export-ModuleMember -Function @(
    'Initialize-ErrorLogger',
    'Write-LogEntry',
    'Write-ErrorLog',
    'Write-AIErrorLog',
    'Write-AIRequestLog',
    'Update-AIStats',
    'Invoke-LogRotation',
    'Get-RecentErrors',
    'Get-AIRequestStats',
    'Get-ErrorLogPath',
    'Get-AILogPath'
)

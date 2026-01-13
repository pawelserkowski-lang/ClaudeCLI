# ═══════════════════════════════════════════════════════════════════════════════
# ERROR LOGGER MODULE - Centralized error logging for HYDRA
# ═══════════════════════════════════════════════════════════════════════════════

$script:LogPath = Join-Path $PSScriptRoot '..\..\logs'
$script:ErrorLogFile = Join-Path $script:LogPath 'errors.log'
$script:AILogFile = Join-Path $script:LogPath 'ai-requests.log'
$script:MaxLogSizeMB = 10
$script:MaxLogAgeDays = 30

# === Initialize Logging ===
function Initialize-ErrorLogger {
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
        Add-Content -Path $LogFile -Value $logLine -Encoding UTF8 -ErrorAction Stop
    } catch {
        Write-Warning "Failed to write log: $_"
    }

    return $entry
}

# === Log Error with Context ===
function Write-ErrorLog {
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
        $data['scriptLine'] = $ErrorRecord.InvocationInfo.Line?.Trim()
        $data['scriptPosition'] = $ErrorRecord.InvocationInfo.PositionMessage
        $data['stackTrace'] = $ErrorRecord.ScriptStackTrace
    }

    Write-LogEntry -Level 'ERROR' -Message $Message -Source $Source -Data $data
}

# === Log AI Request ===
function Write-AIRequestLog {
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
}

# === Log Rotation ===
function Invoke-LogRotation {
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
    [CmdletBinding()]
    param(
        [int]$Hours = 24
    )

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
            $timestamp = [datetime]::ParseExact($Matches[1], "yyyy-MM-dd HH:mm:ss.fff", $null)
            if ($timestamp -lt $cutoff) { continue }
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

# === Export ===
Export-ModuleMember -Function @(
    'Initialize-ErrorLogger',
    'Write-LogEntry',
    'Write-ErrorLog',
    'Write-AIRequestLog',
    'Invoke-LogRotation',
    'Get-RecentErrors',
    'Get-AIRequestStats'
)

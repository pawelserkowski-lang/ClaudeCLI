#Requires -Version 5.1

<#
.SYNOPSIS
    Centralized error handling module for AI Handler operations.

.DESCRIPTION
    Provides unified error classification, structured error objects, retry logic,
    and fallback mechanisms for AI provider operations. Integrates with ErrorLogger
    when available for persistent logging.

.NOTES
    Module: AIErrorHandler
    Version: 1.0.0
    Author: HYDRA System
    Requires: PowerShell 5.1+
#>

# ============================================================================
# ERROR CATEGORIES CONFIGURATION
# ============================================================================

<#
.SYNOPSIS
    Error category definitions with patterns, recovery options, and fallback strategies.

.DESCRIPTION
    Each category contains:
    - Patterns: Regex patterns to match error messages
    - Recoverable: Whether the error can be retried
    - RetryAfter: Suggested delay in milliseconds before retry
    - Fallback: Suggested fallback action
#>
$script:ErrorCategories = @{
    RateLimit = @{
        Patterns = @(
            'rate.?limit',
            'too.?many.?requests',
            '429',
            'quota.?exceeded',
            'throttl',
            'requests?.?per.?minute',
            'rpm.?limit',
            'tpm.?limit',
            'tokens?.?per.?minute'
        )
        Recoverable = $true
        RetryAfter = 60000  # 60 seconds
        Fallback = 'SwitchProvider'
    }

    Overloaded = @{
        Patterns = @(
            'overloaded',
            'capacity',
            '503',
            'service.?unavailable',
            'temporarily.?unavailable',
            'server.?busy',
            'high.?demand',
            'try.?again.?later'
        )
        Recoverable = $true
        RetryAfter = 30000  # 30 seconds
        Fallback = 'SwitchModel'
    }

    AuthError = @{
        Patterns = @(
            'auth',
            '401',
            '403',
            'unauthorized',
            'forbidden',
            'invalid.?api.?key',
            'api.?key.?invalid',
            'authentication.?failed',
            'access.?denied',
            'permission.?denied'
        )
        Recoverable = $false
        RetryAfter = 0
        Fallback = 'SwitchProvider'
    }

    ServerError = @{
        Patterns = @(
            '500',
            '502',
            '504',
            'internal.?server.?error',
            'bad.?gateway',
            'gateway.?timeout',
            'server.?error',
            'upstream.?error'
        )
        Recoverable = $true
        RetryAfter = 5000  # 5 seconds
        Fallback = 'Retry'
    }

    NetworkError = @{
        Patterns = @(
            'network',
            'connection',
            'timeout',
            'timed?.?out',
            'unreachable',
            'dns',
            'socket',
            'econnrefused',
            'econnreset',
            'enotfound',
            'no.?route',
            'host.?not.?found'
        )
        Recoverable = $true
        RetryAfter = 3000  # 3 seconds
        Fallback = 'Retry'
    }

    ValidationError = @{
        Patterns = @(
            'invalid',
            'validation',
            'malformed',
            'bad.?request',
            '400',
            'missing.?required',
            'parameter',
            'schema',
            'format.?error',
            'parse.?error',
            'json.?error'
        )
        Recoverable = $false
        RetryAfter = 0
        Fallback = 'None'
    }
}

# ============================================================================
# ERROR CLASSIFICATION
# ============================================================================

function Get-ErrorCategory {
    <#
    .SYNOPSIS
        Classifies an exception into a predefined error category.

    .DESCRIPTION
        Analyzes the exception message and type against known patterns
        to determine the error category for appropriate handling.

    .PARAMETER Exception
        The exception object to classify.

    .PARAMETER ErrorMessage
        Alternative: direct error message string to classify.

    .OUTPUTS
        PSCustomObject with Category, Recoverable, RetryAfter, Fallback, MatchedPattern properties.

    .EXAMPLE
        $category = Get-ErrorCategory -Exception $_.Exception
        if ($category.Recoverable) { Start-Sleep -Milliseconds $category.RetryAfter }

    .EXAMPLE
        Get-ErrorCategory -ErrorMessage "Rate limit exceeded"
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(ParameterSetName = 'Exception')]
        [System.Exception]$Exception,

        [Parameter(ParameterSetName = 'Message')]
        [string]$ErrorMessage
    )

    # Build search text from exception or direct message
    $searchText = if ($Exception) {
        @(
            $Exception.Message,
            $Exception.GetType().Name,
            $(if ($Exception.InnerException) { $Exception.InnerException.Message } else { '' })
        ) -join ' '
    } else {
        $ErrorMessage
    }

    $searchText = $searchText.ToLower()

    # Search through categories
    foreach ($categoryName in $script:ErrorCategories.Keys) {
        $category = $script:ErrorCategories[$categoryName]

        foreach ($pattern in $category.Patterns) {
            if ($searchText -match $pattern) {
                return [PSCustomObject]@{
                    Category       = $categoryName
                    Recoverable    = $category.Recoverable
                    RetryAfter     = $category.RetryAfter
                    Fallback       = $category.Fallback
                    MatchedPattern = $pattern
                }
            }
        }
    }

    # Unknown category - default to non-recoverable
    return [PSCustomObject]@{
        Category       = 'Unknown'
        Recoverable    = $false
        RetryAfter     = 0
        Fallback       = 'None'
        MatchedPattern = $null
    }
}

# ============================================================================
# STRUCTURED ERROR OBJECTS
# ============================================================================

function New-AIError {
    <#
    .SYNOPSIS
        Creates a structured error object for AI operations.

    .DESCRIPTION
        Generates a standardized error object containing all relevant context
        for debugging, logging, and recovery decisions.

    .PARAMETER Message
        The error message describing what went wrong.

    .PARAMETER Operation
        The operation that was being performed (e.g., 'Invoke-AIRequest', 'Get-Completion').

    .PARAMETER Provider
        The AI provider involved (e.g., 'ollama', 'anthropic', 'openai').

    .PARAMETER Model
        The model being used when the error occurred.

    .PARAMETER Exception
        The original exception object, if available.

    .PARAMETER Context
        Additional context hashtable with operation-specific details.

    .OUTPUTS
        PSCustomObject with structured error information.

    .EXAMPLE
        $error = New-AIError -Message "API call failed" -Operation "Invoke-AIRequest" `
                             -Provider "anthropic" -Model "claude-3-5-haiku" -Exception $_.Exception
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory)]
        [string]$Message,

        [Parameter(Mandatory)]
        [string]$Operation,

        [Parameter()]
        [string]$Provider = 'unknown',

        [Parameter()]
        [string]$Model = 'unknown',

        [Parameter()]
        [System.Exception]$Exception,

        [Parameter()]
        [hashtable]$Context = @{}
    )

    # Classify the error
    $categoryInfo = if ($Exception) {
        Get-ErrorCategory -Exception $Exception
    } elseif ($Message) {
        Get-ErrorCategory -ErrorMessage $Message
    } else {
        Get-ErrorCategory -ErrorMessage 'unknown'
    }

    # Build structured error object
    $errorObject = [PSCustomObject]@{
        Message       = $Message
        Operation     = $Operation
        Provider      = $Provider
        Model         = $Model
        Category      = $categoryInfo.Category
        Recoverable   = $categoryInfo.Recoverable
        RetryAfter    = $categoryInfo.RetryAfter
        Fallback      = $categoryInfo.Fallback
        Timestamp     = [DateTime]::UtcNow.ToString('o')
        Context       = $Context
        ExceptionType = $(if ($Exception) { $Exception.GetType().FullName } else { $null })
        StackTrace    = $(if ($Exception) { $Exception.StackTrace } else { $null })
        InnerMessage  = $(if ($Exception -and $Exception.InnerException) {
            $Exception.InnerException.Message
        } else { $null })
    }

    return $errorObject
}

# ============================================================================
# UNIFIED OPERATION WRAPPER
# ============================================================================

function Invoke-AIOperation {
    <#
    .SYNOPSIS
        Unified wrapper for AI operations with retry logic and fallback support.

    .DESCRIPTION
        Executes an AI operation with automatic retry on recoverable errors,
        customizable callbacks for error handling, and fallback mechanisms.

    .PARAMETER Operation
        Name of the operation for logging purposes.

    .PARAMETER Script
        ScriptBlock containing the operation to execute.

    .PARAMETER MaxRetries
        Maximum number of retry attempts. Default: 3.

    .PARAMETER RetryDelayMs
        Base delay in milliseconds between retries. Default: 1000.
        Automatically adjusted based on error category.

    .PARAMETER OnError
        ScriptBlock to execute when an error occurs. Receives $AIError object.

    .PARAMETER OnRetry
        ScriptBlock to execute before each retry. Receives $Attempt and $AIError.

    .PARAMETER OnFallback
        ScriptBlock to execute when all retries fail. Receives $AIError.
        Should return alternative result or $null.

    .PARAMETER Provider
        Provider name for error context.

    .PARAMETER Model
        Model name for error context.

    .PARAMETER Context
        Additional context hashtable.

    .OUTPUTS
        PSCustomObject with Success, Result, Attempts, UsedFallback, Error properties.

    .EXAMPLE
        $result = Invoke-AIOperation -Operation "GetCompletion" -Script {
            Invoke-RestMethod -Uri $apiUrl -Body $body
        } -MaxRetries 3 -OnError { Write-Warning $args[0].Message }

    .EXAMPLE
        $result = Invoke-AIOperation -Operation "LocalQuery" -Script {
            & ollama run llama3.2:3b $prompt
        } -OnFallback {
            # Fallback to cloud provider
            Invoke-RestMethod -Uri $cloudApiUrl -Body $body
        }
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory)]
        [string]$Operation,

        [Parameter(Mandatory)]
        [scriptblock]$Script,

        [Parameter()]
        [int]$MaxRetries = 3,

        [Parameter()]
        [int]$RetryDelayMs = 1000,

        [Parameter()]
        [scriptblock]$OnError,

        [Parameter()]
        [scriptblock]$OnRetry,

        [Parameter()]
        [scriptblock]$OnFallback,

        [Parameter()]
        [string]$Provider = 'unknown',

        [Parameter()]
        [string]$Model = 'unknown',

        [Parameter()]
        [hashtable]$Context = @{}
    )

    $attempt = 0
    $lastError = $null
    $usedFallback = $false

    while ($attempt -lt $MaxRetries) {
        $attempt++

        try {
            # Execute the operation
            $result = & $Script

            # Success - return result
            return [PSCustomObject]@{
                Success      = $true
                Result       = $result
                Attempts     = $attempt
                UsedFallback = $false
                Error        = $null
            }
        }
        catch {
            # Create structured error
            $aiError = New-AIError -Message $_.Exception.Message `
                                   -Operation $Operation `
                                   -Provider $Provider `
                                   -Model $Model `
                                   -Exception $_.Exception `
                                   -Context ($Context + @{ Attempt = $attempt })

            $lastError = $aiError

            # Call OnError callback
            if ($OnError) {
                try {
                    & $OnError $aiError
                } catch {
                    Write-Warning "OnError callback failed: $_"
                }
            }

            # Log to ErrorLogger if available
            Write-ErrorContext -AIError $aiError -Verbose:$false

            # Check if we should retry
            if (-not $aiError.Recoverable) {
                Write-Verbose "[$Operation] Non-recoverable error (${$aiError.Category}), skipping retries"
                break
            }

            # Check if we have retries left
            if ($attempt -lt $MaxRetries) {
                # Calculate delay
                $delay = [Math]::Max($RetryDelayMs, $aiError.RetryAfter)

                # Exponential backoff
                $delay = $delay * [Math]::Pow(1.5, $attempt - 1)
                $delay = [Math]::Min($delay, 120000)  # Cap at 2 minutes

                Write-Verbose "[$Operation] Attempt $attempt failed, retrying in $($delay/1000)s..."

                # Call OnRetry callback
                if ($OnRetry) {
                    try {
                        & $OnRetry $attempt $aiError
                    } catch {
                        Write-Warning "OnRetry callback failed: $_"
                    }
                }

                Start-Sleep -Milliseconds $delay
            }
        }
    }

    # All retries exhausted - try fallback
    if ($OnFallback -and $lastError) {
        Write-Verbose "[$Operation] All retries exhausted, attempting fallback..."

        try {
            $fallbackResult = & $OnFallback $lastError

            if ($null -ne $fallbackResult) {
                return [PSCustomObject]@{
                    Success      = $true
                    Result       = $fallbackResult
                    Attempts     = $attempt
                    UsedFallback = $true
                    Error        = $lastError
                }
            }
        }
        catch {
            Write-Warning "Fallback failed: $_"
            $lastError = New-AIError -Message "Fallback failed: $($_.Exception.Message)" `
                                     -Operation "$Operation.Fallback" `
                                     -Provider $Provider `
                                     -Model $Model `
                                     -Exception $_.Exception `
                                     -Context $Context
        }
    }

    # Complete failure
    return [PSCustomObject]@{
        Success      = $false
        Result       = $null
        Attempts     = $attempt
        UsedFallback = $usedFallback
        Error        = $lastError
    }
}

# ============================================================================
# ERROR LOGGING AND CONTEXT
# ============================================================================

function Write-ErrorContext {
    <#
    .SYNOPSIS
        Formats and logs an AI error with rich context.

    .DESCRIPTION
        Outputs formatted error information to the console and optionally
        to the ErrorLogger module for persistent storage.

    .PARAMETER AIError
        The structured AI error object from New-AIError.

    .PARAMETER LogToFile
        If true, also logs to ErrorLogger (when available). Default: true.

    .PARAMETER Detailed
        If true, includes full stack trace and context. Default: false.

    .EXAMPLE
        Write-ErrorContext -AIError $error -Detailed

    .EXAMPLE
        $error | Write-ErrorContext -LogToFile
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [PSCustomObject]$AIError,

        [Parameter()]
        [switch]$LogToFile = $true,

        [Parameter()]
        [switch]$Detailed
    )

    process {
        # Build formatted output
        $separator = "-" * 60
        $output = @"

$separator
AI ERROR: $($AIError.Category)
$separator
Timestamp : $($AIError.Timestamp)
Operation : $($AIError.Operation)
Provider  : $($AIError.Provider)
Model     : $($AIError.Model)
Message   : $($AIError.Message)
Recoverable: $($AIError.Recoverable)
Fallback  : $($AIError.Fallback)
"@

        if ($Detailed) {
            $output += @"

--- DETAILED CONTEXT ---
Exception Type: $($AIError.ExceptionType)
Inner Message : $($AIError.InnerMessage)
Context       : $($AIError.Context | ConvertTo-Json -Compress)
Stack Trace   :
$($AIError.StackTrace)
"@
        }

        $output += "`n$separator`n"

        # Output to console with appropriate color
        $color = switch ($AIError.Category) {
            'RateLimit'       { 'Yellow' }
            'Overloaded'      { 'Yellow' }
            'AuthError'       { 'Red' }
            'ServerError'     { 'Magenta' }
            'NetworkError'    { 'Cyan' }
            'ValidationError' { 'Red' }
            default           { 'Gray' }
        }

        Write-Host $output -ForegroundColor $color

        # Log to ErrorLogger if available and requested
        if ($LogToFile) {
            try {
                # Check if ErrorLogger is available
                $errorLoggerPath = Join-Path $PSScriptRoot "..\modules\ErrorLogger.psm1"
                if (Test-Path $errorLoggerPath) {
                    # Import if not already loaded
                    if (-not (Get-Module -Name ErrorLogger)) {
                        Import-Module $errorLoggerPath -Force -ErrorAction SilentlyContinue
                    }

                    # Log using ErrorLogger if Write-AIErrorLog exists
                    if (Get-Command -Name Write-AIErrorLog -ErrorAction SilentlyContinue) {
                        Write-AIErrorLog -Category $AIError.Category `
                                         -Message $AIError.Message `
                                         -Provider $AIError.Provider `
                                         -Model $AIError.Model `
                                         -Context $AIError.Context
                    }
                }
            }
            catch {
                # Silently ignore ErrorLogger failures
                Write-Verbose "ErrorLogger integration failed: $_"
            }
        }
    }
}

# ============================================================================
# UTILITY FUNCTIONS
# ============================================================================

function Get-AIErrorCategories {
    <#
    .SYNOPSIS
        Returns all configured error categories and their properties.

    .DESCRIPTION
        Useful for debugging and understanding error classification rules.

    .EXAMPLE
        Get-AIErrorCategories | Format-Table
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject[]])]
    param()

    $script:ErrorCategories.GetEnumerator() | ForEach-Object {
        [PSCustomObject]@{
            Category    = $_.Key
            Patterns    = $_.Value.Patterns -join ', '
            Recoverable = $_.Value.Recoverable
            RetryAfter  = "$($_.Value.RetryAfter)ms"
            Fallback    = $_.Value.Fallback
        }
    }
}

function Test-AIError {
    <#
    .SYNOPSIS
        Tests error classification with a sample message.

    .DESCRIPTION
        Useful for debugging and validating error patterns.

    .PARAMETER Message
        Error message to test.

    .EXAMPLE
        Test-AIError -Message "Rate limit exceeded, try again in 60s"
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Message
    )

    $category = Get-ErrorCategory -ErrorMessage $Message

    Write-Host "`nError Classification Test" -ForegroundColor Cyan
    Write-Host "-" * 40
    Write-Host "Input    : $Message"
    Write-Host "Category : $($category.Category)" -ForegroundColor Yellow
    Write-Host "Pattern  : $($category.MatchedPattern)"
    Write-Host "Recover  : $($category.Recoverable)"
    Write-Host "Retry    : $($category.RetryAfter)ms"
    Write-Host "Fallback : $($category.Fallback)"

    return $category
}

# ============================================================================
# MODULE EXPORTS
# ============================================================================

Export-ModuleMember -Function @(
    'Get-ErrorCategory',
    'New-AIError',
    'Invoke-AIOperation',
    'Write-ErrorContext',
    'Get-AIErrorCategories',
    'Test-AIError'
) -Variable @(
    'ErrorCategories'
)

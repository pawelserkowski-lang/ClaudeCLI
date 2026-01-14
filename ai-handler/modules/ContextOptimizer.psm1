#Requires -Version 5.1
<#
.SYNOPSIS
    Context Optimizer Module - Token savings and memory management for HYDRA

.DESCRIPTION
    Comprehensive context optimization system providing:
    - AutoMemory: Automatic saving of important context to Serena memories
    - MCPCache: Caching of MCP tool results to avoid redundant calls
    - ContextCompressor: Compression of long context to save tokens
    - SessionState: Persistent state between messages
    - TokenCounter: Accurate token estimation for context management

.VERSION
    1.0.0

.AUTHOR
    HYDRA System

.NOTES
    Designed to reduce token usage by 30-50% while maintaining context quality.

    Integration points:
    - Serena MCP for memory persistence
    - Local file cache for MCP results
    - AI summarization for context compression

.EXAMPLE
    # Compress context before AI call
    $compressed = Compress-Context -Text $longText -MaxTokens 2000

.EXAMPLE
    # Cache MCP result
    $result = Get-CachedMCPResult -Tool "read_file" -Args @{path="file.txt"}
#>

# ============================================================================
# MODULE INITIALIZATION
# ============================================================================

$script:ModuleRoot = Split-Path $PSScriptRoot -Parent
$script:CacheDir = Join-Path $script:ModuleRoot "cache\mcp-cache"
$script:SessionFile = Join-Path $script:ModuleRoot "session-state.json"
$script:MemoriesDir = "C:\Users\BIURODOM\Desktop\ClaudeCLI\.serena\memories"

# Create cache directory if not exists
if (-not (Test-Path $script:CacheDir)) {
    New-Item -ItemType Directory -Path $script:CacheDir -Force | Out-Null
}

# In-memory cache with TTL
$script:MCPCache = @{}
$script:SessionState = @{
    StartTime = Get-Date
    TokensUsed = 0
    ToolCalls = @()
    KeyDecisions = @()
    FilesMentioned = @()
    ErrorsEncountered = @()
}

# Token estimation constants
$script:TokensPerChar = 0.25  # ~4 chars per token for English
$script:TokensPerCharPolish = 0.35  # Polish uses more tokens

# ============================================================================
# TOKEN COUNTER
# ============================================================================

function Get-TokenEstimate {
    <#
    .SYNOPSIS
        Estimates token count for text

    .PARAMETER Text
        The text to estimate tokens for

    .PARAMETER Language
        Language hint: "en", "pl", "code" (affects estimation)

    .OUTPUTS
        Integer - estimated token count
    #>
    [CmdletBinding()]
    [OutputType([int])]
    param(
        [Parameter(Mandatory)]
        [string]$Text,

        [ValidateSet("en", "pl", "code", "auto")]
        [string]$Language = "auto"
    )

    if (-not $Text) { return 0 }

    # Auto-detect language
    if ($Language -eq "auto") {
        # Detect Polish by checking for common Polish words or diacritics pattern
        $polishPattern = '[\u0105\u0107\u0119\u0142\u0144\u00F3\u015B\u017A\u017C\u0104\u0106\u0118\u0141\u0143\u00D3\u015A\u0179\u017B]'
        if ($Text -match $polishPattern) {
            $Language = "pl"
        } elseif ($Text -match '(function|def |class |import |const |let |var )') {
            $Language = "code"
        } else {
            $Language = "en"
        }
    }

    $ratio = switch ($Language) {
        "pl"   { $script:TokensPerCharPolish }
        "code" { 0.3 }  # Code is more token-efficient
        default { $script:TokensPerChar }
    }

    return [Math]::Ceiling($Text.Length * $ratio)
}

function Get-ContextTokenUsage {
    <#
    .SYNOPSIS
        Analyzes token usage in current context

    .PARAMETER Context
        Hashtable with context parts (system, messages, tools, etc.)

    .OUTPUTS
        Detailed breakdown of token usage
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [hashtable]$Context
    )

    $usage = @{
        Total = 0
        Breakdown = @{}
        Recommendations = @()
    }

    foreach ($key in $Context.Keys) {
        $text = if ($Context[$key] -is [string]) {
            $Context[$key]
        } elseif ($Context[$key] -is [array]) {
            ($Context[$key] | ConvertTo-Json -Compress)
        } else {
            ($Context[$key] | ConvertTo-Json -Compress)
        }

        $tokens = Get-TokenEstimate -Text $text
        $usage.Breakdown[$key] = $tokens
        $usage.Total += $tokens
    }

    # Generate recommendations
    foreach ($part in $usage.Breakdown.Keys) {
        $tokens = $usage.Breakdown[$part]
        if ($tokens -gt 10000) {
            $usage.Recommendations += "Consider compressing '$part' ($tokens tokens)"
        }
    }

    if ($usage.Total -gt 50000) {
        $usage.Recommendations += "Total context ($($usage.Total) tokens) approaching limit - summarize history"
    }

    return $usage
}

# ============================================================================
# MCP CACHE
# ============================================================================

function Get-MCPCacheKey {
    <#
    .SYNOPSIS
        Generates cache key for MCP tool call
    #>
    param(
        [string]$Tool,
        [hashtable]$Args
    )

    $argsJson = $Args | ConvertTo-Json -Compress -Depth 5
    $hash = [System.Security.Cryptography.SHA256]::Create()
    $bytes = [System.Text.Encoding]::UTF8.GetBytes("$Tool|$argsJson")
    $hashBytes = $hash.ComputeHash($bytes)
    return [BitConverter]::ToString($hashBytes).Replace("-", "").Substring(0, 16)
}

function Get-CachedMCPResult {
    <#
    .SYNOPSIS
        Retrieves cached MCP result if available

    .PARAMETER Tool
        MCP tool name (e.g., "read_file", "list_directory")

    .PARAMETER Args
        Tool arguments

    .PARAMETER MaxAgeSeconds
        Maximum cache age (default: 300 = 5 minutes)

    .OUTPUTS
        Cached result or $null if not cached/expired
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Tool,

        [Parameter(Mandatory)]
        [hashtable]$Args,

        [int]$MaxAgeSeconds = 300
    )

    # Only cache read-only operations
    $readOnlyTools = @(
        "read_file", "list_directory", "get_file_info",
        "find_symbol", "get_symbols_overview", "search_for_pattern",
        "list_memories", "read_memory"
    )

    if ($Tool -notin $readOnlyTools) {
        return $null
    }

    $cacheKey = Get-MCPCacheKey -Tool $Tool -Args $Args

    # Check in-memory cache first
    if ($script:MCPCache.ContainsKey($cacheKey)) {
        $entry = $script:MCPCache[$cacheKey]
        $age = (Get-Date) - $entry.Timestamp

        if ($age.TotalSeconds -lt $MaxAgeSeconds) {
            Write-Verbose "[MCPCache] HIT (memory): $Tool - saved ~$(Get-TokenEstimate $entry.Result) tokens"
            return $entry.Result
        }
        else {
            $script:MCPCache.Remove($cacheKey)
        }
    }

    # Check file cache
    $cacheFile = Join-Path $script:CacheDir "$cacheKey.json"
    if (Test-Path $cacheFile) {
        $fileAge = (Get-Date) - (Get-Item $cacheFile).LastWriteTime

        if ($fileAge.TotalSeconds -lt $MaxAgeSeconds) {
            try {
                $cached = Get-Content $cacheFile -Raw | ConvertFrom-Json
                $script:MCPCache[$cacheKey] = @{
                    Result = $cached.Result
                    Timestamp = [DateTime]::Parse($cached.Timestamp)
                }
                Write-Verbose "[MCPCache] HIT (disk): $Tool"
                return $cached.Result
            }
            catch {
                Remove-Item $cacheFile -Force -ErrorAction SilentlyContinue
            }
        }
        else {
            Remove-Item $cacheFile -Force -ErrorAction SilentlyContinue
        }
    }

    return $null
}

function Set-CachedMCPResult {
    <#
    .SYNOPSIS
        Stores MCP result in cache

    .PARAMETER Tool
        MCP tool name

    .PARAMETER Args
        Tool arguments

    .PARAMETER Result
        The result to cache
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Tool,

        [Parameter(Mandatory)]
        [hashtable]$Args,

        [Parameter(Mandatory)]
        $Result
    )

    $cacheKey = Get-MCPCacheKey -Tool $Tool -Args $Args

    # Store in memory
    $script:MCPCache[$cacheKey] = @{
        Result = $Result
        Timestamp = Get-Date
    }

    # Store to disk for persistence
    $cacheFile = Join-Path $script:CacheDir "$cacheKey.json"
    try {
        @{
            Tool = $Tool
            Args = $Args
            Result = $Result
            Timestamp = (Get-Date).ToString("o")
        } | ConvertTo-Json -Depth 10 | Set-Content $cacheFile -Encoding UTF8
    }
    catch {
        Write-Verbose "[MCPCache] Failed to persist cache: $($_.Exception.Message)"
    }
}

function Clear-MCPCache {
    <#
    .SYNOPSIS
        Clears the MCP result cache

    .PARAMETER OlderThanMinutes
        Only clear entries older than specified minutes (0 = all)
    #>
    [CmdletBinding()]
    param(
        [int]$OlderThanMinutes = 0
    )

    $script:MCPCache = @{}

    if ($OlderThanMinutes -eq 0) {
        Get-ChildItem $script:CacheDir -Filter "*.json" | Remove-Item -Force
        Write-Host "[MCPCache] Cache cleared completely" -ForegroundColor Green
    }
    else {
        $cutoff = (Get-Date).AddMinutes(-$OlderThanMinutes)
        Get-ChildItem $script:CacheDir -Filter "*.json" | Where-Object {
            $_.LastWriteTime -lt $cutoff
        } | Remove-Item -Force
        Write-Host "[MCPCache] Cleared entries older than $OlderThanMinutes minutes" -ForegroundColor Green
    }
}

function Get-MCPCacheStats {
    <#
    .SYNOPSIS
        Returns cache statistics
    #>
    [CmdletBinding()]
    param()

    $files = Get-ChildItem $script:CacheDir -Filter "*.json" -ErrorAction SilentlyContinue
    $totalSize = ($files | Measure-Object -Property Length -Sum).Sum

    return [PSCustomObject]@{
        MemoryEntries = $script:MCPCache.Count
        DiskEntries = $files.Count
        DiskSizeKB = [Math]::Round($totalSize / 1KB, 2)
        EstimatedTokensSaved = $script:MCPCache.Values | ForEach-Object {
            Get-TokenEstimate -Text ($_.Result | ConvertTo-Json -Compress)
        } | Measure-Object -Sum | Select-Object -ExpandProperty Sum
    }
}

# ============================================================================
# CONTEXT COMPRESSOR
# ============================================================================

function Compress-Context {
    <#
    .SYNOPSIS
        Compresses long context to reduce token usage

    .DESCRIPTION
        Uses multiple strategies:
        1. Remove redundant whitespace
        2. Summarize repetitive sections
        3. Extract key information
        4. Use local AI for intelligent summarization

    .PARAMETER Text
        The text to compress

    .PARAMETER MaxTokens
        Target maximum tokens

    .PARAMETER Strategy
        Compression strategy: "simple", "smart", "ai"

    .OUTPUTS
        Compressed text
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Text,

        [int]$MaxTokens = 4000,

        [ValidateSet("simple", "smart", "ai")]
        [string]$Strategy = "smart"
    )

    $currentTokens = Get-TokenEstimate -Text $Text

    if ($currentTokens -le $MaxTokens) {
        return $Text
    }

    Write-Verbose "[ContextCompressor] Compressing from $currentTokens to $MaxTokens tokens using '$Strategy' strategy"

    switch ($Strategy) {
        "simple" {
            # Basic whitespace reduction
            $compressed = $Text -replace '\s+', ' '
            $compressed = $compressed -replace '^\s+|\s+$', ''
            return $compressed
        }

        "smart" {
            # Smart compression with pattern-based reduction
            $compressed = $Text

            # Remove excessive blank lines
            $compressed = $compressed -replace '(\r?\n){3,}', "`n`n"

            # Compress repetitive patterns
            $compressed = $compressed -replace '(={3,})', '==='
            $compressed = $compressed -replace '(-{3,})', '---'
            $compressed = $compressed -replace '(\.{4,})', '...'

            # Truncate very long lines (likely data dumps)
            $lines = $compressed -split "`n"
            $lines = $lines | ForEach-Object {
                if ($_.Length -gt 500) {
                    $_.Substring(0, 200) + " ... [TRUNCATED: $($_.Length - 200) chars] ... " + $_.Substring($_.Length - 100)
                } else { $_ }
            }
            $compressed = $lines -join "`n"

            # If still too long, truncate from middle
            $currentTokens = Get-TokenEstimate -Text $compressed
            if ($currentTokens -gt $MaxTokens) {
                $targetChars = [Math]::Floor($MaxTokens / 0.25)
                $keepStart = [Math]::Floor($targetChars * 0.6)
                $keepEnd = [Math]::Floor($targetChars * 0.3)

                $compressed = $compressed.Substring(0, $keepStart) +
                              "`n`n[... CONTEXT COMPRESSED: removed ~$($compressed.Length - $keepStart - $keepEnd) chars ...]`n`n" +
                              $compressed.Substring($compressed.Length - $keepEnd)
            }

            return $compressed
        }

        "ai" {
            # Use local AI for intelligent summarization
            try {
                if (Get-Command Invoke-AIRequest -ErrorAction SilentlyContinue) {
                    $response = Invoke-AIRequest -Messages @(
                        @{ role = "system"; content = "You are a context compressor. Summarize the following text, keeping all key information, decisions, and code snippets. Output only the summary, no explanations." }
                        @{ role = "user"; content = "Compress this to max $MaxTokens tokens while keeping essential info:`n`n$Text" }
                    ) -Model "llama3.2:1b" -MaxTokens $MaxTokens

                    if ($response.Success -and $response.Content) {
                        return $response.Content
                    }
                }
            }
            catch {
                Write-Verbose "[ContextCompressor] AI compression failed, falling back to smart"
            }

            # Fallback to smart
            return Compress-Context -Text $Text -MaxTokens $MaxTokens -Strategy "smart"
        }
    }
}

function Get-ContextSummary {
    <#
    .SYNOPSIS
        Creates a structured summary of conversation context

    .PARAMETER Messages
        Array of conversation messages

    .OUTPUTS
        Structured summary with key points
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [array]$Messages
    )

    $summary = @{
        TotalMessages = $Messages.Count
        UserQueries = @()
        KeyDecisions = @()
        FilesModified = @()
        CodeGenerated = @()
        Errors = @()
    }

    foreach ($msg in $Messages) {
        $content = $msg.content

        if ($msg.role -eq "user") {
            # Extract user intent
            if ($content.Length -gt 100) {
                $summary.UserQueries += $content.Substring(0, 100) + "..."
            } else {
                $summary.UserQueries += $content
            }
        }
        elseif ($msg.role -eq "assistant") {
            # Extract key actions
            if ($content -match 'Created|Modified|Updated|Fixed|Implemented') {
                $matches = [regex]::Matches($content, '(Created|Modified|Updated|Fixed|Implemented)[^.]+')
                $summary.KeyDecisions += $matches.Value
            }

            # Extract file operations
            if ($content -match '([A-Za-z0-9_\-\.]+\.(ps1|psm1|json|md|js|ts))') {
                $summary.FilesModified += $matches.Value | Select-Object -Unique
            }
        }
    }

    return $summary
}

# ============================================================================
# AUTO MEMORY (Serena Integration)
# ============================================================================

function Save-ToSerenaMemory {
    <#
    .SYNOPSIS
        Saves important context to Serena memory

    .PARAMETER Name
        Memory slot name (max 25 slots available)

    .PARAMETER Content
        Content to save

    .PARAMETER Category
        Category: project_purpose, tech_stack, code_style_conventions,
                  codebase_structure, development_commands, system_utilities,
                  guidelines_design_patterns, testing_commands

    .PARAMETER Append
        Append to existing memory instead of overwrite
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Name,

        [Parameter(Mandatory)]
        [string]$Content,

        [ValidateSet("project_purpose", "tech_stack", "code_style_conventions",
                     "codebase_structure", "development_commands", "system_utilities",
                     "guidelines_design_patterns", "testing_commands", "session_notes",
                     "architecture_decisions", "api_patterns", "error_patterns")]
        [string]$Category = "session_notes",

        [switch]$Append
    )

    $memoryFile = Join-Path $script:MemoriesDir "$Name.md"

    if ($Append -and (Test-Path $memoryFile)) {
        $existing = Get-Content $memoryFile -Raw
        $Content = "$existing`n`n---`n`n$Content"
    }

    # Add metadata header
    $header = @"
# $Name
<!-- Category: $Category -->
<!-- Updated: $(Get-Date -Format "yyyy-MM-dd HH:mm") -->

"@

    $fullContent = $header + $Content

    try {
        Set-Content -Path $memoryFile -Value $fullContent -Encoding UTF8
        Write-Host "[AutoMemory] Saved to Serena: $Name ($Category)" -ForegroundColor Green
        return $true
    }
    catch {
        Write-Warning "[AutoMemory] Failed to save: $($_.Exception.Message)"
        return $false
    }
}

function Get-SerenaMemory {
    <#
    .SYNOPSIS
        Retrieves memory from Serena

    .PARAMETER Name
        Memory name (without .md extension)

    .OUTPUTS
        Memory content or $null
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Name
    )

    $memoryFile = Join-Path $script:MemoriesDir "$Name.md"

    if (Test-Path $memoryFile) {
        return Get-Content $memoryFile -Raw
    }

    return $null
}

function Get-AllSerenaMemories {
    <#
    .SYNOPSIS
        Lists all available Serena memories

    .OUTPUTS
        Array of memory info objects
    #>
    [CmdletBinding()]
    param()

    $memories = Get-ChildItem $script:MemoriesDir -Filter "*.md" | ForEach-Object {
        $content = Get-Content $_.FullName -Raw
        $category = if ($content -match '<!-- Category: ([^>]+) -->') { $matches[1] } else { "unknown" }
        $updated = if ($content -match '<!-- Updated: ([^>]+) -->') { $matches[1] } else { $_.LastWriteTime }

        [PSCustomObject]@{
            Name = $_.BaseName
            Category = $category
            Updated = $updated
            SizeKB = [Math]::Round($_.Length / 1KB, 2)
            Tokens = Get-TokenEstimate -Text $content
        }
    }

    return $memories
}

function Update-SessionMemory {
    <#
    .SYNOPSIS
        Automatically updates session_notes memory with current session info

    .DESCRIPTION
        Should be called periodically or at session end to persist important context
    #>
    [CmdletBinding()]
    param()

    $sessionInfo = @"
## Session: $(Get-Date -Format "yyyy-MM-dd HH:mm")

### Key Decisions
$($script:SessionState.KeyDecisions | ForEach-Object { "- $_" } | Out-String)

### Files Mentioned
$($script:SessionState.FilesMentioned | Select-Object -Unique | ForEach-Object { "- $_" } | Out-String)

### Errors Encountered
$($script:SessionState.ErrorsEncountered | ForEach-Object { "- $_" } | Out-String)

### Tool Calls Made
- Total: $($script:SessionState.ToolCalls.Count)
- Tokens used: ~$($script:SessionState.TokensUsed)
"@

    Save-ToSerenaMemory -Name "session_notes" -Content $sessionInfo -Category "session_notes" -Append
}

# ============================================================================
# SESSION STATE
# ============================================================================

function Add-SessionDecision {
    <#
    .SYNOPSIS
        Records a key decision made during the session
    #>
    param(
        [Parameter(Mandatory)]
        [string]$Decision
    )

    $script:SessionState.KeyDecisions += "[$(Get-Date -Format 'HH:mm')] $Decision"
}

function Add-SessionFile {
    <#
    .SYNOPSIS
        Records a file that was mentioned/modified
    #>
    param(
        [Parameter(Mandatory)]
        [string]$FilePath
    )

    $script:SessionState.FilesMentioned += $FilePath
}

function Add-SessionError {
    <#
    .SYNOPSIS
        Records an error encountered
    #>
    param(
        [Parameter(Mandatory)]
        [string]$Error
    )

    $script:SessionState.ErrorsEncountered += "[$(Get-Date -Format 'HH:mm')] $Error"
}

function Add-SessionTokens {
    <#
    .SYNOPSIS
        Adds to token counter
    #>
    param(
        [int]$Tokens
    )

    $script:SessionState.TokensUsed += $Tokens
}

function Get-SessionState {
    <#
    .SYNOPSIS
        Returns current session state
    #>
    return $script:SessionState
}

function Reset-SessionState {
    <#
    .SYNOPSIS
        Resets session state (call at session start)
    #>

    $script:SessionState = @{
        StartTime = Get-Date
        TokensUsed = 0
        ToolCalls = @()
        KeyDecisions = @()
        FilesMentioned = @()
        ErrorsEncountered = @()
    }

    Write-Host "[SessionState] Reset for new session" -ForegroundColor Green
}

# ============================================================================
# OPTIMIZATION RECOMMENDATIONS
# ============================================================================

function Get-OptimizationRecommendations {
    <#
    .SYNOPSIS
        Analyzes current usage and provides optimization recommendations

    .OUTPUTS
        Array of recommendation objects
    #>
    [CmdletBinding()]
    param()

    $recommendations = @()

    # Check MCP cache usage
    $cacheStats = Get-MCPCacheStats
    if ($cacheStats.MemoryEntries -eq 0) {
        $recommendations += [PSCustomObject]@{
            Category = "MCP Cache"
            Priority = "High"
            Recommendation = "Enable MCP result caching to avoid redundant tool calls"
            Savings = "~1000-5000 tokens per session"
        }
    }

    # Check Serena memories
    $memories = Get-AllSerenaMemories
    $totalMemoryTokens = ($memories | Measure-Object -Property Tokens -Sum).Sum
    if ($totalMemoryTokens -gt 10000) {
        $recommendations += [PSCustomObject]@{
            Category = "Serena Memories"
            Priority = "Medium"
            Recommendation = "Consider consolidating or compressing memories ($totalMemoryTokens tokens)"
            Savings = "~$([Math]::Round($totalMemoryTokens * 0.3)) tokens"
        }
    }

    # Check session state
    $session = Get-SessionState
    if ($session.TokensUsed -gt 50000) {
        $recommendations += [PSCustomObject]@{
            Category = "Session"
            Priority = "High"
            Recommendation = "Session is token-heavy. Consider summarizing context"
            Savings = "~$([Math]::Round($session.TokensUsed * 0.4)) tokens"
        }
    }

    # Check for missing memories
    $importantMemories = @("project_purpose", "codebase_structure", "development_commands")
    $missingMemories = $importantMemories | Where-Object { $_ -notin $memories.Name }
    if ($missingMemories) {
        $recommendations += [PSCustomObject]@{
            Category = "Knowledge Base"
            Priority = "Medium"
            Recommendation = "Missing important memories: $($missingMemories -join ', ')"
            Savings = "Faster context loading in future sessions"
        }
    }

    return $recommendations
}

function Show-OptimizationStatus {
    <#
    .SYNOPSIS
        Displays comprehensive optimization status
    #>
    [CmdletBinding()]
    param()

    Write-Host "`n=== Context Optimization Status ===" -ForegroundColor Cyan

    # MCP Cache
    $cacheStats = Get-MCPCacheStats
    Write-Host "`n[MCP Cache]" -ForegroundColor Yellow
    Write-Host "  Memory entries: $($cacheStats.MemoryEntries)"
    Write-Host "  Disk entries: $($cacheStats.DiskEntries) ($($cacheStats.DiskSizeKB) KB)"
    Write-Host "  Est. tokens saved: $($cacheStats.EstimatedTokensSaved)" -ForegroundColor Green

    # Serena Memories
    $memories = Get-AllSerenaMemories
    Write-Host "`n[Serena Memories]" -ForegroundColor Yellow
    Write-Host "  Total slots: $($memories.Count)/25"
    $memories | Format-Table Name, Category, Tokens, Updated -AutoSize | Out-String | Write-Host

    # Session State
    $session = Get-SessionState
    $duration = (Get-Date) - $session.StartTime
    Write-Host "[Session State]" -ForegroundColor Yellow
    Write-Host "  Duration: $([Math]::Round($duration.TotalMinutes, 1)) min"
    Write-Host "  Tokens used: ~$($session.TokensUsed)"
    Write-Host "  Decisions: $($session.KeyDecisions.Count)"
    Write-Host "  Files: $($session.FilesMentioned.Count)"

    # Recommendations
    $recs = Get-OptimizationRecommendations
    if ($recs) {
        Write-Host "`n[Recommendations]" -ForegroundColor Yellow
        foreach ($rec in $recs) {
            $color = switch ($rec.Priority) { "High" { "Red" }; "Medium" { "Yellow" }; default { "Gray" } }
            Write-Host "  [$($rec.Priority)] $($rec.Category): $($rec.Recommendation)" -ForegroundColor $color
            Write-Host "         Potential savings: $($rec.Savings)" -ForegroundColor DarkGray
        }
    }

    Write-Host ""
}

# ============================================================================
# MODULE EXPORTS
# ============================================================================

Export-ModuleMember -Function @(
    # Token counting
    'Get-TokenEstimate',
    'Get-ContextTokenUsage',

    # MCP Cache
    'Get-CachedMCPResult',
    'Set-CachedMCPResult',
    'Clear-MCPCache',
    'Get-MCPCacheStats',

    # Context compression
    'Compress-Context',
    'Get-ContextSummary',

    # Serena memories
    'Save-ToSerenaMemory',
    'Get-SerenaMemory',
    'Get-AllSerenaMemories',
    'Update-SessionMemory',

    # Session state
    'Add-SessionDecision',
    'Add-SessionFile',
    'Add-SessionError',
    'Add-SessionTokens',
    'Get-SessionState',
    'Reset-SessionState',

    # Optimization
    'Get-OptimizationRecommendations',
    'Show-OptimizationStatus'
)

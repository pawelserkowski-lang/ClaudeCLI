# AI Handler Integration for Claude Code - HYDRA 10.1
# Provides context, recommendations, token optimization, and advanced AI module suggestions

param(
    [Parameter(ValueFromPipeline=$true)]
    [string]$InputJson
)

$ErrorActionPreference = 'SilentlyContinue'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

# Parse hook input
$hookData = $null
if ($InputJson) {
    try { $hookData = $InputJson | ConvertFrom-Json } catch { }
}

# Extract prompt
$prompt = if ($hookData.prompt) { $hookData.prompt }
          elseif ($hookData.user_prompt) { $hookData.user_prompt }
          elseif ($env:CLAUDE_USER_PROMPT) { $env:CLAUDE_USER_PROMPT }
          else { $null }

# Skip for empty, short, or command prompts
if (-not $prompt -or $prompt.Length -lt 5 -or $prompt.StartsWith('/')) {
    exit 0
}

# Initialize AI Handler via AIFacade (preferred entry point)
[Environment]::SetEnvironmentVariable('CLAUDECLI_ENCRYPTION_KEY', 'ClaudeHYDRA-2024', 'Process')
$aiHandlerPath = "C:\Users\BIURODOM\Desktop\ClaudeHYDRA\ai-handler"

# Load AIFacade (handles all module loading automatically)
$null = Import-Module "$aiHandlerPath\AIFacade.psm1" -Force 2>&1
$null = Initialize-AISystem -SkipAdvanced 2>&1

# Token estimation for current prompt
$promptTokens = 0
try {
    if (Get-Command Get-TokenEstimate -ErrorAction SilentlyContinue) {
        $promptTokens = Get-TokenEstimate -Text $prompt -Language "auto"
    }
} catch { $promptTokens = [math]::Ceiling($prompt.Length * 0.25) }

# Track session tokens
try {
    if (Get-Command Add-SessionTokens -ErrorAction SilentlyContinue) {
        Add-SessionTokens -Tokens $promptTokens
    }
} catch { }

# Get MCP cache stats
$cacheInfo = ""
try {
    if (Get-Command Get-MCPCacheStats -ErrorAction SilentlyContinue) {
        $stats = Get-MCPCacheStats
        if ($stats.MemoryEntries -gt 0) {
            $cacheInfo = "Cache: $($stats.MemoryEntries) entries (~$($stats.EstimatedTokensSaved) tokens saved)"
        }
    }
} catch { }

# Quick analysis
$category = "general"
$modelRec = "llama3.2:3b"
$advancedMode = $null
$suggestedCommand = $null

# Detect category and recommend advanced module
$promptLower = $prompt.ToLower()

if ($promptLower -match 'write|code|function|implement|script|class|def |fn ') {
    $category = "code"
    $modelRec = "qwen2.5-coder:1.5b"
    $advancedMode = "self-correction"
    $suggestedCommand = "/self-correct"
} elseif ($promptLower -match 'explain|analyze|compare|why|how does') {
    $category = "analysis"
    $modelRec = "llama3.2:3b"
    $advancedMode = "speculative"
    $suggestedCommand = "/speculate"
} elseif ($promptLower -match 'quick|fast|simple|what is|\?$') {
    $category = "quick"
    $modelRec = "llama3.2:1b"
    $advancedMode = "racing"
    $suggestedCommand = "/speculate"
} elseif ($promptLower -match 'debug|fix|error|issue|bug') {
    $category = "debug"
    $modelRec = "phi3:mini"
    $advancedMode = "self-correction"
    $suggestedCommand = "/self-correct"
} elseif ($promptLower -match 'refactor|import|depend|context|related') {
    $category = "semantic"
    $modelRec = "llama3.2:3b"
    $advancedMode = "semantic-rag"
    $suggestedCommand = "/semantic-query"
} elseif ($promptLower -match 'sql|query|select|join|database') {
    $category = "sql"
    $modelRec = "llama3.2:3b"
    $advancedMode = "few-shot"
    $suggestedCommand = "/few-shot"
}

# Get CPU load
$cpu = 0
try {
    $cpu = [math]::Round((Get-CimInstance Win32_Processor).LoadPercentage, 0)
} catch { $cpu = 50 }

$provider = if ($cpu -lt 70) { "local" } elseif ($cpu -lt 90) { "hybrid" } else { "cloud" }

# Build suggestion line
$suggestion = if ($suggestedCommand) { "Suggested: $suggestedCommand" } else { "" }

# Build token info
$tokenInfo = "Prompt: ~$promptTokens tokens"
if ($cacheInfo) { $tokenInfo += " | $cacheInfo" }

# Output context for Claude
Write-Output @"

<user-prompt-submit-hook>
HYDRA 10.1 - AI Handler Active

Prompt Analysis:
  Category: $category
  Model: $modelRec
  Provider: $provider (CPU: $cpu%)
  Tokens: $tokenInfo
  Advanced: $advancedMode

$suggestion

Commands:
  /ai             Local AI query (cost: `$0)
  /ai-batch       Parallel batch queries
  /self-correct   Code with validation
  /speculate      Model racing (fastest)
  /semantic-query Deep RAG with imports
  /few-shot       Learn from history
  /load-balance   CPU-aware provider
  /optimize-context Token optimization status

Tips:
  - Use Serena memories for persistent context (25 slots)
  - MCP cache saves redundant tool calls (5 min TTL)
  - Run /optimize-context for token usage analysis
</user-prompt-submit-hook>
"@

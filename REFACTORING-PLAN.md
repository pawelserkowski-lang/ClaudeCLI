# ClaudeCLI Complete Refactoring Plan

**Version**: 1.0 | **Date**: 2026-01-13 | **Status**: Planning

---

## Executive Summary

This document details 5 comprehensive refactoring strategies for ClaudeCLI/HYDRA 10.0. The codebase currently has:
- **15 AI modules** totaling ~7,100 LOC
- **1 monolithic file** (AIModelHandler.psm1) at 2,122 LOC
- **~600 lines** of duplicated code
- **5+ circular dependencies**
- **0% unit test coverage**

---

## Approach 1: Modular Decomposition (Split the Monolith)

### Problem Statement

`AIModelHandler.psm1` handles 8+ distinct responsibilities in 2,122 lines:
1. Configuration management (Get-AIConfig, Save-AIConfig)
2. State management (Initialize-AIState, Get-AIState, Save-AIState)
3. Logging (Write-AIHandlerLog)
4. Rate limiting (Update-UsageTracking, Get-RateLimitStatus)
5. Model selection (Get-OptimalModel, Get-FallbackModel)
6. Provider API calls (Invoke-*API functions)
7. Streaming (Invoke-StreamingRequest)
8. Parallel execution (Invoke-AIRequestParallel, Invoke-AIBatch)

### Target Architecture

```
ai-handler/
├── core/
│   ├── AIConfig.psm1           # Configuration CRUD (~200 LOC)
│   ├── AIState.psm1            # State management (~150 LOC)
│   ├── AILogger.psm1           # Logging utilities (~100 LOC)
│   └── AIConstants.psm1        # All constants/thresholds (~80 LOC)
├── rate-limiting/
│   └── RateLimiter.psm1        # Rate limit logic (~180 LOC)
├── model-selection/
│   └── ModelSelector.psm1      # Model selection algorithm (~200 LOC)
├── providers/
│   ├── ProviderBase.psm1       # Base provider class (~100 LOC)
│   ├── AnthropicProvider.psm1  # Anthropic API (~150 LOC)
│   ├── OpenAIProvider.psm1     # OpenAI API (~120 LOC)
│   ├── GoogleProvider.psm1     # Google API (~120 LOC)
│   ├── MistralProvider.psm1    # Mistral API (~100 LOC)
│   ├── GroqProvider.psm1       # Groq API (~100 LOC)
│   └── OllamaProvider.psm1     # Ollama API (~150 LOC)
├── fallback/
│   └── ProviderFallback.psm1   # Failover chain logic (~250 LOC)
├── streaming/
│   └── StreamHandler.psm1      # Streaming response handling (~150 LOC)
├── parallel/
│   └── ParallelExecutor.psm1   # Parallel request execution (~200 LOC)
└── AIModelHandler.psm1         # Orchestrator facade (~300 LOC)
```

### Implementation Steps

#### Step 1: Create `core/AIConstants.psm1`
```powershell
# Extract from AIModelHandler.psm1 lines 24-35, 95-308

$script:Paths = @{
    Config = Join-Path $PSScriptRoot "..\ai-config.json"
    State = Join-Path $PSScriptRoot "..\ai-state.json"
    Cache = Join-Path $PSScriptRoot "..\cache"
}

$script:Thresholds = @{
    RateLimitWarning = 0.85
    RateLimitCritical = 0.95
    MaxRetries = 3
    RetryDelayMs = 1000
    TimeoutMs = 30000
}

$script:ProviderPriority = @("anthropic", "openai", "google", "mistral", "groq", "ollama")

$script:TierScores = @{
    pro = 3
    standard = 2
    lite = 1
}

Export-ModuleMember -Variable Paths, Thresholds, ProviderPriority, TierScores
```

#### Step 2: Create `core/AIConfig.psm1`
```powershell
# Extract from AIModelHandler.psm1 lines 322-348

function Get-AIConfig {
    [CmdletBinding()]
    param()

    $configPath = $script:Paths.Config
    if (Test-Path $configPath) {
        try {
            return Get-Content $configPath -Raw | ConvertFrom-Json | ConvertTo-Hashtable
        } catch {
            Write-Warning "Config load failed: $_"
        }
    }
    return Get-DefaultConfig
}

function Save-AIConfig {
    [CmdletBinding()]
    param([hashtable]$Config)

    $json = $Config | ConvertTo-Json -Depth 10
    Write-AtomicFile -Path $script:Paths.Config -Content $json
}

function Get-DefaultConfig { ... }
function Merge-Config { ... }
function Test-ConfigValid { ... }

Export-ModuleMember -Function Get-AIConfig, Save-AIConfig, Get-DefaultConfig, Merge-Config, Test-ConfigValid
```

#### Step 3: Create `core/AIState.psm1`
```powershell
# Extract from AIModelHandler.psm1 lines 350-421

$script:RuntimeState = @{
    currentProvider = "anthropic"
    currentModel = "claude-sonnet-4-5-20250929"
    usage = @{}
    errors = @()
    lastRequest = $null
}

function Get-AIState { ... }
function Save-AIState { ... }
function Initialize-AIState { ... }
function Reset-AIState { ... }
function Update-AIState { ... }

Export-ModuleMember -Function Get-AIState, Save-AIState, Initialize-AIState, Reset-AIState, Update-AIState
```

#### Step 4: Create `rate-limiting/RateLimiter.psm1`
```powershell
# Extract from AIModelHandler.psm1 lines 425-538

function Update-UsageTracking {
    param(
        [string]$Provider,
        [string]$Model,
        [int]$InputTokens = 0,
        [int]$OutputTokens = 0,
        [bool]$IsError = $false
    )
    # ... existing implementation
}

function Get-RateLimitStatus {
    param([string]$Provider, [string]$Model)
    # ... existing implementation
}

function Test-RateLimitAvailable {
    param([string]$Provider, [string]$Model)
    $status = Get-RateLimitStatus -Provider $Provider -Model $Model
    return $status.available
}

function Reset-RateLimitCounters {
    param([string]$Provider, [string]$Model)
    # Reset minute counters
}

Export-ModuleMember -Function Update-UsageTracking, Get-RateLimitStatus, Test-RateLimitAvailable, Reset-RateLimitCounters
```

#### Step 5: Create `providers/ProviderBase.psm1`
```powershell
# New abstraction layer

class AIProvider {
    [string]$Name
    [string]$BaseUrl
    [string]$ApiKeyEnv
    [bool]$Enabled

    [hashtable] InvokeRequest([array]$Messages, [int]$MaxTokens, [float]$Temperature, [bool]$Stream) {
        throw "Must be implemented by subclass"
    }

    [bool] TestConnectivity() {
        throw "Must be implemented by subclass"
    }

    [string] GetApiKey() {
        if ($this.ApiKeyEnv) {
            return [Environment]::GetEnvironmentVariable($this.ApiKeyEnv)
        }
        return $null
    }

    [bool] HasApiKey() {
        return [bool]$this.GetApiKey()
    }
}

Export-ModuleMember -Function @() -Variable @()
```

#### Step 6: Create `providers/AnthropicProvider.psm1`
```powershell
# Extract from AIModelHandler.psm1 lines 1049-1131

. (Join-Path $PSScriptRoot "ProviderBase.psm1")

class AnthropicProvider : AIProvider {
    AnthropicProvider() {
        $this.Name = "Anthropic"
        $this.BaseUrl = "https://api.anthropic.com/v1"
        $this.ApiKeyEnv = "ANTHROPIC_API_KEY"
        $this.Enabled = $true
    }

    [hashtable] InvokeRequest([array]$Messages, [int]$MaxTokens, [float]$Temperature, [bool]$Stream) {
        $apiKey = $this.GetApiKey()
        if (-not $apiKey) {
            throw "ANTHROPIC_API_KEY not set"
        }

        # Convert messages to Anthropic format
        $systemMessage = ($Messages | Where-Object { $_.role -eq "system" } | Select-Object -First 1).content
        $chatMessages = $Messages | Where-Object { $_.role -ne "system" }

        $body = @{
            model = $this.CurrentModel
            max_tokens = $MaxTokens
            temperature = $Temperature
            messages = @($chatMessages)
        }
        if ($systemMessage) { $body.system = $systemMessage }

        $headers = @{
            "x-api-key" = $apiKey
            "anthropic-version" = "2023-06-01"
            "content-type" = "application/json"
        }

        if ($Stream) {
            return $this.InvokeStreamingRequest($body, $headers)
        }

        $response = Invoke-RestMethod -Uri "$($this.BaseUrl)/messages" -Method Post -Headers $headers -Body ($body | ConvertTo-Json -Depth 10)

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
}

function New-AnthropicProvider { return [AnthropicProvider]::new() }

Export-ModuleMember -Function New-AnthropicProvider
```

#### Step 7: Refactor `AIModelHandler.psm1` as Facade
```powershell
# Slim orchestrator that imports and coordinates modules

#Requires -Version 5.1

# Import core modules
Import-Module (Join-Path $PSScriptRoot "core\AIConstants.psm1") -Force
Import-Module (Join-Path $PSScriptRoot "core\AIConfig.psm1") -Force
Import-Module (Join-Path $PSScriptRoot "core\AIState.psm1") -Force
Import-Module (Join-Path $PSScriptRoot "rate-limiting\RateLimiter.psm1") -Force
Import-Module (Join-Path $PSScriptRoot "model-selection\ModelSelector.psm1") -Force
Import-Module (Join-Path $PSScriptRoot "fallback\ProviderFallback.psm1") -Force

# Import providers
$providerPath = Join-Path $PSScriptRoot "providers"
Get-ChildItem "$providerPath\*Provider.psm1" | ForEach-Object {
    Import-Module $_.FullName -Force
}

function Invoke-AIRequest {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [array]$Messages,
        [string]$Provider = "anthropic",
        [string]$Model,
        [int]$MaxTokens = 4096,
        [float]$Temperature = 0.7,
        [switch]$AutoFallback,
        [switch]$Stream
    )

    # Delegate to ProviderFallback module
    Invoke-AIRequestWithFallback @PSBoundParameters
}

# Re-export all functions from submodules
Export-ModuleMember -Function @(
    'Get-AIConfig', 'Save-AIConfig',
    'Get-AIState', 'Initialize-AIState', 'Reset-AIState',
    'Get-RateLimitStatus', 'Update-UsageTracking',
    'Get-OptimalModel', 'Get-FallbackModel',
    'Invoke-AIRequest', 'Invoke-AIBatch',
    'Get-AIStatus', 'Get-AIHealth', 'Test-AIProviders'
)
```

### Migration Checklist

- [ ] Create `core/` directory structure
- [ ] Extract constants to `AIConstants.psm1`
- [ ] Extract config functions to `AIConfig.psm1`
- [ ] Extract state functions to `AIState.psm1`
- [ ] Extract rate limiting to `RateLimiter.psm1`
- [ ] Create provider base class
- [ ] Migrate each provider to separate file
- [ ] Refactor `AIModelHandler.psm1` to facade
- [ ] Update all imports in dependent modules
- [ ] Run integration tests
- [ ] Update CLAUDE.md documentation

### Estimated Effort: 4 weeks

---

## Approach 2: Extract Shared Utilities (DRY Principle)

### Problem Statement

Multiple patterns are duplicated across modules:

| Pattern | Occurrences | Files |
|---------|-------------|-------|
| JSON read/write | 8+ | ErrorLogger, FewShotLearning, ModelDiscovery, AIModelHandler |
| Ollama availability check | 5+ | SelfCorrection, TaskClassifier, LoadBalancer, AdvancedAI |
| System metrics (CPU/Memory) | 3+ | LoadBalancer, TaskClassifier, AdvancedAI |
| Prompt validation | 3+ | PromptOptimizer, TaskClassifier, SmartQueue |
| API key verification | 4+ | AIModelHandler, providers |

### Target Architecture

```
ai-handler/
├── utils/
│   ├── AIUtil-JsonIO.psm1      # Atomic JSON operations
│   ├── AIUtil-Health.psm1      # System & provider health checks
│   ├── AIUtil-Validation.psm1  # Prompt/code validation
│   ├── AIUtil-Crypto.psm1      # API key handling
│   └── AIUtil-Network.psm1     # HTTP utilities
```

### Implementation: `AIUtil-JsonIO.psm1`

```powershell
#Requires -Version 5.1
<#
.SYNOPSIS
    Atomic JSON file operations with thread safety
#>

function Read-JsonFile {
    <#
    .SYNOPSIS
        Read and parse JSON file with error handling
    .PARAMETER Path
        Path to JSON file
    .PARAMETER Default
        Default value if file doesn't exist or is invalid
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path,

        [object]$Default = $null
    )

    if (-not (Test-Path $Path)) {
        return $Default
    }

    try {
        $content = Get-Content $Path -Raw -Encoding UTF8
        if ([string]::IsNullOrWhiteSpace($content)) {
            return $Default
        }
        return $content | ConvertFrom-Json | ConvertTo-Hashtable
    } catch {
        Write-Warning "[JsonIO] Failed to read $Path: $($_.Exception.Message)"
        return $Default
    }
}

function Write-JsonFile {
    <#
    .SYNOPSIS
        Write JSON file atomically (write to temp, then rename)
    .PARAMETER Path
        Target file path
    .PARAMETER Data
        Data to serialize
    .PARAMETER Depth
        JSON serialization depth (default: 10)
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path,

        [Parameter(Mandatory)]
        [object]$Data,

        [int]$Depth = 10
    )

    $tempPath = "$Path.tmp.$([guid]::NewGuid().ToString().Substring(0,8))"

    try {
        $json = $Data | ConvertTo-Json -Depth $Depth
        $json | Set-Content $tempPath -Encoding UTF8 -Force

        # Atomic rename
        if (Test-Path $Path) {
            Remove-Item $Path -Force
        }
        Rename-Item $tempPath $Path -Force

        return $true
    } catch {
        if (Test-Path $tempPath) {
            Remove-Item $tempPath -Force -ErrorAction SilentlyContinue
        }
        throw "Failed to write $Path: $($_.Exception.Message)"
    }
}

function ConvertTo-Hashtable {
    <#
    .SYNOPSIS
        Convert PSObject to hashtable (PS 5.1 compatibility)
    #>
    param([Parameter(ValueFromPipeline)]$InputObject)
    process {
        if ($null -eq $InputObject) { return $null }
        if ($InputObject -is [System.Collections.IEnumerable] -and $InputObject -isnot [string]) {
            $collection = @(foreach ($object in $InputObject) { ConvertTo-Hashtable $object })
            return ,$collection
        } elseif ($InputObject -is [psobject]) {
            $hash = @{}
            foreach ($property in $InputObject.PSObject.Properties) {
                $hash[$property.Name] = ConvertTo-Hashtable $property.Value
            }
            return $hash
        } else {
            return $InputObject
        }
    }
}

Export-ModuleMember -Function Read-JsonFile, Write-JsonFile, ConvertTo-Hashtable
```

### Implementation: `AIUtil-Health.psm1`

```powershell
#Requires -Version 5.1
<#
.SYNOPSIS
    System and provider health monitoring utilities
#>

$script:OllamaPort = 11434
$script:HealthCache = @{}
$script:CacheTTLSeconds = 5

function Test-OllamaAvailable {
    <#
    .SYNOPSIS
        Check if Ollama is running on localhost
    .PARAMETER UseCache
        Use cached result if within TTL (default: true)
    #>
    [CmdletBinding()]
    param([switch]$NoCache)

    $cacheKey = "ollama"
    $now = Get-Date

    if (-not $NoCache -and $script:HealthCache[$cacheKey]) {
        $cached = $script:HealthCache[$cacheKey]
        if (($now - $cached.Timestamp).TotalSeconds -lt $script:CacheTTLSeconds) {
            return $cached.Available
        }
    }

    $available = $false
    try {
        $tcp = New-Object System.Net.Sockets.TcpClient
        $tcp.Connect('localhost', $script:OllamaPort)
        $available = $tcp.Connected
        $tcp.Close()
    } catch { }

    $script:HealthCache[$cacheKey] = @{
        Available = $available
        Timestamp = $now
    }

    return $available
}

function Get-SystemMetrics {
    <#
    .SYNOPSIS
        Get CPU, memory, and recommendation
    #>
    [CmdletBinding()]
    param()

    $metrics = @{
        Timestamp = Get-Date
        CpuPercent = 50
        MemoryPercent = 50
        MemoryAvailableGB = 0
        Recommendation = "local"
    }

    try {
        $cpu = Get-WmiObject Win32_Processor | Measure-Object -Property LoadPercentage -Average
        $metrics.CpuPercent = [math]::Round($cpu.Average, 1)
    } catch { }

    try {
        $os = Get-WmiObject Win32_OperatingSystem
        $totalMB = $os.TotalVisibleMemorySize / 1024
        $freeMB = $os.FreePhysicalMemory / 1024
        $metrics.MemoryPercent = [math]::Round((($totalMB - $freeMB) / $totalMB) * 100, 1)
        $metrics.MemoryAvailableGB = [math]::Round($freeMB / 1024, 2)
    } catch { }

    # Recommendation logic
    if ($metrics.CpuPercent -gt 90 -or $metrics.MemoryPercent -gt 85) {
        $metrics.Recommendation = "cloud"
    } elseif ($metrics.CpuPercent -gt 70) {
        $metrics.Recommendation = "hybrid"
    } else {
        $metrics.Recommendation = "local"
    }

    return $metrics
}

function Test-ProviderConnectivity {
    <#
    .SYNOPSIS
        Test if a cloud provider API is reachable
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateSet("anthropic", "openai", "google", "mistral", "groq")]
        [string]$Provider
    )

    $endpoints = @{
        anthropic = "https://api.anthropic.com"
        openai = "https://api.openai.com"
        google = "https://generativelanguage.googleapis.com"
        mistral = "https://api.mistral.ai"
        groq = "https://api.groq.com"
    }

    try {
        $request = [System.Net.WebRequest]::Create($endpoints[$Provider])
        $request.Method = "HEAD"
        $request.Timeout = 5000
        $response = $request.GetResponse()
        $response.Close()
        return $true
    } catch {
        return $false
    }
}

function Test-ApiKeyPresent {
    <#
    .SYNOPSIS
        Check if API key environment variable is set
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$EnvVarName
    )

    return [bool][Environment]::GetEnvironmentVariable($EnvVarName)
}

Export-ModuleMember -Function Test-OllamaAvailable, Get-SystemMetrics, Test-ProviderConnectivity, Test-ApiKeyPresent
```

### Implementation: `AIUtil-Validation.psm1`

```powershell
#Requires -Version 5.1
<#
.SYNOPSIS
    Prompt and code validation utilities
#>

function Get-PromptCategory {
    <#
    .SYNOPSIS
        Categorize a prompt by intent
    #>
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Prompt)

    $promptLower = $Prompt.ToLower()

    $patterns = @{
        code = @("write.*function", "write.*code", "create.*class", "implement", "fix.*bug", "debug", "in python", "in javascript", "sql query")
        analysis = @("explain", "analyze", "compare", "what is", "how does", "why", "describe", "review")
        creative = @("brainstorm", "imagine", "ideas", "story", "creative")
        task = @("do", "execute", "build", "setup", "create", "make")
        question = @("^what is", "^who is", "^when", "^where", "^how", "\?$")
    }

    foreach ($category in $patterns.Keys) {
        foreach ($pattern in $patterns[$category]) {
            if ($promptLower -match $pattern) {
                return $category
            }
        }
    }

    return "general"
}

function Get-PromptClarity {
    <#
    .SYNOPSIS
        Score prompt clarity (0-100)
    #>
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Prompt)

    $score = 50  # Base score

    # Length scoring
    $wordCount = ($Prompt -split '\s+').Count
    if ($wordCount -ge 10) { $score += 15 }
    elseif ($wordCount -ge 5) { $score += 10 }
    elseif ($wordCount -lt 3) { $score -= 20 }

    # Vague terms penalty
    $vagueTerms = @("something", "stuff", "thing", "it", "that", "whatever", "somehow")
    foreach ($term in $vagueTerms) {
        if ($Prompt -match "\b$term\b") {
            $score -= 10
        }
    }

    # Specificity bonus
    if ($Prompt -match "\b(using|with|for|in)\s+\w+") { $score += 10 }
    if ($Prompt -match "\d+") { $score += 5 }  # Contains numbers (often specific)

    return [math]::Max(0, [math]::Min(100, $score))
}

function Get-CodeLanguage {
    <#
    .SYNOPSIS
        Auto-detect programming language from code
    #>
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Code)

    $patterns = @{
        powershell = @('^\s*function\s+\w+', '\$\w+\s*=', 'Write-Host', '\[CmdletBinding\]')
        python = @('^\s*def\s+\w+', '^\s*import\s+', 'print\s*\(', '^\s*class\s+\w+:')
        javascript = @('^\s*const\s+', '^\s*let\s+', '^\s*function\s+\w+', '=>', 'console\.log')
        typescript = @(':\s*(string|number|boolean)', '^\s*interface\s+', '^\s*type\s+\w+\s*=')
        rust = @('^\s*fn\s+', '^\s*let\s+mut', '^\s*struct\s+', 'Vec<')
        sql = @('^\s*SELECT', '^\s*INSERT', '^\s*UPDATE', '^\s*CREATE\s+TABLE')
    }

    $scores = @{}
    foreach ($lang in $patterns.Keys) {
        $scores[$lang] = 0
        foreach ($pattern in $patterns[$lang]) {
            if ($Code -match $pattern) { $scores[$lang]++ }
        }
    }

    $best = $scores.GetEnumerator() | Sort-Object Value -Descending | Select-Object -First 1
    return if ($best.Value -gt 0) { $best.Key } else { "text" }
}

Export-ModuleMember -Function Get-PromptCategory, Get-PromptClarity, Get-CodeLanguage
```

### Refactoring Existing Modules

After creating utility modules, update existing modules:

```powershell
# Before (FewShotLearning.psm1)
try {
    $data = Get-Content $script:SuccessHistoryFile -Raw | ConvertFrom-Json
    return $data.entries
} catch {
    Write-Warning "[FewShot] Failed to load history: $($_.Exception.Message)"
    return @()
}

# After
Import-Module (Join-Path $PSScriptRoot "..\utils\AIUtil-JsonIO.psm1") -Force

$data = Read-JsonFile -Path $script:SuccessHistoryFile -Default @{ entries = @() }
return $data.entries
```

```powershell
# Before (LoadBalancer.psm1)
try {
    $tcp = New-Object System.Net.Sockets.TcpClient
    $tcp.Connect('localhost', 11434)
    $ollamaStatus = $tcp.Connected
    $tcp.Close()
} catch { }

# After
Import-Module (Join-Path $PSScriptRoot "..\utils\AIUtil-Health.psm1") -Force

$ollamaStatus = Test-OllamaAvailable
```

### Migration Checklist

- [ ] Create `utils/` directory
- [ ] Implement `AIUtil-JsonIO.psm1`
- [ ] Implement `AIUtil-Health.psm1`
- [ ] Implement `AIUtil-Validation.psm1`
- [ ] Implement `AIUtil-Crypto.psm1`
- [ ] Implement `AIUtil-Network.psm1`
- [ ] Update `FewShotLearning.psm1` to use utils
- [ ] Update `ErrorLogger.psm1` to use utils
- [ ] Update `LoadBalancer.psm1` to use utils
- [ ] Update `SelfCorrection.psm1` to use utils
- [ ] Update `TaskClassifier.psm1` to use utils
- [ ] Update `AdvancedAI.psm1` to use utils
- [ ] Remove duplicate code
- [ ] Add unit tests for utilities

### Estimated Effort: 1 week

---

## Approach 3: Dependency Injection Pattern (Fix Circular Dependencies)

### Problem Statement

Current circular dependency chain:
```
AIModelHandler → PromptOptimizer → TaskClassifier → SmartQueue → AIModelHandler
                                                  ↓
                                            TaskClassifier (circular!)
```

Silent import failures cause runtime errors:
```powershell
# Current problematic pattern
if (Test-Path $script:PromptOptimizerPath) {
    Import-Module $script:PromptOptimizerPath -Force -ErrorAction SilentlyContinue
}
# Later code assumes functions exist - BOOM!
```

### Target Architecture

```
                    ┌─────────────────────┐
                    │   AIFacade.psm1     │  ← Single entry point
                    │  (Dependency Root)  │
                    └──────────┬──────────┘
                               │
         ┌─────────────────────┼─────────────────────┐
         │                     │                     │
         ▼                     ▼                     ▼
   ┌───────────┐        ┌───────────┐        ┌───────────┐
   │ AIConfig  │        │ AIState   │        │RateLimiter│
   │(no deps)  │        │(no deps)  │        │(no deps)  │
   └───────────┘        └───────────┘        └───────────┘
                               │
                               ▼
                    ┌─────────────────────┐
                    │  AIModelHandler     │  ← Receives dependencies
                    │  (Injected deps)    │
                    └──────────┬──────────┘
                               │
         ┌─────────────────────┼─────────────────────┐
         ▼                     ▼                     ▼
   ┌───────────┐        ┌───────────┐        ┌───────────┐
   │AdvancedAI │        │SelfCorrect│        │FewShot    │
   └───────────┘        └───────────┘        └───────────┘
```

### Implementation: `AIFacade.psm1`

```powershell
#Requires -Version 5.1
<#
.SYNOPSIS
    AI System Facade - Single entry point with dependency injection
.DESCRIPTION
    Loads all AI modules in correct order and injects dependencies.
    Prevents circular imports by controlling load order.
#>

$script:ModulesLoaded = $false
$script:Dependencies = @{}

function Initialize-AISystem {
    <#
    .SYNOPSIS
        Initialize AI system with proper dependency order
    #>
    [CmdletBinding()]
    param([switch]$Force)

    if ($script:ModulesLoaded -and -not $Force) {
        return $script:Dependencies
    }

    $basePath = Split-Path -Parent $PSScriptRoot
    $modulesPath = Join-Path $basePath "modules"
    $utilsPath = Join-Path $basePath "utils"

    # Phase 1: Load utilities (no dependencies)
    $utilities = @(
        "AIUtil-JsonIO.psm1",
        "AIUtil-Health.psm1",
        "AIUtil-Validation.psm1"
    )

    foreach ($util in $utilities) {
        $path = Join-Path $utilsPath $util
        if (Test-Path $path) {
            Import-Module $path -Force -Global -ErrorAction Stop
        } else {
            throw "Required utility not found: $util"
        }
    }

    # Phase 2: Load core (no AI dependencies)
    $core = @(
        "core\AIConstants.psm1",
        "core\AIConfig.psm1",
        "core\AIState.psm1"
    )

    foreach ($mod in $core) {
        $path = Join-Path $basePath $mod
        if (Test-Path $path) {
            Import-Module $path -Force -Global -ErrorAction Stop
        }
    }

    # Phase 3: Load infrastructure
    Import-Module (Join-Path $basePath "rate-limiting\RateLimiter.psm1") -Force -Global
    Import-Module (Join-Path $basePath "model-selection\ModelSelector.psm1") -Force -Global

    # Phase 4: Load main handler
    Import-Module (Join-Path $basePath "AIModelHandler.psm1") -Force -Global

    # Phase 5: Load advanced modules (can depend on handler)
    $advanced = @(
        "SelfCorrection.psm1",
        "FewShotLearning.psm1",
        "SpeculativeDecoding.psm1",
        "LoadBalancer.psm1",
        "SemanticFileMapping.psm1",
        "PromptOptimizer.psm1",
        "TaskClassifier.psm1",
        "SmartQueue.psm1"
    )

    foreach ($mod in $advanced) {
        $path = Join-Path $modulesPath $mod
        if (Test-Path $path) {
            try {
                Import-Module $path -Force -Global -ErrorAction Stop
            } catch {
                Write-Warning "Optional module failed: $mod - $($_.Exception.Message)"
            }
        }
    }

    # Phase 6: Load orchestrator
    Import-Module (Join-Path $modulesPath "AdvancedAI.psm1") -Force -Global -ErrorAction SilentlyContinue

    # Build dependency container
    $script:Dependencies = @{
        Config = Get-AIConfig
        State = Get-AIState
        Utilities = @{
            JsonIO = Get-Module AIUtil-JsonIO
            Health = Get-Module AIUtil-Health
        }
        Services = @{
            RateLimiter = Get-Module RateLimiter
            ModelSelector = Get-Module ModelSelector
        }
    }

    $script:ModulesLoaded = $true
    Write-Host "[AIFacade] System initialized" -ForegroundColor Green

    return $script:Dependencies
}

function Get-AIDependencies {
    <#
    .SYNOPSIS
        Get dependency container
    #>
    if (-not $script:ModulesLoaded) {
        Initialize-AISystem
    }
    return $script:Dependencies
}

function Invoke-AI {
    <#
    .SYNOPSIS
        Unified AI invocation with automatic initialization
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Prompt,

        [string]$Mode = "auto",
        [string]$Model,
        [int]$MaxTokens = 2048
    )

    Initialize-AISystem

    if (Get-Command Invoke-AdvancedAI -ErrorAction SilentlyContinue) {
        return Invoke-AdvancedAI -Prompt $Prompt -Mode $Mode -Model $Model -MaxTokens $MaxTokens
    } else {
        $messages = @(@{ role = "user"; content = $Prompt })
        return Invoke-AIRequest -Messages $messages -MaxTokens $MaxTokens
    }
}

Export-ModuleMember -Function Initialize-AISystem, Get-AIDependencies, Invoke-AI
```

### Refactoring Modules to Accept Dependencies

```powershell
# Before (SelfCorrection.psm1)
$mainModule = Join-Path $script:ModulePath "AIModelHandler.psm1"
if (-not (Get-Module AIModelHandler)) {
    Import-Module $mainModule -Force  # Potential circular import!
}

# After (SelfCorrection.psm1)
function Test-CodeSyntax {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Code,

        [string]$Language = "auto",

        # Dependency injection
        [scriptblock]$AIRequestFunc = $null
    )

    # Use injected function or try to get from loaded module
    if (-not $AIRequestFunc) {
        if (Get-Command Invoke-AIRequest -ErrorAction SilentlyContinue) {
            $AIRequestFunc = { param($p, $m, $msgs, $mt, $t) Invoke-AIRequest -Provider $p -Model $m -Messages $msgs -MaxTokens $mt -Temperature $t }
        } else {
            throw "Invoke-AIRequest not available. Initialize AI system first."
        }
    }

    # ... rest of implementation using $AIRequestFunc
}
```

### Migration Checklist

- [ ] Create `AIFacade.psm1`
- [ ] Define explicit load order
- [ ] Refactor modules to accept dependencies
- [ ] Remove inline `Import-Module` calls from modules
- [ ] Update `_launcher.ps1` to use `Initialize-AISystem`
- [ ] Update `AdvancedAI.psm1` to use facade
- [ ] Add health check for loaded modules
- [ ] Test all module combinations
- [ ] Document dependency graph

### Estimated Effort: 2 weeks

---

## Approach 4: Standardized Error Handling (Reliability)

### Problem Statement

Current error handling is inconsistent:

| Pattern | Files | Issue |
|---------|-------|-------|
| No handling | SelfCorrection | Silent failures |
| Silent continue | AIModelHandler | Hidden errors |
| Magic fallback | LoadBalancer | `CpuPercent = 50` |
| Throw only | Some providers | No recovery |

### Target Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    AIErrorHandler.psm1                       │
├─────────────────────────────────────────────────────────────┤
│  Invoke-AIOperation { ... }    # Unified wrapper            │
│  Get-ErrorCategory { ... }     # Classify errors            │
│  Write-ErrorContext { ... }    # Rich logging               │
│  New-AIError { ... }           # Structured errors          │
│  Test-Recoverable { ... }      # Can we retry?              │
└─────────────────────────────────────────────────────────────┘
```

### Implementation: `AIErrorHandler.psm1`

```powershell
#Requires -Version 5.1
<#
.SYNOPSIS
    Centralized error handling for AI operations
#>

$script:ErrorCategories = @{
    RateLimit = @{
        Patterns = @("rate.?limit", "429", "too many requests")
        Recoverable = $true
        RetryAfter = 60
        Fallback = $true
    }
    Overloaded = @{
        Patterns = @("overloaded", "503", "capacity")
        Recoverable = $true
        RetryAfter = 30
        Fallback = $true
    }
    AuthError = @{
        Patterns = @("401", "403", "unauthorized", "forbidden", "invalid.*key")
        Recoverable = $false
        RetryAfter = 0
        Fallback = $true
    }
    ServerError = @{
        Patterns = @("500", "502", "504", "server error")
        Recoverable = $true
        RetryAfter = 5
        Fallback = $true
    }
    NetworkError = @{
        Patterns = @("timeout", "connection refused", "network", "ECONNREFUSED")
        Recoverable = $true
        RetryAfter = 3
        Fallback = $true
    }
    ValidationError = @{
        Patterns = @("invalid.*request", "400", "bad request", "validation")
        Recoverable = $false
        RetryAfter = 0
        Fallback = $false
    }
}

function Get-ErrorCategory {
    <#
    .SYNOPSIS
        Classify an error by category
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [System.Exception]$Exception
    )

    $message = $Exception.Message.ToLower()

    foreach ($category in $script:ErrorCategories.Keys) {
        $info = $script:ErrorCategories[$category]
        foreach ($pattern in $info.Patterns) {
            if ($message -match $pattern) {
                return @{
                    Category = $category
                    Recoverable = $info.Recoverable
                    RetryAfter = $info.RetryAfter
                    Fallback = $info.Fallback
                }
            }
        }
    }

    return @{
        Category = "Unknown"
        Recoverable = $false
        RetryAfter = 0
        Fallback = $false
    }
}

function New-AIError {
    <#
    .SYNOPSIS
        Create structured AI error object
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Message,

        [string]$Operation,
        [string]$Provider,
        [string]$Model,
        [System.Exception]$InnerException,
        [hashtable]$Context = @{}
    )

    $errorInfo = if ($InnerException) {
        Get-ErrorCategory -Exception $InnerException
    } else {
        @{ Category = "Custom"; Recoverable = $false; RetryAfter = 0; Fallback = $false }
    }

    return @{
        Message = $Message
        Operation = $Operation
        Provider = $Provider
        Model = $Model
        Category = $errorInfo.Category
        Recoverable = $errorInfo.Recoverable
        RetryAfter = $errorInfo.RetryAfter
        CanFallback = $errorInfo.Fallback
        Timestamp = (Get-Date).ToString("o")
        Context = $Context
        InnerException = $InnerException
    }
}

function Invoke-AIOperation {
    <#
    .SYNOPSIS
        Execute AI operation with standardized error handling
    .PARAMETER Operation
        Name of the operation (for logging)
    .PARAMETER Script
        ScriptBlock to execute
    .PARAMETER MaxRetries
        Maximum retry attempts
    .PARAMETER OnError
        Optional error handler scriptblock
    .PARAMETER Context
        Additional context for error reporting
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Operation,

        [Parameter(Mandatory)]
        [scriptblock]$Script,

        [int]$MaxRetries = 3,
        [int]$RetryDelayMs = 1000,

        [scriptblock]$OnError,
        [scriptblock]$OnRetry,
        [scriptblock]$OnFallback,

        [hashtable]$Context = @{}
    )

    $attempt = 0
    $lastError = $null

    while ($attempt -lt $MaxRetries) {
        $attempt++

        try {
            $result = & $Script
            return @{
                Success = $true
                Result = $result
                Attempts = $attempt
            }
        } catch {
            $lastError = $_
            $errorInfo = Get-ErrorCategory -Exception $_.Exception

            $aiError = New-AIError -Message $_.Exception.Message `
                -Operation $Operation `
                -InnerException $_.Exception `
                -Context $Context

            # Log error
            if (Get-Command Write-ErrorLog -ErrorAction SilentlyContinue) {
                Write-ErrorLog -Message "[$Operation] Attempt $attempt failed: $($_.Exception.Message)" `
                    -ErrorRecord $_ -Source "AIErrorHandler"
            }

            # Call error handler
            if ($OnError) {
                & $OnError $aiError
            }

            # Check if we should retry
            if (-not $errorInfo.Recoverable) {
                break
            }

            # Check if we should fallback instead of retry
            if ($errorInfo.Fallback -and $OnFallback -and $attempt -eq $MaxRetries) {
                $fallbackResult = & $OnFallback $aiError
                if ($fallbackResult) {
                    return @{
                        Success = $true
                        Result = $fallbackResult
                        Attempts = $attempt
                        UsedFallback = $true
                    }
                }
            }

            # Retry with delay
            if ($attempt -lt $MaxRetries) {
                $delay = [math]::Max($RetryDelayMs, $errorInfo.RetryAfter * 1000)

                if ($OnRetry) {
                    & $OnRetry $aiError $attempt $delay
                }

                Start-Sleep -Milliseconds ($delay * $attempt)
            }
        }
    }

    # All retries exhausted
    return @{
        Success = $false
        Error = $lastError
        Attempts = $attempt
        ErrorInfo = Get-ErrorCategory -Exception $lastError.Exception
    }
}

function Write-ErrorContext {
    <#
    .SYNOPSIS
        Write rich error context to log
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [hashtable]$AIError,

        [ValidateSet("Console", "File", "Both")]
        [string]$Output = "Both"
    )

    $message = @"
[AI ERROR] $($AIError.Timestamp)
Operation: $($AIError.Operation)
Provider: $($AIError.Provider)
Model: $($AIError.Model)
Category: $($AIError.Category)
Recoverable: $($AIError.Recoverable)
Message: $($AIError.Message)
"@

    if ($Output -in @("Console", "Both")) {
        Write-Host $message -ForegroundColor Red
    }

    if ($Output -in @("File", "Both")) {
        if (Get-Command Write-ErrorLog -ErrorAction SilentlyContinue) {
            Write-ErrorLog -Message $AIError.Message -Source $AIError.Operation
        }
    }
}

Export-ModuleMember -Function Get-ErrorCategory, New-AIError, Invoke-AIOperation, Write-ErrorContext
```

### Usage Examples

```powershell
# Before
try {
    $response = Invoke-RestMethod -Uri $uri -Method Post -Body $body
} catch {
    Write-Warning "Request failed: $_"
    # No retry, no fallback, lost context
}

# After
$result = Invoke-AIOperation -Operation "AnthropicRequest" -Context @{
    Provider = "anthropic"
    Model = $Model
} -Script {
    Invoke-RestMethod -Uri $uri -Method Post -Body $body
} -OnRetry {
    param($error, $attempt, $delay)
    Write-Host "[Retry] Attempt $attempt in ${delay}ms..." -ForegroundColor Yellow
} -OnFallback {
    param($error)
    # Try different provider
    Invoke-OpenAIRequest -Messages $Messages
}

if ($result.Success) {
    return $result.Result
} else {
    Write-ErrorContext -AIError $result.Error
    throw $result.Error.Message
}
```

### Migration Checklist

- [ ] Create `AIErrorHandler.psm1`
- [ ] Define error categories and patterns
- [ ] Implement `Invoke-AIOperation` wrapper
- [ ] Update `Invoke-AnthropicAPI` to use wrapper
- [ ] Update `Invoke-OpenAIAPI` to use wrapper
- [ ] Update `Invoke-OllamaAPI` to use wrapper
- [ ] Update `Invoke-AIRequest` to use wrapper
- [ ] Update `LoadBalancer` fallback logic
- [ ] Update `SelfCorrection` error handling
- [ ] Add error rate monitoring
- [ ] Add user notifications for degraded service
- [ ] Write integration tests

### Estimated Effort: 1.5 weeks

---

## Approach 5: Layered Architecture (Clean Boundaries)

### Problem Statement

Current architecture has no clear boundaries:
- UI code calls provider APIs directly
- Modules import each other freely
- No clear separation of concerns
- Difficult to test in isolation

### Target Architecture

```
┌─────────────────────────────────────────────────────────────────────────────┐
│ Layer 4: PRESENTATION                                                        │
│ ┌─────────────────┐ ┌─────────────────┐ ┌─────────────────┐                 │
│ │ _launcher.ps1   │ │ GUI-Utils.psm1  │ │ ConsoleUI.psm1  │                 │
│ └────────┬────────┘ └────────┬────────┘ └────────┬────────┘                 │
├──────────┼───────────────────┼───────────────────┼──────────────────────────┤
│ Layer 3: ORCHESTRATION                                                       │
│ ┌────────▼────────┐ ┌────────▼────────┐ ┌────────▼────────┐                 │
│ │ AdvancedAI.psm1 │ │ HYDRA-GUI.psm1  │ │ SmartQueue.psm1 │                 │
│ └────────┬────────┘ └────────┬────────┘ └────────┬────────┘                 │
├──────────┼───────────────────┼───────────────────┼──────────────────────────┤
│ Layer 2: BUSINESS LOGIC                                                      │
│ ┌────────▼────────┐ ┌────────▼────────┐ ┌────────▼────────┐ ┌─────────────┐ │
│ │ ModelSelector   │ │ RateLimiter     │ │ SelfCorrection  │ │ FewShot     │ │
│ │ ProviderFallback│ │ LoadBalancer    │ │ TaskClassifier  │ │ Speculation │ │
│ └────────┬────────┘ └────────┬────────┘ └────────┬────────┘ └──────┬──────┘ │
├──────────┼───────────────────┼───────────────────┼─────────────────┼────────┤
│ Layer 1: INFRASTRUCTURE                                                      │
│ ┌────────▼────────┐ ┌────────▼────────┐ ┌────────▼────────┐ ┌──────▼──────┐ │
│ │ AIUtil-JsonIO   │ │ AIUtil-Health   │ │ Providers       │ │ ErrorLogger │ │
│ │ AIUtil-Network  │ │ AIConfig/State  │ │ (API calls)     │ │ SecureStore │ │
│ └─────────────────┘ └─────────────────┘ └─────────────────┘ └─────────────┘ │
└─────────────────────────────────────────────────────────────────────────────┘

RULE: Each layer can only call DOWN, never UP
```

### Directory Structure

```
ai-handler/
├── layer1-infrastructure/
│   ├── utils/
│   │   ├── AIUtil-JsonIO.psm1
│   │   ├── AIUtil-Health.psm1
│   │   ├── AIUtil-Network.psm1
│   │   └── AIUtil-Validation.psm1
│   ├── config/
│   │   ├── AIConfig.psm1
│   │   ├── AIState.psm1
│   │   └── AIConstants.psm1
│   ├── logging/
│   │   ├── ErrorLogger.psm1
│   │   └── AILogger.psm1
│   ├── security/
│   │   └── SecureStorage.psm1
│   └── providers/
│       ├── ProviderBase.psm1
│       ├── AnthropicProvider.psm1
│       ├── OpenAIProvider.psm1
│       ├── GoogleProvider.psm1
│       ├── OllamaProvider.psm1
│       └── ProviderRegistry.psm1
│
├── layer2-business/
│   ├── model-selection/
│   │   ├── ModelSelector.psm1
│   │   └── ProviderFallback.psm1
│   ├── rate-limiting/
│   │   ├── RateLimiter.psm1
│   │   └── LoadBalancer.psm1
│   ├── generation/
│   │   ├── SelfCorrection.psm1
│   │   ├── FewShotLearning.psm1
│   │   ├── SpeculativeDecoding.psm1
│   │   └── SemanticFileMapping.psm1
│   └── classification/
│       ├── TaskClassifier.psm1
│       └── PromptOptimizer.psm1
│
├── layer3-orchestration/
│   ├── AIOrchestrator.psm1      # Main orchestrator
│   ├── AdvancedAI.psm1          # Advanced features
│   ├── SmartQueue.psm1          # Request queuing
│   └── BatchProcessor.psm1       # Batch operations
│
├── layer4-presentation/
│   ├── AIStatusDisplay.psm1     # Status formatting
│   ├── AIProgressBar.psm1       # Progress indicators
│   └── AIResultFormatter.psm1   # Output formatting
│
├── AIFacade.psm1                # Public API
└── AIModelHandler.psm1          # Backward compatibility
```

### Implementation: Layer Contract Enforcement

```powershell
# layer-validator.ps1 - Run in CI/CD to enforce layer rules

$layerOrder = @(
    "layer1-infrastructure",
    "layer2-business",
    "layer3-orchestration",
    "layer4-presentation"
)

$violations = @()

foreach ($layer in $layerOrder) {
    $layerIndex = $layerOrder.IndexOf($layer)
    $files = Get-ChildItem "ai-handler\$layer" -Recurse -Filter "*.psm1"

    foreach ($file in $files) {
        $content = Get-Content $file.FullName -Raw

        # Check for imports from higher layers
        for ($i = $layerIndex + 1; $i -lt $layerOrder.Count; $i++) {
            $higherLayer = $layerOrder[$i]
            if ($content -match $higherLayer) {
                $violations += @{
                    File = $file.Name
                    Layer = $layer
                    Violation = "Imports from $higherLayer (higher layer)"
                }
            }
        }
    }
}

if ($violations.Count -gt 0) {
    Write-Host "LAYER VIOLATIONS FOUND:" -ForegroundColor Red
    $violations | Format-Table -AutoSize
    exit 1
}

Write-Host "All layers valid" -ForegroundColor Green
```

### Implementation: Layer-Specific Module Template

```powershell
# Template for Layer 1 (Infrastructure)
#Requires -Version 5.1

# Layer 1 modules have NO dependencies on other AI modules
# They only use PowerShell built-ins and .NET

$script:LayerName = "Infrastructure"
$script:AllowedDependencies = @()  # None

function Assert-LayerContract {
    # Called at module load to verify we're not violating layers
    $loadedModules = Get-Module | Where-Object { $_.Name -like "AI*" }
    foreach ($mod in $loadedModules) {
        if ($mod.Path -match "layer[234]") {
            throw "Layer violation: Infrastructure module cannot depend on $($mod.Name)"
        }
    }
}

# Rest of module implementation...
```

```powershell
# Template for Layer 2 (Business Logic)
#Requires -Version 5.1

$script:LayerName = "Business"
$script:AllowedDependencies = @("layer1-infrastructure")

# Import infrastructure layer
$infraPath = Join-Path (Split-Path $PSScriptRoot -Parent) "layer1-infrastructure"
Get-ChildItem "$infraPath\**\*.psm1" | ForEach-Object {
    Import-Module $_.FullName -Force
}

# Rest of module implementation...
```

### Layer Responsibilities

| Layer | Responsibility | Can Import From | Cannot Import From |
|-------|----------------|-----------------|-------------------|
| **Layer 1: Infrastructure** | File I/O, HTTP, Config, Logging | .NET, PowerShell built-ins | Any AI module |
| **Layer 2: Business Logic** | Algorithms, Rules, Processing | Layer 1 | Layer 3, 4 |
| **Layer 3: Orchestration** | Workflow coordination, Queuing | Layer 1, 2 | Layer 4 |
| **Layer 4: Presentation** | UI, Formatting, User interaction | Layer 1, 2, 3 | - |

### Backward Compatibility

```powershell
# AIModelHandler.psm1 - Maintained for backward compatibility
#Requires -Version 5.1
<#
.SYNOPSIS
    Backward compatibility wrapper for AIModelHandler
.DESCRIPTION
    This module is maintained for backward compatibility.
    New code should use AIFacade.psm1 directly.
#>

# Import new layered architecture
Import-Module (Join-Path $PSScriptRoot "AIFacade.psm1") -Force

# Re-export all functions for backward compatibility
$exportedFunctions = (Get-Module AIFacade).ExportedFunctions.Keys
Export-ModuleMember -Function $exportedFunctions

# Emit deprecation warning on first use
$script:DeprecationWarningShown = $false
function Show-DeprecationWarning {
    if (-not $script:DeprecationWarningShown) {
        Write-Warning "AIModelHandler.psm1 is deprecated. Use AIFacade.psm1 instead."
        $script:DeprecationWarningShown = $true
    }
}
```

### Migration Path

1. **Phase 1**: Create layer directories without moving code
2. **Phase 2**: Create new modules in layers, copy relevant code
3. **Phase 3**: Update imports in new modules
4. **Phase 4**: Create AIFacade.psm1 that imports new layers
5. **Phase 5**: Update AIModelHandler.psm1 to use AIFacade
6. **Phase 6**: Update _launcher.ps1 to use AIFacade
7. **Phase 7**: Update all slash commands to use new structure
8. **Phase 8**: Remove deprecated code paths
9. **Phase 9**: Add layer validation to CI/CD

### Migration Checklist

- [ ] Create layer directory structure
- [ ] Move utilities to layer1-infrastructure/utils
- [ ] Move config/state to layer1-infrastructure/config
- [ ] Move providers to layer1-infrastructure/providers
- [ ] Create ProviderRegistry for provider management
- [ ] Move business logic to layer2-business
- [ ] Move orchestration to layer3-orchestration
- [ ] Create presentation layer modules
- [ ] Create AIFacade.psm1
- [ ] Update AIModelHandler.psm1 for backward compat
- [ ] Update _launcher.ps1
- [ ] Add layer validation script
- [ ] Update CLAUDE.md documentation
- [ ] Add architecture diagram
- [ ] Write migration guide

### Estimated Effort: 6 weeks

---

## Summary: Implementation Order

| Phase | Approach | Duration | Dependencies | Impact |
|-------|----------|----------|--------------|--------|
| **1** | Extract Utilities (#2) | 1 week | None | Medium - Quick wins |
| **2** | Error Handling (#4) | 1.5 weeks | #2 | Medium - Reliability |
| **3** | Split Monolith (#1) | 4 weeks | #2, #4 | High - Maintainability |
| **4** | Dependency Injection (#3) | 2 weeks | #1 | High - Stability |
| **5** | Layered Architecture (#5) | 6 weeks | All | High - Full restructure |

### Recommended Path

**Minimal refactoring** (2-3 weeks): Approaches #2 + #4
- Extract utilities
- Standardize error handling
- ROI: 40% less duplication, 80% better error handling

**Comprehensive refactoring** (8-10 weeks): All approaches
- Full architectural transformation
- ROI: Testable, maintainable, scalable codebase

---

## Appendix A: Quick Reference

### Files to Create

```
ai-handler/
├── utils/
│   ├── AIUtil-JsonIO.psm1      # NEW
│   ├── AIUtil-Health.psm1      # NEW
│   ├── AIUtil-Validation.psm1  # NEW
│   ├── AIUtil-Crypto.psm1      # NEW
│   └── AIUtil-Network.psm1     # NEW
├── core/
│   ├── AIConfig.psm1           # EXTRACT from AIModelHandler
│   ├── AIState.psm1            # EXTRACT from AIModelHandler
│   ├── AIConstants.psm1        # EXTRACT from AIModelHandler
│   └── AILogger.psm1           # EXTRACT from AIModelHandler
├── rate-limiting/
│   └── RateLimiter.psm1        # EXTRACT from AIModelHandler
├── model-selection/
│   └── ModelSelector.psm1      # EXTRACT from AIModelHandler
├── fallback/
│   └── ProviderFallback.psm1   # EXTRACT from AIModelHandler
├── providers/
│   ├── ProviderBase.psm1       # NEW
│   ├── AnthropicProvider.psm1  # EXTRACT from AIModelHandler
│   ├── OpenAIProvider.psm1     # EXTRACT from AIModelHandler
│   └── OllamaProvider.psm1     # EXTRACT from AIModelHandler
├── error-handling/
│   └── AIErrorHandler.psm1     # NEW
├── AIFacade.psm1               # NEW
└── AIModelHandler.psm1         # REFACTOR to facade
```

### Code to Remove (Duplicates)

| File | Lines | Duplication Type |
|------|-------|------------------|
| FewShotLearning.psm1 | 58-67 | JSON read pattern |
| ErrorLogger.psm1 | 130-145 | JSON parse pattern |
| LoadBalancer.psm1 | 58-69 | CPU metrics |
| SelfCorrection.psm1 | 43-46 | Ollama check |
| TaskClassifier.psm1 | 95-110 | Ollama check |
| AdvancedAI.psm1 | 422-433 | Ollama check |

---

*Document generated: 2026-01-13*
*Author: HYDRA Refactoring System*

#Requires -Version 5.1
<#
.SYNOPSIS
    HYDRA Task Classifier v2 - Local-First AI Task Routing
.DESCRIPTION
    Intelligent task classification with LOCAL MODEL PRIORITY:
    1. First tries local Ollama models (free, fast, offline-capable)
    2. Falls back to cloud only when necessary
    3. Automatic offline detection and fallback
    4. Queue integration for parallel execution
.VERSION
    2.0.0
#>

$script:ModulePath = Split-Path -Parent $PSScriptRoot

# Import AI Handler for Invoke-AIRequest
$aiHandlerPath = Join-Path $script:ModulePath "AIModelHandler.psm1"
if (Test-Path $aiHandlerPath) {
    Import-Module $aiHandlerPath -Force -Global
}

# Configuration - LOCAL FIRST
$script:ClassifierConfig = @{
    # PRIMARY: Local Ollama models (preferred)
    LocalClassifier = @{
        Provider = "ollama"
        Models = @(
            "llama3.2:3b",      # Best local classifier
            "phi3:mini",        # Fast alternative
            "qwen2.5:3b",       # Good reasoning
            "llama3.2:1b"       # Ultra-fast fallback
        )
    }
    # FALLBACK: Cloud models (when local unavailable)
    CloudClassifier = @{
        Provider = "anthropic"
        Model = "claude-sonnet-4-5-20250929"
        FallbackProvider = "openai"
        FallbackModel = "gpt-4o-mini"
    }
    # Execution model preferences by tier
    ExecutionModels = @{
        lite = @{
            local = @("llama3.2:1b", "phi3:mini", "qwen2.5:0.5b")
            cloud = @("claude-3-5-haiku-20241022", "gpt-4o-mini")
        }
        standard = @{
            local = @("llama3.2:3b", "qwen2.5-coder:7b", "phi3:medium")
            cloud = @("claude-sonnet-4-5-20250929", "gpt-4o")
        }
        pro = @{
            local = @("llama3.3:70b", "qwen2.5:32b", "deepseek-coder:33b")
            cloud = @("claude-opus-4-5-20251101", "gpt-4o")
        }
    }
    # Settings
    PreferLocal = $true
    CacheEnabled = $true
    CacheTTLSeconds = 300
    OfflineMode = $false
    TimeoutSeconds = 30
}

# State
$script:ClassificationCache = @{}
$script:NetworkStatus = @{ Online = $true; LastCheck = $null; OllamaAvailable = $false }

#region Network & Ollama Detection

function Test-NetworkConnectivity {
    <#
    .SYNOPSIS
        Tests internet connectivity
    #>
    [CmdletBinding()]
    param([switch]$Force)
    
    # Use cached result if recent (5 seconds)
    if (-not $Force -and $script:NetworkStatus.LastCheck) {
        $age = ((Get-Date) - $script:NetworkStatus.LastCheck).TotalSeconds
        if ($age -lt 5) {
            return $script:NetworkStatus.Online
        }
    }
    
    try {
        $result = Test-Connection -ComputerName "8.8.8.8" -Count 1 -Quiet -ErrorAction SilentlyContinue
        $script:NetworkStatus.Online = $result
        $script:NetworkStatus.LastCheck = Get-Date
        return $result
    } catch {
        $script:NetworkStatus.Online = $false
        $script:NetworkStatus.LastCheck = Get-Date
        return $false
    }
}

function Test-OllamaAvailability {
    <#
    .SYNOPSIS
        Tests if Ollama is running and has models
    #>
    [CmdletBinding()]
    param([switch]$Force)
    
    # Use cached result if recent (10 seconds)
    if (-not $Force -and $script:NetworkStatus.OllamaCheck) {
        $age = ((Get-Date) - $script:NetworkStatus.OllamaCheck).TotalSeconds
        if ($age -lt 10) {
            return $script:NetworkStatus.OllamaAvailable
        }
    }
    
    try {
        $response = Invoke-RestMethod -Uri "http://localhost:11434/api/tags" -Method Get -TimeoutSec 2 -ErrorAction Stop
        $hasModels = $response.models.Count -gt 0
        $script:NetworkStatus.OllamaAvailable = $hasModels
        $script:NetworkStatus.OllamaModels = $response.models.name
        $script:NetworkStatus.OllamaCheck = Get-Date
        return $hasModels
    } catch {
        $script:NetworkStatus.OllamaAvailable = $false
        $script:NetworkStatus.OllamaCheck = Get-Date
        return $false
    }
}

function Get-AvailableLocalModel {
    <#
    .SYNOPSIS
        Gets best available local Ollama model from preference list
    #>
    [CmdletBinding()]
    param(
        [string[]]$PreferredModels = @("llama3.2:3b", "phi3:mini", "llama3.2:1b")
    )
    
    if (-not (Test-OllamaAvailability)) {
        return $null
    }
    
    $available = $script:NetworkStatus.OllamaModels
    foreach ($model in $PreferredModels) {
        # Check exact match or partial match
        $match = $available | Where-Object { $_ -eq $model -or $_ -like "$model*" }
        if ($match) {
            return $match | Select-Object -First 1
        }
    }
    
    # Return any available model
    return $available | Select-Object -First 1
}

function Get-ConnectionStatus {
    <#
    .SYNOPSIS
        Returns comprehensive connection status
    #>
    [CmdletBinding()]
    param()
    
    $ollama = Test-OllamaAvailability
    $internet = Test-NetworkConnectivity
    
    $mode = if ($ollama -and $internet) { "full" }
            elseif ($ollama) { "offline-local" }
            elseif ($internet) { "cloud-only" }
            else { "offline-pattern" }
    
    $localModel = if ($ollama) { Get-AvailableLocalModel } else { $null }

    return @{
        LocalAvailable = $ollama
        OllamaAvailable = $ollama
        OllamaModels = $script:NetworkStatus.OllamaModels
        InternetAvailable = $internet
        Mode = $mode
        LocalModel = $localModel
        Recommendation = if ($ollama) { "local" } elseif ($internet) { "cloud" } else { "pattern" }
    }
}

#endregion

#region Classification

function Get-ClassifierModel {
    <#
    .SYNOPSIS
        Gets best available classifier model - LOCAL FIRST
    #>
    [CmdletBinding()]
    param([switch]$PreferCloud)
    
    # Check Ollama first (unless cloud preferred)
    if (-not $PreferCloud) {
        $localModel = Get-AvailableLocalModel -PreferredModels $script:ClassifierConfig.LocalClassifier.Models
        if ($localModel) {
            Write-Verbose "[TaskClassifier] Using local Ollama: $localModel"
            return @{
                Provider = "ollama"
                Model = $localModel
                IsLocal = $true
            }
        }
    }
    
    # Check internet for cloud
    if (-not (Test-NetworkConnectivity)) {
        Write-Verbose "[TaskClassifier] Offline - no classifier available"
        return $null
    }
    
    # Try Anthropic
    if ($env:ANTHROPIC_API_KEY) {
        return @{
            Provider = "anthropic"
            Model = $script:ClassifierConfig.CloudClassifier.Model
            IsLocal = $false
        }
    }
    
    # Try OpenAI
    if ($env:OPENAI_API_KEY) {
        return @{
            Provider = "openai"
            Model = $script:ClassifierConfig.CloudClassifier.FallbackModel
            IsLocal = $false
        }
    }
    
    return $null
}

function Invoke-TaskClassification {
    <#
    .SYNOPSIS
        Classifies task using LOCAL-FIRST approach
    .PARAMETER Prompt
        The prompt to classify
    .PARAMETER PreferLocal
        Prioritize local Ollama models (default: true)
    .PARAMETER UseCache
        Use cached classifications
    .PARAMETER ForQueue
        Include queue metadata for parallel execution
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [string]$Prompt,
        
        [switch]$PreferLocal = $true,
        [switch]$UseCache = $true,
        [switch]$ForceRefresh,
        [switch]$ForQueue
    )
    
    begin {
        $systemPrompt = @"
You are a task classifier. Analyze the request and respond with JSON only:
{
    "category": "code|analysis|creative|simple|complex|data|research",
    "complexity": 1-10,
    "tier": "lite|standard|pro",
    "local_suitable": true/false,
    "parallel_safe": true/false,
    "estimated_tokens": number,
    "reasoning": "brief explanation"
}

Complexity: 1-3=lite, 4-6=standard, 7-10=pro
local_suitable: true if task can run on local 3B model
parallel_safe: true if task is independent (no shared state)
"@
    }
    
    process {
        # Generate cache key
        $promptHash = [System.BitConverter]::ToString(
            [System.Security.Cryptography.SHA256]::Create().ComputeHash(
                [System.Text.Encoding]::UTF8.GetBytes($Prompt.Substring(0, [Math]::Min($Prompt.Length, 500)))
            )
        ).Replace("-", "").Substring(0, 16)
        
        # Check cache
        if ($UseCache -and -not $ForceRefresh -and $script:ClassificationCache.ContainsKey($promptHash)) {
            $cached = $script:ClassificationCache[$promptHash]
            $age = ((Get-Date) - $cached.Timestamp).TotalSeconds
            if ($age -lt $script:ClassifierConfig.CacheTTLSeconds) {
                Write-Verbose "[TaskClassifier] Using cached classification"
                $cached.Result.FromCache = $true
                return $cached.Result
            }
        }
        
        # Get classifier
        $classifier = Get-ClassifierModel -PreferCloud:(-not $PreferLocal)
        
        # Fallback to pattern-based if no classifier
        if (-not $classifier) {
            Write-Host "[TaskClassifier] Using offline pattern classification" -ForegroundColor Yellow
            return Get-PatternBasedClassification -Prompt $Prompt -ForQueue:$ForQueue
        }
        
        $isLocal = $classifier.IsLocal
        $providerLabel = if ($isLocal) { "LOCAL" } else { "CLOUD" }
        Write-Host "[TaskClassifier] Using $providerLabel $($classifier.Provider)/$($classifier.Model)" -ForegroundColor $(if ($isLocal) { "Green" } else { "Cyan" })
        
        try {
            $messages = @(
                @{ role = "system"; content = $systemPrompt }
                @{ role = "user"; content = "Classify: $Prompt" }
            )
            
            $response = Invoke-AIRequest `
                -Provider $classifier.Provider `
                -Model $classifier.Model `
                -Messages $messages `
                -MaxTokens 300 `
                -Temperature 0.1 `
                -NoOptimize `
                -ErrorAction Stop
            
            if ($response -and $response.content) {
                $jsonMatch = [regex]::Match($response.content, '\{[\s\S]*\}')
                if ($jsonMatch.Success) {
                    $parsed = $jsonMatch.Value | ConvertFrom-Json
                    
                    $result = @{
                        Category = $parsed.category
                        Complexity = [int]$parsed.complexity
                        Tier = $parsed.tier
                        LocalSuitable = [bool]$parsed.local_suitable
                        ParallelSafe = [bool]$parsed.parallel_safe
                        EstimatedTokens = [int]$parsed.estimated_tokens
                        Reasoning = $parsed.reasoning
                        ClassifierModel = "$($classifier.Provider)/$($classifier.Model)"
                        IsLocalClassifier = $isLocal
                        ClassifiedAt = Get-Date
                        FromCache = $false
                    }
                    
                    # Add queue metadata
                    if ($ForQueue) {
                        $result.QueuePriority = switch ($result.Complexity) {
                            { $_ -ge 8 } { 1 }  # High priority
                            { $_ -ge 5 } { 2 }  # Normal
                            default { 3 }       # Low
                        }
                        $result.PreferredProvider = if ($result.LocalSuitable) { "ollama" } else { "cloud" }
                    }
                    
                    # Cache
                    if ($UseCache) {
                        $script:ClassificationCache[$promptHash] = @{
                            Result = $result
                            Timestamp = Get-Date
                        }
                    }
                    
                    Write-Host "[TaskClassifier] $($result.Category) | Complexity: $($result.Complexity)/10 | Tier: $($result.Tier) | Local: $($result.LocalSuitable)" -ForegroundColor Green
                    return $result
                }
            }
            
            Write-Warning "[TaskClassifier] Failed to parse response, using pattern fallback"
            return Get-PatternBasedClassification -Prompt $Prompt -ForQueue:$ForQueue
            
        } catch {
            Write-Warning "[TaskClassifier] Error: $($_.Exception.Message)"
            return Get-PatternBasedClassification -Prompt $Prompt -ForQueue:$ForQueue
        }
    }
}

function Get-PatternBasedClassification {
    <#
    .SYNOPSIS
        Offline pattern-based classification fallback
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Prompt,
        [switch]$ForQueue
    )
    
    $promptLower = $Prompt.ToLower()
    $length = $Prompt.Length
    
    # Pattern definitions with local suitability
    $patterns = @{
        code = @{
            keywords = @('write', 'implement', 'function', 'code', 'script', 'debug', 'fix', 'class', 'api')
            tier = "standard"; complexity = 5; localSuitable = $true; parallelSafe = $true
        }
        analysis = @{
            keywords = @('analyze', 'compare', 'evaluate', 'explain', 'why', 'how does', 'research')
            tier = "standard"; complexity = 6; localSuitable = $true; parallelSafe = $true
        }
        creative = @{
            keywords = @('write story', 'brainstorm', 'imagine', 'create', 'design', 'invent')
            tier = "pro"; complexity = 7; localSuitable = $false; parallelSafe = $true
        }
        complex = @{
            keywords = @('architect', 'design system', 'plan', 'strategy', 'migrate', 'refactor')
            tier = "pro"; complexity = 8; localSuitable = $false; parallelSafe = $false
        }
        data = @{
            keywords = @('csv', 'json', 'data', 'parse', 'sql', 'query', 'database', 'extract')
            tier = "standard"; complexity = 5; localSuitable = $true; parallelSafe = $true
        }
        simple = @{
            keywords = @('what is', 'who is', 'when', 'where', 'translate', 'list', 'define')
            tier = "lite"; complexity = 2; localSuitable = $true; parallelSafe = $true
        }
    }
    
    $matched = "simple"
    $config = $patterns.simple
    
    foreach ($cat in $patterns.Keys) {
        foreach ($kw in $patterns[$cat].keywords) {
            if ($promptLower -match [regex]::Escape($kw)) {
                $matched = $cat
                $config = $patterns[$cat]
                break
            }
        }
        if ($matched -ne "simple") { break }
    }
    
    # Adjust for length
    $complexity = $config.complexity
    if ($length -gt 1000) { $complexity = [Math]::Min(10, $complexity + 1) }
    if ($length -gt 2000) { $complexity = [Math]::Min(10, $complexity + 1) }
    
    $result = @{
        Category = $matched
        Complexity = $complexity
        Tier = $config.tier
        LocalSuitable = $config.localSuitable
        ParallelSafe = $config.parallelSafe
        EstimatedTokens = [int]($length / 4)
        Reasoning = "Pattern-based (offline)"
        ClassifierModel = "pattern-matcher"
        IsLocalClassifier = $true
        ClassifiedAt = Get-Date
        FromCache = $false
    }
    
    if ($ForQueue) {
        $result.QueuePriority = switch ($complexity) {
            { $_ -ge 8 } { 1 }
            { $_ -ge 5 } { 2 }
            default { 3 }
        }
        $result.PreferredProvider = if ($config.localSuitable) { "ollama" } else { "cloud" }
    }
    
    return $result
}

#endregion

#region Model Selection

function Get-OptimalExecutionModel {
    <#
    .SYNOPSIS
        Selects optimal execution model based on classification - LOCAL FIRST
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [hashtable]$Classification,
        
        [switch]$PreferLocal = $true,
        [switch]$PreferCheapest
    )
    
    # Support both Tier and RecommendedTier keys
    $tier = if ($Classification.Tier) { $Classification.Tier }
            elseif ($Classification.RecommendedTier) { $Classification.RecommendedTier }
            else { "standard" }

    # Default LocalSuitable based on complexity
    $localSuitable = if ($null -ne $Classification.LocalSuitable) { $Classification.LocalSuitable }
                     elseif ($Classification.Complexity -and $Classification.Complexity -le 7) { $true }
                     else { $true }

    # Validate tier exists in config
    if (-not $script:ClassifierConfig.ExecutionModels.ContainsKey($tier)) {
        $tier = "standard"  # Default fallback
    }
    $tierConfig = $script:ClassifierConfig.ExecutionModels[$tier]
    
    # Try local first if suitable and preferred
    if ($PreferLocal -and $localSuitable) {
        $localModel = Get-AvailableLocalModel -PreferredModels $tierConfig.local
        if ($localModel) {
            return @{
                Provider = "ollama"
                Model = $localModel
                IsLocal = $true
                Tier = $tier
                Cost = 0
            }
        }
    }
    
    # Fall back to cloud
    if (Test-NetworkConnectivity) {
        foreach ($cloudModel in $tierConfig.cloud) {
            # Check if we have API key for this model
            $provider = if ($cloudModel -match 'claude') { "anthropic" }
                       elseif ($cloudModel -match 'gpt') { "openai" }
                       else { continue }
            
            $keyVar = if ($provider -eq "anthropic") { "ANTHROPIC_API_KEY" } else { "OPENAI_API_KEY" }
            if ([Environment]::GetEnvironmentVariable($keyVar)) {
                return @{
                    Provider = $provider
                    Model = $cloudModel
                    IsLocal = $false
                    Tier = $tier
                    Cost = 0.001  # Placeholder
                }
            }
        }
    }
    
    # Last resort: any local model
    $anyLocal = Get-AvailableLocalModel -PreferredModels @("llama3.2:1b", "phi3:mini")
    if ($anyLocal) {
        return @{
            Provider = "ollama"
            Model = $anyLocal
            IsLocal = $true
            Tier = "lite"
            Cost = 0
        }
    }
    
    Write-Warning "[TaskClassifier] No models available"
    return $null
}

#endregion

#region Cache Management

function Clear-ClassificationCache {
    [CmdletBinding()]
    param()
    $count = $script:ClassificationCache.Count
    $script:ClassificationCache.Clear()
    Write-Host "[TaskClassifier] Cleared $count cached classifications" -ForegroundColor Yellow
}

function Get-ClassificationStats {
    [CmdletBinding()]
    param()
    
    $now = Get-Date
    $valid = 0; $expired = 0
    
    foreach ($key in $script:ClassificationCache.Keys) {
        $age = ($now - $script:ClassificationCache[$key].Timestamp).TotalSeconds
        if ($age -lt $script:ClassifierConfig.CacheTTLSeconds) { $valid++ } else { $expired++ }
    }
    
    $status = Get-ConnectionStatus
    
    return @{
        TotalCached = $script:ClassificationCache.Count
        ValidEntries = $valid
        ExpiredEntries = $expired
        CacheTTLSeconds = $script:ClassifierConfig.CacheTTLSeconds
        ConnectionStatus = $status.Mode
        OllamaAvailable = $status.OllamaAvailable
        OllamaModels = $status.OllamaModels
        InternetAvailable = $status.InternetAvailable
    }
}

#endregion

Export-ModuleMember -Function @(
    'Invoke-TaskClassification',
    'Get-ClassifierModel',
    'Get-PatternBasedClassification',
    'Get-OptimalExecutionModel',
    'Get-ConnectionStatus',
    'Test-OllamaAvailability',
    'Test-NetworkConnectivity',
    'Get-AvailableLocalModel',
    'Clear-ClassificationCache',
    'Get-ClassificationStats'
)

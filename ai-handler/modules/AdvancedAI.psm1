#Requires -Version 5.1
<#
.SYNOPSIS
    Advanced AI Module - Unified Interface for Self-Correction, Few-Shot, and Speculation
.DESCRIPTION
    Master module that combines all advanced AI capabilities:
    1. Agentic Self-Correction - Automatic code validation and regeneration
    2. Dynamic Few-Shot Learning - Context-aware learning from history
    3. Speculative Decoding - Parallel multi-model generation

    Use this module for the most advanced AI generation capabilities.
.VERSION
    1.1.0
.AUTHOR
    HYDRA System
#>

$script:ModulePath = Split-Path -Parent $PSScriptRoot

#region Utility Module Imports

# Import health utilities (Test-OllamaAvailable, Get-SystemMetrics)
$healthUtilPath = Join-Path $script:ModulePath "utils\AIUtil-Health.psm1"
if (Test-Path $healthUtilPath) {
    Import-Module $healthUtilPath -Force -DisableNameChecking -ErrorAction SilentlyContinue
}

# Import Ollama provider (Get-OllamaModels)
$ollamaProviderPath = Join-Path $script:ModulePath "providers\OllamaProvider.psm1"
if (Test-Path $ollamaProviderPath) {
    Import-Module $ollamaProviderPath -Force -DisableNameChecking -ErrorAction SilentlyContinue
}

#endregion

#region Module Loading

function Initialize-AdvancedAI {
    <#
    .SYNOPSIS
        Initialize all advanced AI modules
    #>
    [CmdletBinding()]
    param()

    $modulesPath = Join-Path $script:ModulePath "modules"
    $utilsPath = Join-Path $script:ModulePath "utils"
    $providersPath = Join-Path $script:ModulePath "providers"

    # Load utility modules first (health checks, etc.)
    $utilModules = @(
        @{ Path = (Join-Path $utilsPath "AIUtil-Health.psm1"); Name = "AIUtil-Health" }
    )

    foreach ($util in $utilModules) {
        if (Test-Path $util.Path) {
            Import-Module $util.Path -Force -Global -DisableNameChecking
            Write-Host "[AdvancedAI] Loaded utility: $($util.Name)" -ForegroundColor DarkGray
        }
    }

    # Load provider modules (Ollama, etc.)
    $providerModules = @(
        @{ Path = (Join-Path $providersPath "OllamaProvider.psm1"); Name = "OllamaProvider" }
    )

    foreach ($provider in $providerModules) {
        if (Test-Path $provider.Path) {
            Import-Module $provider.Path -Force -Global -DisableNameChecking
            Write-Host "[AdvancedAI] Loaded provider: $($provider.Name)" -ForegroundColor DarkGray
        }
    }

    # Load all submodules (order matters - no dependencies first)
    $modules = @(
        "SelfCorrection.psm1",
        "FewShotLearning.psm1",
        "SpeculativeDecoding.psm1",
        "LoadBalancer.psm1",
        "SemanticFileMapping.psm1"
    )

    foreach ($module in $modules) {
        $path = Join-Path $modulesPath $module
        if (Test-Path $path) {
            Import-Module $path -Force -Global -DisableNameChecking
            Write-Host "[AdvancedAI] Loaded: $module" -ForegroundColor Gray
        } else {
            Write-Warning "[AdvancedAI] Module not found: $module"
        }
    }

    # Load main AI handler
    $mainModule = Join-Path $script:ModulePath "AIModelHandler.psm1"
    if (Test-Path $mainModule) {
        Import-Module $mainModule -Force -Global -DisableNameChecking
    }

    # Initialize few-shot cache
    try {
        Initialize-FewShotCache
    } catch {
        Write-Warning "[AdvancedAI] Could not initialize cache: $($_.Exception.Message)"
    }

    Write-Host "[AdvancedAI] All modules initialized" -ForegroundColor Green
}

#endregion

#region Unified Pipeline

function Invoke-AdvancedAI {
    <#
    .SYNOPSIS
        Unified advanced AI generation with all features
    .DESCRIPTION
        Combines self-correction, few-shot learning, and speculative decoding
        into a single powerful generation pipeline.

    .PARAMETER Prompt
        User prompt
    .PARAMETER Mode
        Generation mode:
        - "auto": Automatically select best approach
        - "code": Code generation with self-correction
        - "analysis": Thorough analysis with speculation
        - "fast": Speed-optimized with racing
        - "consensus": Multi-model consensus
        - "fewshot": Few-shot enhanced generation

    .PARAMETER Model
        Specific model to use (optional)
    .PARAMETER MaxTokens
        Maximum output tokens
    .PARAMETER SaveSuccess
        Save successful responses to few-shot history
    .PARAMETER Verbose
        Show detailed progress

    .EXAMPLE
        Invoke-AdvancedAI "Write a Python function to sort a list" -Mode code

    .EXAMPLE
        Invoke-AdvancedAI "Explain async/await in JavaScript" -Mode analysis
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position = 0)]
        [string]$Prompt,

        [ValidateSet("auto", "code", "analysis", "fast", "consensus", "fewshot")]
        [string]$Mode = "auto",

        [string]$Model,

        [int]$MaxTokens = 2048,

        [switch]$SaveSuccess,

        [string]$SystemPrompt
    )

    # Initialize if needed
    $selfCorrectionLoaded = Get-Module SelfCorrection
    if (-not $selfCorrectionLoaded) {
        Initialize-AdvancedAI
    }

    Write-Host "`n=== Advanced AI Generation ===" -ForegroundColor Cyan
    Write-Host "Mode: $Mode | MaxTokens: $MaxTokens" -ForegroundColor Gray

    $startTime = Get-Date
    $result = $null

    # Auto-detect mode if "auto"
    if ($Mode -eq "auto") {
        $Mode = Get-OptimalMode -Prompt $Prompt
        Write-Host "[Auto] Selected mode: $Mode" -ForegroundColor Yellow
    }

    try {
        switch ($Mode) {
            "code" {
                # Code generation with self-correction
                Write-Host "[Mode: Code] Using self-correction pipeline..." -ForegroundColor Cyan

                # Get few-shot examples
                $examples = Get-SuccessfulExamples -Query $Prompt -MaxExamples 2

                if ($examples.Count -gt 0) {
                    $enhanced = New-FewShotPrompt -UserPrompt $Prompt -Examples $examples
                    $effectivePrompt = $enhanced.prompt
                    Write-Host "[FewShot] Added $($examples.Count) example(s)" -ForegroundColor Gray
                } else {
                    $effectivePrompt = $Prompt
                }

                $codeResult = Invoke-CodeWithSelfCorrection `
                    -Prompt $effectivePrompt `
                    -Model $(if ($Model) { $Model } else { "qwen2.5-coder:1.5b" }) `
                    -MaxAttempts 3 `
                    -SystemPrompt $SystemPrompt `
                    -MaxTokens $MaxTokens

                $result = @{
                    Content = $codeResult.Code
                    Mode = "code"
                    Valid = $codeResult.Valid
                    Attempts = $codeResult.Attempts
                    Language = $codeResult.Language
                    FewShotExamples = $examples.Count
                }
            }

            "analysis" {
                # Analysis with speculative decoding
                Write-Host "[Mode: Analysis] Using speculative decoding..." -ForegroundColor Cyan

                $specResult = Invoke-AnalysisSpeculation `
                    -Prompt $Prompt `
                    -MaxTokens $MaxTokens

                $result = @{
                    Content = $specResult.Content
                    Mode = "analysis"
                    Model = $specResult.Model
                    SelectionReason = $specResult.SelectionReason
                }
            }

            "fast" {
                # Speed-optimized with model racing
                Write-Host "[Mode: Fast] Racing models..." -ForegroundColor Cyan

                $raceResult = Invoke-ModelRace `
                    -Prompt $Prompt `
                    -Models @("llama3.2:1b", "phi3:mini") `
                    -SystemPrompt $SystemPrompt `
                    -MaxTokens $MaxTokens `
                    -TimeoutMs 15000

                $result = @{
                    Content = $raceResult.Content
                    Mode = "fast"
                    Model = $raceResult.Model
                    WinnerTime = $raceResult.ElapsedSeconds
                }
            }

            "consensus" {
                # Multi-model consensus
                Write-Host "[Mode: Consensus] Generating with multiple models..." -ForegroundColor Cyan

                $consensusResult = Invoke-ConsensusGeneration `
                    -Prompt $Prompt `
                    -Models @("llama3.2:3b", "qwen2.5-coder:1.5b", "phi3:mini") `
                    -SystemPrompt $SystemPrompt `
                    -MaxTokens $MaxTokens

                $result = @{
                    Content = $consensusResult.Content
                    Mode = "consensus"
                    HasConsensus = $consensusResult.Consensus
                    Similarity = $consensusResult.Similarity
                    AllResponses = $consensusResult.AllResponses
                }
            }

            "fewshot" {
                # Few-shot enhanced generation
                Write-Host "[Mode: FewShot] Using historical examples..." -ForegroundColor Cyan

                $fewshotResult = Invoke-AIWithFewShot `
                    -Prompt $Prompt `
                    -Model $(if ($Model) { $Model } else { "llama3.2:3b" }) `
                    -SystemPrompt $SystemPrompt `
                    -MaxTokens $MaxTokens

                $result = @{
                    Content = $fewshotResult.Content
                    Mode = "fewshot"
                    ExamplesUsed = $fewshotResult.ExamplesUsed
                    Model = $fewshotResult.Model
                }
            }
        }

    } catch {
        Write-Error "[AdvancedAI] Generation failed: $($_.Exception.Message)"
        return @{
            Content = $null
            Error = $_.Exception.Message
            Mode = $Mode
        }
    }

    $elapsed = ((Get-Date) - $startTime).TotalSeconds
    $result.ElapsedSeconds = $elapsed

    # Save to history if requested
    if ($SaveSuccess -and $result.Content) {
        $historyId = Save-SuccessfulResponse -Prompt $Prompt -Response $result.Content -Rating 4
        $result.HistoryId = $historyId
        Write-Host "[FewShot] Saved to history (ID: $historyId)" -ForegroundColor Green
    }

    Write-Host "`n=== Generation Complete ===" -ForegroundColor Cyan
    Write-Host "Mode: $Mode | Time: $([math]::Round($elapsed, 2))s" -ForegroundColor Gray

    return $result
}

function Get-OptimalMode {
    <#
    .SYNOPSIS
        Auto-detect optimal generation mode based on prompt
    #>
    param([string]$Prompt)

    $promptLower = $Prompt.ToLower()

    # Code patterns
    $codePatterns = @(
        "write.*function", "write.*code", "create.*class",
        "implement", "fix.*bug", "debug",
        "in python", "in javascript", "in powershell", "in rust",
        "sql query", "regex"
    )

    foreach ($pattern in $codePatterns) {
        if ($promptLower -match $pattern) {
            return "code"
        }
    }

    # Analysis patterns
    $analysisPatterns = @(
        "explain", "analyze", "compare", "what is",
        "how does", "why", "describe", "review"
    )

    foreach ($pattern in $analysisPatterns) {
        if ($promptLower -match $pattern) {
            return "analysis"
        }
    }

    # Fast patterns (simple questions)
    $fastPatterns = @(
        "^what is", "^who is", "^when", "^where",
        "quick", "simple", "short answer"
    )

    foreach ($pattern in $fastPatterns) {
        if ($promptLower -match $pattern) {
            return "fast"
        }
    }

    # Default to fewshot for general queries
    return "fewshot"
}

#endregion

#region Convenience Functions

function New-AICode {
    <#
    .SYNOPSIS
        Quick code generation with self-correction
    .EXAMPLE
        New-AICode "Python function to download a file from URL"
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position = 0)]
        [string]$Description,

        [string]$Language,

        [switch]$Save
    )

    $prompt = $Description
    if ($Language) {
        $prompt = "Write $Language code: $Description"
    }

    $result = Invoke-AdvancedAI -Prompt $prompt -Mode "code" -SaveSuccess:$Save

    if ($result.Content) {
        Write-Host "`n--- Generated Code ---" -ForegroundColor Cyan
        Write-Host $result.Content
        Write-Host "----------------------" -ForegroundColor Cyan
        Write-Host "Language: $($result.Language) | Valid: $($result.Valid) | Attempts: $($result.Attempts)" -ForegroundColor Gray
    }

    return $result
}

function Get-AIAnalysis {
    <#
    .SYNOPSIS
        Quick analysis with speculative decoding
    .EXAMPLE
        Get-AIAnalysis "Compare REST vs GraphQL for mobile apps"
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position = 0)]
        [string]$Topic,

        [switch]$Consensus
    )

    $mode = if ($Consensus) { "consensus" } else { "analysis" }
    $result = Invoke-AdvancedAI -Prompt $Topic -Mode $mode

    if ($result.Content) {
        Write-Host "`n$($result.Content)" -ForegroundColor White
    }

    return $result
}

function Get-AIQuick {
    <#
    .SYNOPSIS
        Fastest possible AI response using model racing
    .EXAMPLE
        Get-AIQuick "What is the capital of Poland?"
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position = 0)]
        [string]$Question
    )

    $result = Invoke-AdvancedAI -Prompt $Question -Mode "fast"

    if ($result.Content) {
        Write-Host $result.Content
        Write-Host "`n[Fast: $($result.Model) in $([math]::Round($result.WinnerTime, 2))s]" -ForegroundColor Gray
    }

    return $result
}

#endregion

#region Status and Info

function Get-AdvancedAIStatus {
    <#
    .SYNOPSIS
        Get status of all advanced AI modules
    .DESCRIPTION
        Uses utility modules for health checks:
        - Test-OllamaAvailable from AIUtil-Health.psm1
        - Get-SystemMetrics from AIUtil-Health.psm1
        - Get-OllamaModels from OllamaProvider.psm1
    #>
    [CmdletBinding()]
    param()

    Write-Host "`n=== Advanced AI Status ===" -ForegroundColor Cyan

    # Check Ollama using utility module (with caching)
    $ollamaCheck = $null
    $ollamaRunning = $false
    try {
        # Use Test-OllamaAvailable from AIUtil-Health
        $ollamaCheck = Test-OllamaAvailable -IncludeModels
        $ollamaRunning = $ollamaCheck.Available
    } catch {
        # Fallback if utility module not loaded
        try {
            $request = [System.Net.WebRequest]::Create("http://localhost:11434/api/tags")
            $request.Method = "GET"
            $request.Timeout = 3000
            $response = $request.GetResponse()
            $response.Close()
            $ollamaRunning = $true
        } catch {
            $ollamaRunning = $false
        }
    }

    # Check module status
    $modules = @{
        "SelfCorrection" = $null
        "FewShotLearning" = $null
        "SpeculativeDecoding" = $null
        "LoadBalancer" = $null
        "SemanticFileMapping" = $null
        "AIModelHandler" = $null
    }

    foreach ($moduleName in $modules.Keys) {
        $loaded = Get-Module $moduleName
        $status = if ($loaded) { "[OK]" } else { "[NOT LOADED]" }
        $color = if ($loaded) { "Green" } else { "Yellow" }
        Write-Host "  $moduleName $status" -ForegroundColor $color
    }

    # Few-shot stats
    Write-Host "`n--- Few-Shot Learning ---" -ForegroundColor Cyan
    try {
        $stats = Get-FewShotStats
        Write-Host "  Total Examples: $($stats.TotalEntries)"
        Write-Host "  Categories: $($stats.Categories.Keys -join ', ')"
        Write-Host "  Total Uses: $($stats.TotalUses)"
        Write-Host "  Avg Rating: $($stats.AverageRating)"
    } catch {
        Write-Host "  [Not initialized]" -ForegroundColor Gray
    }

    # System load - use Get-SystemMetrics from AIUtil-Health
    Write-Host "`n--- System Load ---" -ForegroundColor Cyan
    $systemMetrics = $null
    try {
        # Try AIUtil-Health's Get-SystemMetrics first
        $systemMetrics = Get-SystemMetrics
        Write-Host "  CPU: $($systemMetrics.CpuPercent)%"
        Write-Host "  Memory: $($systemMetrics.MemoryPercent)%"
        Write-Host "  Available Memory: $($systemMetrics.MemoryAvailableGB) GB"
        Write-Host "  Recommendation: $($systemMetrics.Recommendation)"
        if ($systemMetrics.Cached) {
            Write-Host "  (cached: $($systemMetrics.CacheAgeSeconds)s ago)" -ForegroundColor DarkGray
        }
    } catch {
        # Fallback to LoadBalancer's Get-SystemLoad if available
        try {
            $load = Get-SystemLoad
            Write-Host "  CPU: $($load.CpuPercent)%"
            Write-Host "  Memory: $($load.MemoryPercent)%"
            Write-Host "  Recommendation: $($load.Recommendation)"
            $systemMetrics = $load
        } catch {
            Write-Host "  [System metrics not available]" -ForegroundColor Gray
            $systemMetrics = @{CpuPercent=0; MemoryPercent=0; Recommendation="unknown"}
        }
    }

    # Ollama status - use Get-OllamaModels from OllamaProvider
    Write-Host "`n--- Local Models (Ollama) ---" -ForegroundColor Cyan
    if ($ollamaRunning) {
        try {
            # Try using OllamaProvider's Get-OllamaModels
            $models = Get-OllamaModels
            if ($models -and $models.Count -gt 0) {
                foreach ($m in $models) {
                    Write-Host "  $($m.Name) ($($m.Size) GB)" -ForegroundColor Green
                }
            } elseif ($ollamaCheck -and $ollamaCheck.Models) {
                # Use cached models from health check
                foreach ($modelName in $ollamaCheck.Models) {
                    Write-Host "  $modelName" -ForegroundColor Green
                }
            } else {
                Write-Host "  [No models installed]" -ForegroundColor Yellow
            }
        } catch {
            Write-Host "  [Ollama running but models unknown]" -ForegroundColor Yellow
        }
    } else {
        Write-Host "  [Ollama not running]" -ForegroundColor Yellow
    }

    Write-Host ""

    # Return status object
    return @{
        OllamaRunning = $ollamaRunning
        OllamaResponseTimeMs = if ($ollamaCheck) { $ollamaCheck.ResponseTimeMs } else { $null }
        SelfCorrectionEnabled = (Get-Module SelfCorrection) -ne $null
        FewShotEnabled = (Get-Module FewShotLearning) -ne $null
        SpeculativeEnabled = (Get-Module SpeculativeDecoding) -ne $null
        LoadBalancerEnabled = (Get-Module LoadBalancer) -ne $null
        SemanticMappingEnabled = (Get-Module SemanticFileMapping) -ne $null
        SystemMetrics = $systemMetrics
    }
}

#endregion

#region Exports

Export-ModuleMember -Function @(
    'Initialize-AdvancedAI',
    'Invoke-AdvancedAI',
    'Get-OptimalMode',
    'New-AICode',
    'Get-AIAnalysis',
    'Get-AIQuick',
    'Get-AdvancedAIStatus'
)

#endregion

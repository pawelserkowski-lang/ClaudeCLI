#Requires -Version 5.1
<#
.SYNOPSIS
    Initialize Advanced AI Modules for ClaudeCLI
.DESCRIPTION
    Loads and initializes all advanced AI capabilities using the AIFacade system:
    - Agentic Self-Correction
    - Dynamic Few-Shot Learning
    - Speculative Decoding
    - Load Balancing
    - Semantic File Mapping (RAG)
    - Prompt Optimizer
    - Task Classifier
    - Smart Queue
    - Model Discovery
    - Semantic Git Commit
    - AI Code Review
    - Predictive Autocomplete

    Uses AIFacade.psm1 for dependency injection and phased module loading.
.EXAMPLE
    . .\Initialize-AdvancedAI.ps1
.EXAMPLE
    . "C:\Users\BIURODOM\Desktop\ClaudeCLI\ai-handler\Initialize-AdvancedAI.ps1"
#>

$ErrorActionPreference = "Stop"

$script:AIHandlerPath = $PSScriptRoot

Write-Host @"

    _       _                               _      _    ___
   / \   __| |_   ____ _ _ __   ___ ___  __| |    / \  |_ _|
  / _ \ / _`| \ \ / / _`| | '_ \ / __/ _ \/ _`| |   / _ \  | |
 / ___ \ (_| |\ V / (_| | | | | (_|  __/ (_| |  / ___ \ | |
/_/   \_\__,_| \_/ \__,_|_| |_|\___\___|\__,_| /_/   \_\___|

        HYDRA Advanced AI System v3.0
        Modular Architecture with AIFacade

"@ -ForegroundColor Cyan

# ============================================================================
# LOAD AI FACADE (Single Entry Point)
# ============================================================================

Write-Host "[Init] Loading AIFacade..." -ForegroundColor Gray
$facadeModule = Join-Path $script:AIHandlerPath "AIFacade.psm1"

if (Test-Path $facadeModule) {
    try {
        Import-Module $facadeModule -Force -Global -ErrorAction Stop
        Write-Host "[OK] AIFacade loaded" -ForegroundColor Green
    }
    catch {
        Write-Error "Failed to load AIFacade.psm1: $($_.Exception.Message)"
        return
    }
}
else {
    Write-Error "AIFacade.psm1 not found at $facadeModule"
    return
}

# ============================================================================
# INITIALIZE AI SYSTEM (Phased Module Loading)
# ============================================================================

Write-Host "`n[Init] Initializing AI System (5-phase loading)..." -ForegroundColor Gray

$initResult = Initialize-AISystem -Force

if ($initResult.Status -eq "Initialized") {
    Write-Host "[OK] AI System initialized in $([math]::Round($initResult.Duration, 2))s" -ForegroundColor Green
    Write-Host "[OK] Loaded $($initResult.TotalLoaded) modules" -ForegroundColor Green

    if ($initResult.TotalFailed -gt 0) {
        Write-Host "[WARN] $($initResult.TotalFailed) modules failed to load" -ForegroundColor Yellow
        foreach ($failed in $initResult.FailedModules) {
            Write-Host "       - $($failed.Name): $($failed.Error)" -ForegroundColor Yellow
        }
    }
}
else {
    Write-Warning "AI System initialization returned status: $($initResult.Status)"
}

# ============================================================================
# CHECK OLLAMA AVAILABILITY
# ============================================================================

Write-Host "`n[Init] Checking Ollama..." -ForegroundColor Gray

function Test-OllamaRunning {
    try {
        $request = [System.Net.WebRequest]::Create("http://localhost:11434/api/tags")
        $request.Method = "GET"
        $request.Timeout = 3000
        $response = $request.GetResponse()
        $response.Close()
        return $true
    }
    catch {
        return $false
    }
}

if (Test-OllamaRunning) {
    Write-Host "[OK] Ollama is running" -ForegroundColor Green

    try {
        $response = Invoke-RestMethod -Uri "http://localhost:11434/api/tags" -Method Get -ErrorAction SilentlyContinue
        if ($response.models) {
            $modelNames = $response.models | ForEach-Object { $_.name }
            Write-Host "[OK] Available models: $($modelNames -join ', ')" -ForegroundColor Green
        }
    }
    catch {
        Write-Host "[OK] Ollama running (could not list models)" -ForegroundColor Green
    }
}
else {
    Write-Host "[WARN] Ollama is not running. Starting..." -ForegroundColor Yellow
    $ollamaExe = "$env:LOCALAPPDATA\Programs\Ollama\ollama.exe"
    if (Test-Path $ollamaExe) {
        Start-Process -FilePath $ollamaExe -ArgumentList "serve" -WindowStyle Hidden
        Start-Sleep -Seconds 3
        if (Test-OllamaRunning) {
            Write-Host "[OK] Ollama started successfully" -ForegroundColor Green
        }
    }
    else {
        Write-Host "[INFO] Ollama not installed. Run Install-Ollama.ps1 to install." -ForegroundColor Yellow
    }
}

# ============================================================================
# INITIALIZE CACHE DIRECTORY
# ============================================================================

Write-Host "`n[Init] Initializing Few-Shot cache..." -ForegroundColor Gray
$cachePath = Join-Path $script:AIHandlerPath "cache"
if (-not (Test-Path $cachePath)) {
    New-Item -ItemType Directory -Path $cachePath -Force | Out-Null
}
Write-Host "[OK] Cache ready at $cachePath" -ForegroundColor Green

# ============================================================================
# DISPLAY SYSTEM STATUS
# ============================================================================

Write-Host "`n[Init] Getting system status..." -ForegroundColor Gray
$status = Get-AISystemStatus -Detailed -CheckProviders

# Display provider status
Write-Host "`n=== Provider Status ===" -ForegroundColor Cyan
if ($status.ProviderStatus) {
    foreach ($provider in $status.ProviderStatus.Keys) {
        $providerInfo = $status.ProviderStatus[$provider]
        if ($providerInfo.Available) {
            Write-Host "  [OK] $provider" -ForegroundColor Green -NoNewline
            if ($providerInfo.Models) {
                Write-Host " ($($providerInfo.Models.Count) models)" -ForegroundColor Gray
            }
            else {
                Write-Host ""
            }
        }
        else {
            Write-Host "  [--] $provider" -ForegroundColor Yellow -NoNewline
            if ($providerInfo.Error) {
                Write-Host " (not running)" -ForegroundColor Yellow
            }
            elseif (-not $providerInfo.KeySet) {
                Write-Host " (no API key)" -ForegroundColor Yellow
            }
            else {
                Write-Host ""
            }
        }
    }
}

# Display module categories
Write-Host "`n=== Loaded Modules by Category ===" -ForegroundColor Cyan
foreach ($category in $status.Categories.Keys | Sort-Object) {
    $count = $status.Categories[$category]
    if ($count -gt 0) {
        Write-Host "  $category`: $count functions" -ForegroundColor Gray
    }
}

# ============================================================================
# HELP TEXT
# ============================================================================

Write-Host @"

=== Advanced AI Ready ===

Unified Interface (via AIFacade):
  Invoke-AI              - Single entry point for all AI requests
  Initialize-AISystem    - Load all modules (already done)
  Get-AISystemStatus     - Check system status
  Get-AIDependencies     - Access dependency container
  Reset-AISystem         - Reset and reinitialize

Advanced AI Functions:
  Invoke-AdvancedAI      - Unified AI generation with all features
  New-AICode             - Quick code generation with self-correction
  Get-AIAnalysis         - Analysis with speculative decoding
  Get-AIQuick            - Fastest response using model racing
  Get-AdvancedAIStatus   - Check advanced module status

Self-Correction:
  Invoke-SelfCorrection       - Validate code
  Invoke-CodeWithSelfCorrection - Generate code with auto-fix

Few-Shot Learning:
  Get-SuccessfulExamples      - Get relevant examples
  Save-SuccessfulResponse     - Save successful response
  Get-FewShotStats            - View cache statistics

Speculative Decoding:
  Invoke-SpeculativeDecoding  - Parallel multi-model generation
  Invoke-CodeSpeculation      - Code-optimized speculation
  Invoke-ModelRace            - Race models for speed
  Invoke-ConsensusGeneration  - Multi-model consensus

Load Balancing:
  Get-LoadBalancedProvider    - Auto-select provider based on CPU
  Invoke-LoadBalancedBatch    - CPU-aware batch processing
  Get-LoadBalancerStatus      - View load and thresholds
  Watch-SystemLoad            - Monitor CPU/memory in real-time

Semantic File Mapping:
  Get-RelatedFiles            - Find files related by imports
  New-DependencyGraph         - Create project dependency graph
  Get-ExpandedContext         - Get AI context with related files
  Invoke-SemanticQuery        - Query about file with full context
  Get-ProjectStructure        - Analyze project structure

Prompt Optimization:
  Optimize-Prompt             - Analyze and enhance prompts
  Get-BetterPrompt            - Quick one-liner enhancement
  Test-PromptQuality          - Visual quality report

Examples:
  Invoke-AI "Explain async/await" -Mode auto
  Invoke-AI "Write Python sort function" -Mode code
  Invoke-AI "2+2?" -Mode fast
  Invoke-LoadBalancedBatch -Prompts @("Q1","Q2","Q3") -AdaptiveBalancing
  Invoke-SemanticQuery -FilePath "app.py" -Query "How does auth work?" -IncludeRelated

"@ -ForegroundColor White

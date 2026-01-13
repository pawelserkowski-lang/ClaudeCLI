<#
.SYNOPSIS
    Test script for Smart Classification system
.DESCRIPTION
    Tests TaskClassifier and SmartQueue modules
#>

$ErrorActionPreference = "Stop"
$script:ModulePath = $PSScriptRoot

# Import modules in correct order (TaskClassifier last to ensure exports)
Write-Host "`n=== Loading Modules ===" -ForegroundColor Cyan
Import-Module (Join-Path $script:ModulePath "AIModelHandler.psm1") -Force
Import-Module (Join-Path $script:ModulePath "modules\SmartQueue.psm1") -Force
# Import TaskClassifier LAST to ensure its exports are available
Import-Module (Join-Path $script:ModulePath "modules\TaskClassifier.psm1") -Force -Global
Write-Host "[OK] All modules loaded" -ForegroundColor Green

# Test 1: Network and Ollama
Write-Host "`n=== TEST 1: Connectivity ===" -ForegroundColor Cyan
$networkStatus = Test-NetworkConnectivity
$ollamaStatus = Test-OllamaAvailability
$localModel = Get-AvailableLocalModel

Write-Host "  Internet available: $networkStatus" -ForegroundColor $(if ($networkStatus) { "Green" } else { "Yellow" })
Write-Host "  Ollama available: $ollamaStatus" -ForegroundColor $(if ($ollamaStatus) { "Green" } else { "Yellow" })
Write-Host "  Best local model: $(if ($localModel) { $localModel } else { 'N/A' })" -ForegroundColor $(if ($localModel) { "Green" } else { "Yellow" })

# Test 2: Connection Status
Write-Host "`n=== TEST 2: Connection Status ===" -ForegroundColor Cyan
$connStatus = Get-ConnectionStatus
Write-Host "  LocalAvailable: $($connStatus.LocalAvailable)"
Write-Host "  InternetAvailable: $($connStatus.InternetAvailable)"
Write-Host "  Mode: $($connStatus.Mode)" -ForegroundColor Green
Write-Host "  LocalModel: $($connStatus.LocalModel)"

# Test 3: Pattern-based classification (offline fallback)
Write-Host "`n=== TEST 3: Pattern-Based Classification (Offline Fallback) ===" -ForegroundColor Cyan
$testPrompts = @(
    "Write a Python function to sort a list",
    "What is the capital of France?",
    "Explain quantum computing in simple terms",
    "Analyze this CSV data and find trends"
)

foreach ($prompt in $testPrompts) {
    $classification = Get-PatternBasedClassification -Prompt $prompt
    Write-Host "  '$($prompt.Substring(0, [Math]::Min(40, $prompt.Length)))...'" -ForegroundColor White
    Write-Host "    -> Category: $($classification.Category), Complexity: $($classification.Complexity)" -ForegroundColor Gray
}

# Test 4: AI-powered classification (if local model available)
Write-Host "`n=== TEST 4: AI Classification ===" -ForegroundColor Cyan
if ($ollamaStatus -and $localModel) {
    $testPrompt = "Write a PowerShell function that calculates factorial"
    Write-Host "  Testing prompt: '$testPrompt'" -ForegroundColor White

    try {
        $result = Invoke-TaskClassification -Prompt $testPrompt
        Write-Host "  [OK] Classification successful:" -ForegroundColor Green
        Write-Host "    Category: $($result.Category)"
        Write-Host "    Complexity: $($result.Complexity)/10"
        Write-Host "    Tier: $($result.RecommendedTier)"
        Write-Host "    Classifier: $($result.ClassifierModel)"
        Write-Host "    Cached: $($result.FromCache)"
    } catch {
        Write-Host "  [FAIL] Classification error: $_" -ForegroundColor Red
    }
} else {
    Write-Host "  [SKIP] No local model available for AI classification" -ForegroundColor Yellow
    Write-Host "  Using pattern-based fallback instead" -ForegroundColor Yellow
}

# Test 5: Get optimal execution model
Write-Host "`n=== TEST 5: Optimal Execution Model ===" -ForegroundColor Cyan
$classification = @{
    Category = "code"
    Complexity = 5
    RecommendedTier = "standard"
}

$optimal = Get-OptimalExecutionModel -Classification $classification
if ($optimal) {
    Write-Host "  Provider: $($optimal.Provider)" -ForegroundColor Green
    Write-Host "  Model: $($optimal.Model)" -ForegroundColor Green
    Write-Host "  IsLocal: $($optimal.IsLocal)"
} else {
    Write-Host "  [WARN] No optimal model found" -ForegroundColor Yellow
}

# Test 6: SmartQueue basic operations
Write-Host "`n=== TEST 6: SmartQueue Basic Operations ===" -ForegroundColor Cyan
try {
    # Clear any existing queue
    Clear-SmartQueue

    # Add items
    $id1 = Add-ToSmartQueue -Prompt "Simple math: 2+2" -Priority "low" -SkipClassification
    $id2 = Add-ToSmartQueue -Prompt "Complex analysis task" -Priority "high" -SkipClassification

    Write-Host "  Added 2 items to queue" -ForegroundColor Green

    # Get queue status
    $status = Get-SmartQueueStatus
    Write-Host "  Queue size: $($status.QueueSize)"
    Write-Host "  Pending: $($status.Pending)"

    # Clear queue
    Clear-SmartQueue
    Write-Host "  Queue cleared" -ForegroundColor Green
} catch {
    Write-Host "  [FAIL] SmartQueue error: $_" -ForegroundColor Red
}

# Summary
Write-Host "`n=== SUMMARY ===" -ForegroundColor Cyan
Write-Host "  Local-first classification: " -NoNewline
if ($ollamaStatus) {
    Write-Host "ENABLED (using $localModel)" -ForegroundColor Green
} else {
    Write-Host "DISABLED (Ollama not running)" -ForegroundColor Yellow
}

Write-Host "  Offline fallback: ENABLED (pattern-based)" -ForegroundColor Green
Write-Host "  SmartQueue: READY" -ForegroundColor Green

Write-Host "`n[TEST COMPLETE]" -ForegroundColor Cyan

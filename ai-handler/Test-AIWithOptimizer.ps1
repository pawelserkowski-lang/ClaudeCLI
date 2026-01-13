#Requires -Version 5.1
# Test PromptOptimizer with real AI calls

$ErrorActionPreference = "Continue"

Import-Module "$PSScriptRoot\AIModelHandler.psm1" -Force

Write-Host ("=" * 60) -ForegroundColor Cyan
Write-Host "  TEST Z PRAWDZIWYM AI (Ollama)" -ForegroundColor Cyan  
Write-Host ("=" * 60) -ForegroundColor Cyan

# Check Ollama
if (-not (Test-OllamaAvailable)) {
    Write-Host "Ollama nie dziala! Uruchamiam..." -ForegroundColor Yellow
    Start-Process "ollama" -ArgumentList "serve" -WindowStyle Hidden
    Start-Sleep -Seconds 5
}

Write-Host "`n[TEST 1] BEZ optymalizacji" -ForegroundColor Yellow
Write-Host "Prompt: python sort" -ForegroundColor Gray
Write-Host "-" * 40 -ForegroundColor DarkGray
try {
    $result1 = Invoke-AIRequest -Messages @(@{role="user"; content="python sort"}) `
        -Provider "ollama" -Model "llama3.2:3b" -MaxTokens 300 -NoOptimize
    
    $preview = $result1.content
    if ($preview.Length -gt 400) { $preview = $preview.Substring(0, 400) + "..." }
    Write-Host $preview -ForegroundColor White
} catch {
    Write-Host "Error: $_" -ForegroundColor Red
}

Write-Host "`n[TEST 2] Z OPTYMALIZACJA" -ForegroundColor Yellow
Write-Host "Prompt: python sort (+ auto-enhancement)" -ForegroundColor Gray
Write-Host "-" * 40 -ForegroundColor DarkGray
try {
    $result2 = Invoke-AIRequest -Messages @(@{role="user"; content="python sort"}) `
        -Provider "ollama" -Model "llama3.2:3b" -MaxTokens 300 -OptimizePrompt -ShowOptimization
    
    $preview = $result2.content
    if ($preview.Length -gt 400) { $preview = $preview.Substring(0, 400) + "..." }
    Write-Host $preview -ForegroundColor White
    
    if ($result2._meta.promptOptimization) {
        Write-Host "`n[Optimization Metadata]" -ForegroundColor Magenta
        Write-Host "  Category: $($result2._meta.promptOptimization.category)" -ForegroundColor Gray
        Write-Host "  Clarity: $($result2._meta.promptOptimization.clarityScore)/100" -ForegroundColor Gray
        Write-Host "  Enhancements: $($result2._meta.promptOptimization.enhancements -join ', ')" -ForegroundColor Gray
    }
} catch {
    Write-Host "Error: $_" -ForegroundColor Red
}

Write-Host "`n[TEST 3] Slaby prompt z optymalizacja" -ForegroundColor Yellow
Write-Host "Prompt: fix it" -ForegroundColor Gray
Write-Host "-" * 40 -ForegroundColor DarkGray
try {
    $result3 = Invoke-AIRequest -Messages @(@{role="user"; content="fix it"}) `
        -Provider "ollama" -Model "llama3.2:3b" -MaxTokens 200 -OptimizePrompt -ShowOptimization
    
    $preview = $result3.content
    if ($preview.Length -gt 300) { $preview = $preview.Substring(0, 300) + "..." }
    Write-Host $preview -ForegroundColor White
    
    if ($result3._meta.promptOptimization) {
        Write-Host "`n[Optimization Metadata]" -ForegroundColor Magenta
        Write-Host "  Category: $($result3._meta.promptOptimization.category)" -ForegroundColor Gray
        Write-Host "  Clarity: $($result3._meta.promptOptimization.clarityScore)/100" -ForegroundColor Gray
        Write-Host "  Enhancements: $($result3._meta.promptOptimization.enhancements -join ', ')" -ForegroundColor Gray
    }
} catch {
    Write-Host "Error: $_" -ForegroundColor Red
}

Write-Host "`n" + ("=" * 60) -ForegroundColor Cyan
Write-Host "  TESTY ZAKONCZONE" -ForegroundColor Green
Write-Host ("=" * 60) -ForegroundColor Cyan

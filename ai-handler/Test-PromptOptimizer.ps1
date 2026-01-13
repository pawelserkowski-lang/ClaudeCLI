#Requires -Version 5.1
# Test script for PromptOptimizer module

$ErrorActionPreference = "Stop"

try {
    Import-Module "$PSScriptRoot\modules\PromptOptimizer.psm1" -Force
    Write-Host "Module loaded successfully!" -ForegroundColor Green
} catch {
    Write-Host "Failed to load module: $_" -ForegroundColor Red
    exit 1
}

Write-Host "`n" + ("=" * 60) -ForegroundColor Cyan
Write-Host "  PROMPT OPTIMIZER - TESTY" -ForegroundColor Cyan
Write-Host ("=" * 60) -ForegroundColor Cyan

# Test 1
Write-Host "`n[TEST 1] Bardzo krotki prompt" -ForegroundColor Yellow
$result = Optimize-Prompt -Prompt "python sort" -Detailed
Write-Host "Original: python sort" -ForegroundColor Gray
Write-Host "Category: $($result.Category)" -ForegroundColor Green
Write-Host "Clarity: $($result.ClarityScore)/100" -ForegroundColor Green
Write-Host "Language: $($result.Language)" -ForegroundColor Green
Write-Host "Enhancements: $($result.Enhancements -join ', ')" -ForegroundColor Green
Write-Host "Optimized:" -ForegroundColor White
Write-Host $result.OptimizedPrompt -ForegroundColor Cyan

# Test 2
Write-Host "`n[TEST 2] Niejasny prompt" -ForegroundColor Yellow
$result = Optimize-Prompt -Prompt "do something with the stuff" -Detailed
Write-Host "Original: do something with the stuff" -ForegroundColor Gray
Write-Host "Category: $($result.Category)" -ForegroundColor Green
Write-Host "Clarity: $($result.ClarityScore)/100" -ForegroundColor Green
Write-Host "Enhancements: $($result.Enhancements -join ', ')" -ForegroundColor Green
Write-Host "Optimized:" -ForegroundColor White
Write-Host $result.OptimizedPrompt -ForegroundColor Cyan

# Test 3
Write-Host "`n[TEST 3] Prompt analityczny" -ForegroundColor Yellow
$result = Optimize-Prompt -Prompt "compare React and Vue frameworks" -Detailed
Write-Host "Original: compare React and Vue frameworks" -ForegroundColor Gray
Write-Host "Category: $($result.Category)" -ForegroundColor Green
Write-Host "Clarity: $($result.ClarityScore)/100" -ForegroundColor Green
Write-Host "Enhancements: $($result.Enhancements -join ', ')" -ForegroundColor Green
Write-Host "Optimized:" -ForegroundColor White
Write-Host $result.OptimizedPrompt -ForegroundColor Cyan

# Test 4
Write-Host "`n[TEST 4] Pytanie" -ForegroundColor Yellow
$result = Optimize-Prompt -Prompt "what is async await?" -Detailed
Write-Host "Original: what is async await?" -ForegroundColor Gray
Write-Host "Category: $($result.Category)" -ForegroundColor Green
Write-Host "Clarity: $($result.ClarityScore)/100" -ForegroundColor Green
Write-Host "Enhancements: $($result.Enhancements -join ', ')" -ForegroundColor Green
Write-Host "Optimized:" -ForegroundColor White
Write-Host $result.OptimizedPrompt -ForegroundColor Cyan

# Test 5
Write-Host "`n[TEST 5] Kod z jezykiem" -ForegroundColor Yellow
$result = Optimize-Prompt -Prompt "write a rust function to parse json" -Detailed
Write-Host "Original: write a rust function to parse json" -ForegroundColor Gray
Write-Host "Category: $($result.Category)" -ForegroundColor Green
Write-Host "Clarity: $($result.ClarityScore)/100" -ForegroundColor Green
Write-Host "Language: $($result.Language)" -ForegroundColor Green
Write-Host "Enhancements: $($result.Enhancements -join ', ')" -ForegroundColor Green
Write-Host "Optimized:" -ForegroundColor White
Write-Host $result.OptimizedPrompt -ForegroundColor Cyan

# Test 6: Quality check
Write-Host "`n[TEST 6] Quality Check" -ForegroundColor Yellow
Test-PromptQuality -Prompt "fix it"

Write-Host "`n" + ("=" * 60) -ForegroundColor Cyan
Write-Host "  TESTY ZAKONCZONE" -ForegroundColor Green
Write-Host ("=" * 60) -ForegroundColor Cyan

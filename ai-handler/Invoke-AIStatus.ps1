#Requires -Version 5.1
<#
.SYNOPSIS
    Check AI providers status - wrapper for /ai-status command
.DESCRIPTION
    Displays status of all configured AI providers, models, and settings.
    Integrates Health dashboard and Config management.
.PARAMETER Test
    Run connectivity test for each provider
.PARAMETER Models
    Show detailed model list
.PARAMETER Health
    Show health dashboard with token usage and costs (from Invoke-AIHealth)
.PARAMETER Config
    Show current configuration (from Invoke-AIConfig)
.PARAMETER Set
    Configuration key to set (use with -Value)
.PARAMETER Value
    Value to set for the configuration key
.PARAMETER Json
    Output health data as JSON (use with -Health)
.EXAMPLE
    .\Invoke-AIStatus.ps1
.EXAMPLE
    .\Invoke-AIStatus.ps1 -Test
.EXAMPLE
    .\Invoke-AIStatus.ps1 -Health
.EXAMPLE
    .\Invoke-AIStatus.ps1 -Config
.EXAMPLE
    .\Invoke-AIStatus.ps1 -Set preferLocal -Value true
#>

param(
    [switch]$Test,
    [switch]$Models,
    [switch]$Health,
    [switch]$Config,
    [string]$Set,
    [string]$Value,
    [switch]$Json
)

$ErrorActionPreference = "SilentlyContinue"

# Import AI Facade
$facadePath = Join-Path $PSScriptRoot "AIFacade.psm1"
Import-Module $facadePath -Force
$null = Initialize-AISystem -SkipAdvanced

$configPath = Join-Path $PSScriptRoot "ai-config.json"
$config = Get-AIConfig

# ============================================
# HEALTH MODE (from Invoke-AIHealth.ps1)
# ============================================
if ($Health) {
    $health = Get-AIHealth

    if ($Json) {
        $health | ConvertTo-Json -Depth 10
        return
    }

    Write-Host ""
    Write-Host "  ============================================" -ForegroundColor Cyan
    Write-Host "            AI HEALTH DASHBOARD" -ForegroundColor Cyan
    Write-Host "  ============================================" -ForegroundColor Cyan

    foreach ($provider in $health.providers) {
        $status = if ($provider.enabled -and $provider.hasKey) { "OK" } else { "BRAK KLUCZA / DISABLED" }
        $color = if ($provider.enabled -and $provider.hasKey) { "Green" } else { "Yellow" }
        Write-Host ""
        Write-Host "  [$($provider.name)] $status" -ForegroundColor $color

        foreach ($model in $provider.models) {
            $tokenText = "$($model.tokens.percent)%"
            $costText = "`$" + $model.usage.totalCost
            Write-Host "    $($model.name) [$($model.tier)] tokeny: $tokenText, koszt: $costText" -ForegroundColor Gray
        }
    }
    Write-Host ""
    return
}

# ============================================
# CONFIG MODE (from Invoke-AIConfig.ps1)
# ============================================
if ($Config) {
    $configData = Get-Content $configPath -Raw | ConvertFrom-Json

    Write-Host ""
    Write-Host "  ============================================" -ForegroundColor Cyan
    Write-Host "          CURRENT CONFIGURATION" -ForegroundColor Cyan
    Write-Host "  ============================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  SETTINGS:" -ForegroundColor Yellow
    Write-Host "  preferLocal:       $($configData.settings.preferLocal)" -ForegroundColor White
    Write-Host "  autoFallback:      $($configData.settings.autoFallback)" -ForegroundColor White
    Write-Host "  costOptimization:  $($configData.settings.costOptimization)" -ForegroundColor White
    Write-Host "  ollamaDefaultModel: $($configData.settings.ollamaDefaultModel)" -ForegroundColor White
    Write-Host "  maxRetries:        $($configData.settings.maxRetries)" -ForegroundColor White
    Write-Host "  retryDelayMs:      $($configData.settings.retryDelayMs)" -ForegroundColor White
    Write-Host ""
    Write-Host "  PARALLEL EXECUTION:" -ForegroundColor Yellow
    Write-Host "  maxConcurrent:     $($configData.settings.parallelExecution.maxConcurrent)" -ForegroundColor White
    Write-Host "  batchSize:         $($configData.settings.parallelExecution.batchSize)" -ForegroundColor White
    Write-Host "  timeoutMs:         $($configData.settings.parallelExecution.timeoutMs)" -ForegroundColor White
    Write-Host ""
    Write-Host "  PROVIDER PRIORITY:" -ForegroundColor Yellow
    $i = 1
    foreach ($p in $configData.providerFallbackOrder) {
        Write-Host "  [$i] $p" -ForegroundColor White
        $i++
    }
    Write-Host ""
    Write-Host "  Config file: $configPath" -ForegroundColor Gray
    Write-Host ""
    return
}

# ============================================
# SET VALUE MODE (from Invoke-AIConfig.ps1)
# ============================================
if ($Set -and $Value) {
    $configData = Get-Content $configPath -Raw | ConvertFrom-Json
    $changed = $false

    switch ($Set.ToLower()) {
        "preferlocal" {
            $configData.settings.preferLocal = ($Value -eq "true")
            $changed = $true
        }
        "autofallback" {
            $configData.settings.autoFallback = ($Value -eq "true")
            $changed = $true
        }
        "costoptimization" {
            $configData.settings.costOptimization = ($Value -eq "true")
            $changed = $true
        }
        "ollamadefaultmodel" {
            $configData.settings.ollamaDefaultModel = $Value
            $changed = $true
        }
        "defaultmodel" {
            $configData.settings.ollamaDefaultModel = $Value
            $changed = $true
        }
        "maxconcurrent" {
            $intValue = [int]$Value
            if ($intValue -lt 1) { $intValue = 1 }
            if ($intValue -gt 16) { $intValue = 16 }
            $configData.settings.parallelExecution.maxConcurrent = $intValue
            $changed = $true
        }
        "timeout" {
            $configData.settings.parallelExecution.timeoutMs = [int]$Value
            $changed = $true
        }
        "maxretries" {
            $configData.settings.maxRetries = [int]$Value
            $changed = $true
        }
        "retrydelayms" {
            $configData.settings.retryDelayMs = [int]$Value
            $changed = $true
        }
        default {
            Write-Host ""
            Write-Host "  [ERROR] Unknown setting: $Set" -ForegroundColor Red
            Write-Host ""
            Write-Host "  Valid settings:" -ForegroundColor Yellow
            Write-Host "    preferLocal, autoFallback, costOptimization" -ForegroundColor Gray
            Write-Host "    ollamaDefaultModel, defaultModel" -ForegroundColor Gray
            Write-Host "    maxConcurrent, timeout, maxRetries, retryDelayMs" -ForegroundColor Gray
            Write-Host ""
            return
        }
    }

    if ($changed) {
        $configData | ConvertTo-Json -Depth 10 | Set-Content $configPath -Encoding UTF8
        Write-Host ""
        Write-Host "  ============================================" -ForegroundColor Green
        Write-Host "          CONFIGURATION UPDATED" -ForegroundColor Green
        Write-Host "  ============================================" -ForegroundColor Green
        Write-Host ""
        Write-Host "  [OK] $Set = $Value" -ForegroundColor Green
        Write-Host ""
        Write-Host "  Config saved to: $configPath" -ForegroundColor Gray
        Write-Host ""
    }
    return
}

# ============================================
# DEFAULT STATUS MODE
# ============================================
Write-Host ""
Write-Host "  ============================================" -ForegroundColor Cyan
Write-Host "            AI HANDLER STATUS" -ForegroundColor Cyan
Write-Host "  ============================================" -ForegroundColor Cyan
Write-Host ""

# 1. Provider Status
Write-Host "  PROVIDERS" -ForegroundColor Yellow
Write-Host "  -----------------------------------------" -ForegroundColor Gray

foreach ($providerName in $config.providerFallbackOrder) {
    $provider = $config.providers[$providerName]
    $priority = $provider.priority

    Write-Host "  [$priority] " -NoNewline -ForegroundColor Gray
    Write-Host "$providerName" -NoNewline -ForegroundColor White
    Write-Host " ($($provider.name))" -NoNewline -ForegroundColor Gray

    # Check status
    if ($providerName -eq "ollama") {
        if (Test-OllamaAvailable) {
            Write-Host " [OK]" -ForegroundColor Green
        } else {
            Write-Host " [OFFLINE]" -ForegroundColor Red
        }
    } else {
        if ($provider.apiKeyEnv) {
            $key = [Environment]::GetEnvironmentVariable($provider.apiKeyEnv)
            if ($key) {
                $masked = $key.Substring(0, [Math]::Min(10, $key.Length)) + "..."
                Write-Host " [OK] " -ForegroundColor Green -NoNewline
                Write-Host $masked -ForegroundColor Gray
            } else {
                Write-Host " [NO KEY] " -ForegroundColor Red -NoNewline
                Write-Host "Set $($provider.apiKeyEnv)" -ForegroundColor Gray
            }
        }
    }
}

Write-Host ""

# 2. Local Models (Ollama)
Write-Host "  LOCAL MODELS (Ollama)" -ForegroundColor Yellow
Write-Host "  -----------------------------------------" -ForegroundColor Gray

if (Test-OllamaAvailable) {
    $localModels = Get-LocalModels
    if ($localModels.Count -gt 0) {
        foreach ($model in $localModels) {
            $isDefault = $model.Name -eq $config.settings.ollamaDefaultModel
            Write-Host "  " -NoNewline
            if ($isDefault) {
                Write-Host "[*] " -NoNewline -ForegroundColor Green
            } else {
                Write-Host "[ ] " -NoNewline -ForegroundColor Gray
            }
            Write-Host "$($model.Name)" -NoNewline -ForegroundColor White
            Write-Host " ($($model.Size) GB)" -ForegroundColor Gray
        }
    } else {
        Write-Host "  No models installed" -ForegroundColor Red
    }
} else {
    Write-Host "  Ollama not running" -ForegroundColor Red
}

Write-Host ""

# 3. Configuration
Write-Host "  CONFIGURATION" -ForegroundColor Yellow
Write-Host "  -----------------------------------------" -ForegroundColor Gray

Write-Host "  Prefer Local: " -NoNewline -ForegroundColor Gray
if ($config.settings.preferLocal) {
    Write-Host "YES" -ForegroundColor Green
} else {
    Write-Host "NO" -ForegroundColor Yellow
}

Write-Host "  Auto Fallback: " -NoNewline -ForegroundColor Gray
if ($config.settings.autoFallback) {
    Write-Host "YES" -ForegroundColor Green
} else {
    Write-Host "NO" -ForegroundColor Yellow
}

Write-Host "  Cost Optimization: " -NoNewline -ForegroundColor Gray
if ($config.settings.costOptimization) {
    Write-Host "YES" -ForegroundColor Green
} else {
    Write-Host "NO" -ForegroundColor Yellow
}

Write-Host "  Default Model: " -NoNewline -ForegroundColor Gray
Write-Host $config.settings.ollamaDefaultModel -ForegroundColor White

Write-Host "  Max Concurrent: " -NoNewline -ForegroundColor Gray
Write-Host $config.settings.parallelExecution.maxConcurrent -ForegroundColor White

Write-Host ""

# 4. Fallback Chain
Write-Host "  FALLBACK CHAIN" -ForegroundColor Yellow
Write-Host "  -----------------------------------------" -ForegroundColor Gray

# Read directly from JSON for accurate display
$jsonPath = Join-Path $PSScriptRoot "ai-config.json"
$jsonText = Get-Content $jsonPath -Raw
$jsonObj = $jsonText | ConvertFrom-Json

Write-Host "  anthropic : " -NoNewline -ForegroundColor White
Write-Host ($jsonObj.fallbackChain.anthropic -join " -> ") -ForegroundColor Gray

Write-Host "  openai : " -NoNewline -ForegroundColor White
Write-Host ($jsonObj.fallbackChain.openai -join " -> ") -ForegroundColor Gray

Write-Host "  ollama : " -NoNewline -ForegroundColor White
Write-Host ($jsonObj.fallbackChain.ollama -join " -> ") -ForegroundColor Gray

Write-Host ""

# 5. Connectivity Test (if -Test flag)
if ($Test) {
    Write-Host "  CONNECTIVITY TEST" -ForegroundColor Yellow
    Write-Host "  -----------------------------------------" -ForegroundColor Gray

    $testProviders = @(
        @{ Name = "ollama"; Model = "llama3.2:1b" }
        @{ Name = "openai"; Model = "gpt-4o-mini" }
        @{ Name = "anthropic"; Model = "claude-3-5-haiku-20241022" }
    )

    foreach ($provider in $testProviders) {
        Write-Host "  Testing $($provider.Name)... " -NoNewline -ForegroundColor Gray

        try {
            $testMessages = @(
                @{ role = "user"; content = "Say OK" }
            )

            $startTime = Get-Date
            $response = Invoke-AIRequest -Provider $provider.Name -Model $provider.Model `
                -Messages $testMessages -MaxTokens 10
            $elapsed = ((Get-Date) - $startTime).TotalMilliseconds

            Write-Host "[OK] " -ForegroundColor Green -NoNewline
            Write-Host "$([math]::Round($elapsed))ms" -ForegroundColor Gray
        } catch {
            $errMsg = $_.Exception.Message
            if ($errMsg.Length -gt 40) { $errMsg = $errMsg.Substring(0, 40) }
            Write-Host "[FAIL] " -ForegroundColor Red -NoNewline
            Write-Host $errMsg -ForegroundColor Gray
        }
    }
    Write-Host ""
}

# 6. Cost Summary
Write-Host "  COST PER 1K TOKENS" -ForegroundColor Yellow
Write-Host "  -----------------------------------------" -ForegroundColor Gray

$costData = @(
    @{ Provider = "ollama"; Model = "*"; Input = 0; Output = 0 }
    @{ Provider = "openai"; Model = "gpt-4o-mini"; Input = 0.15; Output = 0.60 }
    @{ Provider = "openai"; Model = "gpt-4o"; Input = 2.50; Output = 10.00 }
    @{ Provider = "anthropic"; Model = "claude-3-5-haiku"; Input = 0.80; Output = 4.00 }
    @{ Provider = "anthropic"; Model = "claude-sonnet-4"; Input = 3.00; Output = 15.00 }
)

foreach ($cost in $costData) {
    $total = $cost.Input + $cost.Output
    Write-Host "  $($cost.Provider)/$($cost.Model): " -NoNewline -ForegroundColor Gray
    if ($total -eq 0) {
        Write-Host "`$0.00 (FREE)" -ForegroundColor Green
    } else {
        Write-Host "`$$($cost.Input)/`$$($cost.Output)" -ForegroundColor Yellow
    }
}

Write-Host ""
Write-Host "  ============================================" -ForegroundColor Cyan
Write-Host ""

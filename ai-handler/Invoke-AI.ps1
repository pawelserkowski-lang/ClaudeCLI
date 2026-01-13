<#
.SYNOPSIS
    Quick AI invocation with automatic fallback and smart classification
.DESCRIPTION
    Wrapper for the AI Model Handler with intelligent task classification.
    Uses premium AI (Claude Opus / GPT-4o) to classify tasks and route
    them to the optimal execution model.
.EXAMPLE
    .\Invoke-AI.ps1 -Prompt "Explain quantum computing"
.EXAMPLE
    .\Invoke-AI.ps1 -Prompt "Write a Python function" -Smart
.EXAMPLE
    .\Invoke-AI.ps1 -Prompt "Complex architecture question" -Smart -Verbose
.EXAMPLE
    .\Invoke-AI.ps1 -Status
#>

[CmdletBinding(DefaultParameterSetName = 'Query')]
param(
    [Parameter(ParameterSetName = 'Query', Position = 0)]
    [string]$Prompt,

    [Parameter(ParameterSetName = 'Query')]
    [ValidateSet("simple", "complex", "creative", "code", "vision", "analysis", "auto")]
    [string]$Task = "auto",

    [Parameter(ParameterSetName = 'Query')]
    [string]$SystemPrompt,

    [Parameter(ParameterSetName = 'Query')]
    [string]$Provider,

    [Parameter(ParameterSetName = 'Query')]
    [string]$Model,

    [Parameter(ParameterSetName = 'Query')]
    [int]$MaxTokens = 4096,

    [Parameter(ParameterSetName = 'Query')]
    [float]$Temperature = 0.7,

    [Parameter(ParameterSetName = 'Query')]
    [switch]$PreferCheapest,

    [Parameter(ParameterSetName = 'Query')]
    [Alias("Smart")]
    [switch]$SmartClassify,

    [Parameter(ParameterSetName = 'Query')]
    [switch]$NoFallback,

    [Parameter(ParameterSetName = 'Query')]
    [switch]$Stream,

    [Parameter(ParameterSetName = 'Query')]
    [switch]$ShowClassification,

    [Parameter(ParameterSetName = 'Status')]
    [switch]$Status,

    [Parameter(ParameterSetName = 'Test')]
    [switch]$Test,

    [Parameter(ParameterSetName = 'Reset')]
    [switch]$Reset,

    [Parameter(ParameterSetName = 'ClassifierStats')]
    [switch]$ClassifierStats
)

$ErrorActionPreference = "Stop"
$ModulePath = Join-Path $PSScriptRoot "AIModelHandler.psm1"
$ClassifierPath = Join-Path $PSScriptRoot "modules\TaskClassifier.psm1"

# Import modules
Import-Module $ModulePath -Force
if (Test-Path $ClassifierPath) {
    Import-Module $ClassifierPath -Force
}

# Handle different modes
switch ($PSCmdlet.ParameterSetName) {
    'Status' {
        Get-AIStatus
        return
    }

    'Test' {
        $results = Test-AIProviders
        Write-Host "`n=== Summary ===" -ForegroundColor Cyan
        $ok = ($results | Where-Object { $_.status -eq "ok" }).Count
        $total = $results.Count
        Write-Host "Providers available: $ok / $total" -ForegroundColor $(if ($ok -gt 0) { "Green" } else { "Red" })
        return
    }

    'Reset' {
        Reset-AIState -Force
        if (Get-Command Clear-ClassificationCache -ErrorAction SilentlyContinue) {
            Clear-ClassificationCache
        }
        return
    }

    'ClassifierStats' {
        if (Get-Command Get-ClassificationStats -ErrorAction SilentlyContinue) {
            $stats = Get-ClassificationStats
            Write-Host "`n=== Task Classifier Stats ===" -ForegroundColor Cyan
            Write-Host "Classifier Model: $($stats.ClassifierModel)" -ForegroundColor Green
            Write-Host "Cached entries:   $($stats.TotalCached) ($($stats.ValidEntries) valid, $($stats.ExpiredEntries) expired)"
            Write-Host "Cache TTL:        $($stats.CacheTTLSeconds)s"
        } else {
            Write-Host "TaskClassifier module not loaded" -ForegroundColor Yellow
        }
        return
    }

    'Query' {
        if (-not $Prompt) {
            Write-Host "Usage: .\Invoke-AI.ps1 -Prompt 'Your question here'" -ForegroundColor Yellow
            Write-Host "`nOptions:" -ForegroundColor Cyan
            Write-Host "  -Task             : auto, simple, complex, creative, code, vision, analysis"
            Write-Host "  -Smart (-SmartClassify) : Use premium AI to classify and route task" -ForegroundColor Green
            Write-Host "  -ShowClassification : Show classification details"
            Write-Host "  -SystemPrompt     : Custom system prompt"
            Write-Host "  -Provider         : Force specific provider"
            Write-Host "  -Model            : Force specific model"
            Write-Host "  -PreferCheapest   : Use cheapest suitable model"
            Write-Host "  -NoFallback       : Disable automatic fallback"
            Write-Host "  -Status           : Show current status"
            Write-Host "  -Test             : Test all providers"
            Write-Host "  -ClassifierStats  : Show classifier statistics"
            Write-Host "  -Reset            : Reset usage data"
            return
        }

        # Build messages
        $messages = @()

        if ($SystemPrompt) {
            $messages += @{ role = "system"; content = $SystemPrompt }
        }

        $messages += @{ role = "user"; content = $Prompt }

        # Smart classification mode OR auto task type
        $classification = $null
        if (($SmartClassify -or $Task -eq "auto") -and -not $Model) {
            if (Get-Command Invoke-TaskClassification -ErrorAction SilentlyContinue) {
                Write-Host "`n[Step 1] Classifying task with premium AI..." -ForegroundColor Cyan
                $classification = Invoke-TaskClassification -Prompt $Prompt
                
                if ($ShowClassification -or $VerbosePreference -eq 'Continue') {
                    Write-Host "`n=== Classification Result ===" -ForegroundColor Magenta
                    Write-Host "  Category:    $($classification.Category)" -ForegroundColor White
                    Write-Host "  Complexity:  $($classification.Complexity)/10" -ForegroundColor White
                    Write-Host "  Tier:        $($classification.RecommendedTier)" -ForegroundColor White
                    Write-Host "  Capabilities: $($classification.Capabilities -join ', ')" -ForegroundColor Gray
                    Write-Host "  Reasoning:   $($classification.Reasoning)" -ForegroundColor Gray
                    Write-Host "  Classifier:  $($classification.ClassifierModel)" -ForegroundColor DarkGray
                    Write-Host ""
                }
                
                # Use classification to set task type
                $Task = $classification.Category
                if ($Task -notin @("simple", "complex", "creative", "code", "vision", "analysis")) {
                    $Task = "simple"
                }
            } else {
                Write-Verbose "TaskClassifier not available, using default classification"
                if ($Task -eq "auto") { $Task = "simple" }
            }
        }

        # Select model if not specified
        if (-not $Model) {
            Write-Host "[Step 2] Selecting optimal execution model..." -ForegroundColor Cyan
            
            $modelParams = @{
                Task = $Task
                EstimatedTokens = if ($classification) { $classification.EstimatedTokens } else { $Prompt.Length }
                PreferCheapest = $PreferCheapest -or ($classification -and $classification.Complexity -le 3)
            }
            
            if ($classification -and $classification.Capabilities) {
                $modelParams.RequiredCapabilities = $classification.Capabilities
            }
            
            $optimal = Get-OptimalModel @modelParams
            if ($optimal) {
                $Provider = $optimal.provider
                $Model = $optimal.model
                Write-Host "  Selected: $Provider/$Model (tier: $($optimal.tier), cost: `$$([math]::Round($optimal.cost, 4)))" -ForegroundColor Green
            }
        }

        $config = Get-AIConfig
        $streamEnabled = $Stream -or ($config.settings.streamResponses -eq $true)

        # Make request
        try {
            Write-Host "`n[Step 3] Executing request..." -ForegroundColor Cyan
            
            $response = Invoke-AIRequest -Messages $messages `
                -Provider $Provider -Model $Model `
                -MaxTokens $MaxTokens -Temperature $Temperature `
                -AutoFallback:(-not $NoFallback) -Stream:$streamEnabled

            # Output response
            Write-Host "`n" + ("=" * 60) -ForegroundColor Green
            Write-Host " RESPONSE" -ForegroundColor Green
            Write-Host ("=" * 60) -ForegroundColor Green
            if (-not $streamEnabled) {
                Write-Host $response.content
            }

            # Show metadata
            Write-Host "`n" + ("-" * 40) -ForegroundColor Gray
            Write-Host "Provider: $($response._meta.provider) | Model: $($response._meta.model)" -ForegroundColor Gray
            Write-Host "Tokens: $($response.usage.input_tokens) in / $($response.usage.output_tokens) out" -ForegroundColor Gray
            if ($classification) {
                Write-Host "Classification: $($classification.Category) (complexity: $($classification.Complexity)/10)" -ForegroundColor DarkGray
            }

        } catch {
            Write-Host "`nError: $($_.Exception.Message)" -ForegroundColor Red
            exit 1
        }
    }
}

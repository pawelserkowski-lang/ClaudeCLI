<#
.SYNOPSIS
    Unified AI CLI - Quick queries, batch processing, and model management
.DESCRIPTION
    Wrapper for the AI Model Handler with intelligent task classification.
    Supports quick local queries, batch processing, and model pull operations.
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
.EXAMPLE
    .\Invoke-AI.ps1 -Quick "What is 2+2?"
.EXAMPLE
    .\Invoke-AI.ps1 -Quick "Write a sort function" -Code
.EXAMPLE
    .\Invoke-AI.ps1 -Batch "Query 1; Query 2; Query 3"
.EXAMPLE
    .\Invoke-AI.ps1 -Pull "llama3.2:3b"
.EXAMPLE
    .\Invoke-AI.ps1 -Pull -List
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
    [switch]$ClassifierStats,

    # === QUICK MODE (from Invoke-QuickAI.ps1) ===
    [Parameter(ParameterSetName = 'Quick', Position = 0)]
    [string]$Quick,

    [Parameter(ParameterSetName = 'Quick')]
    [switch]$Code,

    [Parameter(ParameterSetName = 'Quick')]
    [switch]$Fast,

    # === BATCH MODE (from Invoke-QuickAIBatch.ps1) ===
    [Parameter(ParameterSetName = 'Batch', Position = 0)]
    [string[]]$Batch,

    [Parameter(ParameterSetName = 'Batch')]
    [string]$BatchFile,

    [Parameter(ParameterSetName = 'Batch')]
    [int]$MaxConcurrent = 4,

    # === PULL MODE (from Invoke-AIPull.ps1) ===
    [Parameter(ParameterSetName = 'Pull', Position = 0)]
    [string]$Pull,

    [Parameter(ParameterSetName = 'Pull')]
    [switch]$List,

    [Parameter(ParameterSetName = 'Pull')]
    [switch]$Popular,

    [Parameter(ParameterSetName = 'Pull')]
    [switch]$Remove
)

$ErrorActionPreference = "Stop"

# Import AI Facade (primary entry point)
$FacadePath = Join-Path $PSScriptRoot "AIFacade.psm1"
Import-Module $FacadePath -Force

# Initialize AI System (loads all modules including AIModelHandler)
$null = Initialize-AISystem -SkipAdvanced

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

    # === QUICK MODE: Fast local AI query (from Invoke-QuickAI.ps1) ===
    'Quick' {
        if (-not $Quick) {
            Write-Host "Usage: .\Invoke-AI.ps1 -Quick 'Your question'" -ForegroundColor Yellow
            Write-Host "`nQuick Mode Options:" -ForegroundColor Cyan
            Write-Host "  -Code    : Use code-specialized model (qwen2.5-coder:1.5b)"
            Write-Host "  -Fast    : Use fastest model (llama3.2:1b)"
            Write-Host "`nExamples:" -ForegroundColor Gray
            Write-Host "  -Quick 'What is 2+2?'"
            Write-Host "  -Quick 'Write a Python sort function' -Code"
            Write-Host "  -Quick 'Capital of France?' -Fast"
            return
        }

        # Auto-select model for quick mode
        $quickModel = "llama3.2:3b"
        if ($Code) {
            $quickModel = "qwen2.5-coder:1.5b"
        } elseif ($Fast) {
            $quickModel = "llama3.2:1b"
        } else {
            # Auto-detect code query
            $codePatterns = @(
                "write.*(function|code|script|class|method)",
                "create.*(function|code|script|class|method)",
                "implement\s+",
                "fix.*(bug|error|code)",
                "\b(regex|regexp)\b",
                "\b(sql|query)\s+(to|for|that)",
                "\bapi\s+(endpoint|call|request)",
                "in\s+(python|javascript|powershell|bash|rust|go|java|c#|typescript)"
            )
            foreach ($pattern in $codePatterns) {
                if ($Quick -match $pattern) {
                    $quickModel = "qwen2.5-coder:1.5b"
                    break
                }
            }
        }

        # Check Ollama
        if (-not (Test-OllamaAvailable)) {
            Write-Host "[ERROR] Ollama is not running. Starting..." -ForegroundColor Red
            $ollamaExe = "$env:LOCALAPPDATA\Programs\Ollama\ollama.exe"
            if (Test-Path $ollamaExe) {
                Start-Process -FilePath $ollamaExe -ArgumentList "serve" -WindowStyle Hidden
                Start-Sleep -Seconds 3
                if (-not (Test-OllamaAvailable)) {
                    Write-Host "[ERROR] Failed to start Ollama" -ForegroundColor Red
                    return
                }
            } else {
                Write-Host "[ERROR] Ollama not installed" -ForegroundColor Red
                return
            }
        }

        Write-Host "[AI] $quickModel" -ForegroundColor Cyan -NoNewline
        Write-Host " | " -NoNewline
        Write-Host "Processing..." -ForegroundColor Gray

        $messages = @(@{ role = "user"; content = $Quick })

        try {
            $startTime = Get-Date
            $response = Invoke-AIRequest -Provider "ollama" -Model $quickModel -Messages $messages -MaxTokens 1024
            $elapsed = ((Get-Date) - $startTime).TotalSeconds

            Write-Host ""
            Write-Host $response.content
            Write-Host ""
            Write-Host "---" -ForegroundColor Gray
            Write-Host "[Done] $([math]::Round($elapsed, 2))s | $($response.usage.input_tokens + $response.usage.output_tokens) tokens | cost=`$0" -ForegroundColor Gray
        } catch {
            Write-Host "[ERROR] $($_.Exception.Message)" -ForegroundColor Red
        }
        return
    }

    # === BATCH MODE: Parallel AI queries (from Invoke-QuickAIBatch.ps1) ===
    'Batch' {
        # Parse queries
        $queryList = @()

        if ($BatchFile -and (Test-Path $BatchFile)) {
            $queryList = Get-Content $BatchFile | Where-Object { $_.Trim() -ne "" }
            Write-Host "[AI-BATCH] Loaded $($queryList.Count) queries from file" -ForegroundColor Cyan
        } elseif ($Batch) {
            $joinedQuery = $Batch -join " "
            if ($joinedQuery -match ";") {
                $queryList = $joinedQuery -split ";" | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne "" }
            } else {
                $queryList = @($joinedQuery)
            }
        }

        if ($queryList.Count -eq 0) {
            Write-Host "[ERROR] No queries provided" -ForegroundColor Red
            Write-Host ""
            Write-Host "Usage:" -ForegroundColor Yellow
            Write-Host '  -Batch "Query 1; Query 2; Query 3"' -ForegroundColor Gray
            Write-Host '  -Batch -BatchFile "queries.txt"' -ForegroundColor Gray
            Write-Host '  -Batch @("Query 1", "Query 2")' -ForegroundColor Gray
            return
        }

        # Check Ollama
        if (-not (Test-OllamaAvailable)) {
            Write-Host "[ERROR] Ollama is not running" -ForegroundColor Red
            $ollamaExe = "$env:LOCALAPPDATA\Programs\Ollama\ollama.exe"
            if (Test-Path $ollamaExe) {
                Write-Host "[AI-BATCH] Starting Ollama..." -ForegroundColor Yellow
                Start-Process -FilePath $ollamaExe -ArgumentList "serve" -WindowStyle Hidden
                Start-Sleep -Seconds 3
                if (-not (Test-OllamaAvailable)) {
                    Write-Host "[ERROR] Failed to start Ollama" -ForegroundColor Red
                    return
                }
            } else {
                return
            }
        }

        $batchModel = "llama3.2:3b"
        Write-Host ""
        Write-Host "  ============================================" -ForegroundColor Cyan
        Write-Host "         AI-BATCH: Parallel Processing" -ForegroundColor Cyan
        Write-Host "  ============================================" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "  Queries: $($queryList.Count)" -ForegroundColor White
        Write-Host "  Model: $batchModel" -ForegroundColor White
        Write-Host "  Parallel: $MaxConcurrent" -ForegroundColor White
        Write-Host ""

        $startTime = Get-Date
        $results = Invoke-AIBatch -Prompts $queryList -Model $batchModel -MaxConcurrent $MaxConcurrent -MaxTokens 512
        $elapsed = ((Get-Date) - $startTime).TotalSeconds

        Write-Host "  ============================================" -ForegroundColor Green
        Write-Host "                   RESULTS" -ForegroundColor Green
        Write-Host "  ============================================" -ForegroundColor Green
        Write-Host ""

        $successCount = 0
        $totalTokens = 0

        for ($i = 0; $i -lt $results.Count; $i++) {
            $r = $results[$i]
            $num = $i + 1

            Write-Host "[$num] " -ForegroundColor Yellow -NoNewline

            $queryShort = $r.Prompt
            if ($queryShort.Length -gt 50) {
                $queryShort = $queryShort.Substring(0, 47) + "..."
            }
            Write-Host $queryShort -ForegroundColor Gray

            if ($r.Success) {
                $successCount++
                Write-Host $r.Content.Trim() -ForegroundColor White
                if ($r.Tokens) {
                    $totalTokens += ($r.Tokens.input_tokens + $r.Tokens.output_tokens)
                }
            } else {
                Write-Host "[ERROR] $($r.Error)" -ForegroundColor Red
            }
            Write-Host ""
        }

        Write-Host "  ============================================" -ForegroundColor Cyan
        Write-Host "                   SUMMARY" -ForegroundColor Cyan
        Write-Host "  ============================================" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "  Success: $successCount/$($results.Count)" -ForegroundColor $(if ($successCount -eq $results.Count) { "Green" } else { "Yellow" })
        Write-Host "  Time: $([math]::Round($elapsed, 2))s total ($([math]::Round($elapsed / $results.Count, 2))s avg)" -ForegroundColor White
        Write-Host "  Tokens: $totalTokens" -ForegroundColor White
        Write-Host "  Cost: `$0.00 (local)" -ForegroundColor Green
        Write-Host ""
        return
    }

    # === PULL MODE: Ollama model management (from Invoke-AIPull.ps1) ===
    'Pull' {
        # Check Ollama first
        if (-not (Test-OllamaAvailable)) {
            Write-Host ""
            Write-Host "  [ERROR] Ollama is not running" -ForegroundColor Red
            Write-Host "  Start Ollama first or run launcher" -ForegroundColor Gray
            Write-Host ""
            return
        }

        # List installed models
        if ($List) {
            Write-Host ""
            Write-Host "  ============================================" -ForegroundColor Cyan
            Write-Host "           INSTALLED OLLAMA MODELS" -ForegroundColor Cyan
            Write-Host "  ============================================" -ForegroundColor Cyan
            Write-Host ""

            $models = Get-LocalModels
            if ($models.Count -eq 0) {
                Write-Host "  No models installed" -ForegroundColor Yellow
            } else {
                $totalSize = 0
                foreach ($m in $models) {
                    Write-Host "  [*] " -NoNewline -ForegroundColor Green
                    Write-Host "$($m.Name)" -NoNewline -ForegroundColor White
                    Write-Host " ($($m.Size) GB)" -ForegroundColor Gray
                    $totalSize += $m.Size
                }
                Write-Host ""
                Write-Host "  Total: $($models.Count) models, $([math]::Round($totalSize, 2)) GB" -ForegroundColor Gray
            }
            Write-Host ""
            return
        }

        # Show popular models
        if ($Popular) {
            Write-Host ""
            Write-Host "  ============================================" -ForegroundColor Cyan
            Write-Host "           POPULAR OLLAMA MODELS" -ForegroundColor Cyan
            Write-Host "  ============================================" -ForegroundColor Cyan
            Write-Host ""
            Write-Host "  GENERAL PURPOSE:" -ForegroundColor Yellow
            Write-Host "  llama3.2:1b        1.3 GB   Fast, lightweight" -ForegroundColor Gray
            Write-Host "  llama3.2:3b        2.0 GB   Balanced (recommended)" -ForegroundColor Gray
            Write-Host "  llama3.1:8b        4.7 GB   High quality" -ForegroundColor Gray
            Write-Host "  mistral:7b         4.1 GB   Strong reasoning" -ForegroundColor Gray
            Write-Host "  gemma2:2b          1.6 GB   Google's compact model" -ForegroundColor Gray
            Write-Host ""
            Write-Host "  CODE SPECIALISTS:" -ForegroundColor Yellow
            Write-Host "  qwen2.5-coder:1.5b 0.9 GB   Code generation (fast)" -ForegroundColor Gray
            Write-Host "  qwen2.5-coder:7b   4.7 GB   Code generation (quality)" -ForegroundColor Gray
            Write-Host "  codellama:7b       3.8 GB   Meta's code model" -ForegroundColor Gray
            Write-Host "  deepseek-coder:6.7b 3.8 GB  DeepSeek code model" -ForegroundColor Gray
            Write-Host ""
            Write-Host "  REASONING:" -ForegroundColor Yellow
            Write-Host "  phi3:mini          2.2 GB   Microsoft reasoning" -ForegroundColor Gray
            Write-Host "  phi3:medium        7.9 GB   Microsoft (larger)" -ForegroundColor Gray
            Write-Host "  qwen2.5:3b         1.9 GB   Alibaba balanced" -ForegroundColor Gray
            Write-Host ""
            Write-Host "  Usage: -Pull <model-name>" -ForegroundColor Cyan
            Write-Host ""
            return
        }

        # No model specified - show help
        if (-not $Pull) {
            Write-Host ""
            Write-Host "  ============================================" -ForegroundColor Cyan
            Write-Host "            AI PULL - Ollama Models" -ForegroundColor Cyan
            Write-Host "  ============================================" -ForegroundColor Cyan
            Write-Host ""
            Write-Host "  COMMANDS:" -ForegroundColor Yellow
            Write-Host "  -Pull -List              List installed models" -ForegroundColor Gray
            Write-Host "  -Pull -Popular           Show popular models" -ForegroundColor Gray
            Write-Host "  -Pull <model>            Pull/download model" -ForegroundColor Gray
            Write-Host "  -Pull <model> -Remove    Remove installed model" -ForegroundColor Gray
            Write-Host ""
            Write-Host "  EXAMPLES:" -ForegroundColor Yellow
            Write-Host "  -Pull -List" -ForegroundColor White
            Write-Host "  -Pull llama3.2:3b" -ForegroundColor White
            Write-Host "  -Pull codellama:7b" -ForegroundColor White
            Write-Host "  -Pull phi3:mini -Remove" -ForegroundColor White
            Write-Host ""
            return
        }

        # Remove model
        if ($Remove -and $Pull) {
            Write-Host ""
            Write-Host "  Removing $Pull..." -ForegroundColor Yellow

            $process = Start-Process -FilePath "ollama" -ArgumentList "rm $Pull" -Wait -PassThru -NoNewWindow

            if ($process.ExitCode -eq 0) {
                Write-Host "  [OK] Model $Pull removed" -ForegroundColor Green
            } else {
                Write-Host "  [ERROR] Failed to remove $Pull" -ForegroundColor Red
            }
            Write-Host ""
            return
        }

        # Pull model
        if ($Pull) {
            Write-Host ""
            Write-Host "  ============================================" -ForegroundColor Cyan
            Write-Host "           PULLING: $Pull" -ForegroundColor Cyan
            Write-Host "  ============================================" -ForegroundColor Cyan
            Write-Host ""
            Write-Host "  This may take a few minutes depending on model size..." -ForegroundColor Gray
            Write-Host ""

            $pinfo = New-Object System.Diagnostics.ProcessStartInfo
            $pinfo.FileName = "ollama"
            $pinfo.Arguments = "pull $Pull"
            $pinfo.RedirectStandardOutput = $true
            $pinfo.RedirectStandardError = $true
            $pinfo.UseShellExecute = $false
            $pinfo.CreateNoWindow = $true

            $process = New-Object System.Diagnostics.Process
            $process.StartInfo = $pinfo
            $process.Start() | Out-Null

            while (-not $process.HasExited) {
                $line = $process.StandardOutput.ReadLine()
                if ($line) {
                    if ($line -match "pulling|downloading|verifying|writing") {
                        Write-Host "  $line" -ForegroundColor Gray
                    } elseif ($line -match "(\d+)%") {
                        Write-Host "`r  Progress: $($Matches[1])%   " -NoNewline -ForegroundColor Yellow
                    }
                }
                Start-Sleep -Milliseconds 100
            }

            $remaining = $process.StandardOutput.ReadToEnd()
            $errors = $process.StandardError.ReadToEnd()

            Write-Host ""

            if ($process.ExitCode -eq 0) {
                Write-Host ""
                Write-Host "  [OK] Model $Pull pulled successfully!" -ForegroundColor Green

                # Update config if new model
                $configPath = Join-Path $PSScriptRoot "ai-config.json"
                $config = Get-Content $configPath -Raw | ConvertFrom-Json

                $existingModels = $config.providers.ollama.models.PSObject.Properties.Name
                if ($Pull -notin $existingModels) {
                    Write-Host "  [INFO] Adding $Pull to configuration..." -ForegroundColor Cyan

                    $newModel = @{
                        tier = "lite"
                        contextWindow = 128000
                        maxOutput = 4096
                        inputCost = 0.00
                        outputCost = 0.00
                        tokensPerMinute = 999999
                        requestsPerMinute = 999999
                        capabilities = @("code", "analysis")
                    }

                    $config.providers.ollama.models | Add-Member -NotePropertyName $Pull -NotePropertyValue $newModel -Force

                    $currentChain = @($config.fallbackChain.ollama)
                    if ($Pull -notin $currentChain) {
                        $currentChain += $Pull
                        $config.fallbackChain.ollama = $currentChain
                    }

                    $config | ConvertTo-Json -Depth 10 | Set-Content $configPath -Encoding UTF8
                    Write-Host "  [OK] Configuration updated" -ForegroundColor Green
                }
            } else {
                Write-Host "  [ERROR] Failed to pull $Pull" -ForegroundColor Red
                if ($errors) {
                    Write-Host "  $errors" -ForegroundColor Red
                }
            }
            Write-Host ""
        }
        return
    }

    'Query' {
        if (-not $Prompt) {
            Write-Host "Usage: .\Invoke-AI.ps1 -Prompt 'Your question here'" -ForegroundColor Yellow
            Write-Host "`n=== UNIFIED AI CLI ===" -ForegroundColor Cyan
            Write-Host ""
            Write-Host "STANDARD MODE:" -ForegroundColor Yellow
            Write-Host "  -Prompt <text>    : Full AI query with smart routing"
            Write-Host "  -Task             : auto, simple, complex, creative, code, vision, analysis"
            Write-Host "  -Smart            : Use premium AI to classify and route task" -ForegroundColor Green
            Write-Host "  -ShowClassification : Show classification details"
            Write-Host "  -SystemPrompt     : Custom system prompt"
            Write-Host "  -Provider         : Force specific provider"
            Write-Host "  -Model            : Force specific model"
            Write-Host "  -PreferCheapest   : Use cheapest suitable model"
            Write-Host "  -NoFallback       : Disable automatic fallback"
            Write-Host ""
            Write-Host "QUICK MODE (local Ollama, `$0):" -ForegroundColor Yellow
            Write-Host "  -Quick <text>     : Fast local AI query"
            Write-Host "  -Code             : Use code-specialized model"
            Write-Host "  -Fast             : Use fastest model"
            Write-Host ""
            Write-Host "BATCH MODE (parallel, `$0):" -ForegroundColor Yellow
            Write-Host "  -Batch <queries>  : Multiple queries (semicolon-separated)"
            Write-Host "  -BatchFile <path> : Load queries from file"
            Write-Host "  -MaxConcurrent    : Parallel limit (default: 4)"
            Write-Host ""
            Write-Host "PULL MODE (model management):" -ForegroundColor Yellow
            Write-Host "  -Pull <model>     : Download Ollama model"
            Write-Host "  -Pull -List       : List installed models"
            Write-Host "  -Pull -Popular    : Show popular models"
            Write-Host "  -Pull <model> -Remove : Remove model"
            Write-Host ""
            Write-Host "OTHER:" -ForegroundColor Yellow
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

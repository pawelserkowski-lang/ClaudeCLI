#Requires -Version 5.1
<#
.SYNOPSIS
    HYDRA Smart Queue - Intelligent Prompt Queue with Parallel Execution
.DESCRIPTION
    Advanced queue system that:
    1. Classifies prompts using pattern-based analysis (no TaskClassifier dependency)
    2. Prioritizes based on complexity and urgency
    3. Executes tasks in parallel (local + cloud simultaneously)
    4. Handles offline scenarios gracefully
    5. Provides real-time progress feedback
.VERSION
    2.0.0
#>

$script:ModulePath = Split-Path -Parent $PSScriptRoot

# Import utility modules
$jsonIOPath = Join-Path $PSScriptRoot "AIUtil-JsonIO.psm1"
$healthPath = Join-Path $PSScriptRoot "AIUtil-Health.psm1"
$validationPath = Join-Path $PSScriptRoot "AIUtil-Validation.psm1"
$promptOptimizerPath = Join-Path $PSScriptRoot "PromptOptimizer.psm1"
$aiHandlerPath = Join-Path $script:ModulePath "AIModelHandler.psm1"

# Import available modules
if (Test-Path $jsonIOPath) { Import-Module $jsonIOPath -Force }
if (Test-Path $healthPath) { Import-Module $healthPath -Force }
if (Test-Path $validationPath) { Import-Module $validationPath -Force }
if (Test-Path $promptOptimizerPath) { Import-Module $promptOptimizerPath -Force }
if (Test-Path $aiHandlerPath) { Import-Module $aiHandlerPath -Force }

# Queue Configuration
$script:QueueConfig = @{
    MaxConcurrentLocal = 2      # Max parallel Ollama requests
    MaxConcurrentCloud = 4      # Max parallel cloud requests
    MaxConcurrentTotal = 5      # Total max parallel
    QueuePersistPath = Join-Path $script:ModulePath "queue\smart-queue.json"
    ResultsPath = Join-Path $script:ModulePath "queue\results"
    DefaultTimeout = 120000     # 2 minutes per request
    RetryAttempts = 2
    EnableParallel = $true
}

# Queue State
$script:Queue = [System.Collections.Concurrent.ConcurrentQueue[hashtable]]::new()
$script:ActiveJobs = [System.Collections.Concurrent.ConcurrentDictionary[string,hashtable]]::new()
$script:CompletedResults = [System.Collections.ArrayList]::new()
$script:QueueStats = @{
    TotalQueued = 0
    TotalCompleted = 0
    TotalFailed = 0
    LocalExecutions = 0
    CloudExecutions = 0
    StartTime = $null
}

#region Internal Health & Connection Functions
# These provide fallbacks when AIUtil-Health.psm1 is not available

function Get-ConnectionStatusInternal {
    <#
    .SYNOPSIS
        Internal connection status check - uses AIUtil-Health when available
    #>
    [CmdletBinding()]
    param()

    # Try AIUtil-Health first
    if (Get-Command Get-AIHealthStatus -ErrorAction SilentlyContinue) {
        $health = Get-AIHealthStatus
        return @{
            LocalAvailable = $health.OllamaOnline
            OllamaAvailable = $health.OllamaOnline
            OllamaModels = $health.OllamaModels
            InternetAvailable = $health.InternetOnline
            Mode = $health.Mode
            LocalModel = $health.PreferredLocalModel
            Recommendation = if ($health.OllamaOnline) { "local" } elseif ($health.InternetOnline) { "cloud" } else { "pattern" }
        }
    }

    # Fallback: inline implementation
    $ollamaOnline = $false
    $ollamaModels = @()
    try {
        $response = Invoke-RestMethod -Uri "http://localhost:11434/api/tags" -Method Get -TimeoutSec 2 -ErrorAction Stop
        $ollamaOnline = $response.models.Count -gt 0
        $ollamaModels = $response.models.name
    } catch { }

    $internetOnline = $false
    try {
        $tcp = New-Object System.Net.Sockets.TcpClient
        $tcp.Connect('8.8.8.8', 53)
        $internetOnline = $tcp.Connected
        $tcp.Close()
    } catch { }

    $mode = if ($ollamaOnline -and $internetOnline) { "full" }
            elseif ($ollamaOnline) { "offline-local" }
            elseif ($internetOnline) { "cloud-only" }
            else { "offline-pattern" }

    $localModel = if ($ollamaOnline -and $ollamaModels.Count -gt 0) { $ollamaModels[0] } else { $null }

    return @{
        LocalAvailable = $ollamaOnline
        OllamaAvailable = $ollamaOnline
        OllamaModels = $ollamaModels
        InternetAvailable = $internetOnline
        Mode = $mode
        LocalModel = $localModel
        Recommendation = if ($ollamaOnline) { "local" } elseif ($internetOnline) { "cloud" } else { "pattern" }
    }
}

function Get-AvailableLocalModelInternal {
    <#
    .SYNOPSIS
        Gets best available local Ollama model - uses AIUtil-Health when available
    #>
    [CmdletBinding()]
    param(
        [string[]]$PreferredModels = @("llama3.2:3b", "phi3:mini", "llama3.2:1b")
    )

    # Try AIUtil-Health first
    if (Get-Command Get-BestLocalModel -ErrorAction SilentlyContinue) {
        return Get-BestLocalModel -PreferredModels $PreferredModels
    }

    # Fallback: inline implementation
    try {
        $response = Invoke-RestMethod -Uri "http://localhost:11434/api/tags" -Method Get -TimeoutSec 2 -ErrorAction Stop
        $available = $response.models.name

        foreach ($model in $PreferredModels) {
            $match = $available | Where-Object { $_ -eq $model -or $_ -like "$model*" }
            if ($match) { return $match | Select-Object -First 1 }
        }

        return $available | Select-Object -First 1
    } catch {
        return $null
    }
}

function Get-InternalClassification {
    <#
    .SYNOPSIS
        Pattern-based classification using Get-PromptCategory from PromptOptimizer
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Prompt,
        [switch]$ForQueue
    )

    # Use Get-PromptCategory from PromptOptimizer if available
    $category = "general"
    if (Get-Command Get-PromptCategory -ErrorAction SilentlyContinue) {
        $category = Get-PromptCategory -Prompt $Prompt
    } else {
        # Inline fallback
        $promptLower = $Prompt.ToLower()
        if ($promptLower -match '(write|implement|function|code|script)') { $category = "code" }
        elseif ($promptLower -match '(analyze|compare|explain)') { $category = "analysis" }
        elseif ($promptLower -match '(sql|query|database)') { $category = "database" }
        elseif ($promptLower -match '(what is|who|when|where)') { $category = "question" }
    }

    # Map category to tier and complexity
    $tierMap = @{
        code = @{ tier = "standard"; complexity = 5; localSuitable = $true }
        debug = @{ tier = "standard"; complexity = 6; localSuitable = $true }
        refactor = @{ tier = "standard"; complexity = 6; localSuitable = $true }
        analysis = @{ tier = "standard"; complexity = 5; localSuitable = $true }
        database = @{ tier = "standard"; complexity = 5; localSuitable = $true }
        question = @{ tier = "lite"; complexity = 2; localSuitable = $true }
        creative = @{ tier = "pro"; complexity = 7; localSuitable = $false }
        general = @{ tier = "lite"; complexity = 3; localSuitable = $true }
    }

    $config = if ($tierMap.ContainsKey($category)) { $tierMap[$category] } else { $tierMap.general }

    # Adjust complexity for length
    $length = $Prompt.Length
    $complexity = $config.complexity
    if ($length -gt 1000) { $complexity = [Math]::Min(10, $complexity + 1) }
    if ($length -gt 2000) { $complexity = [Math]::Min(10, $complexity + 1) }

    $result = @{
        Category = $category
        Complexity = $complexity
        Tier = $config.tier
        LocalSuitable = $config.localSuitable
        ParallelSafe = $true
        EstimatedTokens = [int]($length / 4)
        Reasoning = "Pattern-based (SmartQueue internal)"
        ClassifierModel = "prompt-category"
        IsLocalClassifier = $true
        ClassifiedAt = Get-Date
        FromCache = $false
    }

    if ($ForQueue) {
        $result.QueuePriority = switch ($complexity) {
            { $_ -ge 8 } { 1 }  # High priority
            { $_ -ge 5 } { 2 }  # Normal
            default { 3 }       # Low
        }
        $result.PreferredProvider = if ($config.localSuitable) { "ollama" } else { "cloud" }
    }

    return $result
}

function Get-OptimalExecutionModelInternal {
    <#
    .SYNOPSIS
        Selects optimal execution model based on classification
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [hashtable]$Classification,
        [switch]$PreferLocal = $true
    )

    $tier = if ($Classification.Tier) { $Classification.Tier } else { "standard" }
    $localSuitable = if ($null -ne $Classification.LocalSuitable) { $Classification.LocalSuitable } else { $true }

    $tierModels = @{
        lite = @{ local = @("llama3.2:1b", "phi3:mini"); cloud = @("claude-3-5-haiku-20241022", "gpt-4o-mini") }
        standard = @{ local = @("llama3.2:3b", "qwen2.5-coder:1.5b"); cloud = @("claude-sonnet-4-5-20250929", "gpt-4o") }
        pro = @{ local = @("llama3.3:70b", "qwen2.5:32b"); cloud = @("claude-opus-4-5-20251101", "gpt-4o") }
    }

    $tierConfig = if ($tierModels.ContainsKey($tier)) { $tierModels[$tier] } else { $tierModels.standard }

    # Try local first
    if ($PreferLocal -and $localSuitable) {
        $localModel = Get-AvailableLocalModelInternal -PreferredModels $tierConfig.local
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
    $connStatus = Get-ConnectionStatusInternal
    if ($connStatus.InternetAvailable) {
        foreach ($cloudModel in $tierConfig.cloud) {
            $provider = if ($cloudModel -match 'claude') { "anthropic" } elseif ($cloudModel -match 'gpt') { "openai" } else { continue }
            $keyVar = if ($provider -eq "anthropic") { "ANTHROPIC_API_KEY" } else { "OPENAI_API_KEY" }
            if ([Environment]::GetEnvironmentVariable($keyVar)) {
                return @{
                    Provider = $provider
                    Model = $cloudModel
                    IsLocal = $false
                    Tier = $tier
                    Cost = 0.001
                }
            }
        }
    }

    # Last resort: any local model
    $anyLocal = Get-AvailableLocalModelInternal -PreferredModels @("llama3.2:1b", "phi3:mini")
    if ($anyLocal) {
        return @{
            Provider = "ollama"
            Model = $anyLocal
            IsLocal = $true
            Tier = "lite"
            Cost = 0
        }
    }

    return $null
}

#endregion

#region Auto Prompt Optimization

function Optimize-PromptAuto {
    <#
    .SYNOPSIS
        Automatically improves prompts using fast AI model
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Prompt,

        [switch]$UseAI,
        [string]$FastModel = 'llama3.2:1b'
    )

    $improved = $Prompt.Trim()
    $enhancements = @()

    # Rule-based improvements
    # 1. Add conciseness for short prompts
    if ($improved -notmatch '\?$' -and $improved.Length -lt 50) {
        $improved = "$improved. Be concise."
        $enhancements += "conciseness"
    }

    # 2. Detect code requests
    if ($improved -match '(write|create|implement|code|function|script)' -and
        $improved -notmatch 'format|markdown|code block') {
        $improved = "$improved Use proper code formatting with comments."
        $enhancements += "code-format"
    }

    # 3. Detect explanation requests
    if ($improved -match '(explain|what is|how does|why)' -and
        $improved -notmatch 'example') {
        $improved = "$improved Include a brief example."
        $enhancements += "example"
    }

    # 4. Detect comparison requests
    if ($improved -match '(compare|difference|vs|versus)') {
        $improved = "$improved Present as a comparison table."
        $enhancements += "table"
    }

    # 5. Language detection for code
    if ($improved -match '\b(python|javascript|typescript|rust|go|powershell|bash|sql|csharp)\b') {
        $lang = $Matches[1]
        $improved = "[$lang] $improved"
        $enhancements += "lang-tag"
    }

    # AI-powered improvement (optional)
    if ($UseAI) {
        try {
            $ollamaOnline = $false
            try {
                $tcp = New-Object System.Net.Sockets.TcpClient
                $tcp.Connect('localhost', 11434)
                $ollamaOnline = $tcp.Connected
                $tcp.Close()
            } catch { }

            if ($ollamaOnline) {
                $aiPrompt = "Improve this prompt for better AI response. Return ONLY the improved prompt (max 2 sentences):`n$Prompt"
                $body = @{
                    model = $FastModel
                    prompt = $aiPrompt
                    stream = $false
                    options = @{ num_predict = 100 }
                } | ConvertTo-Json

                $response = Invoke-RestMethod -Uri 'http://localhost:11434/api/generate' `
                    -Method Post -Body $body -ContentType 'application/json' -TimeoutSec 10

                if ($response.response -and $response.response.Length -gt 10) {
                    $improved = $response.response.Trim()
                    $enhancements += "AI-enhanced"
                }
            }
        } catch { }
    }

    return @{
        Original = $Prompt
        Optimized = $improved
        Enhancements = $enhancements
        Changed = $Prompt -ne $improved
    }
}

function Get-PromptComplexity {
    <#
    .SYNOPSIS
        Analyzes prompt complexity for smart routing
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Prompt
    )

    $wordCount = ($Prompt -split '\s+').Count
    $hasCode = $Prompt -match '(function|class|def |import |require|const |let |var |\{|\})'
    $hasMultiStep = $Prompt -match '(first|then|after|finally|step|1\.|2\.|3\.)'
    $hasAnalysis = $Prompt -match '(analyze|compare|explain|review|debug|optimize)'

    $score = 0
    $score += [math]::Min($wordCount / 10, 5)
    if ($hasCode) { $score += 3 }
    if ($hasMultiStep) { $score += 2 }
    if ($hasAnalysis) { $score += 2 }

    $complexity = switch ($score) {
        { $_ -le 3 }  { 'simple' }
        { $_ -le 6 }  { 'medium' }
        { $_ -le 9 }  { 'complex' }
        default       { 'advanced' }
    }

    return @{
        Complexity = $complexity
        Score = [math]::Round($score, 1)
        WordCount = $wordCount
        HasCode = $hasCode
        HasMultiStep = $hasMultiStep
        RecommendedModel = switch ($complexity) {
            'simple'   { 'llama3.2:1b' }
            'medium'   { 'llama3.2:3b' }
            'complex'  { 'qwen2.5-coder:1.5b' }
            'advanced' { 'phi3:mini' }
        }
    }
}

#endregion

#region Queue Management

function Add-ToSmartQueue {
    <#
    .SYNOPSIS
        Adds prompt to smart queue with AI classification
    .PARAMETER Prompt
        The prompt to queue
    .PARAMETER Priority
        Override priority (1=high, 2=normal, 3=low)
    .PARAMETER Tag
        Optional tag for grouping
    .PARAMETER Callback
        ScriptBlock to call on completion
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [string]$Prompt,

        [ValidateSet("high", "normal", "low", 1, 2, 3)]
        $Priority = "normal",

        [string]$Tag = "default",

        [scriptblock]$Callback,

        [switch]$SkipClassification
    )

    process {
        $id = [guid]::NewGuid().ToString().Substring(0, 8)

        # Convert string priority to int
        $priorityInt = switch ($Priority) {
            "high" { 1 }
            "normal" { 2 }
            "low" { 3 }
            1 { 1 }
            2 { 2 }
            3 { 3 }
            default { 0 }  # 0 means use classification-based priority
        }

        # Classify prompt using internal classification (uses Get-PromptCategory from PromptOptimizer)
        $classification = $null
        if (-not $SkipClassification) {
            Write-Host "[Queue] Classifying prompt $id..." -ForegroundColor Cyan
            $classification = Get-InternalClassification -Prompt $Prompt -ForQueue
        }

        # Build queue item
        $item = @{
            Id = $id
            Prompt = $Prompt
            Priority = if ($priorityInt -gt 0) { $priorityInt }
                      elseif ($classification -and $classification.QueuePriority) { $classification.QueuePriority }
                      else { 2 }
            Classification = $classification
            Tag = $Tag
            Callback = $Callback
            Status = "queued"
            QueuedAt = Get-Date
            Attempts = 0
            Result = $null
            Error = $null
        }

        # Add to queue
        $script:Queue.Enqueue($item)
        $script:QueueStats.TotalQueued++

        $tierLabel = if ($classification) { $classification.Tier } else { "unknown" }
        $localLabel = if ($classification -and $classification.LocalSuitable) { "LOCAL" } else { "CLOUD" }

        Write-Host "[Queue] Added #$id | Priority: $($item.Priority) | Tier: $tierLabel | Target: $localLabel" -ForegroundColor Green

        return $id
    }
}

function Add-BatchToSmartQueue {
    <#
    .SYNOPSIS
        Adds multiple prompts to queue efficiently
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string[]]$Prompts,
        
        [string]$Tag = "batch",
        
        [switch]$ClassifyInParallel
    )
    
    $batchId = [guid]::NewGuid().ToString().Substring(0, 8)
    $ids = @()
    
    Write-Host "[Queue] Adding batch of $($Prompts.Count) prompts (batch: $batchId)..." -ForegroundColor Cyan
    
    if ($ClassifyInParallel -and $Prompts.Count -gt 1) {
        # Parallel classification
        $classified = Invoke-ParallelClassification -Prompts $Prompts
        
        for ($i = 0; $i -lt $Prompts.Count; $i++) {
            $item = @{
                Id = "$batchId-$i"
                Prompt = $Prompts[$i]
                Priority = $classified[$i].QueuePriority
                Classification = $classified[$i]
                Tag = $Tag
                BatchId = $batchId
                Status = "queued"
                QueuedAt = Get-Date
                Attempts = 0
            }
            $script:Queue.Enqueue($item)
            $ids += $item.Id
        }
    } else {
        # Sequential
        foreach ($prompt in $Prompts) {
            $id = Add-ToSmartQueue -Prompt $prompt -Tag $Tag
            $ids += $id
        }
    }
    
    $script:QueueStats.TotalQueued += $Prompts.Count
    Write-Host "[Queue] Batch $batchId added: $($ids.Count) items" -ForegroundColor Green
    
    return @{
        BatchId = $batchId
        ItemIds = $ids
        Count = $ids.Count
    }
}

function Get-QueueStatus {
    <#
    .SYNOPSIS
        Returns current queue status
    #>
    [CmdletBinding()]
    param()
    
    $pending = $script:Queue.Count
    $active = $script:ActiveJobs.Count
    $completed = $script:CompletedResults.Count
    
    return @{
        Pending = $pending
        Active = $active
        Completed = $completed
        Failed = $script:QueueStats.TotalFailed
        TotalQueued = $script:QueueStats.TotalQueued
        LocalExecutions = $script:QueueStats.LocalExecutions
        CloudExecutions = $script:QueueStats.CloudExecutions
        ActiveJobs = $script:ActiveJobs.Keys | ForEach-Object { $script:ActiveJobs[$_].Id }
    }
}

#endregion

#region Parallel Execution

function Start-QueueProcessor {
    <#
    .SYNOPSIS
        Starts processing queue with parallel execution
    .PARAMETER MaxParallel
        Maximum concurrent executions
    .PARAMETER ProcessCurrent
        Also process the current/immediate prompt in parallel
    .PARAMETER WaitForCompletion
        Wait for all items to complete
    #>
    [CmdletBinding()]
    param(
        [int]$MaxParallel = $script:QueueConfig.MaxConcurrentTotal,
        [switch]$WaitForCompletion,
        [hashtable]$CurrentPrompt
    )
    
    if ($script:Queue.Count -eq 0 -and -not $CurrentPrompt) {
        Write-Host "[Queue] Queue is empty" -ForegroundColor Yellow
        return
    }
    
    $script:QueueStats.StartTime = Get-Date
    Write-Host "[Queue] Starting processor (max parallel: $MaxParallel)..." -ForegroundColor Cyan
    
    # Check connection status using internal function
    $connStatus = Get-ConnectionStatusInternal
    Write-Host "[Queue] Mode: $($connStatus.Mode) | Ollama: $($connStatus.OllamaAvailable) | Internet: $($connStatus.InternetAvailable)" -ForegroundColor Gray
    
    # If current prompt provided, add it with highest priority
    if ($CurrentPrompt) {
        $currentItem = @{
            Id = "current-" + [guid]::NewGuid().ToString().Substring(0, 4)
            Prompt = $CurrentPrompt.Prompt
            Priority = 0  # Highest
            Classification = $CurrentPrompt.Classification
            Status = "queued"
            QueuedAt = Get-Date
            IsCurrent = $true
        }
        
        # Insert at front (create new queue with current first)
        $tempItems = @($currentItem)
        while ($script:Queue.TryDequeue([ref]$null)) {
            $item = $null
            if ($script:Queue.TryDequeue([ref]$item)) {
                $tempItems += $item
            }
        }
        foreach ($item in $tempItems) {
            $script:Queue.Enqueue($item)
        }
    }
    
    # Create runspace pool
    $iss = [System.Management.Automation.Runspaces.InitialSessionState]::CreateDefault()
    $runspacePool = [runspacefactory]::CreateRunspacePool(1, $MaxParallel)
    $runspacePool.Open()
    
    $jobs = @{}
    $localCount = 0
    $cloudCount = 0
    
    try {
        while ($script:Queue.Count -gt 0 -or $jobs.Count -gt 0) {
            
            # Start new jobs if capacity available
            while ($jobs.Count -lt $MaxParallel -and $script:Queue.Count -gt 0) {
                $item = $null
                if (-not $script:Queue.TryDequeue([ref]$item)) { break }
                
                # Determine execution model using internal functions
                $execModel = $null
                if ($item.Classification) {
                    $execModel = Get-OptimalExecutionModelInternal -Classification $item.Classification -PreferLocal
                }

                if (-not $execModel) {
                    # Fallback model selection using internal function
                    $localModel = Get-AvailableLocalModelInternal
                    if ($localModel) {
                        $execModel = @{ Provider = "ollama"; Model = $localModel; IsLocal = $true }
                    } elseif ($connStatus.InternetAvailable) {
                        $execModel = @{ Provider = "anthropic"; Model = "claude-3-5-haiku-20241022"; IsLocal = $false }
                    }
                }
                
                if (-not $execModel) {
                    Write-Warning "[Queue] No model available for item $($item.Id)"
                    $item.Status = "failed"
                    $item.Error = "No model available"
                    $script:QueueStats.TotalFailed++
                    continue
                }
                
                # Check concurrency limits
                if ($execModel.IsLocal) {
                    if ($localCount -ge $script:QueueConfig.MaxConcurrentLocal) {
                        # Re-queue and wait
                        $script:Queue.Enqueue($item)
                        Start-Sleep -Milliseconds 100
                        continue
                    }
                    $localCount++
                } else {
                    if ($cloudCount -ge $script:QueueConfig.MaxConcurrentCloud) {
                        $script:Queue.Enqueue($item)
                        Start-Sleep -Milliseconds 100
                        continue
                    }
                    $cloudCount++
                }
                
                $item.Status = "running"
                $item.StartedAt = Get-Date
                $item.ExecutionModel = $execModel
                $script:ActiveJobs[$item.Id] = $item
                
                $providerLabel = if ($execModel.IsLocal) { "LOCAL" } else { "CLOUD" }
                Write-Host "[Queue] Starting #$($item.Id) on $providerLabel $($execModel.Provider)/$($execModel.Model)" -ForegroundColor $(if ($execModel.IsLocal) { "Green" } else { "Cyan" })
                
                # Create PowerShell instance
                $ps = [powershell]::Create()
                $ps.RunspacePool = $runspacePool
                
                $scriptBlock = {
                    param($ModulePath, $Provider, $Model, $Prompt, $MaxTokens)
                    
                    Import-Module $ModulePath -Force
                    
                    $messages = @(@{ role = "user"; content = $Prompt })
                    
                    try {
                        $response = Invoke-AIRequest `
                            -Provider $Provider `
                            -Model $Model `
                            -Messages $messages `
                            -MaxTokens $MaxTokens `
                            -NoOptimize `
                            -ErrorAction Stop
                        
                        return @{
                            Success = $true
                            Content = $response.content
                            Usage = $response.usage
                            Provider = $Provider
                            Model = $Model
                        }
                    } catch {
                        return @{
                            Success = $false
                            Error = $_.Exception.Message
                            Provider = $Provider
                            Model = $Model
                        }
                    }
                }
                
                [void]$ps.AddScript($scriptBlock)
                [void]$ps.AddParameter("ModulePath", $aiHandlerPath)
                [void]$ps.AddParameter("Provider", $execModel.Provider)
                [void]$ps.AddParameter("Model", $execModel.Model)
                [void]$ps.AddParameter("Prompt", $item.Prompt)
                [void]$ps.AddParameter("MaxTokens", 4096)
                
                $handle = $ps.BeginInvoke()
                
                $jobs[$item.Id] = @{
                    PowerShell = $ps
                    Handle = $handle
                    Item = $item
                    IsLocal = $execModel.IsLocal
                }
            }
            
            # Check completed jobs
            $completedIds = @()
            foreach ($jobId in $jobs.Keys) {
                $job = $jobs[$jobId]
                if ($job.Handle.IsCompleted) {
                    $completedIds += $jobId
                    
                    try {
                        $result = $job.PowerShell.EndInvoke($job.Handle)
                        $item = $job.Item
                        $item.CompletedAt = Get-Date
                        $item.Duration = ($item.CompletedAt - $item.StartedAt).TotalSeconds
                        
                        if ($result -and $result.Success) {
                            $item.Status = "completed"
                            $item.Result = $result.Content
                            $item.Usage = $result.Usage
                            $script:QueueStats.TotalCompleted++
                            
                            if ($job.IsLocal) { 
                                $script:QueueStats.LocalExecutions++ 
                            } else { 
                                $script:QueueStats.CloudExecutions++ 
                            }
                            
                            Write-Host "[Queue] Completed #$($item.Id) in $([math]::Round($item.Duration, 1))s" -ForegroundColor Green
                            
                            # Execute callback if provided
                            if ($item.Callback) {
                                try {
                                    & $item.Callback $item
                                } catch {
                                    Write-Warning "[Queue] Callback error: $($_.Exception.Message)"
                                }
                            }
                        } else {
                            $item.Status = "failed"
                            $item.Error = $result.Error
                            $script:QueueStats.TotalFailed++
                            Write-Warning "[Queue] Failed #$($item.Id): $($result.Error)"
                        }
                        
                        [void]$script:CompletedResults.Add($item)
                        
                    } catch {
                        $item.Status = "failed"
                        $item.Error = $_.Exception.Message
                        $script:QueueStats.TotalFailed++
                    } finally {
                        $job.PowerShell.Dispose()
                        [void]$script:ActiveJobs.TryRemove($jobId, [ref]$null)
                        
                        if ($job.IsLocal) { $localCount-- } else { $cloudCount-- }
                    }
                }
            }
            
            foreach ($id in $completedIds) {
                $jobs.Remove($id)
            }
            
            # Brief sleep to prevent CPU spinning
            if ($jobs.Count -gt 0 -or $script:Queue.Count -gt 0) {
                Start-Sleep -Milliseconds 50
            }
        }
        
    } finally {
        $runspacePool.Close()
        $runspacePool.Dispose()
    }
    
    # Summary
    $elapsed = ((Get-Date) - $script:QueueStats.StartTime).TotalSeconds
    Write-Host "`n[Queue] Processing complete!" -ForegroundColor Cyan
    Write-Host "  Total: $($script:QueueStats.TotalCompleted) completed, $($script:QueueStats.TotalFailed) failed" -ForegroundColor White
    Write-Host "  Local: $($script:QueueStats.LocalExecutions) | Cloud: $($script:QueueStats.CloudExecutions)" -ForegroundColor Gray
    Write-Host "  Time: $([math]::Round($elapsed, 1))s" -ForegroundColor Gray
    
    return $script:CompletedResults
}

function Invoke-ParallelClassification {
    <#
    .SYNOPSIS
        Classifies multiple prompts in parallel using internal classification
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string[]]$Prompts,

        [int]$MaxParallel = 4
    )

    Write-Host "[Queue] Classifying $($Prompts.Count) prompts in parallel..." -ForegroundColor Cyan

    $results = [System.Collections.ArrayList]::new()

    # Use runspace pool for parallel classification
    $iss = [System.Management.Automation.Runspaces.InitialSessionState]::CreateDefault()
    $runspacePool = [runspacefactory]::CreateRunspacePool(1, $MaxParallel)
    $runspacePool.Open()

    $jobs = @()

    # Get paths for modules needed in runspaces
    $promptOptimizerPathLocal = $promptOptimizerPath

    try {
        foreach ($prompt in $Prompts) {
            $ps = [powershell]::Create()
            $ps.RunspacePool = $runspacePool

            # Use inline classification with Get-PromptCategory from PromptOptimizer
            [void]$ps.AddScript({
                param($PromptOptimizerPath, $Prompt)

                # Import PromptOptimizer for Get-PromptCategory
                if (Test-Path $PromptOptimizerPath) {
                    Import-Module $PromptOptimizerPath -Force
                }

                # Classify using Get-PromptCategory
                $category = "general"
                if (Get-Command Get-PromptCategory -ErrorAction SilentlyContinue) {
                    $category = Get-PromptCategory -Prompt $Prompt
                } else {
                    $promptLower = $Prompt.ToLower()
                    if ($promptLower -match '(write|implement|function|code|script)') { $category = "code" }
                    elseif ($promptLower -match '(analyze|compare|explain)') { $category = "analysis" }
                    elseif ($promptLower -match '(sql|query|database)') { $category = "database" }
                    elseif ($promptLower -match '(what is|who|when|where)') { $category = "question" }
                }

                # Map category to tier and complexity
                $tierMap = @{
                    code = @{ tier = "standard"; complexity = 5; localSuitable = $true }
                    debug = @{ tier = "standard"; complexity = 6; localSuitable = $true }
                    analysis = @{ tier = "standard"; complexity = 5; localSuitable = $true }
                    database = @{ tier = "standard"; complexity = 5; localSuitable = $true }
                    question = @{ tier = "lite"; complexity = 2; localSuitable = $true }
                    creative = @{ tier = "pro"; complexity = 7; localSuitable = $false }
                    general = @{ tier = "lite"; complexity = 3; localSuitable = $true }
                }

                $config = if ($tierMap.ContainsKey($category)) { $tierMap[$category] } else { $tierMap.general }
                $length = $Prompt.Length
                $complexity = $config.complexity
                if ($length -gt 1000) { $complexity = [Math]::Min(10, $complexity + 1) }

                @{
                    Category = $category
                    Complexity = $complexity
                    Tier = $config.tier
                    LocalSuitable = $config.localSuitable
                    ParallelSafe = $true
                    EstimatedTokens = [int]($length / 4)
                    QueuePriority = switch ($complexity) { { $_ -ge 8 } { 1 }; { $_ -ge 5 } { 2 }; default { 3 } }
                    PreferredProvider = if ($config.localSuitable) { "ollama" } else { "cloud" }
                    ClassifiedAt = Get-Date
                }
            })
            [void]$ps.AddParameter("PromptOptimizerPath", $promptOptimizerPathLocal)
            [void]$ps.AddParameter("Prompt", $prompt)

            $jobs += @{
                PowerShell = $ps
                Handle = $ps.BeginInvoke()
                Prompt = $prompt
            }
        }

        # Collect results
        foreach ($job in $jobs) {
            try {
                $result = $job.PowerShell.EndInvoke($job.Handle)
                [void]$results.Add($result)
            } catch {
                # Fallback classification using internal function
                [void]$results.Add((Get-InternalClassification -Prompt $job.Prompt -ForQueue))
            } finally {
                $job.PowerShell.Dispose()
            }
        }

    } finally {
        $runspacePool.Close()
        $runspacePool.Dispose()
    }

    return $results
}

#endregion

#region Results

function Get-QueueResults {
    <#
    .SYNOPSIS
        Returns completed results
    #>
    [CmdletBinding()]
    param(
        [string]$Tag,
        [string]$BatchId,
        [switch]$SuccessOnly,
        [switch]$FailedOnly
    )
    
    $results = $script:CompletedResults
    
    if ($Tag) { $results = $results | Where-Object { $_.Tag -eq $Tag } }
    if ($BatchId) { $results = $results | Where-Object { $_.BatchId -eq $BatchId } }
    if ($SuccessOnly) { $results = $results | Where-Object { $_.Status -eq "completed" } }
    if ($FailedOnly) { $results = $results | Where-Object { $_.Status -eq "failed" } }
    
    return $results
}

function Clear-QueueResults {
    [CmdletBinding()]
    param()

    $count = $script:CompletedResults.Count
    $script:CompletedResults.Clear()
    $script:QueueStats = @{
        TotalQueued = 0; TotalCompleted = 0; TotalFailed = 0
        LocalExecutions = 0; CloudExecutions = 0; StartTime = $null
    }
    Write-Host "[Queue] Cleared $count results" -ForegroundColor Yellow
}

function Clear-SmartQueue {
    <#
    .SYNOPSIS
        Clears all items from the queue and resets state
    #>
    [CmdletBinding()]
    param()

    # Clear the queue
    while ($script:Queue.TryDequeue([ref]$null)) { }

    # Clear active jobs
    $script:ActiveJobs.Clear()

    # Clear results
    Clear-QueueResults

    Write-Host "[Queue] Queue cleared and reset" -ForegroundColor Yellow
}

function Get-SmartQueueStatus {
    <#
    .SYNOPSIS
        Alias for Get-QueueStatus for naming consistency
    #>
    [CmdletBinding()]
    param()
    Get-QueueStatus
}

function Get-QueueConnectionStatus {
    <#
    .SYNOPSIS
        Returns connection status for queue operations
    .DESCRIPTION
        Public wrapper for internal connection status check.
        Uses AIUtil-Health.psm1 when available, falls back to inline implementation.
    #>
    [CmdletBinding()]
    param()
    Get-ConnectionStatusInternal
}

#endregion

Export-ModuleMember -Function @(
    'Optimize-PromptAuto',
    'Get-PromptComplexity',
    'Add-ToSmartQueue',
    'Add-BatchToSmartQueue',
    'Get-QueueStatus',
    'Get-SmartQueueStatus',
    'Get-QueueConnectionStatus',
    'Start-QueueProcessor',
    'Invoke-ParallelClassification',
    'Get-QueueResults',
    'Clear-QueueResults',
    'Clear-SmartQueue'
)

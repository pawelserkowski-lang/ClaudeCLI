# =============================================================================
# AGENT SWARM v3.0 - 12 Witcher Agents with Parallel Execution
# Based on HYDRA 10.4 Gemini CLI - Ported to ClaudeHYDRA
# =============================================================================

# === AGENT DEFINITIONS (School of the Wolf) ===
$script:AgentModels = @{
    "Ciri"     = "llama3.2:1b"           # Fastest - simple tasks
    "Regis"    = "phi3:mini"             # Analytical - deep research
    "Yennefer" = "qwen2.5-coder:1.5b"    # Code - architecture
    "Triss"    = "qwen2.5-coder:1.5b"    # Code - testing
    "Lambert"  = "qwen2.5-coder:1.5b"    # Code - debug
    "Philippa" = "qwen2.5-coder:1.5b"    # Code - integrations
    "Geralt"   = "llama3.2:3b"           # General - security/ops
    "Jaskier"  = "llama3.2:3b"           # General - docs
    "Vesemir"  = "llama3.2:3b"           # General - review
    "Eskel"    = "llama3.2:3b"           # General - DevOps
    "Zoltan"   = "llama3.2:3b"           # General - data
    "Dijkstra" = "llama3.2:3b"           # General - planning
}

$script:AgentPersonas = @{
    "Geralt"   = @{ Name = "White Wolf";  Role = "Security/Ops";        Focus = "System commands, security checks" }
    "Yennefer" = @{ Name = "Sorceress";   Role = "Architecture/Code";   Focus = "Main code implementation" }
    "Triss"    = @{ Name = "Healer";      Role = "QA/Testing";          Focus = "Tests, validation, bug fixes" }
    "Jaskier"  = @{ Name = "Bard";        Role = "Docs/Communication";  Focus = "Documentation, logs, reports" }
    "Vesemir"  = @{ Name = "Mentor";      Role = "Mentoring/Review";    Focus = "Code review, best practices" }
    "Ciri"     = @{ Name = "Prodigy";     Role = "Speed/Quick";         Focus = "Fast simple tasks" }
    "Eskel"    = @{ Name = "Pragmatist";  Role = "DevOps/Infrastructure"; Focus = "CI/CD, deployment" }
    "Lambert"  = @{ Name = "Skeptic";     Role = "Debugging/Profiling"; Focus = "Debug, performance" }
    "Zoltan"   = @{ Name = "Craftsman";   Role = "Data/Database";       Focus = "Data operations, DB" }
    "Regis"    = @{ Name = "Sage";        Role = "Research/Analysis";   Focus = "Deep analysis, research" }
    "Dijkstra" = @{ Name = "Spymaster";   Role = "Planning/Strategy";   Focus = "Strategic planning" }
    "Philippa" = @{ Name = "Strategist";  Role = "Integration/API";     Focus = "External APIs" }
}

# === SWARM STATE ===
$script:SwarmState = @{
    YoloMode = $false
    MaxConcurrency = 5
    TimeoutSeconds = 60
    Results = @{}
    StartTime = $null
}

# === YOLO MODE CONFIG ===
$script:YoloConfig = @{
    Standard = @{
        Concurrency = 5
        Timeout = 60
        Retries = 3
        RiskBlocking = $true
    }
    Yolo = @{
        Concurrency = 10
        Timeout = 15
        Retries = 1
        RiskBlocking = $false
    }
}

<#
.SYNOPSIS
    Get the Ollama model assigned to a specific agent.
#>
function Get-AgentModel {
    param([string]$Agent)

    if ($script:AgentModels.ContainsKey($Agent)) {
        return $script:AgentModels[$Agent]
    }
    return "llama3.2:3b"  # Default fallback
}

<#
.SYNOPSIS
    Get agent persona information.
#>
function Get-AgentPersona {
    param([string]$Agent)

    if ($script:AgentPersonas.ContainsKey($Agent)) {
        return $script:AgentPersonas[$Agent]
    }
    return @{ Name = "Unknown"; Role = "General"; Focus = "Various tasks" }
}

<#
.SYNOPSIS
    Enable or disable YOLO mode.
#>
function Set-YoloMode {
    param([switch]$Enable, [switch]$Disable)

    if ($Enable) {
        $script:SwarmState.YoloMode = $true
        $script:SwarmState.MaxConcurrency = $script:YoloConfig.Yolo.Concurrency
        $script:SwarmState.TimeoutSeconds = $script:YoloConfig.Yolo.Timeout
        Write-Host "[YOLO] Mode ENABLED - Fast & Dangerous" -ForegroundColor Red
    }
    elseif ($Disable) {
        $script:SwarmState.YoloMode = $false
        $script:SwarmState.MaxConcurrency = $script:YoloConfig.Standard.Concurrency
        $script:SwarmState.TimeoutSeconds = $script:YoloConfig.Standard.Timeout
        Write-Host "[SAFE] Standard mode enabled" -ForegroundColor Green
    }

    return $script:SwarmState.YoloMode
}

<#
.SYNOPSIS
    Get current YOLO mode status.
#>
function Get-YoloStatus {
    return @{
        YoloMode = $script:SwarmState.YoloMode
        Concurrency = $script:SwarmState.MaxConcurrency
        Timeout = $script:SwarmState.TimeoutSeconds
        Config = if ($script:SwarmState.YoloMode) { $script:YoloConfig.Yolo } else { $script:YoloConfig.Standard }
    }
}

<#
.SYNOPSIS
    Select best agent(s) for a given task.
#>
function Select-AgentForTask {
    param(
        [string]$Task,
        [switch]$Multiple
    )

    $taskLower = $Task.ToLower()
    $selectedAgents = @()

    # Task routing logic
    switch -Regex ($taskLower) {
        'security|audit|scan|vulnerability' { $selectedAgents += "Geralt" }
        'code|implement|function|class|write' { $selectedAgents += "Yennefer" }
        'test|validate|qa|spec|assert' { $selectedAgents += "Triss" }
        'doc|readme|comment|explain|log' { $selectedAgents += "Jaskier" }
        'review|improve|refactor|best.?practice' { $selectedAgents += "Vesemir" }
        'quick|fast|simple|trivial' { $selectedAgents += "Ciri" }
        'deploy|ci|cd|docker|infra|devops' { $selectedAgents += "Eskel" }
        'debug|profile|perf|optimize|slow' { $selectedAgents += "Lambert" }
        'data|database|sql|migration|query' { $selectedAgents += "Zoltan" }
        'research|analyze|investigate|deep' { $selectedAgents += "Regis" }
        'plan|strategy|coordinate|roadmap' { $selectedAgents += "Dijkstra" }
        'api|integration|external|http|rest' { $selectedAgents += "Philippa" }
    }

    # Default to Geralt if no match
    if ($selectedAgents.Count -eq 0) {
        $selectedAgents += "Geralt"
    }

    if ($Multiple) {
        return $selectedAgents | Select-Object -Unique
    }
    return $selectedAgents[0]
}

<#
.SYNOPSIS
    Execute a single agent task via Ollama.
#>
function Invoke-AgentTask {
    param(
        [string]$Agent,
        [string]$Task,
        [int]$TimeoutSeconds = 60
    )

    $model = Get-AgentModel -Agent $Agent
    $persona = Get-AgentPersona -Agent $Agent

    # Build system prompt with persona
    $systemPrompt = @"
You are $Agent ($($persona.Name)), a $($persona.Role) specialist.
Your focus: $($persona.Focus)
Respond concisely and professionally. Be direct.
"@

    try {
        $body = @{
            model = $model
            messages = @(
                @{ role = "system"; content = $systemPrompt }
                @{ role = "user"; content = $Task }
            )
            stream = $false
        } | ConvertTo-Json -Depth 10

        $response = Invoke-RestMethod -Uri "http://localhost:11434/api/chat" `
            -Method Post -Body $body -ContentType "application/json" `
            -TimeoutSec $TimeoutSeconds

        return @{
            Agent = $Agent
            Model = $model
            Success = $true
            Response = $response.message.content
            Tokens = @{
                Prompt = $response.prompt_eval_count
                Completion = $response.eval_count
            }
        }
    }
    catch {
        return @{
            Agent = $Agent
            Model = $model
            Success = $false
            Error = $_.Exception.Message
        }
    }
}

<#
.SYNOPSIS
    Execute multiple agent tasks in parallel using RunspacePool.
#>
function Invoke-ParallelAgentTasks {
    param(
        [array]$Tasks,  # Array of @{ Agent = "Name"; Task = "Description" }
        [int]$MaxConcurrency = $script:SwarmState.MaxConcurrency,
        [int]$TimeoutSeconds = $script:SwarmState.TimeoutSeconds
    )

    if ($Tasks.Count -eq 0) { return @() }

    Write-Host "[SWARM] Executing $($Tasks.Count) tasks with $MaxConcurrency concurrent workers" -ForegroundColor Cyan

    # Create RunspacePool
    $runspacePool = [runspacefactory]::CreateRunspacePool(1, $MaxConcurrency)
    $runspacePool.Open()

    $jobs = @()
    $results = @()

    # Script block for each task
    $scriptBlock = {
        param($Agent, $Task, $Model, $Persona, $Timeout)

        $systemPrompt = "You are $Agent ($($Persona.Name)), a $($Persona.Role) specialist. Focus: $($Persona.Focus). Be concise."

        try {
            $body = @{
                model = $Model
                messages = @(
                    @{ role = "system"; content = $systemPrompt }
                    @{ role = "user"; content = $Task }
                )
                stream = $false
            } | ConvertTo-Json -Depth 10

            $response = Invoke-RestMethod -Uri "http://localhost:11434/api/chat" `
                -Method Post -Body $body -ContentType "application/json" `
                -TimeoutSec $Timeout

            return @{
                Agent = $Agent
                Model = $Model
                Success = $true
                Response = $response.message.content
            }
        }
        catch {
            return @{
                Agent = $Agent
                Model = $Model
                Success = $false
                Error = $_.Exception.Message
            }
        }
    }

    # Start all tasks
    foreach ($taskItem in $Tasks) {
        $agent = $taskItem.Agent
        $task = $taskItem.Task
        $model = Get-AgentModel -Agent $agent
        $persona = Get-AgentPersona -Agent $agent

        $powershell = [powershell]::Create().AddScript($scriptBlock)
        $powershell.AddParameter("Agent", $agent)
        $powershell.AddParameter("Task", $task)
        $powershell.AddParameter("Model", $model)
        $powershell.AddParameter("Persona", $persona)
        $powershell.AddParameter("Timeout", $TimeoutSeconds)
        $powershell.RunspacePool = $runspacePool

        $jobs += @{
            PowerShell = $powershell
            Handle = $powershell.BeginInvoke()
            Agent = $agent
        }

        Write-Host "  [$agent] Started with $model" -ForegroundColor DarkGray
    }

    # Wait for all to complete
    foreach ($job in $jobs) {
        try {
            $result = $job.PowerShell.EndInvoke($job.Handle)
            $results += $result

            $status = if ($result.Success) { "[OK]" } else { "[FAIL]" }
            $color = if ($result.Success) { "Green" } else { "Red" }
            Write-Host "  $($job.Agent) $status" -ForegroundColor $color
        }
        catch {
            $results += @{
                Agent = $job.Agent
                Success = $false
                Error = $_.Exception.Message
            }
        }
        finally {
            $job.PowerShell.Dispose()
        }
    }

    $runspacePool.Close()
    $runspacePool.Dispose()

    return $results
}

<#
.SYNOPSIS
    Main 6-Step Swarm Protocol.

.DESCRIPTION
    1. Speculate - Gather context (Flash + Search)
    2. Plan - Create task plan (Pro/Deep Thinking)
    3. Execute - Run agents in parallel (Ollama)
    4. Synthesize - Merge results (Pro)
    5. Log - Create summary (Flash)
    6. Archive - Save transcript
#>
function Invoke-AgentSwarm {
    param(
        [Parameter(Mandatory)]
        [string]$Query,

        [string[]]$Agents,  # Specific agents to use, or auto-select

        [switch]$SkipSpeculate,
        [switch]$SkipArchive,
        [switch]$ShowDetails
    )

    $script:SwarmState.StartTime = Get-Date
    $swarmId = [guid]::NewGuid().ToString().Substring(0, 8)

    Write-Host ""
    Write-Host "=" * 60 -ForegroundColor DarkCyan
    Write-Host "  AGENT SWARM [$swarmId]" -ForegroundColor Cyan
    Write-Host "  Query: $($Query.Substring(0, [Math]::Min(50, $Query.Length)))..." -ForegroundColor DarkGray
    Write-Host "=" * 60 -ForegroundColor DarkCyan
    Write-Host ""

    $results = @{
        SwarmId = $swarmId
        Query = $Query
        Steps = @{}
        FinalAnswer = $null
        Duration = $null
    }

    # === STEP 1: SPECULATE ===
    if (-not $SkipSpeculate) {
        Write-Host "[1/6] SPECULATE - Gathering context..." -ForegroundColor Yellow
        $speculateResult = Invoke-AgentTask -Agent "Regis" -Task "Research and provide context for: $Query"
        $results.Steps["Speculate"] = $speculateResult
        if ($ShowDetails -and $speculateResult.Success) {
            Write-Host "  Context gathered: $($speculateResult.Response.Substring(0, [Math]::Min(100, $speculateResult.Response.Length)))..." -ForegroundColor DarkGray
        }
    }

    # === STEP 2: PLAN ===
    Write-Host "[2/6] PLAN - Creating task breakdown..." -ForegroundColor Yellow
    $planPrompt = @"
Break down this task into subtasks for specialized agents:
Query: $Query

Available agents:
- Yennefer (code), Triss (testing), Lambert (debug), Philippa (API)
- Geralt (security), Eskel (DevOps), Zoltan (data)
- Jaskier (docs), Vesemir (review), Regis (research), Dijkstra (planning)
- Ciri (quick simple tasks)

Return a JSON array of tasks: [{"agent": "Name", "task": "Description"}]
"@

    $planResult = Invoke-AgentTask -Agent "Dijkstra" -Task $planPrompt
    $results.Steps["Plan"] = $planResult

    # Parse plan or use provided agents
    $taskList = @()
    if ($Agents -and $Agents.Count -gt 0) {
        foreach ($agent in $Agents) {
            $taskList += @{ Agent = $agent; Task = $Query }
        }
    }
    elseif ($planResult.Success) {
        try {
            # Try to extract JSON from response
            $jsonMatch = [regex]::Match($planResult.Response, '\[.*\]', [System.Text.RegularExpressions.RegexOptions]::Singleline)
            if ($jsonMatch.Success) {
                $parsed = $jsonMatch.Value | ConvertFrom-Json
                foreach ($item in $parsed) {
                    $taskList += @{ Agent = $item.agent; Task = $item.task }
                }
            }
        }
        catch {
            # Fallback: auto-select single agent
            $autoAgent = Select-AgentForTask -Task $Query
            $taskList += @{ Agent = $autoAgent; Task = $Query }
        }
    }

    if ($taskList.Count -eq 0) {
        $autoAgent = Select-AgentForTask -Task $Query
        $taskList += @{ Agent = $autoAgent; Task = $Query }
    }

    Write-Host "  Tasks planned: $($taskList.Count)" -ForegroundColor DarkGray

    # === STEP 3: EXECUTE (Parallel) ===
    Write-Host "[3/6] EXECUTE - Running agents in parallel..." -ForegroundColor Yellow
    $executeResults = Invoke-ParallelAgentTasks -Tasks $taskList
    $results.Steps["Execute"] = $executeResults

    # === STEP 4: SYNTHESIZE ===
    Write-Host "[4/6] SYNTHESIZE - Merging results..." -ForegroundColor Yellow
    $successfulResults = $executeResults | Where-Object { $_.Success }

    if ($successfulResults.Count -gt 0) {
        $synthesizePrompt = @"
Synthesize these agent responses into a coherent final answer:

Original Query: $Query

Agent Responses:
$($successfulResults | ForEach-Object { "[$($_.Agent)]: $($_.Response)" } | Out-String)

Provide a unified, comprehensive answer.
"@

        $synthesizeResult = Invoke-AgentTask -Agent "Vesemir" -Task $synthesizePrompt
        $results.Steps["Synthesize"] = $synthesizeResult
        $results.FinalAnswer = $synthesizeResult.Response
    }
    else {
        $results.FinalAnswer = "No successful agent responses to synthesize."
    }

    # === STEP 5: LOG ===
    Write-Host "[5/6] LOG - Creating summary..." -ForegroundColor Yellow
    $logPrompt = "Create a brief 2-3 sentence summary of this task completion: $Query"
    $logResult = Invoke-AgentTask -Agent "Jaskier" -Task $logPrompt -TimeoutSeconds 30
    $results.Steps["Log"] = $logResult

    # === STEP 6: ARCHIVE ===
    if (-not $SkipArchive) {
        Write-Host "[6/6] ARCHIVE - Saving transcript..." -ForegroundColor Yellow
        $archivePath = Join-Path $PSScriptRoot "..\..\swarm-logs"
        if (-not (Test-Path $archivePath)) {
            New-Item -ItemType Directory -Path $archivePath -Force | Out-Null
        }

        $archiveFile = Join-Path $archivePath "swarm-$swarmId-$(Get-Date -Format 'yyyyMMdd-HHmmss').json"
        $results | ConvertTo-Json -Depth 10 | Set-Content -Path $archiveFile -Encoding UTF8
        $results.Steps["Archive"] = @{ Path = $archiveFile; Success = $true }
    }

    # Calculate duration
    $results.Duration = ((Get-Date) - $script:SwarmState.StartTime).TotalSeconds

    # === DISPLAY RESULTS ===
    Write-Host ""
    Write-Host "=" * 60 -ForegroundColor DarkGreen
    Write-Host "  SWARM COMPLETE" -ForegroundColor Green
    Write-Host "  Duration: $([math]::Round($results.Duration, 2))s | Agents: $($taskList.Count)" -ForegroundColor DarkGray
    Write-Host "=" * 60 -ForegroundColor DarkGreen
    Write-Host ""
    Write-Host $results.FinalAnswer -ForegroundColor White
    Write-Host ""

    return $results
}

<#
.SYNOPSIS
    Quick single-agent query.
#>
function Invoke-QuickAgent {
    param(
        [Parameter(Mandatory)]
        [string]$Query,
        [string]$Agent
    )

    if (-not $Agent) {
        $Agent = Select-AgentForTask -Task $Query
    }

    Write-Host "[$Agent] Processing..." -ForegroundColor Cyan
    $result = Invoke-AgentTask -Agent $Agent -Task $Query

    if ($result.Success) {
        Write-Host $result.Response -ForegroundColor White
    }
    else {
        Write-Host "Error: $($result.Error)" -ForegroundColor Red
    }

    return $result
}

<#
.SYNOPSIS
    List all available agents.
#>
function Get-SwarmAgents {
    $agents = @()
    foreach ($agent in $script:AgentPersonas.Keys) {
        $persona = $script:AgentPersonas[$agent]
        $model = $script:AgentModels[$agent]
        $agents += [PSCustomObject]@{
            Agent = $agent
            Persona = $persona.Name
            Role = $persona.Role
            Focus = $persona.Focus
            Model = $model
        }
    }
    return $agents | Format-Table -AutoSize
}

<#
.SYNOPSIS
    Get swarm execution statistics.
#>
function Get-SwarmStats {
    return @{
        YoloMode = $script:SwarmState.YoloMode
        MaxConcurrency = $script:SwarmState.MaxConcurrency
        TimeoutSeconds = $script:SwarmState.TimeoutSeconds
        AgentCount = $script:AgentModels.Count
        LastRunTime = $script:SwarmState.StartTime
    }
}

# === EXPORTS ===
Export-ModuleMember -Function @(
    # Core Swarm
    'Invoke-AgentSwarm',
    'Invoke-QuickAgent',
    'Invoke-AgentTask',
    'Invoke-ParallelAgentTasks',

    # Agent Management
    'Get-AgentModel',
    'Get-AgentPersona',
    'Select-AgentForTask',
    'Get-SwarmAgents',

    # YOLO Mode
    'Set-YoloMode',
    'Get-YoloStatus',

    # Stats
    'Get-SwarmStats'
)

#Requires -Version 7.0
<#
.SYNOPSIS
    Parallel task executor with dependency awareness (DAG)
.DESCRIPTION
    Execute tasks respecting dependencies while maximizing parallelization
#>

param(
    [Parameter(Mandatory)]
    [hashtable]$Tasks  # @{ TaskName = @{ Script = {...}; DependsOn = @('OtherTask') } }
)

$CoreCount = [Environment]::ProcessorCount
Write-Host "🔀 Task DAG Executor" -ForegroundColor Cyan

# Topological sort to determine execution order
function Get-ExecutionOrder {
    param([hashtable]$Tasks)
    
    $visited = @{}
    $order = [System.Collections.Generic.List[string]]::new()
    $inProgress = @{}
    
    function Visit($name) {
        if ($inProgress[$name]) {
            throw "Circular dependency detected at: $name"
        }
        if ($visited[$name]) { return }
        
        $inProgress[$name] = $true
        
        $task = $Tasks[$name]
        if ($task.DependsOn) {
            foreach ($dep in $task.DependsOn) {
                if (-not $Tasks.ContainsKey($dep)) {
                    throw "Unknown dependency: $dep (required by $name)"
                }
                Visit $dep
            }
        }
        
        $inProgress[$name] = $false
        $visited[$name] = $true
        $order.Add($name)
    }
    
    foreach ($name in $Tasks.Keys) {
        Visit $name
    }
    
    return $order
}

# Group tasks by level (tasks that can run in parallel)
function Get-ExecutionLevels {
    param([hashtable]$Tasks, [System.Collections.Generic.List[string]]$Order)
    
    $levels = [System.Collections.Generic.List[System.Collections.Generic.List[string]]]::new()
    $completed = @{}
    
    while ($completed.Count -lt $Order.Count) {
        $currentLevel = [System.Collections.Generic.List[string]]::new()
        
        foreach ($name in $Order) {
            if ($completed[$name]) { continue }
            
            $task = $Tasks[$name]
            $depsCompleted = $true
            
            if ($task.DependsOn) {
                foreach ($dep in $task.DependsOn) {
                    if (-not $completed[$dep]) {
                        $depsCompleted = $false
                        break
                    }
                }
            }
            
            if ($depsCompleted) {
                $currentLevel.Add($name)
            }
        }
        
        if ($currentLevel.Count -eq 0) {
            throw "Unable to make progress - possible circular dependency"
        }
        
        foreach ($name in $currentLevel) {
            $completed[$name] = $true
        }
        
        $levels.Add($currentLevel)
    }
    
    return $levels
}

# Execute
try {
    $order = Get-ExecutionOrder -Tasks $Tasks
    $levels = Get-ExecutionLevels -Tasks $Tasks -Order $order
    
    Write-Host "📋 Execution plan: $($levels.Count) levels, $($Tasks.Count) tasks" -ForegroundColor Yellow
    
    for ($i = 0; $i -lt $levels.Count; $i++) {
        Write-Host "`nLevel $($i + 1): $($levels[$i] -join ', ')" -ForegroundColor Gray
    }
    
    $startTime = Get-Date
    $allResults = @{}
    
    for ($levelIdx = 0; $levelIdx -lt $levels.Count; $levelIdx++) {
        $level = $levels[$levelIdx]
        Write-Host "`n⚡ Executing Level $($levelIdx + 1) ($($level.Count) tasks in parallel)..." -ForegroundColor Cyan
        
        $levelResults = $level | ForEach-Object -Parallel {
            $taskName = $_
            $tasks = $using:Tasks
            $task = $tasks[$taskName]
            
            try {
                $output = & $task.Script
                @{
                    Name = $taskName
                    Success = $true
                    Output = $output
                }
            }
            catch {
                @{
                    Name = $taskName
                    Success = $false
                    Error = $_.Exception.Message
                }
            }
        } -ThrottleLimit $CoreCount
        
        foreach ($result in $levelResults) {
            $allResults[$result.Name] = $result
            $icon = if ($result.Success) { "✅" } else { "❌" }
            $color = if ($result.Success) { "Green" } else { "Red" }
            Write-Host "  $icon $($result.Name)" -ForegroundColor $color
            
            if (-not $result.Success) {
                Write-Host "     Error: $($result.Error)" -ForegroundColor Red
            }
        }
        
        # Check for failures
        $failures = $levelResults | Where-Object { -not $_.Success }
        if ($failures) {
            Write-Host "`n❌ Stopping due to failures in level $($levelIdx + 1)" -ForegroundColor Red
            break
        }
    }
    
    $endTime = Get-Date
    $duration = ($endTime - $startTime).TotalSeconds
    
    Write-Host "`n─" * 50
    Write-Host "⏱️  Duration: $([Math]::Round($duration, 2))s" -ForegroundColor Cyan
    
    $succeeded = ($allResults.Values | Where-Object { $_.Success }).Count
    $failed = ($allResults.Values | Where-Object { -not $_.Success }).Count
    Write-Host "✅ Succeeded: $succeeded | ❌ Failed: $failed" -ForegroundColor $(if ($failed -eq 0) { "Green" } else { "Red" })
    
    return $allResults
}
catch {
    Write-Host "❌ Error: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

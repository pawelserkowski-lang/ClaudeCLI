#Requires -Version 7.0
<#
.SYNOPSIS
    Parallel git operations across multiple repositories
.DESCRIPTION
    Execute git commands on all repos in parallel
#>

param(
    [Parameter(Mandatory = $false)]
    [string]$BasePath = (Get-Location).Path,
    
    [Parameter(Mandatory = $false)]
    [ValidateSet('status', 'fetch', 'pull', 'push', 'sync', 'branch', 'clean')]
    [string]$Operation = 'status',
    
    [string]$CustomCommand
)

$CoreCount = [Environment]::ProcessorCount
Write-Host "🔀 Parallel Git - Operation: $Operation" -ForegroundColor Cyan

# Find all git repositories
$repos = Get-ChildItem -Path $BasePath -Directory -Recurse -Depth 2 | 
         Where-Object { Test-Path (Join-Path $_.FullName ".git") }

Write-Host "📁 Found $($repos.Count) repositories" -ForegroundColor Yellow

if ($repos.Count -eq 0) {
    Write-Host "No git repositories found!" -ForegroundColor Red
    exit 0
}

$gitOps = @{
    status = { git status -sb 2>&1 }
    fetch = { git fetch --all --jobs=4 --prune 2>&1 }
    pull = { git pull --rebase 2>&1 }
    push = { git push 2>&1 }
    sync = { 
        git fetch --all --jobs=4 --prune 2>&1
        git pull --rebase 2>&1
    }
    branch = { git branch -vv 2>&1 }
    clean = { git clean -fd 2>&1; git checkout . 2>&1 }
    custom = { param($cmd) Invoke-Expression "git $cmd" 2>&1 }
}

$startTime = Get-Date

$results = $repos | ForEach-Object -Parallel {
    $repo = $_
    $op = $using:Operation
    $ops = $using:gitOps
    $customCmd = $using:CustomCommand
    
    Push-Location $repo.FullName
    try {
        $script = if ($op -eq 'custom' -or $customCmd) {
            & $ops['custom'] $customCmd
        } else {
            & $ops[$op]
        }
        
        $output = $script -join "`n"
        
        # Check for uncommitted changes
        $hasChanges = (git status --porcelain 2>$null | Measure-Object).Count -gt 0
        $branch = git rev-parse --abbrev-ref HEAD 2>$null
        $behind = git rev-list --count HEAD..@{u} 2>$null
        $ahead = git rev-list --count @{u}..HEAD 2>$null
        
        @{
            Name = $repo.Name
            Path = $repo.FullName
            Branch = $branch
            HasChanges = $hasChanges
            Behind = [int]$behind
            Ahead = [int]$ahead
            Success = $LASTEXITCODE -eq 0
            Output = $output
        }
    }
    catch {
        @{
            Name = $repo.Name
            Path = $repo.FullName
            Success = $false
            Error = $_.Exception.Message
        }
    }
    finally {
        Pop-Location
    }
} -ThrottleLimit $CoreCount

$endTime = Get-Date
$duration = ($endTime - $startTime).TotalSeconds

# Results
Write-Host "`n📊 Git Results:" -ForegroundColor Cyan
Write-Host "─" * 70

foreach ($result in $results | Sort-Object Name) {
    $icon = if ($result.Success) { "✅" } else { "❌" }
    $changeIcon = if ($result.HasChanges) { "📝" } else { "  " }
    $syncStatus = ""
    
    if ($result.Behind -gt 0) { $syncStatus += "⬇$($result.Behind) " }
    if ($result.Ahead -gt 0) { $syncStatus += "⬆$($result.Ahead) " }
    
    $color = if (-not $result.Success) { "Red" }
             elseif ($result.HasChanges) { "Yellow" }
             elseif ($result.Behind -gt 0) { "Magenta" }
             else { "Green" }
    
    Write-Host "$icon $changeIcon $($result.Name.PadRight(30)) [$($result.Branch)] $syncStatus" -ForegroundColor $color
}

Write-Host "`n─" * 70
Write-Host "⏱️  Duration: $([Math]::Round($duration, 2))s | 📁 Repos: $($repos.Count)" -ForegroundColor Cyan

$withChanges = ($results | Where-Object { $_.HasChanges }).Count
$needsPull = ($results | Where-Object { $_.Behind -gt 0 }).Count
if ($withChanges -gt 0 -or $needsPull -gt 0) {
    Write-Host "📝 With changes: $withChanges | ⬇️  Needs pull: $needsPull" -ForegroundColor Yellow
}

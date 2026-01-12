#Requires -Version 7.0
<#
.SYNOPSIS
    Parallel file watcher with action triggers
.DESCRIPTION
    Watch multiple directories for changes and execute actions in parallel
#>

param(
    [Parameter(Mandatory)]
    [string[]]$Paths,
    
    [Parameter(Mandatory = $false)]
    [string]$Filter = "*.*",
    
    [Parameter(Mandatory = $false)]
    [scriptblock]$OnChange,
    
    [switch]$IncludeSubdirectories
)

Write-Host "👁️  Parallel File Watcher" -ForegroundColor Cyan
Write-Host "📁 Watching $($Paths.Count) paths for changes" -ForegroundColor Yellow

# Default action
if (-not $OnChange) {
    $OnChange = {
        param($event)
        Write-Host "[$([DateTime]::Now.ToString('HH:mm:ss'))] $($event.ChangeType): $($event.FullPath)" -ForegroundColor Gray
    }
}

# Create watchers in parallel
$watchers = @()
$jobs = @()

foreach ($path in $Paths) {
    if (-not (Test-Path $path)) {
        Write-Host "⚠️  Path not found: $path" -ForegroundColor Yellow
        continue
    }
    
    $watcher = [System.IO.FileSystemWatcher]::new()
    $watcher.Path = $path
    $watcher.Filter = $Filter
    $watcher.IncludeSubdirectories = $IncludeSubdirectories
    $watcher.NotifyFilter = [System.IO.NotifyFilters]::LastWrite -bor 
                            [System.IO.NotifyFilters]::FileName -bor 
                            [System.IO.NotifyFilters]::DirectoryName
    
    $action = {
        $event = $Event.SourceEventArgs
        $scriptBlock = $Event.MessageData
        & $scriptBlock $event
    }
    
    Register-ObjectEvent -InputObject $watcher -EventName Changed -Action $action -MessageData $OnChange | Out-Null
    Register-ObjectEvent -InputObject $watcher -EventName Created -Action $action -MessageData $OnChange | Out-Null
    Register-ObjectEvent -InputObject $watcher -EventName Deleted -Action $action -MessageData $OnChange | Out-Null
    Register-ObjectEvent -InputObject $watcher -EventName Renamed -Action $action -MessageData $OnChange | Out-Null
    
    $watcher.EnableRaisingEvents = $true
    $watchers += $watcher
    
    Write-Host "✅ Watching: $path" -ForegroundColor Green
}

Write-Host "`nPress Ctrl+C to stop watching...`n" -ForegroundColor Gray

try {
    while ($true) {
        Start-Sleep -Seconds 1
    }
}
finally {
    Write-Host "`nStopping watchers..." -ForegroundColor Yellow
    foreach ($watcher in $watchers) {
        $watcher.EnableRaisingEvents = $false
        $watcher.Dispose()
    }
    Get-EventSubscriber | Unregister-Event
    Write-Host "✅ Watchers stopped" -ForegroundColor Green
}

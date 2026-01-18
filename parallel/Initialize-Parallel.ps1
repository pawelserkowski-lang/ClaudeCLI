#Requires -Version 7.0
<#
.SYNOPSIS
    Initialize parallel execution environment for ClaudeHYDRA
.DESCRIPTION
    Loads all parallel modules and displays available commands
#>

param(
    [switch]$Quiet
)

$ParallelRoot = $PSScriptRoot
$ModulePath = Join-Path $ParallelRoot "modules\ParallelUtils.psm1"

# Import module
try {
    Import-Module $ModulePath -Force -Global
    if (-not $Quiet) {
        Write-Host "✅ ParallelUtils module loaded" -ForegroundColor Green
    }
}
catch {
    Write-Host "❌ Failed to load ParallelUtils: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# Get system info
$config = Get-ParallelConfig

if (-not $Quiet) {
    Write-Host ""
    Write-Host "═" * 60 -ForegroundColor Cyan
    Write-Host "  ⚡ ClaudeHYDRA Parallel Execution System" -ForegroundColor Cyan
    Write-Host "═" * 60 -ForegroundColor Cyan
    Write-Host ""
    Write-Host "🖥️  System Configuration:" -ForegroundColor Yellow
    Write-Host "   CPU Cores: $($config.CoreCount)" -ForegroundColor White
    Write-Host "   Optimal Thread Limit: $($config.OptimalThrottle)" -ForegroundColor White
    Write-Host "   I/O Thread Limit: $($config.RecommendedIOThrottle)" -ForegroundColor White
    Write-Host "   Network Thread Limit: $($config.RecommendedNetworkThrottle)" -ForegroundColor White
    Write-Host ""
    Write-Host "📦 Available Commands:" -ForegroundColor Yellow
    Write-Host ""
    
    # Module functions
    Write-Host "  [Module Functions]" -ForegroundColor Cyan
    $functions = @(
        @{ Name = "Invoke-Parallel"; Desc = "General parallel execution" }
        @{ Name = "Invoke-ParallelJobs"; Desc = "Run multiple jobs simultaneously" }
        @{ Name = "Read-FilesParallel"; Desc = "Read multiple files at once" }
        @{ Name = "Copy-FilesParallel"; Desc = "Copy files in parallel" }
        @{ Name = "Search-FilesParallel"; Desc = "Search across directories" }
        @{ Name = "Get-DirectorySizeParallel"; Desc = "Calculate sizes in parallel" }
        @{ Name = "Invoke-CommandsParallel"; Desc = "Run shell commands in parallel" }
        @{ Name = "Invoke-WebRequestsParallel"; Desc = "Multiple HTTP requests" }
        @{ Name = "Invoke-GitParallel"; Desc = "Git ops across repos" }
        @{ Name = "Compress-FilesParallel"; Desc = "Parallel 7z compression" }
    )
    
    foreach ($f in $functions) {
        Write-Host "   • $($f.Name.PadRight(28)) - $($f.Desc)" -ForegroundColor Gray
    }
    
    Write-Host ""
    Write-Host "  [Standalone Scripts]" -ForegroundColor Cyan
    $scripts = @(
        @{ Name = "Build-Parallel.ps1"; Desc = "Build all projects" }
        @{ Name = "Test-Parallel.ps1"; Desc = "Run tests in parallel" }
        @{ Name = "Lint-Parallel.ps1"; Desc = "Lint all projects" }
        @{ Name = "Invoke-ParallelGit.ps1"; Desc = "Git operations" }
        @{ Name = "Invoke-ParallelDownload.ps1"; Desc = "Multi-connection downloads" }
        @{ Name = "Invoke-ParallelCompress.ps1"; Desc = "Parallel compression" }
        @{ Name = "Watch-FilesParallel.ps1"; Desc = "File system watcher" }
        @{ Name = "Invoke-TaskDAG.ps1"; Desc = "Task dependency executor" }
        @{ Name = "Invoke-MCPParallel.ps1"; Desc = "MCP parallelization guide" }
        @{ Name = "Start-ParallelBrowsers.ps1"; Desc = "Playwright parallel helper" }
    )
    
    foreach ($s in $scripts) {
        Write-Host "   • $($s.Name.PadRight(28)) - $($s.Desc)" -ForegroundColor Gray
    }
    
    Write-Host ""
    Write-Host "═" * 60 -ForegroundColor Cyan
    Write-Host ""
    Write-Host "💡 Quick Start:" -ForegroundColor Yellow
    Write-Host '   $files = @("file1.txt", "file2.txt", "file3.txt")' -ForegroundColor White
    Write-Host '   Read-FilesParallel -Paths $files' -ForegroundColor White
    Write-Host ""
    Write-Host "📖 For more info: Get-Help <FunctionName> -Full" -ForegroundColor Gray
    Write-Host ""
}

# Return config for programmatic use
return $config

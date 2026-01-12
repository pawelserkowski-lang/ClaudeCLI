# API Usage Tracker for Anthropic Claude
param(
    [Parameter(Position=0)]
    [ValidateSet('log', 'stats', 'reset', 'cost', 'export')]
    [string]$Command = 'stats',
    [int]$InputTokens = 0,
    [int]$OutputTokens = 0,
    [string]$Model = 'claude-sonnet-4-5-20250929',
    [string]$Operation = 'chat'
)

$LogFile = Join-Path $PSScriptRoot '.claude\api-usage.json'
if (-not (Test-Path (Split-Path $LogFile))) {
    New-Item -ItemType Directory -Path (Split-Path $LogFile) -Force | Out-Null
}

$Pricing = @{
    'claude-opus-4-5-20251101' = @{ input = 15.00; output = 75.00 }
    'claude-sonnet-4-5-20250929' = @{ input = 3.00; output = 15.00 }
    'claude-haiku-4-20250604' = @{ input = 0.80; output = 4.00 }
}

function Get-UsageLog {
    if (Test-Path $LogFile) {
        return Get-Content $LogFile -Raw | ConvertFrom-Json
    }
    return @{
        sessions = @()
        total_requests = 0
        total_input_tokens = 0
        total_output_tokens = 0
        total_cost_usd = 0.0
        created_at = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
    }
}

function Save-UsageLog($Log) {
    $Log | ConvertTo-Json -Depth 10 | Set-Content $LogFile -Encoding UTF8
}

function Add-UsageEntry {
    param([int]$InputTokens, [int]$OutputTokens, [string]$Model, [string]$Operation)
    $log = Get-UsageLog
    $pricing = $Pricing[$Model]
    if (-not $pricing) {
        Write-Host "Unknown model, using Sonnet 4.5 pricing" -ForegroundColor Yellow
        $pricing = $Pricing['claude-sonnet-4-5-20250929']
    }
    $cost = (($InputTokens / 1000000) * $pricing.input) + (($OutputTokens / 1000000) * $pricing.output)
    $entry = @{
        timestamp = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
        model = $Model
        operation = $Operation
        input_tokens = $InputTokens
        output_tokens = $OutputTokens
        cost_usd = [math]::Round($cost, 6)
    }
    $log.sessions += $entry
    $log.total_requests++
    $log.total_input_tokens += $InputTokens
    $log.total_output_tokens += $OutputTokens
    $log.total_cost_usd = [math]::Round($log.total_cost_usd + $cost, 6)
    Save-UsageLog $log
    Write-Host "Usage logged: $InputTokens in / $OutputTokens out | Cost: $($entry.cost_usd)" -ForegroundColor Green
}

function Show-Stats {
    $log = Get-UsageLog
    if ($log.total_requests -eq 0) {
        Write-Host "No API usage recorded yet." -ForegroundColor Yellow
        return
    }
    Write-Host "`n=============================================================" -ForegroundColor Cyan
    Write-Host "     ANTHROPIC API USAGE STATISTICS" -ForegroundColor Cyan
    Write-Host "=============================================================" -ForegroundColor Cyan
    Write-Host "Total Requests: $($log.total_requests)" -ForegroundColor Green
    Write-Host "Total Tokens: $(($log.total_input_tokens + $log.total_output_tokens).ToString('N0'))" -ForegroundColor Yellow
    Write-Host "Total Cost: `$$($log.total_cost_usd)" -ForegroundColor Cyan
    $recent = $log.sessions | Select-Object -Last 5
    if ($recent) {
        Write-Host "`nRecent Sessions:" -ForegroundColor White
        foreach ($s in $recent) {
            Write-Host "  [$($s.timestamp)] $($s.model) | $($s.input_tokens) in / $($s.output_tokens) out | `$$($s.cost_usd)" -ForegroundColor Gray
        }
    }
    Write-Host "=============================================================`n" -ForegroundColor Cyan
}

function Show-CostBreakdown {
    $log = Get-UsageLog
    if ($log.total_requests -eq 0) {
        Write-Host "No API usage recorded yet." -ForegroundColor Yellow
        return
    }
    Write-Host "`n=============================================================" -ForegroundColor Cyan
    Write-Host "     COST BREAKDOWN BY MODEL" -ForegroundColor Cyan
    Write-Host "=============================================================" -ForegroundColor Cyan
    $grouped = $log.sessions | Group-Object -Property model
    foreach ($g in $grouped) {
        $cost = ($g.Group | Measure-Object -Property cost_usd -Sum).Sum
        $inTok = ($g.Group | Measure-Object -Property input_tokens -Sum).Sum
        $outTok = ($g.Group | Measure-Object -Property output_tokens -Sum).Sum
        Write-Host "$($g.Name)" -ForegroundColor Yellow
        Write-Host "  Requests: $($g.Count) | Tokens: $($inTok.ToString('N0')) in / $($outTok.ToString('N0')) out | Cost: `$$([math]::Round($cost, 4))" -ForegroundColor Gray
    }
    Write-Host "=============================================================`n" -ForegroundColor Cyan
}

function Reset-Log {
    if (Test-Path $LogFile) {
        Remove-Item $LogFile -Force
        Write-Host "Usage log reset" -ForegroundColor Green
    } else {
        Write-Host "No log file to reset" -ForegroundColor Yellow
    }
}

function Export-Log {
    $log = Get-UsageLog
    $path = Join-Path $PSScriptRoot "api-usage-export-$(Get-Date -Format 'yyyyMMdd-HHmmss').json"
    $log | ConvertTo-Json -Depth 10 | Set-Content $path -Encoding UTF8
    Write-Host "Exported to: $path" -ForegroundColor Green
}

switch ($Command) {
    'log' {
        if ($InputTokens -eq 0 -and $OutputTokens -eq 0) {
            Write-Host "Error: Provide -InputTokens and -OutputTokens" -ForegroundColor Red
            exit 1
        }
        Add-UsageEntry -InputTokens $InputTokens -OutputTokens $OutputTokens -Model $Model -Operation $Operation
    }
    'stats' { Show-Stats }
    'cost' { Show-CostBreakdown }
    'reset' { Reset-Log }
    'export' { Export-Log }
}

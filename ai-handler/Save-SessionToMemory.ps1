#Requires -Version 5.1
<#
.SYNOPSIS
    Saves current session context to Serena memories

.DESCRIPTION
    Automatically persists important session information to Serena's memory system.
    Can be called manually or by hooks at session end.

.PARAMETER Summary
    Optional custom summary to add

.PARAMETER Force
    Save even if session is short

.EXAMPLE
    .\Save-SessionToMemory.ps1

.EXAMPLE
    .\Save-SessionToMemory.ps1 -Summary "Completed AI handler refactoring"
#>

param(
    [string]$Summary = "",
    [switch]$Force
)

$ErrorActionPreference = 'Stop'

# Load the ContextOptimizer module
$modulePath = Join-Path $PSScriptRoot "modules\ContextOptimizer.psm1"
if (-not (Test-Path $modulePath)) {
    Write-Error "ContextOptimizer module not found at: $modulePath"
    exit 1
}

Import-Module $modulePath -Force

# Get current session state
$session = Get-SessionState

# Check if session has meaningful content
$hasContent = ($session.KeyDecisions.Count -gt 0) -or
              ($session.FilesMentioned.Count -gt 0) -or
              ($session.ErrorsEncountered.Count -gt 0) -or
              ($session.TokensUsed -gt 1000)

if (-not $hasContent -and -not $Force) {
    Write-Host "Session has no significant content to save. Use -Force to save anyway." -ForegroundColor Yellow
    exit 0
}

# Calculate session duration
$duration = (Get-Date) - $session.StartTime
$durationStr = if ($duration.TotalHours -ge 1) {
    "{0:N1} hours" -f $duration.TotalHours
} else {
    "{0:N0} minutes" -f $duration.TotalMinutes
}

# Build session content
$content = @"
## Session: $(Get-Date -Format "yyyy-MM-dd HH:mm")
Duration: $durationStr | Tokens: ~$($session.TokensUsed)

"@

if ($Summary) {
    $content += @"
### Summary
$Summary

"@
}

if ($session.KeyDecisions.Count -gt 0) {
    $content += @"
### Key Decisions
$($session.KeyDecisions | ForEach-Object { "- $_" } | Out-String)
"@
}

if ($session.FilesMentioned.Count -gt 0) {
    $uniqueFiles = $session.FilesMentioned | Select-Object -Unique | Sort-Object
    $content += @"
### Files Touched
$($uniqueFiles | ForEach-Object { "- ``$_``" } | Out-String)
"@
}

if ($session.ErrorsEncountered.Count -gt 0) {
    $content += @"
### Errors Encountered
$($session.ErrorsEncountered | ForEach-Object { "- $_" } | Out-String)
"@
}

# Get tool call stats if available
if ($session.ToolCalls.Count -gt 0) {
    $toolStats = $session.ToolCalls | Group-Object -Property Tool | Sort-Object Count -Descending | Select-Object -First 5
    $content += @"
### Top Tool Calls
$($toolStats | ForEach-Object { "- $($_.Name): $($_.Count) calls" } | Out-String)
"@
}

# Save to Serena memory
$saved = Save-ToSerenaMemory -Name "session_notes" -Content $content -Category "session_notes" -Append

if ($saved) {
    Write-Host @"

=== Session Saved to Serena Memory ===
Duration: $durationStr
Tokens used: ~$($session.TokensUsed)
Decisions: $($session.KeyDecisions.Count)
Files: $($session.FilesMentioned.Count)
Errors: $($session.ErrorsEncountered.Count)

Memory location: .serena/memories/session_notes.md
"@ -ForegroundColor Green
} else {
    Write-Host "Failed to save session to memory" -ForegroundColor Red
    exit 1
}

# Reset session state for next session
Reset-SessionState

Write-Host "`nSession state reset for next conversation." -ForegroundColor Cyan

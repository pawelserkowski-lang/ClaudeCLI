# Set AI Handler Environment Variables (Persistent)
# Run once to configure the environment

param(
    [switch]$Force,
    [switch]$Remove
)

$keyName = 'CLAUDECLI_ENCRYPTION_KEY'
$keyValue = 'ClaudeHYDRA-2024'

if ($Remove) {
    [Environment]::SetEnvironmentVariable($keyName, $null, 'User')
    Write-Host "[OK] Removed $keyName from environment" -ForegroundColor Yellow
    exit 0
}

# Check if already set
$existing = [Environment]::GetEnvironmentVariable($keyName, 'User')

if ($existing -and -not $Force) {
    Write-Host "[OK] $keyName already configured" -ForegroundColor Green
    Write-Host "    Value: $($existing.Substring(0, [Math]::Min(10, $existing.Length)))..." -ForegroundColor DarkGray
    Write-Host "    Use -Force to overwrite" -ForegroundColor DarkGray
    exit 0
}

# Set the environment variable
[Environment]::SetEnvironmentVariable($keyName, $keyValue, 'User')

# Verify
$verify = [Environment]::GetEnvironmentVariable($keyName, 'User')
if ($verify -eq $keyValue) {
    Write-Host "[OK] AI Handler environment configured successfully" -ForegroundColor Green
    Write-Host ""
    Write-Host "Environment Variable Set:" -ForegroundColor Cyan
    Write-Host "  Name:  $keyName"
    Write-Host "  Scope: User (persistent)"
    Write-Host ""
    Write-Host "NOTE: Restart terminal/Claude Code for changes to take effect" -ForegroundColor Yellow
} else {
    Write-Host "[ERROR] Failed to set environment variable" -ForegroundColor Red
    exit 1
}

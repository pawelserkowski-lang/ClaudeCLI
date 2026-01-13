#Requires -Version 5.1
<#
.SYNOPSIS
    Tests HYDRA prerequisites on Windows
.DESCRIPTION
    Checks for required and optional software before HYDRA installation
#>

[CmdletBinding()]
param()

Write-Host "`nHYDRA 10.0 - Prerequisites Check" -ForegroundColor Magenta
Write-Host "================================`n" -ForegroundColor Magenta

$results = @()

# Helper function
function Test-Prerequisite {
    param(
        [string]$Name,
        [scriptblock]$Test,
        [string]$InstallCmd,
        [bool]$Required = $true
    )

    $result = @{
        Name = $Name
        Required = $Required
        Installed = $false
        Version = ""
        InstallCmd = $InstallCmd
    }

    try {
        $testResult = & $Test
        if ($testResult) {
            $result.Installed = $true
            $result.Version = $testResult
        }
    } catch {
        $result.Installed = $false
    }

    return $result
}

# Check Windows version
$osVersion = [System.Environment]::OSVersion.Version
$isWin10Plus = $osVersion.Major -ge 10
Write-Host "OS: Windows $($osVersion.Major).$($osVersion.Minor)" -ForegroundColor $(if ($isWin10Plus) { 'Green' } else { 'Red' })

# Required prerequisites
$results += Test-Prerequisite -Name "PowerShell" -Required $true -InstallCmd "Built-in" -Test {
    $v = $PSVersionTable.PSVersion
    if ($v.Major -ge 5) { return "$($v.Major).$($v.Minor)" }
    return $null
}

$results += Test-Prerequisite -Name "Node.js" -Required $true -InstallCmd "winget install OpenJS.NodeJS" -Test {
    $v = & node --version 2>$null
    if ($v) { return $v.TrimStart('v') }
    return $null
}

$results += Test-Prerequisite -Name "npm" -Required $true -InstallCmd "(comes with Node.js)" -Test {
    $v = & npm --version 2>$null
    return $v
}

$results += Test-Prerequisite -Name "Git" -Required $true -InstallCmd "winget install Git.Git" -Test {
    $v = & git --version 2>$null
    if ($v) { return ($v -replace 'git version ', '') }
    return $null
}

$results += Test-Prerequisite -Name "Python" -Required $true -InstallCmd "winget install Python.Python.3.12" -Test {
    $v = & python --version 2>$null
    if ($v) { return ($v -replace 'Python ', '') }
    return $null
}

# Optional prerequisites
$results += Test-Prerequisite -Name "Ollama" -Required $false -InstallCmd "https://ollama.com/download" -Test {
    $v = & ollama --version 2>$null
    if ($v) { return ($v -replace 'ollama version ', '') }
    return $null
}

$results += Test-Prerequisite -Name "Claude Code" -Required $false -InstallCmd "npm install -g @anthropic-ai/claude-code" -Test {
    $v = & claude --version 2>$null
    return $v
}

$results += Test-Prerequisite -Name "uvx (for Serena)" -Required $false -InstallCmd "pip install uv" -Test {
    $v = & uvx --version 2>$null
    return $v
}

# Display results
Write-Host "`nResults:" -ForegroundColor Cyan
Write-Host "---------"

foreach ($r in $results) {
    $status = if ($r.Installed) { "[OK]" } else { if ($r.Required) { "[MISSING]" } else { "[OPTIONAL]" } }
    $color = if ($r.Installed) { 'Green' } elseif ($r.Required) { 'Red' } else { 'Yellow' }

    $line = "$status $($r.Name)"
    if ($r.Version) { $line += " v$($r.Version)" }

    Write-Host $line -ForegroundColor $color

    if (-not $r.Installed) {
        Write-Host "       Install: $($r.InstallCmd)" -ForegroundColor Gray
    }
}

# Summary
$missing = $results | Where-Object { -not $_.Installed -and $_.Required }
$optional = $results | Where-Object { -not $_.Installed -and -not $_.Required }

Write-Host "`n---------"
if ($missing.Count -eq 0) {
    Write-Host "All required prerequisites are installed!" -ForegroundColor Green
} else {
    Write-Host "Missing $($missing.Count) required prerequisites." -ForegroundColor Red
}

if ($optional.Count -gt 0) {
    Write-Host "$($optional.Count) optional components not installed." -ForegroundColor Yellow
}

# Return exit code
exit $missing.Count

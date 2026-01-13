#Requires -Version 5.1
<#
.SYNOPSIS
    HYDRA 10.0 Post-Installation Initializer
.DESCRIPTION
    Sets up HYDRA environment after installation
#>

[CmdletBinding()]
param(
    [switch]$Silent,
    [string]$InstallPath = $PSScriptRoot | Split-Path -Parent
)

$ErrorActionPreference = 'Stop'

function Write-Status {
    param([string]$Message, [string]$Color = 'Cyan')
    if (-not $Silent) {
        Write-Host "[HYDRA] $Message" -ForegroundColor $Color
    }
}

function Test-Command {
    param([string]$Command)
    $null -ne (Get-Command $Command -ErrorAction SilentlyContinue)
}

# Banner
if (-not $Silent) {
    Write-Host @"

    ██╗  ██╗██╗   ██╗██████╗ ██████╗  █████╗
    ██║  ██║╚██╗ ██╔╝██╔══██╗██╔══██╗██╔══██╗
    ███████║ ╚████╔╝ ██║  ██║██████╔╝███████║
    ██╔══██║  ╚██╔╝  ██║  ██║██╔══██╗██╔══██║
    ██║  ██║   ██║   ██████╔╝██║  ██║██║  ██║
    ╚═╝  ╚═╝   ╚═╝   ╚═════╝ ╚═╝  ╚═╝╚═╝  ╚═╝
                    v10.0 - Three-Headed Beast

"@ -ForegroundColor Magenta
}

Write-Status "Initializing HYDRA at: $InstallPath"

# Step 1: Verify prerequisites
Write-Status "Checking prerequisites..."

$prereqs = @{
    'PowerShell 5.1+' = { $PSVersionTable.PSVersion.Major -ge 5 }
    'Node.js' = { Test-Command 'node' }
    'npm' = { Test-Command 'npm' }
    'Git' = { Test-Command 'git' }
    'Python 3' = { Test-Command 'python' -or Test-Command 'python3' }
}

$missing = @()
foreach ($item in $prereqs.GetEnumerator()) {
    if (-not (& $item.Value)) {
        $missing += $item.Key
        Write-Host "  [MISSING] $($item.Key)" -ForegroundColor Red
    } else {
        Write-Host "  [OK] $($item.Key)" -ForegroundColor Green
    }
}

# Check Ollama
if (Test-Command 'ollama') {
    Write-Host "  [OK] Ollama" -ForegroundColor Green
    $ollamaInstalled = $true
} else {
    Write-Host "  [OPTIONAL] Ollama (local AI - recommended)" -ForegroundColor Yellow
    $ollamaInstalled = $false
}

if ($missing.Count -gt 0) {
    Write-Host "`nMissing prerequisites: $($missing -join ', ')" -ForegroundColor Yellow
    Write-Host "Some features may not work correctly." -ForegroundColor Yellow
}

# Step 2: Setup Claude Code integration
Write-Status "Setting up Claude Code integration..."

$claudeConfigPath = Join-Path $env:USERPROFILE ".claude.json"
if (Test-Path $claudeConfigPath) {
    try {
        $claudeConfig = Get-Content $claudeConfigPath -Raw | ConvertFrom-Json

        # Add HYDRA MCP servers if not present
        $mcpServers = @{
            'serena' = @{
                command = 'uvx'
                args = @('--from', 'git+https://github.com/oraios/serena', 'serena', 'start-mcp-server', '--context', 'cli', '--project', $InstallPath)
            }
            'desktop-commander' = @{
                command = 'cmd'
                args = @('/c', 'npx', '-y', '@wonderwhy-er/desktop-commander')
            }
            'playwright' = @{
                command = 'cmd'
                args = @('/c', 'npx', '@playwright/mcp@latest')
            }
        }

        if (-not $claudeConfig.mcpServers) {
            $claudeConfig | Add-Member -NotePropertyName 'mcpServers' -NotePropertyValue @{} -Force
        }

        foreach ($server in $mcpServers.GetEnumerator()) {
            if (-not $claudeConfig.mcpServers.$($server.Key)) {
                $claudeConfig.mcpServers | Add-Member -NotePropertyName $server.Key -NotePropertyValue $server.Value -Force
                Write-Host "  Added MCP server: $($server.Key)" -ForegroundColor Green
            }
        }

        $claudeConfig | ConvertTo-Json -Depth 10 | Set-Content $claudeConfigPath -Encoding UTF8
        Write-Status "Claude Code configuration updated" -Color Green
    } catch {
        Write-Host "  Warning: Could not update Claude config: $_" -ForegroundColor Yellow
    }
} else {
    Write-Host "  Claude Code not configured yet. Run 'claude' first." -ForegroundColor Yellow
}

# Step 3: Initialize AI Handler
Write-Status "Initializing AI Handler..."

$aiHandlerPath = Join-Path $InstallPath "ai-handler"
$aiStatePath = Join-Path $aiHandlerPath "ai-state.json"

# Create initial state file
$initialState = @{
    lastUpdated = (Get-Date).ToString('o')
    usage = @{
        anthropic = @{ requests = 0; tokens = 0 }
        openai = @{ requests = 0; tokens = 0 }
        ollama = @{ requests = 0; tokens = 0 }
    }
    rateLimits = @{}
    activeProvider = 'ollama'
    activeModel = 'llama3.2:3b'
}

$initialState | ConvertTo-Json -Depth 5 | Set-Content $aiStatePath -Encoding UTF8
Write-Host "  AI state initialized" -ForegroundColor Green

# Step 4: Pull Ollama models if installed
if ($ollamaInstalled -and -not $Silent) {
    $pullModels = Read-Host "`nPull recommended Ollama models now? (y/N)"
    if ($pullModels -eq 'y' -or $pullModels -eq 'Y') {
        $models = @('llama3.2:3b', 'llama3.2:1b', 'qwen2.5-coder:1.5b', 'phi3:mini')
        foreach ($model in $models) {
            Write-Status "Pulling $model..."
            & ollama pull $model
        }
    }
}

# Step 5: Create environment profile
Write-Status "Creating environment profile..."

$profileContent = @"
# HYDRA 10.0 Environment Profile
# Add to your PowerShell profile: . "$InstallPath\scripts\hydra-profile.ps1"

`$env:HYDRA_HOME = "$InstallPath"
`$env:PATH = "`$env:PATH;$InstallPath;$InstallPath\scripts"

# Import AI Handler
Import-Module "$InstallPath\ai-handler\AIModelHandler.psm1" -ErrorAction SilentlyContinue

# Import Parallel Utils
. "$InstallPath\parallel\Initialize-Parallel.ps1" -ErrorAction SilentlyContinue

# Aliases
Set-Alias hydra "$InstallPath\_launcher.ps1"
Set-Alias ai "$InstallPath\ai-handler\Invoke-AI.ps1"
Set-Alias mcp-check "$InstallPath\mcp-health-check.ps1"

Write-Host "HYDRA 10.0 loaded. Type 'hydra' to start." -ForegroundColor Magenta
"@

$profilePath = Join-Path $InstallPath "scripts\hydra-profile.ps1"
$profileContent | Set-Content $profilePath -Encoding UTF8
Write-Host "  Profile created: $profilePath" -ForegroundColor Green

# Final summary
Write-Host "`n" + "="*50 -ForegroundColor Cyan
Write-Status "HYDRA 10.0 Installation Complete!" -Color Green
Write-Host "="*50 -ForegroundColor Cyan

Write-Host @"

Next steps:
  1. Add to PowerShell profile:
     . "$profilePath"

  2. Set API keys (optional for cloud fallback):
     `$env:ANTHROPIC_API_KEY = "sk-ant-..."
     `$env:OPENAI_API_KEY = "sk-..."

  3. Start HYDRA:
     hydra

  4. Check MCP servers:
     mcp-check

Documentation: $InstallPath\CLAUDE.md

"@ -ForegroundColor White

if (-not $Silent) {
    Read-Host "Press Enter to continue"
}

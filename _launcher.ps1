#!/usr/bin/env pwsh
# =============================================================================
# CLAUDE CLI - HYDRA LAUNCHER v10.1
# Enhanced GUI with status monitoring + YOLO Mode + Agent Swarm
# =============================================================================

param(
    [switch]$NoYolo,         # Disable YOLO mode (default: YOLO ON)
    [switch]$SkipHealthCheck, # Skip Node.js/npm validation
    [switch]$Quiet           # Minimal output
)

# YOLO mode is ON by default
$Yolo = -not $NoYolo

# === FORCE UTF-8 ENCODING ===
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
[Console]::InputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8
$env:PYTHONIOENCODING = 'utf-8'
$env:LANG = 'en_US.UTF-8'
# Disable animations that cause flickering
$env:CI = 'true'
$env:TERM = 'dumb'
chcp 65001 2>$null | Out-Null

$script:ProjectRoot = 'C:\Users\BIURODOM\Desktop\ClaudeHYDRA'
Set-Location $script:ProjectRoot
$yoloSuffix = if ($Yolo) { " [YOLO]" } else { "" }
$Host.UI.RawUI.WindowTitle = "Claude CLI (HYDRA 10.1)$yoloSuffix"

# Use explicit path since $PSScriptRoot can be empty when dot-sourced
$scriptDir = if ($PSScriptRoot) { $PSScriptRoot } else { $script:ProjectRoot }

# Load GUI module (REQUIRED - contains all display functions)
$guiModule = Join-Path $scriptDir 'modules\GUI-Utils.psm1'
if (Test-Path $guiModule) {
    try {
        Import-Module $guiModule -Force -Global -ErrorAction Stop
    } catch {
        Write-Host "ERROR: Failed to load GUI-Utils.psm1: $_" -ForegroundColor Red
    }
} else {
    Write-Host "ERROR: GUI module not found at: $guiModule" -ForegroundColor Red
}

# Load custom profile
$customProfile = Join-Path $scriptDir 'profile.ps1'
if (Test-Path $customProfile) { . $customProfile }

# === CLEAR & SHOW LOGO ===
Clear-Host
Show-HydraLogo -Variant 'claude'

Write-Host "       CLAUDE CLI" -NoNewline -ForegroundColor Yellow
Write-Host " + " -NoNewline -ForegroundColor DarkGray
Write-Host "HYDRA 10.1" -NoNewline -ForegroundColor DarkYellow
if ($Yolo) {
    Write-Host " [YOLO]" -ForegroundColor Red
} else {
    Write-Host ""
}
Write-Host "       MCP: Serena + Desktop Commander + Playwright" -ForegroundColor DarkGray
Write-Host "       Agent Swarm: 12 Witcher Agents (School of the Wolf)" -ForegroundColor DarkGray
Write-Host ""

# === SYSTEM STATUS ===
Write-Separator -Width 55
$sysInfo = Get-SystemInfo
Write-StatusLine -Label "PowerShell" -Value $sysInfo.PowerShell -Status 'info'
Write-StatusLine -Label "Node.js" -Value $sysInfo.Node -Status 'info'
Write-StatusLine -Label "Memory" -Value $sysInfo.Memory -Status 'info'

# === API KEY STATUS ===
$apiKey = Get-APIKeyStatus -Provider 'anthropic'
if ($apiKey.Present) {
    Write-StatusLine -Label "API Key" -Value $apiKey.Masked -Status 'ok'
} else {
    Write-StatusLine -Label "API Key" -Value "Not configured" -Status 'error'
}

# === MCP SERVERS ===
Write-Host ""
Write-Host "  MCP Servers:" -ForegroundColor DarkGray
$servers = @('serena', 'desktop-commander', 'playwright')
foreach ($srv in $servers) {
    $status = Test-MCPServer -Name $srv
    $st = if ($status.Online) { 'ok' } else { 'error' }
    Write-StatusLine -Label $srv -Value $status.Message -Status $st
}

Write-Separator -Width 55

# === ERROR LOGGER ===
$errorLogModule = Join-Path $scriptDir 'ai-handler\modules\ErrorLogger.psm1'
if (Test-Path $errorLogModule) {
    try {
        Import-Module $errorLogModule -Force -Global -ErrorAction Stop
        if (Get-Command Initialize-ErrorLogger -ErrorAction SilentlyContinue) {
            Initialize-ErrorLogger | Out-Null
        }
    } catch {
        # Silently continue if ErrorLogger fails to load
    }
}

# === SMART QUEUE ===
$smartQueueModule = Join-Path $scriptDir 'ai-handler\modules\SmartQueue.psm1'
if (Test-Path $smartQueueModule) {
    Import-Module $smartQueueModule -Force -Global -ErrorAction SilentlyContinue
}

# === AGENT SWARM (12 Witcher Agents) ===
$agentSwarmModule = Join-Path $scriptDir 'ai-handler\modules\AgentSwarm.psm1'
if (Test-Path $agentSwarmModule) {
    try {
        Import-Module $agentSwarmModule -Force -Global -ErrorAction Stop
        # Enable YOLO mode if requested
        if ($Yolo) {
            Set-YoloMode -Enable | Out-Null
        }
    } catch {
        Write-Host "  [WARN] AgentSwarm failed to load: $_" -ForegroundColor Yellow
    }
}

# === AI CODING TOOLS ===
$aiCodingModules = @(
    'SelfCorrection.psm1',
    'PromptOptimizer.psm1',
    'FewShotLearning.psm1'
)
$loadedTools = @()
foreach ($mod in $aiCodingModules) {
    $modPath = Join-Path $scriptDir "ai-handler\modules\$mod"
    if (Test-Path $modPath) {
        Import-Module $modPath -Force -Global -ErrorAction SilentlyContinue
        $loadedTools += $mod -replace '\.psm1$', ''
    }
}

# === AI HANDLER (via AIFacade) ===
Write-Host ""
Write-Host "  AI Handler:" -ForegroundColor DarkGray
$aiFacadeModule = Join-Path $scriptDir 'ai-handler\AIFacade.psm1'
$aiHealthModule = Join-Path $scriptDir 'ai-handler\utils\AIUtil-Health.psm1'

if (Test-Path $aiFacadeModule) {
    try {
        # Load AIFacade - single entry point for AI system
        Import-Module $aiFacadeModule -Force -Global -ErrorAction Stop

        # Load health utilities for Ollama check
        if (Test-Path $aiHealthModule) {
            Import-Module $aiHealthModule -Force -Global -ErrorAction SilentlyContinue
        }

        # Initialize AI system (loads all modules in correct order)
        $initResult = Initialize-AISystem -ErrorAction Stop
        $modulesLoaded = $initResult.TotalLoaded

        # Check Ollama using Test-OllamaAvailable if available, else fallback to TCP
        $ollamaStatus = $false
        if (Get-Command Test-OllamaAvailable -ErrorAction SilentlyContinue) {
            $ollamaCheck = Test-OllamaAvailable -NoCache
            $ollamaStatus = $ollamaCheck.Available
        } else {
            # Fallback: TCP socket check for PS5.1 compatibility
            try {
                $tcp = New-Object System.Net.Sockets.TcpClient
                $tcp.Connect('localhost', 11434)
                $ollamaStatus = $tcp.Connected
                $tcp.Close()
            } catch { }
        }

        # Auto-start Ollama if not running
        if (-not $ollamaStatus) {
            $ollamaPath = "$env:LOCALAPPDATA\Programs\Ollama\ollama.exe"
            if (Test-Path $ollamaPath) {
                Write-StatusLine -Label "Ollama (local)" -Value "Starting..." -Status 'warning'
                Start-Process -FilePath $ollamaPath -ArgumentList "serve" -WindowStyle Hidden
                # Wait for Ollama to start (max 5 seconds)
                $retries = 10
                while ($retries -gt 0 -and -not $ollamaStatus) {
                    Start-Sleep -Milliseconds 500
                    if (Get-Command Test-OllamaAvailable -ErrorAction SilentlyContinue) {
                        $ollamaCheck = Test-OllamaAvailable -NoCache
                        $ollamaStatus = $ollamaCheck.Available
                    } else {
                        try {
                            $tcp = New-Object System.Net.Sockets.TcpClient
                            $tcp.Connect('localhost', 11434)
                            $ollamaStatus = $tcp.Connected
                            $tcp.Close()
                        } catch { }
                    }
                    $retries--
                }
            }
        }

        if ($ollamaStatus) {
            Write-StatusLine -Label "Ollama (local)" -Value "Running on :11434" -Status 'ok'
        } else {
            Write-StatusLine -Label "Ollama (local)" -Value "Not running" -Status 'warning'
        }

        # Check cloud providers using Get-AISystemStatus if available
        $hasAnthropic = [bool]$env:ANTHROPIC_API_KEY
        $hasOpenAI = [bool]$env:OPENAI_API_KEY
        $cloudMsg = @()
        if ($hasAnthropic) { $cloudMsg += "Anthropic" }
        if ($hasOpenAI) { $cloudMsg += "OpenAI" }
        if ($cloudMsg.Count -gt 0) {
            Write-StatusLine -Label "Cloud APIs" -Value ($cloudMsg -join ", ") -Status 'ok'
        } else {
            Write-StatusLine -Label "Cloud APIs" -Value "No keys configured" -Status 'warning'
        }

        # Show loaded modules count
        Write-StatusLine -Label "AI Handler" -Value "v1.0 loaded ($modulesLoaded modules)" -Status 'ok'

        # Create global aliases
        Set-Alias -Name ai -Value (Join-Path $scriptDir 'ai-handler\Invoke-AI.ps1') -Scope Global -Force
    } catch {
        Write-StatusLine -Label "AI Handler" -Value "Load failed: $_" -Status 'error'
    }
} else {
    Write-StatusLine -Label "AI Handler" -Value "AIFacade not found" -Status 'error'
}

# === AI CODING TOOLS STATUS ===
Write-Host ""
Write-Host "  AI Coding Tools:" -ForegroundColor DarkGray
if ($loadedTools.Count -gt 0) {
    Write-StatusLine -Label "Self-Correction" -Value "Invoke-SelfCorrection" -Status 'ok'
    Write-StatusLine -Label "Prompt Optimizer" -Value "Optimize-Prompt" -Status 'ok'
    Write-StatusLine -Label "Few-Shot Learning" -Value "Invoke-AIWithFewShot" -Status 'ok'
} else {
    Write-StatusLine -Label "AI Tools" -Value "Not loaded" -Status 'warning'
}

# === AGENT SWARM STATUS ===
Write-Host ""
Write-Host "  Agent Swarm:" -ForegroundColor DarkGray
if (Get-Command Invoke-AgentSwarm -ErrorAction SilentlyContinue) {
    Write-StatusLine -Label "Witcher Agents" -Value "12 agents loaded" -Status 'ok'
    $yoloStatus = Get-YoloStatus
    if ($yoloStatus.YoloMode) {
        Write-StatusLine -Label "YOLO Mode" -Value "ENABLED (10 threads, 15s timeout)" -Status 'warning'
    } else {
        Write-StatusLine -Label "Mode" -Value "Standard (5 threads, 60s timeout)" -Status 'ok'
    }
    Write-StatusLine -Label "Commands" -Value "Invoke-AgentSwarm, Invoke-QuickAgent" -Status 'info'
} else {
    Write-StatusLine -Label "Agent Swarm" -Value "Not loaded" -Status 'warning'
}

Write-Separator -Width 55

# === WELCOME & TIP ===
Show-WelcomeMessage -CLI 'Claude'
Write-Host ""
Write-Host "  Tip: " -NoNewline -ForegroundColor DarkYellow
Write-Host (Get-TipOfDay) -ForegroundColor DarkGray

Show-QuickCommands -CLI 'claude'
Write-Host ""

# === DEFAULT WORKFLOW INFO ===
Write-Host "  Default Workflow:" -ForegroundColor DarkGray
Write-Host "    /hydra " -NoNewline -ForegroundColor Cyan
Write-Host "- Four-Headed Beast (Serena + DC + Playwright + Swarm)" -ForegroundColor DarkGray
if ($Yolo) {
    Write-Host "    YOLO Mode: " -NoNewline -ForegroundColor DarkGray
    Write-Host "ON" -NoNewline -ForegroundColor Red
    Write-Host " (10 threads, 15s timeout)" -ForegroundColor DarkGray
}
Write-Host ""

Write-Separator -Width 55
Write-Host ""
Write-Host "  Starting Claude CLI..." -ForegroundColor Cyan
Write-Host ""

# === START CLAUDE ===
try {
    $claudePath = "$env:USERPROFILE\AppData\Roaming\npm\claude.cmd"
    if (Test-Path $claudePath) {
        & $claudePath
    } else {
        claude
    }
} catch {
    $errorMsg = $_.Exception.Message
    Write-Host "  ERROR: $errorMsg" -ForegroundColor Red

    # Log error if ErrorLogger is available
    if (Get-Command Write-ErrorLog -ErrorAction SilentlyContinue) {
        Write-ErrorLog -Message "Claude CLI failed to start" -ErrorRecord $_ -Source 'Launcher'
    }
}

# === SESSION END ===
$sessionDuration = Get-SessionDuration

# Show THE END
Show-TheEnd -Variant 'claude' -SessionDuration $sessionDuration

# Log session end
if (Get-Command Write-LogEntry -ErrorAction SilentlyContinue) {
    Write-LogEntry -Level 'INFO' -Message "Session ended" -Source 'Launcher' -Data @{
        duration = $sessionDuration
        cli = 'ClaudeHYDRA'
    }
}

Write-Host "  Press any key to close..." -ForegroundColor Yellow
$null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')

# ═══════════════════════════════════════════════════════════════════════════════
# CLAUDE CLI - HYDRA LAUNCHER v10.0
# Enhanced GUI with status monitoring
# ═══════════════════════════════════════════════════════════════════════════════

Set-Location 'C:\Users\BIURODOM\Desktop\ClaudeCLI'
$Host.UI.RawUI.WindowTitle = 'Claude CLI (HYDRA 10.0)'

# Load GUI module
$guiModule = Join-Path $PSScriptRoot 'modules\GUI-Utils.psm1'
if (Test-Path $guiModule) { Import-Module $guiModule -Force }

# Load custom profile
$customProfile = Join-Path $PSScriptRoot 'profile.ps1'
if (Test-Path $customProfile) { . $customProfile }

# === CLEAR & SHOW LOGO ===
Clear-Host
Show-HydraLogo -Variant 'claude'

Write-Host "       CLAUDE CLI" -NoNewline -ForegroundColor Yellow
Write-Host " + " -NoNewline -ForegroundColor DarkGray
Write-Host "HYDRA 10.0" -ForegroundColor DarkYellow
Write-Host "       MCP: Serena + Desktop Commander + Playwright" -ForegroundColor DarkGray
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
$errorLogModule = Join-Path $PSScriptRoot 'ai-handler\modules\ErrorLogger.psm1'
if (Test-Path $errorLogModule) {
    Import-Module $errorLogModule -Force -Global -ErrorAction SilentlyContinue
    Initialize-ErrorLogger | Out-Null
}

# === SMART QUEUE ===
$smartQueueModule = Join-Path $PSScriptRoot 'ai-handler\modules\SmartQueue.psm1'
if (Test-Path $smartQueueModule) {
    Import-Module $smartQueueModule -Force -Global -ErrorAction SilentlyContinue
}

# === AI CODING TOOLS ===
$aiCodingModules = @(
    'AICodeReview.psm1',
    'SemanticGitCommit.psm1',
    'PredictiveAutocomplete.psm1'
)
$loadedTools = @()
foreach ($mod in $aiCodingModules) {
    $modPath = Join-Path $PSScriptRoot "ai-handler\modules\$mod"
    if (Test-Path $modPath) {
        Import-Module $modPath -Force -Global -ErrorAction SilentlyContinue
        $loadedTools += $mod -replace '\.psm1$', ''
    }
}

# === AI HANDLER ===
Write-Host ""
Write-Host "  AI Handler:" -ForegroundColor DarkGray
$aiHandlerModule = Join-Path $PSScriptRoot 'ai-handler\AIModelHandler.psm1'
if (Test-Path $aiHandlerModule) {
    try {
        Import-Module $aiHandlerModule -Force -Global -ErrorAction Stop
        Initialize-AIState | Out-Null

        # Check Ollama (local) - use TCP socket for PS5.1 compatibility
        $ollamaStatus = $false
        try {
            $tcp = New-Object System.Net.Sockets.TcpClient
            $tcp.Connect('localhost', 11434)
            $ollamaStatus = $tcp.Connected
            $tcp.Close()
        } catch { }

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
                    try {
                        $tcp = New-Object System.Net.Sockets.TcpClient
                        $tcp.Connect('localhost', 11434)
                        $ollamaStatus = $tcp.Connected
                        $tcp.Close()
                    } catch { }
                    $retries--
                }
            }
        }

        if ($ollamaStatus) {
            Write-StatusLine -Label "Ollama (local)" -Value "Running on :11434" -Status 'ok'
        } else {
            Write-StatusLine -Label "Ollama (local)" -Value "Not running" -Status 'warning'
        }

        # Check cloud providers
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

        Write-StatusLine -Label "AI Handler" -Value "v1.0 loaded" -Status 'ok'

        # Create global aliases
        Set-Alias -Name ai -Value (Join-Path $PSScriptRoot 'ai-handler\Invoke-AI.ps1') -Scope Global -Force
    } catch {
        Write-StatusLine -Label "AI Handler" -Value "Load failed: $_" -Status 'error'
    }
} else {
    Write-StatusLine -Label "AI Handler" -Value "Module not found" -Status 'error'
}

# === AI CODING TOOLS STATUS ===
Write-Host ""
Write-Host "  AI Coding Tools:" -ForegroundColor DarkGray
if ($loadedTools.Count -gt 0) {
    Write-StatusLine -Label "Code Review" -Value "Invoke-AICodeReview" -Status 'ok'
    Write-StatusLine -Label "Git Commit" -Value "New-AICommitMessage" -Status 'ok'
    Write-StatusLine -Label "Autocomplete" -Value "Get-CodePrediction" -Status 'ok'
} else {
    Write-StatusLine -Label "AI Tools" -Value "Not loaded" -Status 'warning'
}

Write-Separator -Width 55

# === WELCOME & TIP ===
Show-WelcomeMessage -CLI 'Claude'
Write-Host ""
Write-Host "  Tip: " -NoNewline -ForegroundColor DarkYellow
Write-Host (Get-TipOfDay) -ForegroundColor DarkGray

Show-QuickCommands -CLI 'claude'
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
        cli = 'ClaudeCLI'
    }
}

Write-Host "  Press any key to close..." -ForegroundColor Yellow
$null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')

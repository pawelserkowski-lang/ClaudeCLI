<#
.SYNOPSIS
    Display comprehensive HYDRA 10.1 system status

.DESCRIPTION
    Shows status of all HYDRA components:
    - MCP Servers (Serena, Desktop Commander, Playwright)
    - AI Handler (Ollama, Cloud APIs)
    - Advanced AI Modules
    - System resources (CPU, Memory)

.EXAMPLE
    .\Get-HydraStatus.ps1
    .\Get-HydraStatus.ps1 -Detailed
#>

param(
    [switch]$Detailed
)

$ErrorActionPreference = 'SilentlyContinue'
$root = $PSScriptRoot
$aiHandlerPath = Join-Path $root "ai-handler"

# Colors
function Write-Status($text, $status) {
    $color = switch ($status) {
        "OK" { "Green" }
        "WARN" { "Yellow" }
        "ERROR" { "Red" }
        "INFO" { "Cyan" }
        default { "White" }
    }
    Write-Host $text -ForegroundColor $color
}

# Header
Write-Host @"

  ╔═══════════════════════════════════════════════════════════════╗
  ║  🐉 HYDRA 10.1 - System Status                                ║
  ╠═══════════════════════════════════════════════════════════════╣
"@ -ForegroundColor Cyan

# === System Resources ===
$cpu = [math]::Round((Get-CimInstance Win32_Processor).LoadPercentage, 0)
$mem = [math]::Round((Get-CimInstance Win32_OperatingSystem |
    ForEach-Object { (1 - $_.FreePhysicalMemory / $_.TotalVisibleMemorySize) * 100 }), 0)

$cpuBar = "[" + ("█" * [math]::Floor($cpu/10)) + ("░" * (10 - [math]::Floor($cpu/10))) + "]"
$memBar = "[" + ("█" * [math]::Floor($mem/10)) + ("░" * (10 - [math]::Floor($mem/10))) + "]"

$cpuStatus = if ($cpu -lt 70) { "OK" } elseif ($cpu -lt 90) { "WARN" } else { "ERROR" }
$memStatus = if ($mem -lt 85) { "OK" } else { "WARN" }

Write-Host "  ║  System Resources                                           ║" -ForegroundColor Cyan
Write-Host -NoNewline "  ║    CPU: $cpuBar $($cpu.ToString().PadLeft(3))%  "
Write-Status "[$cpuStatus]" $cpuStatus
Write-Host -NoNewline "  ║    RAM: $memBar $($mem.ToString().PadLeft(3))%  "
Write-Status "[$memStatus]" $memStatus

$provider = if ($cpu -lt 70) { "LOCAL (Ollama)" } elseif ($cpu -lt 90) { "HYBRID" } else { "CLOUD" }
Write-Host "  ║    Recommended Provider: $provider" -ForegroundColor White

# === MCP Servers ===
Write-Host "  ╠═══════════════════════════════════════════════════════════════╣" -ForegroundColor Cyan
Write-Host "  ║  MCP Servers                                                  ║" -ForegroundColor Cyan

$mcpServers = @(
    @{ Name = "Serena"; Port = 9000; Check = "http://localhost:9000/sse" }
    @{ Name = "Desktop Commander"; Port = 8100; Check = $null }
    @{ Name = "Playwright"; Port = 5200; Check = $null }
)

foreach ($server in $mcpServers) {
    $status = "OK"
    $statusText = "Running"

    # Check if port is listening
    $portCheck = Get-NetTCPConnection -LocalPort $server.Port -State Listen 2>$null
    if (-not $portCheck) {
        $status = "WARN"
        $statusText = "Stdio Mode"
    }

    $name = $server.Name.PadRight(20)
    Write-Host -NoNewline "  ║    $name "
    Write-Status "[$statusText]" $status
}

# === Ollama ===
Write-Host "  ╠═══════════════════════════════════════════════════════════════╣" -ForegroundColor Cyan
Write-Host "  ║  AI Providers                                                 ║" -ForegroundColor Cyan

# Check Ollama
$ollamaStatus = "ERROR"
$ollamaText = "Not Running"
$ollamaModels = @()

try {
    $response = Invoke-RestMethod -Uri "http://localhost:11434/api/tags" -Method Get -TimeoutSec 2
    if ($response.models) {
        $ollamaStatus = "OK"
        $ollamaModels = $response.models | Select-Object -ExpandProperty name
        $ollamaText = "$($ollamaModels.Count) models"
    }
} catch {
    $ollamaStatus = "ERROR"
}

Write-Host -NoNewline "  ║    Ollama (local)     "
Write-Status "[$ollamaText]" $ollamaStatus

# Check Anthropic
$anthropicStatus = if ($env:ANTHROPIC_API_KEY) { "OK" } else { "WARN" }
$anthropicText = if ($env:ANTHROPIC_API_KEY) { "API Key Set" } else { "No API Key" }
Write-Host -NoNewline "  ║    Anthropic (cloud)  "
Write-Status "[$anthropicText]" $anthropicStatus

# Check OpenAI
$openaiStatus = if ($env:OPENAI_API_KEY) { "OK" } else { "WARN" }
$openaiText = if ($env:OPENAI_API_KEY) { "API Key Set" } else { "No API Key" }
Write-Host -NoNewline "  ║    OpenAI (cloud)     "
Write-Status "[$openaiText]" $openaiStatus

# === Advanced AI Modules ===
Write-Host "  ╠═══════════════════════════════════════════════════════════════╣" -ForegroundColor Cyan
Write-Host "  ║  Advanced AI Modules                                          ║" -ForegroundColor Cyan

$modules = @(
    @{ Name = "SelfCorrection"; File = "SelfCorrection.psm1" }
    @{ Name = "FewShotLearning"; File = "FewShotLearning.psm1" }
    @{ Name = "SpeculativeDecoding"; File = "SpeculativeDecoding.psm1" }
    @{ Name = "LoadBalancer"; File = "LoadBalancer.psm1" }
    @{ Name = "SemanticFileMapping"; File = "SemanticFileMapping.psm1" }
    @{ Name = "PromptOptimizer"; File = "PromptOptimizer.psm1" }
)

foreach ($mod in $modules) {
    $path = Join-Path $aiHandlerPath "modules\$($mod.File)"
    $exists = Test-Path $path
    $status = if ($exists) { "OK" } else { "ERROR" }
    $statusText = if ($exists) { "Loaded" } else { "Missing" }

    $name = $mod.Name.PadRight(22)
    Write-Host -NoNewline "  ║    $name "
    Write-Status "[$statusText]" $status
}

# === Available Commands ===
Write-Host "  ╠═══════════════════════════════════════════════════════════════╣" -ForegroundColor Cyan
Write-Host "  ║  Quick Commands                                               ║" -ForegroundColor Cyan
Write-Host "  ║    /ai              Local AI query (cost: `$0)                ║" -ForegroundColor White
Write-Host "  ║    /ai-batch        Parallel batch queries                    ║" -ForegroundColor White
Write-Host "  ║    /self-correct    Code with validation                      ║" -ForegroundColor White
Write-Host "  ║    /speculate       Model racing (fastest)                    ║" -ForegroundColor White
Write-Host "  ║    /semantic-query  Deep RAG with imports                     ║" -ForegroundColor White
Write-Host "  ║    /few-shot        Learn from history                        ║" -ForegroundColor White
Write-Host "  ║    /load-balance    CPU-aware provider                        ║" -ForegroundColor White
Write-Host "  ╚═══════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan

# === Detailed Info ===
if ($Detailed -and $ollamaModels.Count -gt 0) {
    Write-Host "`n  Local Ollama Models:" -ForegroundColor Yellow
    foreach ($model in $ollamaModels) {
        Write-Host "    - $model" -ForegroundColor Gray
    }
}

# === Recommendations ===
Write-Host ""
if ($ollamaStatus -eq "ERROR") {
    Write-Host "  [!] Ollama not running. Start with: ollama serve" -ForegroundColor Yellow
}
if ($anthropicStatus -eq "WARN") {
    Write-Host "  [!] No Anthropic API key. Set ANTHROPIC_API_KEY for cloud fallback" -ForegroundColor Yellow
}
if ($cpu -gt 80) {
    Write-Host "  [!] High CPU load. Consider using cloud providers" -ForegroundColor Yellow
}

Write-Host ""

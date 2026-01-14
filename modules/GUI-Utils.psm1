# HYDRA GUI UTILS - Shared GUI components for ClaudeCLI & GeminiCLI

# === ASCII Art Logos ===
function Show-HydraLogo {
    param([string]$Variant = 'claude')
    
    $logo = @"

    ##  ## ##  ## ###   ###   ###  
    ##  ##  ####  ## ## ## ## ## ## 
    ######   ##   ## ## ###   ##### 
    ##  ##   ##   ## ## ## ## ##  ##
    ##  ##   ##   ###  ##  ## ##  ##

"@
    
    $color = if ($Variant -eq 'claude') { 'Yellow' } else { 'Cyan' }
    Write-Host $logo -ForegroundColor $color
}

# === Box Drawing (ASCII) ===
function Write-Box {
    param(
        [string]$Title,
        [string[]]$Content,
        [string]$Color = 'Cyan',
        [int]$Width = 60
    )
    
    $top = "+" + ("-" * ($Width - 2)) + "+"
    $bot = "+" + ("-" * ($Width - 2)) + "+"
    $mid = "+" + ("-" * ($Width - 2)) + "+"
    
    Write-Host $top -ForegroundColor $Color
    if ($Title) {
        $titlePad = " $Title".PadRight($Width - 3)
        if ($titlePad.Length -gt ($Width - 3)) { $titlePad = $titlePad.Substring(0, $Width - 3) }
        Write-Host "|" -NoNewline -ForegroundColor $Color
        Write-Host $titlePad -NoNewline -ForegroundColor White
        Write-Host "|" -ForegroundColor $Color
        Write-Host $mid -ForegroundColor $Color
    }
    foreach ($line in $Content) {
        $linePad = " $line".PadRight($Width - 3)
        if ($linePad.Length -gt ($Width - 3)) { $linePad = $linePad.Substring(0, $Width - 3) }
        Write-Host "|" -NoNewline -ForegroundColor $Color
        Write-Host $linePad -NoNewline -ForegroundColor DarkGray
        Write-Host "|" -ForegroundColor $Color
    }
    Write-Host $bot -ForegroundColor $Color
}


# === Status Line ===
function Write-StatusLine {
    param(
        [string]$Label,
        [string]$Value,
        [string]$Status = 'ok'
    )
    
    $icon = switch ($Status) {
        'ok'      { '[OK]'; $color = 'Green' }
        'error'   { '[X]'; $color = 'Red' }
        { $_ -in 'warn', 'warning' } { '[!]'; $color = 'Yellow' }
        'info'    { '[i]'; $color = 'Cyan' }
        default   { '[.]'; $color = 'DarkGray' }
    }
    
    Write-Host "  $icon " -NoNewline -ForegroundColor $color
    Write-Host "${Label}: " -NoNewline -ForegroundColor DarkGray
    Write-Host $Value -ForegroundColor White
}

# === System Info ===
function Get-SystemInfo {
    $mem = Get-CimInstance Win32_OperatingSystem -ErrorAction SilentlyContinue
    $memUsed = if ($mem) { [math]::Round(($mem.TotalVisibleMemorySize - $mem.FreePhysicalMemory) / 1MB, 1) } else { 0 }
    $memTotal = if ($mem) { [math]::Round($mem.TotalVisibleMemorySize / 1MB, 1) } else { 0 }
    $nodeVer = try { (node -v 2>$null) -replace 'v','' } catch { 'N/A' }
    $psVer = $PSVersionTable.PSVersion.ToString()
    
    return @{
        Memory = "$memUsed/$memTotal GB"
        Node = $nodeVer
        PowerShell = $psVer
    }
}


# === API Key Status ===
function Get-APIKeyStatus {
    param([string]$Provider = 'anthropic')
    
    $keyName = switch ($Provider) {
        'anthropic' { 'ANTHROPIC_API_KEY' }
        'openai'    { 'OPENAI_API_KEY' }
        'google'    { 'GOOGLE_API_KEY' }
        'gemini'    { 'GEMINI_API_KEY' }
        default     { $Provider }
    }
    
    $key = [Environment]::GetEnvironmentVariable($keyName, 'User')
    if (-not $key) { $key = [Environment]::GetEnvironmentVariable($keyName, 'Process') }
    
    if ($key) {
        $len = [Math]::Min(12, $key.Length)
        $masked = $key.Substring(0, $len) + "..." 
        return @{ Present = $true; Masked = $masked; Name = $keyName }
    }
    return @{ Present = $false; Masked = 'Not set'; Name = $keyName }
}

# === MCP Server Status ===
function Test-MCPServer {
    param([string]$Name)
    
    $result = @{ Name = $Name; Online = $false; Message = 'Unknown' }
    
    switch ($Name) {
        'ollama' {
            try {
                $r = Invoke-RestMethod -Uri 'http://localhost:11434/api/tags' -TimeoutSec 2 -ErrorAction Stop
                $result.Online = $true
                $result.Message = "$($r.models.Count) models"
            } catch { $result.Message = 'Not responding' }
        }
        default {
            $result.Online = $true
            $result.Message = 'Available'
        }
    }
    return $result
}


# === Tips of the Day ===
function Get-TipOfDay {
    $tips = @(
        "Use /help to see all available commands",
        "Press Ctrl+C to cancel current operation",
        "Double-Escape interrupts the current task",
        "Use @mcp-server tool_name to call MCP tools",
        "Parallel operations are faster - batch requests!",
        "/ai:quick for fast local AI responses",
        "/hydra:status shows system health",
        "API keys are read from environment variables",
        "Use -y or --yolo for auto-approve mode",
        "Check GEMINI.md or CLAUDE.md for full docs"
    )
    return $tips[(Get-Date).DayOfYear % $tips.Count]
}

# === Welcome Message ===
function Show-WelcomeMessage {
    param([string]$CLI = 'Claude')
    
    $date = Get-Date -Format "yyyy-MM-dd HH:mm"
    $day = (Get-Date).DayOfWeek
    $greeting = switch ((Get-Date).Hour) {
        { $_ -lt 6 }  { "Good night" }
        { $_ -lt 12 } { "Good morning" }
        { $_ -lt 18 } { "Good afternoon" }
        default       { "Good evening" }
    }
    
    Write-Host ""
    Write-Host "  $greeting! " -NoNewline -ForegroundColor White
    Write-Host "$day, $date" -ForegroundColor DarkGray
}


# === Quick Commands ===
function Show-QuickCommands {
    param([string]$CLI = 'claude')
    
    Write-Host ""
    Write-Host "  Quick Commands:" -ForegroundColor DarkGray
    if ($CLI -eq 'claude') {
        Write-Host "    /help" -NoNewline -ForegroundColor Cyan
        Write-Host " - Help  " -NoNewline -ForegroundColor DarkGray
        Write-Host "/commit" -NoNewline -ForegroundColor Cyan
        Write-Host " - Git  " -NoNewline -ForegroundColor DarkGray
        Write-Host "/review-pr" -NoNewline -ForegroundColor Cyan
        Write-Host " - PR" -ForegroundColor DarkGray
    } else {
        Write-Host "    /ai:quick" -NoNewline -ForegroundColor Cyan
        Write-Host " - Fast  " -NoNewline -ForegroundColor DarkGray
        Write-Host "/ai:code" -NoNewline -ForegroundColor Cyan
        Write-Host " - Code  " -NoNewline -ForegroundColor DarkGray
        Write-Host "/hydra:status" -NoNewline -ForegroundColor Cyan
        Write-Host " - Status" -ForegroundColor DarkGray
    }
}

# === Separator ===
function Write-Separator {
    param([string]$Color = 'DarkGray', [int]$Width = 55)
    Write-Host ("-" * $Width) -ForegroundColor $Color
}

# === Session Timer ===
$script:SessionStart = Get-Date
function Get-SessionDuration {
    $duration = (Get-Date) - $script:SessionStart
    $fmt = "{0:hh\:mm\:ss}" -f $duration
    return $fmt
}

# === THE END ASCII Art ===
function Show-TheEnd {
    param(
        [string]$Variant = 'claude',
        [string]$SessionDuration = ''
    )

    $art = @"

  ######## ##  ## #######     ####### ###   ## ######
     ##    ##  ## ##          ##      ####  ## ##   ##
     ##    ###### ####        ####    ## ## ## ##   ##
     ##    ##  ## ##          ##      ##  #### ##   ##
     ##    ##  ## #######     ####### ##   ### ######

"@

    $color = switch ($Variant) {
        'claude' { 'Yellow' }
        'gemini' { 'Cyan' }
        default  { 'White' }
    }
    $accentColor = switch ($Variant) {
        'claude' { 'DarkYellow' }
        'gemini' { 'DarkCyan' }
        default  { 'DarkGray' }
    }

    Write-Host ""
    Write-Host $art -ForegroundColor $color

    # Session summary
    $date = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Write-Host "  +-----------------------------------------------------+" -ForegroundColor $accentColor
    Write-Host "  |" -NoNewline -ForegroundColor $accentColor
    Write-Host "  Session completed: $date" -NoNewline -ForegroundColor White
    Write-Host "       |" -ForegroundColor $accentColor
    if ($SessionDuration) {
        Write-Host "  |" -NoNewline -ForegroundColor $accentColor
        Write-Host "  Duration: $SessionDuration" -NoNewline -ForegroundColor Green
        $padding = " " * (39 - $SessionDuration.Length)
        Write-Host "$padding|" -ForegroundColor $accentColor
    }
    Write-Host "  |" -NoNewline -ForegroundColor $accentColor
    Write-Host "  Thank you for using HYDRA!" -NoNewline -ForegroundColor $color
    Write-Host "                  |" -ForegroundColor $accentColor
    Write-Host "  +-----------------------------------------------------+" -ForegroundColor $accentColor
    Write-Host ""
}

# === Export ===
Export-ModuleMember -Function @(
    'Show-HydraLogo', 'Write-Box', 'Write-StatusLine',
    'Get-SystemInfo', 'Get-APIKeyStatus', 'Test-MCPServer',
    'Get-TipOfDay', 'Show-WelcomeMessage', 'Show-QuickCommands',
    'Write-Separator', 'Get-SessionDuration', 'Show-TheEnd'
)

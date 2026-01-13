# ═══════════════════════════════════════════════════════════════════════════════
# CLAUDE CLI - CUSTOM PROFILE
# Isolated profile for ClaudeCLI (does not load user's default profile)
# ═══════════════════════════════════════════════════════════════════════════════

# === PSReadLine Configuration ===
if (Get-Module -Name PSReadLine -ErrorAction SilentlyContinue) {
    # Double-Escape as interrupt
    $script:lastEscapeTime = [DateTime]::MinValue
    Set-PSReadLineKeyHandler -Key Escape -ScriptBlock {
        $now = [DateTime]::Now
        $diff = ($now - $script:lastEscapeTime).TotalMilliseconds
        if ($diff -lt 400) {
            [Microsoft.PowerShell.PSConsoleReadLine]::CancelLine()
            [Microsoft.PowerShell.PSConsoleReadLine]::AcceptLine()
        } else {
            [Microsoft.PowerShell.PSConsoleReadLine]::RevertLine()
        }
        $script:lastEscapeTime = $now
    }

    # Ctrl+C trap
    Set-PSReadLineKeyHandler -Key Ctrl+c -ScriptBlock {
        $line = $null
        $cursor = $null
        [Microsoft.PowerShell.PSConsoleReadLine]::GetBufferState([ref]$line, [ref]$cursor)
        if ($line.Length -gt 0) {
            [Microsoft.PowerShell.PSConsoleReadLine]::CancelLine()
        } else {
            Write-Host "`n[Ctrl+C] Use 'exit' to quit or Double-Escape to interrupt" -ForegroundColor Yellow
            [Microsoft.PowerShell.PSConsoleReadLine]::AcceptLine()
        }
    }
}

# === Claude Function ===
function Start-Claude {
    param([Parameter(ValueFromRemainingArguments)]$Arguments)
    
    $claudePath = "$env:USERPROFILE\AppData\Roaming\npm\claude.cmd"
    if (Test-Path $claudePath) {
        & $claudePath @Arguments
    } else {
        claude @Arguments
    }
}

Set-Alias -Name c -Value Start-Claude

# === Prompt ===
function prompt {
    $path = (Get-Location).Path
    if ($path.Length -gt 40) { $path = "..." + $path.Substring($path.Length - 37) }
    Write-Host "[" -NoNewline -ForegroundColor DarkGray
    Write-Host "Claude" -NoNewline -ForegroundColor DarkYellow
    Write-Host "] " -NoNewline -ForegroundColor DarkGray
    Write-Host $path -NoNewline -ForegroundColor Blue
    return " > "
}

Write-Host "[ClaudeCLI Profile Loaded]" -ForegroundColor DarkGray

# ═══════════════════════════════════════════════════════════════════════════
# ConsoleUI.psm1 - HYDRA Console UI Utilities
# ═══════════════════════════════════════════════════════════════════════════
# Provides: ASCII art, spinners, progress bars, colored output, tables
# ═══════════════════════════════════════════════════════════════════════════

# ─────────────────────────────────────────────────────────────────────────────
# HYDRA ASCII ART BANNER
# ─────────────────────────────────────────────────────────────────────────────

function Show-HydraBanner {
    param(
        [string]$Version = "10.0",
        [switch]$Compact
    )

    $colors = @('DarkCyan', 'Cyan', 'White', 'Cyan', 'DarkCyan')

    if ($Compact) {
        $banner = @"

    ██╗  ██╗██╗   ██╗██████╗ ██████╗  █████╗
    ██║  ██║╚██╗ ██╔╝██╔══██╗██╔══██╗██╔══██╗
    ███████║ ╚████╔╝ ██║  ██║██████╔╝███████║
    ██╔══██║  ╚██╔╝  ██║  ██║██╔══██╗██╔══██║
    ██║  ██║   ██║   ██████╔╝██║  ██║██║  ██║
    ╚═╝  ╚═╝   ╚═╝   ╚═════╝ ╚═╝  ╚═╝╚═╝  ╚═╝
"@
    } else {
        $banner = @"

          ╭─────╮       ╭─────╮       ╭─────╮
          │ ◉ ◉ │       │ ◉ ◉ │       │ ◉ ◉ │
          │  ▽  │       │  ▽  │       │  ▽  │
          ╰──┬──╯       ╰──┬──╯       ╰──┬──╯
             │    ╲     │     ╱    │
             ╰──────────┴──────────╯
                    ║     ║
    ██╗  ██╗██╗   ██╗██████╗ ██████╗  █████╗
    ██║  ██║╚██╗ ██╔╝██╔══██╗██╔══██╗██╔══██╗
    ███████║ ╚████╔╝ ██║  ██║██████╔╝███████║
    ██╔══██║  ╚██╔╝  ██║  ██║██╔══██╗██╔══██║
    ██║  ██║   ██║   ██████╔╝██║  ██║██║  ██║
    ╚═╝  ╚═╝   ╚═╝   ╚═════╝ ╚═╝  ╚═╝╚═╝  ╚═╝
"@
    }

    $lines = $banner -split "`n"
    $i = 0
    foreach ($line in $lines) {
        $colorIndex = [Math]::Min($i, $colors.Count - 1)
        Write-Host $line -ForegroundColor $colors[$colorIndex]
        $i++
    }

    # Subtitle
    Write-Host ""
    Write-Host "          ┌─────────────────────────────────────────┐" -ForegroundColor DarkGray
    Write-Host "          │  " -NoNewline -ForegroundColor DarkGray
    Write-Host "Claude CLI" -NoNewline -ForegroundColor Cyan
    Write-Host " + " -NoNewline -ForegroundColor DarkGray
    Write-Host "Serena" -NoNewline -ForegroundColor Magenta
    Write-Host " + " -NoNewline -ForegroundColor DarkGray
    Write-Host "Desktop Commander" -NoNewline -ForegroundColor Yellow
    Write-Host "  │" -ForegroundColor DarkGray
    Write-Host "          │             " -NoNewline -ForegroundColor DarkGray
    Write-Host "Version $Version" -NoNewline -ForegroundColor White
    Write-Host "                   │" -ForegroundColor DarkGray
    Write-Host "          └─────────────────────────────────────────┘" -ForegroundColor DarkGray
    Write-Host ""
}

# ─────────────────────────────────────────────────────────────────────────────
# SPINNER ANIMATION
# ─────────────────────────────────────────────────────────────────────────────

$script:SpinnerFrames = @('⠋', '⠙', '⠹', '⠸', '⠼', '⠴', '⠦', '⠧', '⠇', '⠏')
$script:SpinnerIndex = 0

function Show-Spinner {
    param(
        [string]$Message = "Loading",
        [string]$Color = "Cyan"
    )

    $frame = $script:SpinnerFrames[$script:SpinnerIndex]
    $script:SpinnerIndex = ($script:SpinnerIndex + 1) % $script:SpinnerFrames.Count

    Write-Host "`r  $frame " -NoNewline -ForegroundColor $Color
    Write-Host $Message -NoNewline -ForegroundColor White
    Write-Host "   " -NoNewline  # Clear trailing chars
}

function Invoke-WithSpinner {
    param(
        [scriptblock]$ScriptBlock,
        [string]$Message = "Processing",
        [string]$SuccessMessage = "Done",
        [string]$FailMessage = "Failed"
    )

    $job = Start-Job -ScriptBlock $ScriptBlock
    $script:SpinnerIndex = 0

    while ($job.State -eq 'Running') {
        Show-Spinner -Message $Message
        Start-Sleep -Milliseconds 80
    }

    $result = Receive-Job -Job $job
    Remove-Job -Job $job

    if ($job.State -eq 'Completed') {
        Write-Host "`r  ✓ " -NoNewline -ForegroundColor Green
        Write-Host $SuccessMessage -ForegroundColor White
        Write-Host "                              " # Clear line
    } else {
        Write-Host "`r  ✗ " -NoNewline -ForegroundColor Red
        Write-Host $FailMessage -ForegroundColor White
    }

    return $result
}

# ─────────────────────────────────────────────────────────────────────────────
# STATUS ICONS
# ─────────────────────────────────────────────────────────────────────────────

function Get-StatusIcon {
    param(
        [ValidateSet('ok', 'error', 'warning', 'info', 'pending', 'disabled')]
        [string]$Status
    )

    switch ($Status) {
        'ok'       { return @{ Icon = '●'; Color = 'Green' } }
        'error'    { return @{ Icon = '●'; Color = 'Red' } }
        'warning'  { return @{ Icon = '●'; Color = 'Yellow' } }
        'info'     { return @{ Icon = '●'; Color = 'Cyan' } }
        'pending'  { return @{ Icon = '○'; Color = 'DarkGray' } }
        'disabled' { return @{ Icon = '○'; Color = 'DarkGray' } }
        default    { return @{ Icon = '?'; Color = 'Gray' } }
    }
}

function Write-Status {
    param(
        [string]$Label,
        [string]$Value = "",
        [ValidateSet('ok', 'error', 'warning', 'info', 'pending', 'disabled')]
        [string]$Status = 'info',
        [string]$Detail = ""
    )

    $icon = Get-StatusIcon -Status $Status
    Write-Host "  $($icon.Icon) " -NoNewline -ForegroundColor $icon.Color
    Write-Host "$Label" -NoNewline -ForegroundColor White

    if ($Value) {
        Write-Host ": " -NoNewline -ForegroundColor DarkGray
        Write-Host $Value -NoNewline -ForegroundColor $icon.Color
    }

    if ($Detail) {
        Write-Host " ($Detail)" -NoNewline -ForegroundColor DarkGray
    }

    Write-Host ""
}

# ─────────────────────────────────────────────────────────────────────────────
# SECTION HEADERS
# ─────────────────────────────────────────────────────────────────────────────

function Write-Section {
    param(
        [string]$Title,
        [string]$Icon = "▸",
        [string]$Color = "Cyan"
    )

    Write-Host ""
    Write-Host "  $Icon " -NoNewline -ForegroundColor $Color
    Write-Host $Title -ForegroundColor White
    Write-Host "  $('─' * ($Title.Length + 2))" -ForegroundColor DarkGray
}

# ─────────────────────────────────────────────────────────────────────────────
# BOXES AND TABLES
# ─────────────────────────────────────────────────────────────────────────────

function Write-Box {
    param(
        [string[]]$Lines,
        [string]$BorderColor = "DarkGray",
        [string]$TextColor = "White",
        [int]$Padding = 2
    )

    $maxLen = ($Lines | ForEach-Object { $_.Length } | Measure-Object -Maximum).Maximum
    $width = $maxLen + ($Padding * 2)

    Write-Host "  ╭$('─' * $width)╮" -ForegroundColor $BorderColor

    foreach ($line in $Lines) {
        $padded = $line.PadRight($maxLen)
        Write-Host "  │$(' ' * $Padding)" -NoNewline -ForegroundColor $BorderColor
        Write-Host $padded -NoNewline -ForegroundColor $TextColor
        Write-Host "$(' ' * $Padding)│" -ForegroundColor $BorderColor
    }

    Write-Host "  ╰$('─' * $width)╯" -ForegroundColor $BorderColor
}

function Write-Table {
    param(
        [array]$Data,
        [string[]]$Columns,
        [string]$HeaderColor = "Cyan",
        [string]$BorderColor = "DarkGray"
    )

    if (-not $Data -or $Data.Count -eq 0) { return }

    # Calculate column widths
    $widths = @{}
    foreach ($col in $Columns) {
        $maxLen = ($Data | ForEach-Object { $_[$col].ToString().Length } | Measure-Object -Maximum).Maximum
        $widths[$col] = [Math]::Max($maxLen, $col.Length)
    }

    # Header
    $totalWidth = ($widths.Values | Measure-Object -Sum).Sum + ($Columns.Count * 3) + 1
    Write-Host "  ┌$('─' * $totalWidth)┐" -ForegroundColor $BorderColor

    Write-Host "  │ " -NoNewline -ForegroundColor $BorderColor
    foreach ($col in $Columns) {
        Write-Host $col.PadRight($widths[$col]) -NoNewline -ForegroundColor $HeaderColor
        Write-Host " │ " -NoNewline -ForegroundColor $BorderColor
    }
    Write-Host ""

    Write-Host "  ├$('─' * $totalWidth)┤" -ForegroundColor $BorderColor

    # Rows
    foreach ($row in $Data) {
        Write-Host "  │ " -NoNewline -ForegroundColor $BorderColor
        foreach ($col in $Columns) {
            $value = $row[$col].ToString().PadRight($widths[$col])
            $color = if ($row.Color) { $row.Color } else { 'White' }
            Write-Host $value -NoNewline -ForegroundColor $color
            Write-Host " │ " -NoNewline -ForegroundColor $BorderColor
        }
        Write-Host ""
    }

    Write-Host "  └$('─' * $totalWidth)┘" -ForegroundColor $BorderColor
}

# ─────────────────────────────────────────────────────────────────────────────
# PROGRESS BAR
# ─────────────────────────────────────────────────────────────────────────────

function Write-ProgressBar {
    param(
        [int]$Percent,
        [int]$Width = 30,
        [string]$Label = "",
        [string]$FillColor = "Cyan",
        [string]$EmptyColor = "DarkGray"
    )

    $filled = [Math]::Floor($Width * $Percent / 100)
    $empty = $Width - $filled

    Write-Host "  " -NoNewline
    if ($Label) {
        Write-Host "$Label " -NoNewline -ForegroundColor White
    }

    Write-Host "[" -NoNewline -ForegroundColor DarkGray
    Write-Host ("█" * $filled) -NoNewline -ForegroundColor $FillColor
    Write-Host ("░" * $empty) -NoNewline -ForegroundColor $EmptyColor
    Write-Host "] " -NoNewline -ForegroundColor DarkGray
    Write-Host "$Percent%" -ForegroundColor White
}

# ─────────────────────────────────────────────────────────────────────────────
# GRADIENT TEXT
# ─────────────────────────────────────────────────────────────────────────────

function Write-Gradient {
    param(
        [string]$Text,
        [string[]]$Colors = @('DarkCyan', 'Cyan', 'White')
    )

    $segmentLength = [Math]::Ceiling($Text.Length / $Colors.Count)

    for ($i = 0; $i -lt $Text.Length; $i++) {
        $colorIndex = [Math]::Min([Math]::Floor($i / $segmentLength), $Colors.Count - 1)
        Write-Host $Text[$i] -NoNewline -ForegroundColor $Colors[$colorIndex]
    }
    Write-Host ""
}

# ─────────────────────────────────────────────────────────────────────────────
# QUICK STATUS DASHBOARD
# ─────────────────────────────────────────────────────────────────────────────

function Show-QuickDashboard {
    param(
        [hashtable]$Items  # @{ "Label" = @{ Status = "ok"; Value = "..."; Detail = "..." } }
    )

    $maxLabelLen = ($Items.Keys | ForEach-Object { $_.Length } | Measure-Object -Maximum).Maximum

    foreach ($key in $Items.Keys) {
        $item = $Items[$key]
        $icon = Get-StatusIcon -Status $item.Status

        Write-Host "  $($icon.Icon) " -NoNewline -ForegroundColor $icon.Color
        Write-Host $key.PadRight($maxLabelLen) -NoNewline -ForegroundColor White
        Write-Host "  " -NoNewline

        if ($item.Value) {
            Write-Host $item.Value -NoNewline -ForegroundColor $icon.Color
        }

        if ($item.Detail) {
            Write-Host " $($item.Detail)" -NoNewline -ForegroundColor DarkGray
        }

        Write-Host ""
    }
}

# ─────────────────────────────────────────────────────────────────────────────
# KEYBOARD SHORTCUTS HINT
# ─────────────────────────────────────────────────────────────────────────────

function Show-KeyHints {
    param(
        [hashtable]$Keys  # @{ "Ctrl+C" = "Exit"; "Tab" = "Complete" }
    )

    Write-Host ""
    Write-Host "  " -NoNewline

    $first = $true
    foreach ($key in $Keys.Keys) {
        if (-not $first) {
            Write-Host " │ " -NoNewline -ForegroundColor DarkGray
        }

        Write-Host $key -NoNewline -ForegroundColor Yellow
        Write-Host " $($Keys[$key])" -NoNewline -ForegroundColor DarkGray

        $first = $false
    }
    Write-Host ""
}

# ─────────────────────────────────────────────────────────────────────────────
# EXPORTS
# ─────────────────────────────────────────────────────────────────────────────

Export-ModuleMember -Function @(
    'Show-HydraBanner',
    'Show-Spinner',
    'Invoke-WithSpinner',
    'Get-StatusIcon',
    'Write-Status',
    'Write-Section',
    'Write-Box',
    'Write-Table',
    'Write-ProgressBar',
    'Write-Gradient',
    'Show-QuickDashboard',
    'Show-KeyHints'
)

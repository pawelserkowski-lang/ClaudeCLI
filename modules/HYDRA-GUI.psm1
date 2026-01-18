#Requires -Version 5.1
<#
.SYNOPSIS
    HYDRA GUI Module - 50 Visual Enhancements for ClaudeHYDRA & GeminiCLI
.DESCRIPTION
    Comprehensive GUI/TUI module featuring:
    - Animated splash screens and logos
    - Progress bars and spinners
    - Theming system (Dark/Light/Custom)
    - Syntax highlighting
    - Interactive components
    - Status indicators
    - Charts and visualizations
.VERSION
    1.0.0
.AUTHOR
    HYDRA System
#>

#region Configuration

$script:GUI_CONFIG = @{
    Theme = "dark"
    AnimationsEnabled = $true
    SoundEnabled = $true
    CompactMode = $false
    UnicodeSupport = $true
    RefreshRateMs = 100
}

$script:THEMES = @{
    dark = @{
        Primary = "Cyan"
        Secondary = "Blue"
        Accent = "Magenta"
        Success = "Green"
        Warning = "Yellow"
        Error = "Red"
        Muted = "DarkGray"
        Text = "White"
        Background = "Black"
        Border = "DarkCyan"
    }
    light = @{
        Primary = "DarkBlue"
        Secondary = "DarkCyan"
        Accent = "DarkMagenta"
        Success = "DarkGreen"
        Warning = "DarkYellow"
        Error = "DarkRed"
        Muted = "Gray"
        Text = "Black"
        Background = "White"
        Border = "DarkGray"
    }
    dracula = @{
        Primary = "Magenta"
        Secondary = "Cyan"
        Accent = "Green"
        Success = "Green"
        Warning = "Yellow"
        Error = "Red"
        Muted = "DarkGray"
        Text = "White"
        Background = "Black"
        Border = "Magenta"
    }
    nord = @{
        Primary = "Cyan"
        Secondary = "Blue"
        Accent = "DarkCyan"
        Success = "Green"
        Warning = "Yellow"
        Error = "Red"
        Muted = "DarkGray"
        Text = "White"
        Background = "Black"
        Border = "DarkBlue"
    }
    monokai = @{
        Primary = "Yellow"
        Secondary = "Magenta"
        Accent = "Cyan"
        Success = "Green"
        Warning = "Yellow"
        Error = "Red"
        Muted = "DarkGray"
        Text = "White"
        Background = "Black"
        Border = "Yellow"
    }
}

# Current theme colors (resolved)
$script:Colors = $script:THEMES.dark

#endregion

#region Theme Management

function Set-GUITheme {
    <#
    .SYNOPSIS
        Sets the GUI theme
    .PARAMETER Theme
        Theme name: dark, light, dracula, nord, monokai
    #>
    [CmdletBinding()]
    param(
        [ValidateSet("dark", "light", "dracula", "nord", "monokai")]
        [string]$Theme = "dark"
    )

    $script:GUI_CONFIG.Theme = $Theme
    $script:Colors = $script:THEMES[$Theme]
    Write-Host "[GUI] Theme set to: $Theme" -ForegroundColor $script:Colors.Success
}

function Get-GUITheme {
    return $script:GUI_CONFIG.Theme
}

function Get-ThemeColor {
    param([string]$ColorName)
    return $script:Colors[$ColorName]
}

#endregion

#region ASCII Art & Logos

$script:LOGOS = @{
    claude = @"
   ██████╗██╗      █████╗ ██╗   ██╗██████╗ ███████╗
  ██╔════╝██║     ██╔══██╗██║   ██║██╔══██╗██╔════╝
  ██║     ██║     ███████║██║   ██║██║  ██║█████╗
  ██║     ██║     ██╔══██║██║   ██║██║  ██║██╔══╝
  ╚██████╗███████╗██║  ██║╚██████╔╝██████╔╝███████╗
   ╚═════╝╚══════╝╚═╝  ╚═╝ ╚═════╝ ╚═════╝ ╚══════╝
"@
    gemini = @"
   ██████╗ ███████╗███╗   ███╗██╗███╗   ██╗██╗
  ██╔════╝ ██╔════╝████╗ ████║██║████╗  ██║██║
  ██║  ███╗█████╗  ██╔████╔██║██║██╔██╗ ██║██║
  ██║   ██║██╔══╝  ██║╚██╔╝██║██║██║╚██╗██║██║
  ╚██████╔╝███████╗██║ ╚═╝ ██║██║██║ ╚████║██║
   ╚═════╝ ╚══════╝╚═╝     ╚═╝╚═╝╚═╝  ╚═══╝╚═╝
"@
    hydra = @"
  ██╗  ██╗██╗   ██╗██████╗ ██████╗  █████╗
  ██║  ██║╚██╗ ██╔╝██╔══██╗██╔══██╗██╔══██╗
  ███████║ ╚████╔╝ ██║  ██║██████╔╝███████║
  ██╔══██║  ╚██╔╝  ██║  ██║██╔══██╗██╔══██║
  ██║  ██║   ██║   ██████╔╝██║  ██║██║  ██║
  ╚═╝  ╚═╝   ╚═╝   ╚═════╝ ╚═╝  ╚═╝╚═╝  ╚═╝
"@
    hydra_small = @"
  ╦ ╦╦ ╦╔╦╗╦═╗╔═╗
  ╠═╣╚╦╝ ║║╠╦╝╠═╣
  ╩ ╩ ╩ ═╩╝╩╚═╩ ╩
"@
}

function Show-AnimatedLogo {
    <#
    .SYNOPSIS
        Displays animated ASCII logo with wave effect
    .PARAMETER Logo
        Logo type: claude, gemini, hydra, hydra_small
    .PARAMETER Speed
        Animation speed in ms (default: 30)
    #>
    [CmdletBinding()]
    param(
        [ValidateSet("claude", "gemini", "hydra", "hydra_small")]
        [string]$Logo = "hydra",

        [int]$Speed = 30,

        [switch]$Rainbow
    )

    $logoText = $script:LOGOS[$Logo]
    $lines = $logoText -split "`n"
    $rainbowColors = @("Red", "Yellow", "Green", "Cyan", "Blue", "Magenta")

    if ($script:GUI_CONFIG.AnimationsEnabled) {
        # Animated display - line by line with color wave
        $colorIndex = 0
        foreach ($line in $lines) {
            if ($Rainbow) {
                $color = $rainbowColors[$colorIndex % $rainbowColors.Count]
                $colorIndex++
            } else {
                $color = $script:Colors.Primary
            }

            # Character by character for wave effect
            foreach ($char in $line.ToCharArray()) {
                Write-Host $char -NoNewline -ForegroundColor $color
                Start-Sleep -Milliseconds 2
            }
            Write-Host ""
            Start-Sleep -Milliseconds $Speed
        }
    } else {
        # Static display
        Write-Host $logoText -ForegroundColor $script:Colors.Primary
    }
}

function Show-GradientText {
    <#
    .SYNOPSIS
        Displays text with gradient color effect
    #>
    [CmdletBinding()]
    param(
        [string]$Text,
        [string[]]$Colors = @("Blue", "Cyan", "Green", "Yellow")
    )

    $chars = $Text.ToCharArray()
    $step = [math]::Max(1, [math]::Floor($chars.Count / $Colors.Count))

    for ($i = 0; $i -lt $chars.Count; $i++) {
        $colorIndex = [math]::Min([math]::Floor($i / $step), $Colors.Count - 1)
        Write-Host $chars[$i] -NoNewline -ForegroundColor $Colors[$colorIndex]
    }
    Write-Host ""
}

#endregion

#region Progress Indicators

function Show-ProgressBar {
    <#
    .SYNOPSIS
        Displays a progress bar
    .PARAMETER Percent
        Progress percentage (0-100)
    .PARAMETER Label
        Optional label text
    .PARAMETER Width
        Bar width in characters (default: 40)
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateRange(0, 100)]
        [int]$Percent,

        [string]$Label = "",

        [int]$Width = 40,

        [switch]$NoNewline
    )

    $filled = [math]::Floor($Width * $Percent / 100)
    $empty = $Width - $filled

    $bar = "█" * $filled + "░" * $empty

    $color = if ($Percent -lt 33) { $script:Colors.Error }
             elseif ($Percent -lt 66) { $script:Colors.Warning }
             else { $script:Colors.Success }

    $output = "[$bar] $Percent%"
    if ($Label) { $output = "$Label $output" }

    Write-Host "`r$output" -NoNewline:$NoNewline -ForegroundColor $color
}

function Show-Spinner {
    <#
    .SYNOPSIS
        Shows animated spinner
    .PARAMETER Message
        Message to display with spinner
    .PARAMETER Duration
        Duration in seconds (0 = until manually stopped)
    .PARAMETER Style
        Spinner style: dots, line, circle, arrow, pulse
    #>
    [CmdletBinding()]
    param(
        [string]$Message = "Loading",
        [int]$DurationMs = 2000,
        [ValidateSet("dots", "line", "circle", "arrow", "pulse", "braille")]
        [string]$Style = "dots"
    )

    $spinners = @{
        dots = @("⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏")
        line = @("-", "\", "|", "/")
        circle = @("◐", "◓", "◑", "◒")
        arrow = @("←", "↖", "↑", "↗", "→", "↘", "↓", "↙")
        pulse = @("█", "▓", "▒", "░", "▒", "▓")
        braille = @("⣾", "⣽", "⣻", "⢿", "⡿", "⣟", "⣯", "⣷")
    }

    $frames = $spinners[$Style]
    $frameCount = $frames.Count
    $elapsed = 0
    $frameIndex = 0

    while ($elapsed -lt $DurationMs) {
        $frame = $frames[$frameIndex % $frameCount]
        Write-Host "`r$frame $Message " -NoNewline -ForegroundColor $script:Colors.Primary
        Start-Sleep -Milliseconds 80
        $elapsed += 80
        $frameIndex++
    }
    Write-Host "`r✓ $Message " -ForegroundColor $script:Colors.Success
}

function Show-LoadingBar {
    <#
    .SYNOPSIS
        Shows animated loading bar
    #>
    [CmdletBinding()]
    param(
        [string]$Message = "Loading",
        [int]$DurationMs = 2000,
        [int]$Width = 30
    )

    $steps = 20
    $stepDelay = $DurationMs / $steps

    for ($i = 0; $i -le $steps; $i++) {
        $percent = [math]::Floor($i * 100 / $steps)
        $filled = [math]::Floor($Width * $i / $steps)
        $empty = $Width - $filled

        $bar = "█" * $filled + "░" * $empty
        Write-Host "`r$Message [$bar] $percent%" -NoNewline -ForegroundColor $script:Colors.Primary
        Start-Sleep -Milliseconds $stepDelay
    }
    Write-Host ""
}

#endregion

#region Status Indicators

function Show-StatusBadge {
    <#
    .SYNOPSIS
        Shows a status badge with icon
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Text,

        [ValidateSet("success", "warning", "error", "info", "pending")]
        [string]$Status = "info",

        [switch]$NoNewline
    )

    $badges = @{
        success = @{ Icon = "✓"; Color = $script:Colors.Success }
        warning = @{ Icon = "⚠"; Color = $script:Colors.Warning }
        error = @{ Icon = "✗"; Color = $script:Colors.Error }
        info = @{ Icon = "ℹ"; Color = $script:Colors.Primary }
        pending = @{ Icon = "○"; Color = $script:Colors.Muted }
    }

    $badge = $badges[$Status]
    Write-Host "[$($badge.Icon)] $Text" -NoNewline:$NoNewline -ForegroundColor $badge.Color
}

function Show-ModelBadge {
    <#
    .SYNOPSIS
        Shows model tier badge
    #>
    [CmdletBinding()]
    param(
        [string]$Model,
        [ValidateSet("pro", "standard", "lite", "local")]
        [string]$Tier = "standard"
    )

    $tierConfig = @{
        pro = @{ Label = "[PRO]"; Color = "Magenta" }
        standard = @{ Label = "[STD]"; Color = "Blue" }
        lite = @{ Label = "[LITE]"; Color = "Green" }
        local = @{ Label = "[LOCAL]"; Color = "Cyan" }
    }

    $config = $tierConfig[$Tier]
    Write-Host "$Model " -NoNewline -ForegroundColor $script:Colors.Text
    Write-Host $config.Label -NoNewline -ForegroundColor $config.Color
}

function Show-ProviderStatus {
    <#
    .SYNOPSIS
        Shows provider status with colored indicators
    #>
    [CmdletBinding()]
    param(
        [hashtable]$Providers # @{ anthropic = $true; openai = $false; ollama = $true }
    )

    $providerColors = @{
        anthropic = "DarkYellow"
        openai = "Green"
        ollama = "Blue"
        gemini = "Cyan"
    }

    foreach ($provider in $Providers.GetEnumerator()) {
        $icon = if ($provider.Value) { "●" } else { "○" }
        $color = if ($provider.Value) { $providerColors[$provider.Key] } else { "DarkGray" }
        Write-Host "$icon " -NoNewline -ForegroundColor $color
    }
}

function Show-TokenCounter {
    <#
    .SYNOPSIS
        Shows animated token counter with up/down arrows
    #>
    [CmdletBinding()]
    param(
        [int]$InputTokens,
        [int]$OutputTokens,
        [switch]$Animate
    )

    if ($Animate -and $script:GUI_CONFIG.AnimationsEnabled) {
        # Animate counting up
        $steps = 10
        for ($i = 1; $i -le $steps; $i++) {
            $inShow = [math]::Floor($InputTokens * $i / $steps)
            $outShow = [math]::Floor($OutputTokens * $i / $steps)
            Write-Host "`r↑ $inShow ↓ $outShow " -NoNewline -ForegroundColor $script:Colors.Primary
            Start-Sleep -Milliseconds 50
        }
        Write-Host ""
    } else {
        Write-Host "↑ $InputTokens " -NoNewline -ForegroundColor $script:Colors.Success
        Write-Host "↓ $OutputTokens" -NoNewline -ForegroundColor $script:Colors.Warning
    }
}

function Show-CostDisplay {
    <#
    .SYNOPSIS
        Shows cost with color coding based on amount
    #>
    [CmdletBinding()]
    param(
        [decimal]$Cost,
        [decimal]$Limit = 1.0,
        [switch]$Blink
    )

    $percent = if ($Limit -gt 0) { $Cost / $Limit * 100 } else { 0 }

    $color = if ($percent -lt 50) { $script:Colors.Success }
             elseif ($percent -lt 80) { $script:Colors.Warning }
             else { $script:Colors.Error }

    $formatted = "`${0:N4}" -f $Cost

    if ($Blink -and $percent -gt 80 -and $script:GUI_CONFIG.AnimationsEnabled) {
        # Blink effect for high cost
        for ($i = 0; $i -lt 3; $i++) {
            Write-Host "`r$formatted" -NoNewline -ForegroundColor $color
            Start-Sleep -Milliseconds 200
            Write-Host "`r$formatted" -NoNewline -ForegroundColor "Black"
            Start-Sleep -Milliseconds 200
        }
        Write-Host "`r$formatted" -ForegroundColor $color
    } else {
        Write-Host $formatted -NoNewline -ForegroundColor $color
    }
}

#endregion

#region Typing & Thinking Indicators

function Show-ThinkingIndicator {
    <#
    .SYNOPSIS
        Shows "AI is thinking..." with animation
    #>
    [CmdletBinding()]
    param(
        [string]$AIName = "Claude",
        [int]$DurationMs = 3000
    )

    $frames = @("thinking", "thinking.", "thinking..", "thinking...")
    $elapsed = 0
    $frameIndex = 0

    while ($elapsed -lt $DurationMs) {
        $frame = $frames[$frameIndex % $frames.Count]
        Write-Host "`r🤔 $AIName is $frame   " -NoNewline -ForegroundColor $script:Colors.Muted
        Start-Sleep -Milliseconds 400
        $elapsed += 400
        $frameIndex++
    }
    Write-Host "`r" -NoNewline
}

function Show-TypingEffect {
    <#
    .SYNOPSIS
        Displays text with typewriter effect
    #>
    [CmdletBinding()]
    param(
        [string]$Text,
        [int]$DelayMs = 20,
        [string]$Color = "White"
    )

    if (-not $script:GUI_CONFIG.AnimationsEnabled) {
        Write-Host $Text -ForegroundColor $Color
        return
    }

    foreach ($char in $Text.ToCharArray()) {
        Write-Host $char -NoNewline -ForegroundColor $Color
        Start-Sleep -Milliseconds $DelayMs
    }
    Write-Host ""
}

#endregion

#region Boxes & Borders

function Show-Box {
    <#
    .SYNOPSIS
        Shows content in a bordered box
    #>
    [CmdletBinding()]
    param(
        [string[]]$Content,
        [string]$Title = "",
        [int]$Width = 0,
        [ValidateSet("single", "double", "rounded", "heavy")]
        [string]$Style = "single"
    )

    $borders = @{
        single = @{ TL = "┌"; TR = "┐"; BL = "└"; BR = "┘"; H = "─"; V = "│" }
        double = @{ TL = "╔"; TR = "╗"; BL = "╚"; BR = "╝"; H = "═"; V = "║" }
        rounded = @{ TL = "╭"; TR = "╮"; BL = "╰"; BR = "╯"; H = "─"; V = "│" }
        heavy = @{ TL = "┏"; TR = "┓"; BL = "┗"; BR = "┛"; H = "━"; V = "┃" }
    }

    $b = $borders[$Style]

    # Calculate width
    $maxLen = ($Content | ForEach-Object { $_.Length } | Measure-Object -Maximum).Maximum
    if ($Title) { $maxLen = [math]::Max($maxLen, $Title.Length + 4) }
    if ($Width -gt 0) { $maxLen = [math]::Max($maxLen, $Width - 4) }
    $innerWidth = $maxLen + 2

    # Top border with optional title
    if ($Title) {
        $titlePad = $innerWidth - $Title.Length - 2
        $leftPad = [math]::Floor($titlePad / 2)
        $rightPad = $titlePad - $leftPad
        Write-Host "$($b.TL)$($b.H * $leftPad) $Title $($b.H * $rightPad)$($b.TR)" -ForegroundColor $script:Colors.Border
    } else {
        Write-Host "$($b.TL)$($b.H * $innerWidth)$($b.TR)" -ForegroundColor $script:Colors.Border
    }

    # Content lines
    foreach ($line in $Content) {
        $padding = $innerWidth - $line.Length - 2
        Write-Host "$($b.V) $line$(' ' * $padding) $($b.V)" -ForegroundColor $script:Colors.Border
    }

    # Bottom border
    Write-Host "$($b.BL)$($b.H * $innerWidth)$($b.BR)" -ForegroundColor $script:Colors.Border
}

function Show-StatusBar {
    <#
    .SYNOPSIS
        Shows a status bar at bottom of screen
    #>
    [CmdletBinding()]
    param(
        [hashtable[]]$Sections # @( @{Label="Model"; Value="GPT-4"; Color="Cyan"}, ... )
    )

    $separator = " │ "

    foreach ($section in $Sections) {
        Write-Host "$($section.Label): " -NoNewline -ForegroundColor $script:Colors.Muted
        Write-Host $section.Value -NoNewline -ForegroundColor $(if ($section.Color) { $section.Color } else { $script:Colors.Text })
        if ($section -ne $Sections[-1]) {
            Write-Host $separator -NoNewline -ForegroundColor $script:Colors.Border
        }
    }
    Write-Host ""
}

#endregion

#region Charts & Visualizations

function Show-BarChart {
    <#
    .SYNOPSIS
        Shows horizontal bar chart
    #>
    [CmdletBinding()]
    param(
        [hashtable]$Data, # @{ "Label1" = 50; "Label2" = 30 }
        [int]$MaxWidth = 40,
        [string]$Title = ""
    )

    if ($Title) {
        Write-Host "`n$Title" -ForegroundColor $script:Colors.Primary
        Write-Host ("─" * ($Title.Length + 4)) -ForegroundColor $script:Colors.Border
    }

    $maxValue = ($Data.Values | Measure-Object -Maximum).Maximum
    $maxLabelLen = ($Data.Keys | ForEach-Object { $_.Length } | Measure-Object -Maximum).Maximum

    foreach ($item in $Data.GetEnumerator() | Sort-Object Value -Descending) {
        $barLen = if ($maxValue -gt 0) { [math]::Floor($MaxWidth * $item.Value / $maxValue) } else { 0 }
        $bar = "█" * $barLen
        $label = $item.Key.PadRight($maxLabelLen)

        Write-Host "$label │ " -NoNewline -ForegroundColor $script:Colors.Muted
        Write-Host $bar -NoNewline -ForegroundColor $script:Colors.Primary
        Write-Host " $($item.Value)" -ForegroundColor $script:Colors.Text
    }
}

function Show-Sparkline {
    <#
    .SYNOPSIS
        Shows mini sparkline chart
    #>
    [CmdletBinding()]
    param(
        [decimal[]]$Values,
        [string]$Label = ""
    )

    $blocks = @("▁", "▂", "▃", "▄", "▅", "▆", "▇", "█")
    $min = ($Values | Measure-Object -Minimum).Minimum
    $max = ($Values | Measure-Object -Maximum).Maximum
    $range = $max - $min

    if ($Label) { Write-Host "$Label " -NoNewline -ForegroundColor $script:Colors.Muted }

    foreach ($val in $Values) {
        $normalized = if ($range -gt 0) { ($val - $min) / $range } else { 0.5 }
        $blockIndex = [math]::Min([math]::Floor($normalized * 8), 7)
        Write-Host $blocks[$blockIndex] -NoNewline -ForegroundColor $script:Colors.Primary
    }
    Write-Host ""
}

function Show-PieChart {
    <#
    .SYNOPSIS
        Shows ASCII pie chart representation
    #>
    [CmdletBinding()]
    param(
        [hashtable]$Data # @{ "A" = 50; "B" = 30; "C" = 20 }
    )

    $total = ($Data.Values | Measure-Object -Sum).Sum
    $colors = @("Cyan", "Magenta", "Yellow", "Green", "Blue", "Red")
    $colorIndex = 0

    Write-Host ""
    foreach ($item in $Data.GetEnumerator() | Sort-Object Value -Descending) {
        $percent = if ($total -gt 0) { [math]::Round($item.Value / $total * 100, 1) } else { 0 }
        $barLen = [math]::Floor($percent / 2)
        $bar = "█" * $barLen
        $color = $colors[$colorIndex % $colors.Count]

        Write-Host "  $($item.Key.PadRight(15)) " -NoNewline -ForegroundColor $script:Colors.Muted
        Write-Host $bar -NoNewline -ForegroundColor $color
        Write-Host " $percent%" -ForegroundColor $script:Colors.Text

        $colorIndex++
    }
}

#endregion

#region Syntax Highlighting

$script:SyntaxColors = @{
    keyword = "Blue"
    string = "Yellow"
    comment = "DarkGreen"
    number = "Magenta"
    operator = "Gray"
    function = "Cyan"
    variable = "Green"
    type = "DarkCyan"
}

function Show-SyntaxHighlighted {
    <#
    .SYNOPSIS
        Shows code with syntax highlighting
    #>
    [CmdletBinding()]
    param(
        [string]$Code,
        [ValidateSet("powershell", "python", "javascript", "json", "sql", "auto")]
        [string]$Language = "auto"
    )

    # Simple keyword-based highlighting
    $keywords = @{
        powershell = @("function", "param", "if", "else", "foreach", "while", "try", "catch", "return", "throw", "class", "enum")
        python = @("def", "class", "if", "else", "elif", "for", "while", "try", "except", "return", "import", "from", "with", "as")
        javascript = @("function", "const", "let", "var", "if", "else", "for", "while", "try", "catch", "return", "class", "async", "await")
        sql = @("SELECT", "FROM", "WHERE", "INSERT", "UPDATE", "DELETE", "JOIN", "LEFT", "RIGHT", "INNER", "ORDER", "BY", "GROUP", "HAVING")
    }

    $lines = $Code -split "`n"

    foreach ($line in $lines) {
        # Detect and color comments
        if ($line -match '^\s*(#|//|--)') {
            Write-Host $line -ForegroundColor $script:SyntaxColors.comment
            continue
        }

        # Detect strings
        $coloredLine = $line

        # Color keywords
        if ($Language -ne "auto" -and $keywords[$Language]) {
            foreach ($kw in $keywords[$Language]) {
                if ($line -match "\b$kw\b") {
                    # Simple highlight - just print with color
                }
            }
        }

        # Output with basic highlighting
        if ($line -match '"[^"]*"' -or $line -match "'[^']*'") {
            Write-Host $line -ForegroundColor $script:SyntaxColors.string
        } elseif ($line -match '^\s*\d+') {
            Write-Host $line -ForegroundColor $script:SyntaxColors.number
        } else {
            Write-Host $line -ForegroundColor $script:Colors.Text
        }
    }
}

#endregion

#region Interactive Components

function Show-Menu {
    <#
    .SYNOPSIS
        Shows interactive menu with arrow key navigation
    #>
    [CmdletBinding()]
    param(
        [string]$Title,
        [string[]]$Options,
        [int]$DefaultIndex = 0
    )

    $selectedIndex = $DefaultIndex
    $cursorVisible = [Console]::CursorVisible
    [Console]::CursorVisible = $false

    try {
        while ($true) {
            Clear-Host

            if ($Title) {
                Write-Host "`n  $Title" -ForegroundColor $script:Colors.Primary
                Write-Host "  $("─" * $Title.Length)" -ForegroundColor $script:Colors.Border
                Write-Host ""
            }

            for ($i = 0; $i -lt $Options.Count; $i++) {
                if ($i -eq $selectedIndex) {
                    Write-Host "  ► " -NoNewline -ForegroundColor $script:Colors.Accent
                    Write-Host $Options[$i] -ForegroundColor $script:Colors.Primary
                } else {
                    Write-Host "    $($Options[$i])" -ForegroundColor $script:Colors.Muted
                }
            }

            Write-Host "`n  [↑↓] Navigate  [Enter] Select  [Esc] Cancel" -ForegroundColor $script:Colors.Muted

            $key = [Console]::ReadKey($true)

            switch ($key.Key) {
                "UpArrow" {
                    $selectedIndex = if ($selectedIndex -gt 0) { $selectedIndex - 1 } else { $Options.Count - 1 }
                }
                "DownArrow" {
                    $selectedIndex = if ($selectedIndex -lt $Options.Count - 1) { $selectedIndex + 1 } else { 0 }
                }
                "Enter" {
                    return $selectedIndex
                }
                "Escape" {
                    return -1
                }
            }
        }
    } finally {
        [Console]::CursorVisible = $cursorVisible
    }
}

function Show-Confirm {
    <#
    .SYNOPSIS
        Shows Yes/No confirmation dialog
    #>
    [CmdletBinding()]
    param(
        [string]$Message,
        [switch]$DefaultYes
    )

    $options = if ($DefaultYes) { "[Y/n]" } else { "[y/N]" }

    Write-Host "$Message $options " -NoNewline -ForegroundColor $script:Colors.Warning
    $response = Read-Host

    if ($response -eq "") {
        return $DefaultYes
    }

    return $response -match "^[Yy]"
}

function Show-InputBox {
    <#
    .SYNOPSIS
        Shows styled input prompt
    #>
    [CmdletBinding()]
    param(
        [string]$Prompt,
        [string]$Default = "",
        [switch]$Password
    )

    Write-Host "┌─ " -NoNewline -ForegroundColor $script:Colors.Border
    Write-Host $Prompt -ForegroundColor $script:Colors.Primary
    Write-Host "│" -NoNewline -ForegroundColor $script:Colors.Border

    if ($Password) {
        $value = Read-Host -AsSecureString
        $value = [Runtime.InteropServices.Marshal]::PtrToStringAuto(
            [Runtime.InteropServices.Marshal]::SecureStringToBSTR($value)
        )
    } else {
        if ($Default) {
            Write-Host " [$Default] " -NoNewline -ForegroundColor $script:Colors.Muted
        } else {
            Write-Host " " -NoNewline
        }
        $value = Read-Host
        if ($value -eq "" -and $Default) { $value = $Default }
    }

    Write-Host "└─" -ForegroundColor $script:Colors.Border

    return $value
}

#endregion

#region Notifications & Sounds

function Show-Toast {
    <#
    .SYNOPSIS
        Shows Windows toast notification
    #>
    [CmdletBinding()]
    param(
        [string]$Title,
        [string]$Message,
        [ValidateSet("info", "success", "warning", "error")]
        [string]$Type = "info"
    )

    try {
        [Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType = WindowsRuntime] | Out-Null
        [Windows.Data.Xml.Dom.XmlDocument, Windows.Data.Xml.Dom.XmlDocument, ContentType = WindowsRuntime] | Out-Null

        $template = @"
<toast>
    <visual>
        <binding template="ToastText02">
            <text id="1">$Title</text>
            <text id="2">$Message</text>
        </binding>
    </visual>
</toast>
"@

        $xml = New-Object Windows.Data.Xml.Dom.XmlDocument
        $xml.LoadXml($template)

        $toast = [Windows.UI.Notifications.ToastNotification]::new($xml)
        [Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier("HYDRA CLI").Show($toast)

    } catch {
        # Fallback to console message
        $icon = switch ($Type) {
            "success" { "✓" }
            "warning" { "⚠" }
            "error" { "✗" }
            default { "ℹ" }
        }
        Write-Host "[$icon] $Title - $Message" -ForegroundColor $script:Colors.Primary
    }
}

function Play-Sound {
    <#
    .SYNOPSIS
        Plays notification sound
    #>
    [CmdletBinding()]
    param(
        [ValidateSet("success", "error", "notification", "complete")]
        [string]$Type = "notification"
    )

    if (-not $script:GUI_CONFIG.SoundEnabled) { return }

    $sounds = @{
        success = @(800, 100), @(1000, 100)
        error = @(400, 200), @(300, 200)
        notification = @(1500, 100)
        complete = @(600, 100), @(800, 100), @(1000, 150)
    }

    foreach ($beep in $sounds[$Type]) {
        [Console]::Beep($beep[0], $beep[1])
    }
}

#endregion

#region Special Effects

function Show-RainbowText {
    <#
    .SYNOPSIS
        Shows text with rainbow animation
    #>
    [CmdletBinding()]
    param(
        [string]$Text,
        [int]$Cycles = 2
    )

    $colors = @("Red", "Yellow", "Green", "Cyan", "Blue", "Magenta")

    for ($cycle = 0; $cycle -lt $Cycles; $cycle++) {
        for ($offset = 0; $offset -lt $colors.Count; $offset++) {
            $output = ""
            for ($i = 0; $i -lt $Text.Length; $i++) {
                $colorIndex = ($i + $offset) % $colors.Count
                Write-Host $Text[$i] -NoNewline -ForegroundColor $colors[$colorIndex]
            }
            Write-Host "`r" -NoNewline
            Start-Sleep -Milliseconds 100
        }
    }
    Write-Host $Text -ForegroundColor $script:Colors.Primary
}

function Show-MatrixEffect {
    <#
    .SYNOPSIS
        Shows Matrix-style rain effect
    #>
    [CmdletBinding()]
    param(
        [int]$DurationSeconds = 3,
        [int]$Width = 60
    )

    $chars = "ﾊﾐﾋｰｳｼﾅﾓﾆｻﾜﾂｵﾘｱﾎﾃﾏｹﾒｴｶｷﾑﾕﾗｾﾈｽﾀﾇﾍ0123456789"
    $columns = @{}

    $endTime = (Get-Date).AddSeconds($DurationSeconds)

    while ((Get-Date) -lt $endTime) {
        $line = ""
        for ($x = 0; $x -lt $Width; $x++) {
            if (-not $columns[$x] -or (Get-Random -Maximum 10) -eq 0) {
                $columns[$x] = $chars[(Get-Random -Maximum $chars.Length)]
            }
            $line += $columns[$x]
        }
        Write-Host $line -ForegroundColor Green
        Start-Sleep -Milliseconds 50
    }
}

function Show-Sparkle {
    <#
    .SYNOPSIS
        Shows sparkle effect
    #>
    [CmdletBinding()]
    param(
        [string]$Message = "Success!"
    )

    $sparkles = @("✨", "⭐", "💫", "🌟")

    for ($i = 0; $i -lt 5; $i++) {
        $sparkle = $sparkles[(Get-Random -Maximum $sparkles.Count)]
        Write-Host "`r$sparkle $Message $sparkle" -NoNewline -ForegroundColor $script:Colors.Success
        Start-Sleep -Milliseconds 200
    }
    Write-Host ""
}

#endregion

#region Tips & Help

$script:TIPS = @(
    "Use /help to see all available commands"
    "Press Escape twice to interrupt a running operation"
    "Use Tab for command auto-completion"
    "Try /ai-status to check all provider statuses"
    "Use Get-ErrorHistory to see failed prompts"
    "Double-click .vbs file to launch with proper environment"
    "Use -PreferCheapest flag to optimize costs"
    "Local Ollama models are free - no API costs!"
    "Use /queue:status to see pending prompts"
    "Configure themes with Set-GUITheme"
)

function Get-RandomTip {
    return $script:TIPS[(Get-Random -Maximum $script:TIPS.Count)]
}

function Show-TipOfTheDay {
    $tip = Get-RandomTip
    Write-Host ""
    Write-Host "  💡 " -NoNewline -ForegroundColor $script:Colors.Warning
    Write-Host "Tip: " -NoNewline -ForegroundColor $script:Colors.Muted
    Write-Host $tip -ForegroundColor $script:Colors.Text
    Write-Host ""
}

#endregion

#region Session Stats

function Show-SessionStats {
    <#
    .SYNOPSIS
        Shows session statistics
    #>
    [CmdletBinding()]
    param(
        [hashtable]$Stats # @{ Tokens = 1000; Cost = 0.05; Requests = 10; Duration = "1h 30m" }
    )

    Show-Box -Title "Session Stats" -Content @(
        "Duration:  $(if ($Stats.Duration) { $Stats.Duration } else { 'N/A' })"
        "Requests:  $(if ($Stats.Requests) { $Stats.Requests } else { 0 })"
        "Tokens:    $(if ($Stats.Tokens) { $Stats.Tokens } else { 0 })"
        "Cost:      `$$(if ($Stats.Cost) { $Stats.Cost } else { 0 })"
    ) -Style "rounded"
}

function Show-LastSessionInfo {
    <#
    .SYNOPSIS
        Shows info about last session
    #>
    [CmdletBinding()]
    param(
        [DateTime]$LastSession
    )

    $timeAgo = (Get-Date) - $LastSession

    $timeStr = if ($timeAgo.TotalMinutes -lt 60) {
        "$([math]::Round($timeAgo.TotalMinutes))m ago"
    } elseif ($timeAgo.TotalHours -lt 24) {
        "$([math]::Round($timeAgo.TotalHours))h ago"
    } else {
        "$([math]::Round($timeAgo.TotalDays))d ago"
    }

    Write-Host "  Last session: " -NoNewline -ForegroundColor $script:Colors.Muted
    Write-Host $timeStr -ForegroundColor $script:Colors.Text
}

#endregion

#region Exports

Export-ModuleMember -Function @(
    # Theme
    'Set-GUITheme',
    'Get-GUITheme',
    'Get-ThemeColor',

    # Logos & ASCII Art
    'Show-AnimatedLogo',
    'Show-GradientText',

    # Progress
    'Show-ProgressBar',
    'Show-Spinner',
    'Show-LoadingBar',

    # Status
    'Show-StatusBadge',
    'Show-ModelBadge',
    'Show-ProviderStatus',
    'Show-TokenCounter',
    'Show-CostDisplay',

    # Typing
    'Show-ThinkingIndicator',
    'Show-TypingEffect',

    # Boxes
    'Show-Box',
    'Show-StatusBar',

    # Charts
    'Show-BarChart',
    'Show-Sparkline',
    'Show-PieChart',

    # Syntax
    'Show-SyntaxHighlighted',

    # Interactive
    'Show-Menu',
    'Show-Confirm',
    'Show-InputBox',

    # Notifications
    'Show-Toast',
    'Play-Sound',

    # Effects
    'Show-RainbowText',
    'Show-MatrixEffect',
    'Show-Sparkle',

    # Tips
    'Get-RandomTip',
    'Show-TipOfTheDay',

    # Session
    'Show-SessionStats',
    'Show-LastSessionInfo'
)

#endregion

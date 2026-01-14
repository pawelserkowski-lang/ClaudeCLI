#Requires -Version 5.1
<#
.SYNOPSIS
    HYDRA Interactive Module - Advanced TUI Components
.DESCRIPTION
    Interactive components for ClaudeCLI & GeminiCLI:
    - Autocomplete with fuzzy search
    - History browser
    - Settings TUI
    - File drag & drop
    - Quick actions
.VERSION
    1.0.0
#>

#region History Browser

$script:CommandHistory = @()
$script:HistoryFile = Join-Path $env:APPDATA "HYDRA\command_history.json"

function Initialize-History {
    $historyDir = Split-Path $script:HistoryFile -Parent
    if (-not (Test-Path $historyDir)) {
        New-Item -ItemType Directory -Path $historyDir -Force | Out-Null
    }

    if (Test-Path $script:HistoryFile) {
        try {
            $script:CommandHistory = Get-Content $script:HistoryFile -Raw | ConvertFrom-Json
        } catch {
            $script:CommandHistory = @()
        }
    }
}

function Add-ToHistory {
    param(
        [string]$Command,
        [string]$Result = "success"
    )

    $entry = @{
        Command = $Command
        Timestamp = (Get-Date).ToString("o")
        Result = $Result
    }

    $script:CommandHistory = @($entry) + @($script:CommandHistory) | Select-Object -First 500

    $script:CommandHistory | ConvertTo-Json -Depth 5 | Set-Content $script:HistoryFile -Encoding UTF8
}

function Show-HistoryBrowser {
    <#
    .SYNOPSIS
        Interactive history browser with search
    #>
    [CmdletBinding()]
    param(
        [int]$PageSize = 15
    )

    Initialize-History

    if ($script:CommandHistory.Count -eq 0) {
        Write-Host "No command history found." -ForegroundColor Yellow
        return $null
    }

    $filtered = $script:CommandHistory
    $selectedIndex = 0
    $searchTerm = ""
    $page = 0

    [Console]::CursorVisible = $false

    try {
        while ($true) {
            Clear-Host

            Write-Host "`n  📜 Command History Browser" -ForegroundColor Cyan
            Write-Host "  ══════════════════════════" -ForegroundColor DarkCyan

            # Search box
            Write-Host "`n  🔍 Search: " -NoNewline -ForegroundColor Yellow
            Write-Host $searchTerm -ForegroundColor White
            Write-Host ""

            # Filter by search
            if ($searchTerm) {
                $filtered = $script:CommandHistory | Where-Object { $_.Command -like "*$searchTerm*" }
            } else {
                $filtered = $script:CommandHistory
            }

            # Pagination
            $totalPages = [math]::Ceiling($filtered.Count / $PageSize)
            $startIdx = $page * $PageSize
            $pageItems = $filtered | Select-Object -Skip $startIdx -First $PageSize

            # Display items
            $idx = 0
            foreach ($item in $pageItems) {
                $globalIdx = $startIdx + $idx
                $timeAgo = ((Get-Date) - [DateTime]::Parse($item.Timestamp)).TotalHours

                $timeStr = if ($timeAgo -lt 1) { "$([int]($timeAgo * 60))m" }
                           elseif ($timeAgo -lt 24) { "$([int]$timeAgo)h" }
                           else { "$([int]($timeAgo / 24))d" }

                $icon = if ($item.Result -eq "success") { "✓" } else { "✗" }
                $iconColor = if ($item.Result -eq "success") { "Green" } else { "Red" }

                if ($idx -eq $selectedIndex) {
                    Write-Host "  ► " -NoNewline -ForegroundColor Magenta
                } else {
                    Write-Host "    " -NoNewline
                }

                Write-Host $icon -NoNewline -ForegroundColor $iconColor
                Write-Host " $timeStr".PadRight(6) -NoNewline -ForegroundColor DarkGray

                $cmdDisplay = if ($item.Command.Length -gt 50) {
                    $item.Command.Substring(0, 47) + "..."
                } else { $item.Command }

                if ($idx -eq $selectedIndex) {
                    Write-Host $cmdDisplay -ForegroundColor White
                } else {
                    Write-Host $cmdDisplay -ForegroundColor Gray
                }

                $idx++
            }

            # Footer
            Write-Host ""
            Write-Host "  Page $($page + 1)/$totalPages ($($filtered.Count) items)" -ForegroundColor DarkGray
            Write-Host "  [↑↓] Select  [Enter] Use  [/] Search  [Esc] Close" -ForegroundColor DarkGray

            # Input
            $key = [Console]::ReadKey($true)

            switch ($key.Key) {
                "UpArrow" {
                    if ($selectedIndex -gt 0) { $selectedIndex-- }
                    elseif ($page -gt 0) { $page--; $selectedIndex = $PageSize - 1 }
                }
                "DownArrow" {
                    if ($selectedIndex -lt ($pageItems.Count - 1)) { $selectedIndex++ }
                    elseif ($page -lt $totalPages - 1) { $page++; $selectedIndex = 0 }
                }
                "PageUp" {
                    if ($page -gt 0) { $page--; $selectedIndex = 0 }
                }
                "PageDown" {
                    if ($page -lt $totalPages - 1) { $page++; $selectedIndex = 0 }
                }
                "Enter" {
                    $selected = $filtered | Select-Object -Skip ($startIdx + $selectedIndex) -First 1
                    return $selected.Command
                }
                "Escape" {
                    return $null
                }
                "Backspace" {
                    if ($searchTerm.Length -gt 0) {
                        $searchTerm = $searchTerm.Substring(0, $searchTerm.Length - 1)
                        $selectedIndex = 0
                        $page = 0
                    }
                }
                default {
                    if ($key.KeyChar -match '[a-zA-Z0-9 \-_/]') {
                        $searchTerm += $key.KeyChar
                        $selectedIndex = 0
                        $page = 0
                    }
                }
            }
        }
    } finally {
        [Console]::CursorVisible = $true
    }
}

#endregion

#region Autocomplete

$script:Commands = @(
    @{ Name = "/help"; Desc = "Show help" }
    @{ Name = "/ai"; Desc = "Quick AI query" }
    @{ Name = "/ai-status"; Desc = "Check AI providers" }
    @{ Name = "/ai-batch"; Desc = "Batch AI processing" }
    @{ Name = "/ai-config"; Desc = "Configure AI settings" }
    @{ Name = "/commit"; Desc = "Git commit helper" }
    @{ Name = "/review-pr"; Desc = "Review pull request" }
    @{ Name = "/hydra"; Desc = "HYDRA orchestration" }
    @{ Name = "/queue:status"; Desc = "Queue status" }
    @{ Name = "/queue:pause"; Desc = "Pause queue" }
    @{ Name = "/queue:resume"; Desc = "Resume queue" }
    @{ Name = "/clear"; Desc = "Clear screen" }
    @{ Name = "/exit"; Desc = "Exit CLI" }
    @{ Name = "/history"; Desc = "Browse history" }
    @{ Name = "/settings"; Desc = "Open settings" }
    @{ Name = "/theme"; Desc = "Change theme" }
)

function Show-Autocomplete {
    <#
    .SYNOPSIS
        Shows autocomplete dropdown menu
    #>
    [CmdletBinding()]
    param(
        [string]$Prefix = ""
    )

    $matches = $script:Commands | Where-Object { $_.Name -like "$Prefix*" }

    if ($matches.Count -eq 0) { return $null }

    $selectedIndex = 0
    $maxShow = [math]::Min($matches.Count, 8)

    [Console]::CursorVisible = $false
    $startPos = $Host.UI.RawUI.CursorPosition

    try {
        while ($true) {
            # Draw dropdown
            $Host.UI.RawUI.CursorPosition = $startPos

            Write-Host "┌─ Autocomplete ───────────────┐" -ForegroundColor DarkCyan

            for ($i = 0; $i -lt $maxShow; $i++) {
                $item = $matches[$i]

                if ($i -eq $selectedIndex) {
                    Write-Host "│ ► " -NoNewline -ForegroundColor DarkCyan
                    Write-Host $item.Name.PadRight(12) -NoNewline -ForegroundColor Cyan
                    Write-Host $item.Desc.PadRight(14) -NoNewline -ForegroundColor White
                    Write-Host " │" -ForegroundColor DarkCyan
                } else {
                    Write-Host "│   " -NoNewline -ForegroundColor DarkCyan
                    Write-Host $item.Name.PadRight(12) -NoNewline -ForegroundColor Gray
                    Write-Host $item.Desc.PadRight(14) -NoNewline -ForegroundColor DarkGray
                    Write-Host " │" -ForegroundColor DarkCyan
                }
            }

            Write-Host "└──────────────────────────────┘" -ForegroundColor DarkCyan

            $key = [Console]::ReadKey($true)

            switch ($key.Key) {
                "UpArrow" { $selectedIndex = [math]::Max(0, $selectedIndex - 1) }
                "DownArrow" { $selectedIndex = [math]::Min($maxShow - 1, $selectedIndex + 1) }
                "Tab" { return $matches[$selectedIndex].Name }
                "Enter" { return $matches[$selectedIndex].Name }
                "Escape" { return $null }
            }
        }
    } finally {
        [Console]::CursorVisible = $true
        # Clear dropdown area
        $Host.UI.RawUI.CursorPosition = $startPos
        for ($i = 0; $i -lt $maxShow + 2; $i++) {
            Write-Host (" " * 35)
        }
        $Host.UI.RawUI.CursorPosition = $startPos
    }
}

function Get-FuzzyMatches {
    <#
    .SYNOPSIS
        Fuzzy search for commands
    #>
    [CmdletBinding()]
    param(
        [string]$Query,
        [int]$Limit = 5
    )

    $results = @()

    foreach ($cmd in $script:Commands) {
        $score = 0
        $queryLower = $Query.ToLower()
        $nameLower = $cmd.Name.ToLower()

        # Exact prefix match
        if ($nameLower.StartsWith($queryLower)) {
            $score += 100
        }

        # Contains match
        if ($nameLower.Contains($queryLower)) {
            $score += 50
        }

        # Character matches
        $queryChars = $queryLower.ToCharArray()
        $nameIdx = 0
        foreach ($c in $queryChars) {
            $found = $nameLower.IndexOf($c, $nameIdx)
            if ($found -ge 0) {
                $score += 10
                $nameIdx = $found + 1
            }
        }

        if ($score -gt 0) {
            $results += @{ Command = $cmd; Score = $score }
        }
    }

    return $results | Sort-Object Score -Descending | Select-Object -First $Limit | ForEach-Object { $_.Command }
}

#endregion

#region Settings TUI

function Show-SettingsTUI {
    <#
    .SYNOPSIS
        Interactive settings configuration
    #>
    [CmdletBinding()]
    param()

    $categories = @(
        @{
            Name = "🎨 Appearance"
            Settings = @(
                @{ Key = "Theme"; Type = "select"; Options = @("dark", "light", "dracula", "nord", "monokai"); Current = "dark" }
                @{ Key = "AnimationsEnabled"; Type = "toggle"; Current = $true }
                @{ Key = "CompactMode"; Type = "toggle"; Current = $false }
                @{ Key = "UnicodeSupport"; Type = "toggle"; Current = $true }
            )
        }
        @{
            Name = "🔔 Notifications"
            Settings = @(
                @{ Key = "SoundEnabled"; Type = "toggle"; Current = $true }
                @{ Key = "ToastEnabled"; Type = "toggle"; Current = $true }
                @{ Key = "CostAlerts"; Type = "toggle"; Current = $true }
                @{ Key = "CostThreshold"; Type = "number"; Current = 1.0; Min = 0.1; Max = 100 }
            )
        }
        @{
            Name = "🤖 AI Settings"
            Settings = @(
                @{ Key = "PreferLocal"; Type = "toggle"; Current = $true }
                @{ Key = "AutoFallback"; Type = "toggle"; Current = $true }
                @{ Key = "MaxRetries"; Type = "number"; Current = 3; Min = 1; Max = 10 }
                @{ Key = "DefaultProvider"; Type = "select"; Options = @("anthropic", "openai", "ollama"); Current = "anthropic" }
            )
        }
        @{
            Name = "⌨️ Keyboard"
            Settings = @(
                @{ Key = "EscapeAsInterrupt"; Type = "toggle"; Current = $true }
                @{ Key = "AutocompleteEnabled"; Type = "toggle"; Current = $true }
                @{ Key = "HistorySize"; Type = "number"; Current = 500; Min = 100; Max = 5000 }
            )
        }
    )

    $categoryIndex = 0
    $settingIndex = 0

    [Console]::CursorVisible = $false

    try {
        while ($true) {
            Clear-Host

            Write-Host "`n  ⚙️  HYDRA Settings" -ForegroundColor Cyan
            Write-Host "  ═══════════════════════════════════════════" -ForegroundColor DarkCyan
            Write-Host ""

            # Categories (left panel)
            for ($i = 0; $i -lt $categories.Count; $i++) {
                if ($i -eq $categoryIndex) {
                    Write-Host "  ► " -NoNewline -ForegroundColor Magenta
                    Write-Host $categories[$i].Name -ForegroundColor White
                } else {
                    Write-Host "    $($categories[$i].Name)" -ForegroundColor Gray
                }
            }

            Write-Host ""
            Write-Host "  ───────────────────────────────────────────" -ForegroundColor DarkGray
            Write-Host ""

            # Settings for current category
            $currentCategory = $categories[$categoryIndex]

            for ($s = 0; $s -lt $currentCategory.Settings.Count; $s++) {
                $setting = $currentCategory.Settings[$s]
                $isSelected = ($s -eq $settingIndex)

                $prefix = if ($isSelected) { "  ► " } else { "    " }
                $prefixColor = if ($isSelected) { "Magenta" } else { "DarkGray" }

                Write-Host $prefix -NoNewline -ForegroundColor $prefixColor
                Write-Host "$($setting.Key): " -NoNewline -ForegroundColor $(if ($isSelected) { "White" } else { "Gray" })

                switch ($setting.Type) {
                    "toggle" {
                        $value = if ($setting.Current) { "●  ON " } else { "○  OFF" }
                        $color = if ($setting.Current) { "Green" } else { "Red" }
                        Write-Host $value -ForegroundColor $color
                    }
                    "select" {
                        Write-Host "< $($setting.Current) >" -ForegroundColor Cyan
                    }
                    "number" {
                        Write-Host "[ $($setting.Current) ]" -ForegroundColor Yellow
                    }
                }
            }

            # Footer
            Write-Host ""
            Write-Host "  ───────────────────────────────────────────" -ForegroundColor DarkGray
            Write-Host "  [↑↓] Navigate  [←→] Change  [Tab] Category  [S] Save  [Esc] Cancel" -ForegroundColor DarkGray

            # Handle input
            $key = [Console]::ReadKey($true)

            switch ($key.Key) {
                "UpArrow" {
                    $settingIndex = [math]::Max(0, $settingIndex - 1)
                }
                "DownArrow" {
                    $settingIndex = [math]::Min($currentCategory.Settings.Count - 1, $settingIndex + 1)
                }
                "Tab" {
                    $categoryIndex = ($categoryIndex + 1) % $categories.Count
                    $settingIndex = 0
                }
                "LeftArrow" {
                    $setting = $currentCategory.Settings[$settingIndex]
                    switch ($setting.Type) {
                        "toggle" { $setting.Current = -not $setting.Current }
                        "select" {
                            $idx = $setting.Options.IndexOf($setting.Current)
                            $idx = if ($idx -le 0) { $setting.Options.Count - 1 } else { $idx - 1 }
                            $setting.Current = $setting.Options[$idx]
                        }
                        "number" {
                            $setting.Current = [math]::Max($setting.Min, $setting.Current - 1)
                        }
                    }
                }
                "RightArrow" {
                    $setting = $currentCategory.Settings[$settingIndex]
                    switch ($setting.Type) {
                        "toggle" { $setting.Current = -not $setting.Current }
                        "select" {
                            $idx = $setting.Options.IndexOf($setting.Current)
                            $idx = ($idx + 1) % $setting.Options.Count
                            $setting.Current = $setting.Options[$idx]
                        }
                        "number" {
                            $setting.Current = [math]::Min($setting.Max, $setting.Current + 1)
                        }
                    }
                }
                "Enter" {
                    $setting = $currentCategory.Settings[$settingIndex]
                    if ($setting.Type -eq "toggle") {
                        $setting.Current = -not $setting.Current
                    }
                }
                "S" {
                    # Save settings
                    Save-GUISettings -Categories $categories
                    Write-Host "`n  ✓ Settings saved!" -ForegroundColor Green
                    Start-Sleep -Seconds 1
                    return $true
                }
                "Escape" {
                    return $false
                }
            }
        }
    } finally {
        [Console]::CursorVisible = $true
    }
}

function Save-GUISettings {
    param([array]$Categories)

    $settings = @{}
    foreach ($cat in $Categories) {
        foreach ($s in $cat.Settings) {
            $settings[$s.Key] = $s.Current
        }
    }

    $settingsFile = Join-Path $env:APPDATA "HYDRA\gui-settings.json"
    $settingsDir = Split-Path $settingsFile -Parent

    if (-not (Test-Path $settingsDir)) {
        New-Item -ItemType Directory -Path $settingsDir -Force | Out-Null
    }

    $settings | ConvertTo-Json | Set-Content $settingsFile -Encoding UTF8
}

function Get-GUISettings {
    $settingsFile = Join-Path $env:APPDATA "HYDRA\gui-settings.json"

    if (Test-Path $settingsFile) {
        return Get-Content $settingsFile -Raw | ConvertFrom-Json
    }

    return @{
        Theme = "dark"
        AnimationsEnabled = $true
        SoundEnabled = $true
        CompactMode = $false
    }
}

#endregion

#region Quick Actions Bar

function Show-QuickActions {
    <#
    .SYNOPSIS
        Shows F1-F12 quick actions bar
    #>
    [CmdletBinding()]
    param()

    $actions = @{
        "F1" = "Help"
        "F2" = "History"
        "F3" = "Search"
        "F4" = "Settings"
        "F5" = "Refresh"
        "F6" = "Theme"
        "F7" = "Queue"
        "F8" = "Providers"
        "F9" = "Stats"
        "F10" = "Menu"
        "F11" = "FullScr"
        "F12" = "Exit"
    }

    Write-Host ""
    foreach ($action in $actions.GetEnumerator() | Sort-Object Key) {
        Write-Host " $($action.Key)" -NoNewline -ForegroundColor Black -BackgroundColor DarkCyan
        Write-Host "$($action.Value) " -NoNewline -ForegroundColor Cyan
    }
    Write-Host ""
}

#endregion

#region Network & Latency

function Test-APILatency {
    <#
    .SYNOPSIS
        Tests API endpoint latency
    #>
    [CmdletBinding()]
    param(
        [ValidateSet("anthropic", "openai", "ollama", "gemini")]
        [string]$Provider = "anthropic"
    )

    $endpoints = @{
        anthropic = "https://api.anthropic.com"
        openai = "https://api.openai.com"
        ollama = "http://localhost:11434"
        gemini = "https://generativelanguage.googleapis.com"
    }

    $url = $endpoints[$Provider]

    try {
        $sw = [System.Diagnostics.Stopwatch]::StartNew()
        $request = [System.Net.WebRequest]::Create($url)
        $request.Timeout = 5000
        $request.Method = "HEAD"
        $response = $request.GetResponse()
        $sw.Stop()
        $response.Close()

        return @{
            Provider = $Provider
            Latency = $sw.ElapsedMilliseconds
            Status = "OK"
        }
    } catch {
        return @{
            Provider = $Provider
            Latency = -1
            Status = "Error"
        }
    }
}

function Show-LatencyIndicator {
    <#
    .SYNOPSIS
        Shows network latency indicator
    #>
    [CmdletBinding()]
    param(
        [int]$LatencyMs
    )

    $icon = if ($LatencyMs -lt 0) { "✗" }
            elseif ($LatencyMs -lt 100) { "▁" }
            elseif ($LatencyMs -lt 200) { "▃" }
            elseif ($LatencyMs -lt 500) { "▅" }
            else { "▇" }

    $color = if ($LatencyMs -lt 0) { "Red" }
             elseif ($LatencyMs -lt 100) { "Green" }
             elseif ($LatencyMs -lt 300) { "Yellow" }
             else { "Red" }

    Write-Host "$icon ${LatencyMs}ms" -NoNewline -ForegroundColor $color
}

#endregion

#region Model Comparison

function Show-ModelComparison {
    <#
    .SYNOPSIS
        Shows model comparison table
    #>
    [CmdletBinding()]
    param()

    $models = @(
        @{ Name = "Claude Opus 4.5"; Provider = "Anthropic"; Tier = "PRO"; Input = 15.00; Output = 75.00; Context = "200K" }
        @{ Name = "Claude Sonnet 4.5"; Provider = "Anthropic"; Tier = "STD"; Input = 3.00; Output = 15.00; Context = "200K" }
        @{ Name = "Claude Haiku 4"; Provider = "Anthropic"; Tier = "LITE"; Input = 0.80; Output = 4.00; Context = "200K" }
        @{ Name = "GPT-4o"; Provider = "OpenAI"; Tier = "PRO"; Input = 2.50; Output = 10.00; Context = "128K" }
        @{ Name = "GPT-4o-mini"; Provider = "OpenAI"; Tier = "LITE"; Input = 0.15; Output = 0.60; Context = "128K" }
        @{ Name = "Llama 3.3 70B"; Provider = "Ollama"; Tier = "LOCAL"; Input = 0.00; Output = 0.00; Context = "128K" }
        @{ Name = "Qwen 2.5 Coder"; Provider = "Ollama"; Tier = "LOCAL"; Input = 0.00; Output = 0.00; Context = "32K" }
    )

    Write-Host ""
    Write-Host "  ╔══════════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "  ║                      Model Comparison                            ║" -ForegroundColor Cyan
    Write-Host "  ╠═══════════════════╤══════════╤══════╤════════╤════════╤═════════╣" -ForegroundColor Cyan
    Write-Host "  ║ Model             │ Provider │ Tier │ In/1M  │ Out/1M │ Context ║" -ForegroundColor Cyan
    Write-Host "  ╟───────────────────┼──────────┼──────┼────────┼────────┼─────────╢" -ForegroundColor DarkCyan

    foreach ($m in $models) {
        $tierColor = switch ($m.Tier) {
            "PRO" { "Magenta" }
            "STD" { "Blue" }
            "LITE" { "Green" }
            "LOCAL" { "Cyan" }
        }

        Write-Host "  ║ " -NoNewline -ForegroundColor DarkCyan
        Write-Host $m.Name.PadRight(17) -NoNewline -ForegroundColor White
        Write-Host " │ " -NoNewline -ForegroundColor DarkCyan
        Write-Host $m.Provider.PadRight(8) -NoNewline -ForegroundColor Gray
        Write-Host " │ " -NoNewline -ForegroundColor DarkCyan
        Write-Host $m.Tier.PadRight(4) -NoNewline -ForegroundColor $tierColor
        Write-Host " │ " -NoNewline -ForegroundColor DarkCyan
        Write-Host ("`${0:N2}" -f $m.Input).PadLeft(6) -NoNewline -ForegroundColor $(if ($m.Input -eq 0) { "Green" } else { "Yellow" })
        Write-Host " │ " -NoNewline -ForegroundColor DarkCyan
        Write-Host ("`${0:N2}" -f $m.Output).PadLeft(6) -NoNewline -ForegroundColor $(if ($m.Output -eq 0) { "Green" } else { "Yellow" })
        Write-Host " │ " -NoNewline -ForegroundColor DarkCyan
        Write-Host $m.Context.PadLeft(7) -NoNewline -ForegroundColor Gray
        Write-Host " ║" -ForegroundColor DarkCyan
    }

    Write-Host "  ╚═══════════════════╧══════════╧══════╧════════╧════════╧═════════╝" -ForegroundColor Cyan
    Write-Host ""
}

#endregion

#region Exports

Export-ModuleMember -Function @(
    # History
    'Initialize-History',
    'Add-ToHistory',
    'Show-HistoryBrowser',

    # Autocomplete
    'Show-Autocomplete',
    'Get-FuzzyMatches',

    # Settings
    'Show-SettingsTUI',
    'Save-GUISettings',
    'Get-GUISettings',

    # Quick Actions
    'Show-QuickActions',

    # Network
    'Test-APILatency',
    'Show-LatencyIndicator',

    # Comparison
    'Show-ModelComparison'
)

#endregion

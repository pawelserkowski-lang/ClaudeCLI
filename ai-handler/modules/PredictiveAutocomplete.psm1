# ═══════════════════════════════════════════════════════════════════════════════
# PREDICTIVE AUTOCOMPLETE - AI-powered code completion
# ═══════════════════════════════════════════════════════════════════════════════

$script:AutocompleteConfig = @{
    FastModel = 'llama3.2:1b'
    CodeModel = 'qwen2.5-coder:1.5b'
    ContextLines = 15
    MaxPredictions = 3
    TimeoutMs = 5000
    CacheEnabled = $true
    CachePath = Join-Path $PSScriptRoot '..\cache\autocomplete'
}

# Initialize cache
$script:PredictionCache = @{}

# === Get File Language ===
function Get-CodeLanguage {
    [CmdletBinding()]
    param([string]$FilePath)

    $ext = [System.IO.Path]::GetExtension($FilePath).TrimStart('.').ToLower()

    return switch ($ext) {
        'py'    { @{ Name = 'python'; Comment = '#'; MultiStart = '"""'; MultiEnd = '"""' } }
        'js'    { @{ Name = 'javascript'; Comment = '//'; MultiStart = '/*'; MultiEnd = '*/' } }
        'ts'    { @{ Name = 'typescript'; Comment = '//'; MultiStart = '/*'; MultiEnd = '*/' } }
        'jsx'   { @{ Name = 'javascript-react'; Comment = '//'; MultiStart = '/*'; MultiEnd = '*/' } }
        'tsx'   { @{ Name = 'typescript-react'; Comment = '//'; MultiStart = '/*'; MultiEnd = '*/' } }
        'ps1'   { @{ Name = 'powershell'; Comment = '#'; MultiStart = '<#'; MultiEnd = '#>' } }
        'psm1'  { @{ Name = 'powershell'; Comment = '#'; MultiStart = '<#'; MultiEnd = '#>' } }
        'rs'    { @{ Name = 'rust'; Comment = '//'; MultiStart = '/*'; MultiEnd = '*/' } }
        'go'    { @{ Name = 'go'; Comment = '//'; MultiStart = '/*'; MultiEnd = '*/' } }
        'cs'    { @{ Name = 'csharp'; Comment = '//'; MultiStart = '/*'; MultiEnd = '*/' } }
        'java'  { @{ Name = 'java'; Comment = '//'; MultiStart = '/*'; MultiEnd = '*/' } }
        'rb'    { @{ Name = 'ruby'; Comment = '#'; MultiStart = '=begin'; MultiEnd = '=end' } }
        'php'   { @{ Name = 'php'; Comment = '//'; MultiStart = '/*'; MultiEnd = '*/' } }
        'sql'   { @{ Name = 'sql'; Comment = '--'; MultiStart = '/*'; MultiEnd = '*/' } }
        'sh'    { @{ Name = 'bash'; Comment = '#'; MultiStart = ''; MultiEnd = '' } }
        'bash'  { @{ Name = 'bash'; Comment = '#'; MultiStart = ''; MultiEnd = '' } }
        'html'  { @{ Name = 'html'; Comment = ''; MultiStart = '<!--'; MultiEnd = '-->' } }
        'css'   { @{ Name = 'css'; Comment = ''; MultiStart = '/*'; MultiEnd = '*/' } }
        'json'  { @{ Name = 'json'; Comment = ''; MultiStart = ''; MultiEnd = '' } }
        'yaml'  { @{ Name = 'yaml'; Comment = '#'; MultiStart = ''; MultiEnd = '' } }
        'yml'   { @{ Name = 'yaml'; Comment = '#'; MultiStart = ''; MultiEnd = '' } }
        'md'    { @{ Name = 'markdown'; Comment = ''; MultiStart = ''; MultiEnd = '' } }
        default { @{ Name = $ext; Comment = '//'; MultiStart = '/*'; MultiEnd = '*/' } }
    }
}

# === Get Surrounding Context ===
function Get-CodeContext {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$FilePath,

        [int]$LineNumber,
        [int]$ContextLines = $script:AutocompleteConfig.ContextLines
    )

    if (-not (Test-Path $FilePath)) {
        return $null
    }

    $lines = Get-Content -Path $FilePath
    $totalLines = $lines.Count

    if ($LineNumber -le 0) { $LineNumber = $totalLines }

    $startLine = [math]::Max(0, $LineNumber - $ContextLines - 1)
    $endLine = [math]::Min($totalLines - 1, $LineNumber - 1)

    $beforeContext = if ($startLine -lt $endLine) {
        $lines[$startLine..$endLine] -join "`n"
    } else { "" }

    # Get after context for validation
    $afterStart = [math]::Min($totalLines - 1, $LineNumber)
    $afterEnd = [math]::Min($totalLines - 1, $LineNumber + 5)
    $afterContext = if ($afterStart -le $afterEnd -and $afterStart -lt $totalLines) {
        $lines[$afterStart..$afterEnd] -join "`n"
    } else { "" }

    return @{
        Before = $beforeContext
        After = $afterContext
        CurrentLine = if ($LineNumber -le $totalLines) { $lines[$LineNumber - 1] } else { "" }
        LineNumber = $LineNumber
        TotalLines = $totalLines
        FilePath = $FilePath
    }
}

# === Generate Predictions ===
function Get-CodePrediction {
    <#
    .SYNOPSIS
        Get AI-powered code completion predictions
    .DESCRIPTION
        Analyzes code context and predicts the next lines of code.
        Uses local Ollama models for fast, private predictions.
    .PARAMETER FilePath
        Path to the file being edited
    .PARAMETER LineNumber
        Current line number (defaults to end of file)
    .PARAMETER CurrentText
        Text currently being typed
    .PARAMETER Count
        Number of predictions to generate (1-5)
    .EXAMPLE
        Get-CodePrediction -FilePath "app.py" -LineNumber 25
    .EXAMPLE
        Get-CodePrediction -FilePath "script.js" -CurrentText "function handle"
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$FilePath,

        [int]$LineNumber = 0,
        [string]$CurrentText = '',
        [int]$Count = 3,
        [switch]$UseCodeModel
    )

    $language = Get-CodeLanguage -FilePath $FilePath
    $context = Get-CodeContext -FilePath $FilePath -LineNumber $LineNumber

    if (-not $context) {
        Write-Error "Could not read file: $FilePath"
        return
    }

    # Check cache
    $cacheKey = "$FilePath`:$LineNumber`:$CurrentText"
    if ($script:AutocompleteConfig.CacheEnabled -and $script:PredictionCache.ContainsKey($cacheKey)) {
        $cached = $script:PredictionCache[$cacheKey]
        if ((Get-Date) - $cached.Timestamp -lt [TimeSpan]::FromMinutes(5)) {
            return $cached.Predictions
        }
    }

    $model = if ($UseCodeModel) {
        $script:AutocompleteConfig.CodeModel
    } else {
        $script:AutocompleteConfig.FastModel
    }

    $prompt = @"
You are a code completion AI. Predict the next lines of $($language.Name) code.

Context (code before cursor):
``````$($language.Name)
$($context.Before)
$CurrentText
``````

Rules:
1. Complete the current line if partial
2. Predict 1-3 most likely next lines
3. Match the existing code style and indentation
4. Only output code, no explanations
5. If in a function/class, stay in context

Output format (one prediction per line, numbered):
1: <first prediction>
2: <second prediction>
3: <third prediction>
"@

    try {
        $body = @{
            model = $model
            prompt = $prompt
            stream = $false
            options = @{
                num_predict = 150
                temperature = 0.4
                stop = @("`n`n", "```")
            }
        } | ConvertTo-Json -Depth 3

        $startTime = Get-Date
        $response = Invoke-RestMethod -Uri 'http://localhost:11434/api/generate' `
            -Method Post -Body $body -ContentType 'application/json' `
            -TimeoutSec ($script:AutocompleteConfig.TimeoutMs / 1000)

        $durationMs = ((Get-Date) - $startTime).TotalMilliseconds

        # Parse predictions
        $predictions = @()
        $lines = $response.response -split "`n"

        foreach ($line in $lines) {
            if ($line -match '^\d+:\s*(.+)$') {
                $pred = $Matches[1].Trim()
                if ($pred -and $pred.Length -gt 0) {
                    $predictions += @{
                        Text = $pred
                        Confidence = 1.0 - ($predictions.Count * 0.2)
                    }
                }
            } elseif ($line.Trim() -and $line -notmatch '^```' -and $predictions.Count -lt $Count) {
                $predictions += @{
                    Text = $line.Trim()
                    Confidence = 0.6
                }
            }
        }

        # Take only requested count
        $predictions = $predictions | Select-Object -First $Count

        $result = @{
            Predictions = $predictions
            Language = $language.Name
            Model = $model
            DurationMs = [math]::Round($durationMs)
            Context = @{
                LineNumber = $context.LineNumber
                CurrentText = $CurrentText
            }
        }

        # Cache result
        if ($script:AutocompleteConfig.CacheEnabled) {
            $script:PredictionCache[$cacheKey] = @{
                Predictions = $result
                Timestamp = Get-Date
            }
        }

        return $result

    } catch {
        Write-Error "Prediction failed: $_"
        return $null
    }
}

# === Interactive Autocomplete ===
function Invoke-Autocomplete {
    <#
    .SYNOPSIS
        Interactive autocomplete session
    .DESCRIPTION
        Continuously provides predictions as you type
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$FilePath
    )

    if (-not (Test-Path $FilePath)) {
        Write-Error "File not found: $FilePath"
        return
    }

    $language = Get-CodeLanguage -FilePath $FilePath
    Write-Host "`n🤖 Autocomplete Active for $($language.Name)" -ForegroundColor Cyan
    Write-Host "Type code and press Tab for predictions, Esc to exit`n" -ForegroundColor DarkGray

    $lines = Get-Content -Path $FilePath
    $currentLine = $lines.Count + 1
    $buffer = ""

    while ($true) {
        Write-Host "$currentLine│ " -NoNewline -ForegroundColor DarkGray

        $key = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')

        switch ($key.VirtualKeyCode) {
            27 { # Escape
                Write-Host "`n✓ Autocomplete ended" -ForegroundColor Green
                return
            }
            9 { # Tab - Get prediction
                Write-Host "" # New line
                $result = Get-CodePrediction -FilePath $FilePath -LineNumber $currentLine -CurrentText $buffer

                if ($result -and $result.Predictions) {
                    Write-Host "  Predictions:" -ForegroundColor Yellow
                    for ($i = 0; $i -lt $result.Predictions.Count; $i++) {
                        $pred = $result.Predictions[$i]
                        $conf = [math]::Round($pred.Confidence * 100)
                        Write-Host "  [$($i+1)] " -NoNewline -ForegroundColor Cyan
                        Write-Host $pred.Text -NoNewline -ForegroundColor White
                        Write-Host " ($conf%)" -ForegroundColor DarkGray
                    }
                    Write-Host "  Press 1-3 to accept, Enter to skip" -ForegroundColor DarkGray

                    $choice = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
                    if ($choice.Character -match '[1-3]') {
                        $idx = [int]$choice.Character.ToString() - 1
                        if ($idx -lt $result.Predictions.Count) {
                            $selected = $result.Predictions[$idx].Text
                            $buffer += $selected
                            Write-Host "$currentLine│ $buffer" -ForegroundColor White
                        }
                    }
                }
            }
            13 { # Enter - Accept line
                if ($buffer) {
                    Add-Content -Path $FilePath -Value $buffer
                    $buffer = ""
                    $currentLine++
                }
                Write-Host ""
            }
            8 { # Backspace
                if ($buffer.Length -gt 0) {
                    $buffer = $buffer.Substring(0, $buffer.Length - 1)
                    Write-Host "`r$currentLine│ $buffer " -NoNewline
                }
            }
            default {
                if ($key.Character -match '[\x20-\x7E]') {
                    $buffer += $key.Character
                    Write-Host $key.Character -NoNewline
                }
            }
        }
    }
}

# === Batch Predict for File ===
function Get-FilePredictions {
    <#
    .SYNOPSIS
        Generate predictions for multiple locations in a file
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$FilePath,

        [int[]]$LineNumbers = @(),
        [switch]$AllFunctions
    )

    $language = Get-CodeLanguage -FilePath $FilePath
    $lines = Get-Content -Path $FilePath

    # Find function definitions if requested
    if ($AllFunctions) {
        $functionPatterns = @{
            'python' = 'def \w+\s*\('
            'javascript' = '(function\s+\w+|const\s+\w+\s*=.*=>|\w+\s*\([^)]*\)\s*\{)'
            'typescript' = '(function\s+\w+|const\s+\w+|async\s+function)'
            'powershell' = 'function\s+\w+'
            'rust' = 'fn\s+\w+'
            'go' = 'func\s+\w+'
        }

        $pattern = $functionPatterns[$language.Name]
        if ($pattern) {
            for ($i = 0; $i -lt $lines.Count; $i++) {
                if ($lines[$i] -match $pattern) {
                    $LineNumbers += ($i + 1)
                }
            }
        }
    }

    if ($LineNumbers.Count -eq 0) {
        Write-Host "No lines specified. Use -LineNumbers or -AllFunctions" -ForegroundColor Yellow
        return
    }

    $results = @()
    foreach ($lineNum in $LineNumbers) {
        Write-Host "Predicting at line $lineNum..." -ForegroundColor Cyan
        $result = Get-CodePrediction -FilePath $FilePath -LineNumber $lineNum
        if ($result) {
            $results += @{
                LineNumber = $lineNum
                Context = $lines[([math]::Max(0, $lineNum - 2))..([math]::Min($lines.Count - 1, $lineNum))] -join "`n"
                Predictions = $result.Predictions
            }
        }
    }

    return $results
}

# === Clear Prediction Cache ===
function Clear-PredictionCache {
    [CmdletBinding()]
    param()

    $count = $script:PredictionCache.Count
    $script:PredictionCache.Clear()
    Write-Host "Cleared $count cached predictions" -ForegroundColor Yellow
}

# === Export ===
Export-ModuleMember -Function @(
    'Get-CodeLanguage',
    'Get-CodeContext',
    'Get-CodePrediction',
    'Invoke-Autocomplete',
    'Get-FilePredictions',
    'Clear-PredictionCache'
)

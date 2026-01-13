# ═══════════════════════════════════════════════════════════════════════════════
# AI CODE REVIEW PIPELINE - Multi-model code review with consensus
# ═══════════════════════════════════════════════════════════════════════════════

$script:ReviewConfig = @{
    FastModel = 'llama3.2:1b'
    MediumModel = 'llama3.2:3b'
    AccurateModel = 'qwen2.5-coder:1.5b'
    ConsensusThreshold = 0.6  # 60% agreement required
    MaxFileSize = 50000       # 50KB max
    TimeoutMs = 30000
}

# === Quick Scan (Fast Model) ===
function Invoke-QuickScan {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Code,
        [string]$Language = 'auto'
    )

    $prompt = @"
Quickly scan this $Language code for obvious issues. List only CRITICAL problems (max 5):
- Syntax errors
- Security vulnerabilities
- Obvious bugs
- Missing error handling

Code:
``````
$Code
``````

Format: [SEVERITY] Issue description (line number if known)
"@

    try {
        $body = @{
            model = $script:ReviewConfig.FastModel
            prompt = $prompt
            stream = $false
            options = @{ num_predict = 300; temperature = 0.3 }
        } | ConvertTo-Json -Depth 3

        $response = Invoke-RestMethod -Uri 'http://localhost:11434/api/generate' `
            -Method Post -Body $body -ContentType 'application/json' `
            -TimeoutSec ($script:ReviewConfig.TimeoutMs / 1000)

        return @{
            Success = $true
            Model = $script:ReviewConfig.FastModel
            Phase = 'quick-scan'
            Issues = $response.response
            DurationMs = $response.total_duration / 1000000
        }
    } catch {
        return @{ Success = $false; Error = $_.Exception.Message; Phase = 'quick-scan' }
    }
}

# === Detailed Review (Medium Model) ===
function Invoke-DetailedReview {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Code,
        [string]$Language = 'auto',
        [string]$QuickScanResults = ''
    )

    $contextPrompt = if ($QuickScanResults) {
        "`nPrevious scan found these issues:`n$QuickScanResults`n`nVerify and expand on these findings."
    } else { "" }

    $prompt = @"
Perform a detailed code review of this $Language code.$contextPrompt

Analyze:
1. **Logic errors** - incorrect conditions, off-by-one errors
2. **Best practices** - naming, structure, patterns
3. **Performance** - inefficient loops, memory issues
4. **Maintainability** - complexity, readability

Code:
``````
$Code
``````

Format each issue as:
[CATEGORY] Description | Suggestion | Line(s)
"@

    try {
        $body = @{
            model = $script:ReviewConfig.MediumModel
            prompt = $prompt
            stream = $false
            options = @{ num_predict = 600; temperature = 0.4 }
        } | ConvertTo-Json -Depth 3

        $response = Invoke-RestMethod -Uri 'http://localhost:11434/api/generate' `
            -Method Post -Body $body -ContentType 'application/json' `
            -TimeoutSec ($script:ReviewConfig.TimeoutMs / 1000)

        return @{
            Success = $true
            Model = $script:ReviewConfig.MediumModel
            Phase = 'detailed-review'
            Issues = $response.response
            DurationMs = $response.total_duration / 1000000
        }
    } catch {
        return @{ Success = $false; Error = $_.Exception.Message; Phase = 'detailed-review' }
    }
}

# === Accurate Validation (Code-Specific Model) ===
function Invoke-AccurateValidation {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Code,
        [string]$Language = 'auto',
        [string]$PreviousFindings = ''
    )

    $prompt = @"
You are a senior code reviewer. Validate these findings and add any missed issues.

Previous findings:
$PreviousFindings

Code to review ($Language):
``````
$Code
``````

Tasks:
1. Confirm valid issues (mark as [CONFIRMED])
2. Dismiss false positives (mark as [DISMISSED] with reason)
3. Add any missed critical issues (mark as [NEW])
4. Provide specific fix suggestions

Output format:
[STATUS] Category: Description
  Fix: Specific code suggestion
"@

    try {
        $body = @{
            model = $script:ReviewConfig.AccurateModel
            prompt = $prompt
            stream = $false
            options = @{ num_predict = 800; temperature = 0.2 }
        } | ConvertTo-Json -Depth 3

        $response = Invoke-RestMethod -Uri 'http://localhost:11434/api/generate' `
            -Method Post -Body $body -ContentType 'application/json' `
            -TimeoutSec ($script:ReviewConfig.TimeoutMs / 1000)

        return @{
            Success = $true
            Model = $script:ReviewConfig.AccurateModel
            Phase = 'accurate-validation'
            Issues = $response.response
            DurationMs = $response.total_duration / 1000000
        }
    } catch {
        return @{ Success = $false; Error = $_.Exception.Message; Phase = 'accurate-validation' }
    }
}

# === Full Pipeline ===
function Invoke-AICodeReview {
    <#
    .SYNOPSIS
        Multi-model AI code review pipeline
    .DESCRIPTION
        Runs code through 3 AI models:
        1. Fast scan (llama3.2:1b) - quick issue detection
        2. Detailed review (llama3.2:3b) - thorough analysis
        3. Accurate validation (qwen-coder) - consensus verification
    .PARAMETER FilePath
        Path to file to review
    .PARAMETER Code
        Direct code string to review
    .PARAMETER Language
        Programming language (auto-detected if not specified)
    .PARAMETER SkipConsensus
        Skip the third validation phase
    .EXAMPLE
        Invoke-AICodeReview -FilePath "src/app.py"
    .EXAMPLE
        Get-Content script.js | Invoke-AICodeReview -Language javascript
    #>
    [CmdletBinding()]
    param(
        [Parameter(ValueFromPipeline)]
        [string]$Code,

        [string]$FilePath,
        [string]$Language = 'auto',
        [switch]$SkipConsensus,
        [switch]$Verbose
    )

    $startTime = Get-Date

    # Get code from file if path provided
    if ($FilePath -and (Test-Path $FilePath)) {
        $Code = Get-Content -Path $FilePath -Raw
        if ($Language -eq 'auto') {
            $ext = [System.IO.Path]::GetExtension($FilePath).TrimStart('.')
            $Language = switch ($ext) {
                'py'   { 'python' }
                'js'   { 'javascript' }
                'ts'   { 'typescript' }
                'ps1'  { 'powershell' }
                'rs'   { 'rust' }
                'go'   { 'go' }
                'cs'   { 'csharp' }
                'java' { 'java' }
                'rb'   { 'ruby' }
                'php'  { 'php' }
                default { $ext }
            }
        }
    }

    if (-not $Code) {
        Write-Error "No code provided. Use -FilePath or pipe code."
        return
    }

    # Check file size
    if ($Code.Length -gt $script:ReviewConfig.MaxFileSize) {
        Write-Warning "File too large ($($Code.Length) bytes). Truncating to $($script:ReviewConfig.MaxFileSize) bytes."
        $Code = $Code.Substring(0, $script:ReviewConfig.MaxFileSize)
    }

    Write-Host "`n╔════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║          AI CODE REVIEW PIPELINE                       ║" -ForegroundColor Cyan
    Write-Host "╚════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
    Write-Host "  Language: $Language | Size: $($Code.Length) chars" -ForegroundColor DarkGray

    $results = @{
        Language = $Language
        CodeSize = $Code.Length
        Phases = @()
        AllIssues = @()
        ConsensusIssues = @()
    }

    # Phase 1: Quick Scan
    Write-Host "`n[1/3] Quick Scan " -NoNewline -ForegroundColor Yellow
    Write-Host "($($script:ReviewConfig.FastModel))..." -ForegroundColor DarkGray

    $quickScan = Invoke-QuickScan -Code $Code -Language $Language
    $results.Phases += $quickScan

    if ($quickScan.Success) {
        Write-Host "  ✓ Completed in $([math]::Round($quickScan.DurationMs))ms" -ForegroundColor Green
        if ($Verbose) { Write-Host $quickScan.Issues -ForegroundColor Gray }
    } else {
        Write-Host "  ✗ Failed: $($quickScan.Error)" -ForegroundColor Red
    }

    # Phase 2: Detailed Review
    Write-Host "`n[2/3] Detailed Review " -NoNewline -ForegroundColor Yellow
    Write-Host "($($script:ReviewConfig.MediumModel))..." -ForegroundColor DarkGray

    $detailedReview = Invoke-DetailedReview -Code $Code -Language $Language `
        -QuickScanResults $(if ($quickScan.Success) { $quickScan.Issues } else { '' })
    $results.Phases += $detailedReview

    if ($detailedReview.Success) {
        Write-Host "  ✓ Completed in $([math]::Round($detailedReview.DurationMs))ms" -ForegroundColor Green
        if ($Verbose) { Write-Host $detailedReview.Issues -ForegroundColor Gray }
    } else {
        Write-Host "  ✗ Failed: $($detailedReview.Error)" -ForegroundColor Red
    }

    # Phase 3: Accurate Validation (Consensus)
    if (-not $SkipConsensus) {
        Write-Host "`n[3/3] Consensus Validation " -NoNewline -ForegroundColor Yellow
        Write-Host "($($script:ReviewConfig.AccurateModel))..." -ForegroundColor DarkGray

        $previousFindings = @()
        if ($quickScan.Success) { $previousFindings += $quickScan.Issues }
        if ($detailedReview.Success) { $previousFindings += $detailedReview.Issues }

        $validation = Invoke-AccurateValidation -Code $Code -Language $Language `
            -PreviousFindings ($previousFindings -join "`n`n")
        $results.Phases += $validation

        if ($validation.Success) {
            Write-Host "  ✓ Completed in $([math]::Round($validation.DurationMs))ms" -ForegroundColor Green
            $results.ConsensusIssues = $validation.Issues
        } else {
            Write-Host "  ✗ Failed: $($validation.Error)" -ForegroundColor Red
        }
    }

    # Summary
    $totalTime = ((Get-Date) - $startTime).TotalSeconds
    $successPhases = ($results.Phases | Where-Object { $_.Success }).Count
    $totalPhases = $results.Phases.Count

    Write-Host "`n╔════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║                    REVIEW SUMMARY                      ║" -ForegroundColor Cyan
    Write-Host "╚════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
    Write-Host "  Phases: $successPhases/$totalPhases successful" -ForegroundColor $(if ($successPhases -eq $totalPhases) { 'Green' } else { 'Yellow' })
    Write-Host "  Total time: $([math]::Round($totalTime, 1))s" -ForegroundColor DarkGray

    if ($results.ConsensusIssues) {
        Write-Host "`n  CONFIRMED ISSUES:" -ForegroundColor White
        Write-Host $results.ConsensusIssues -ForegroundColor Gray
    }

    $results.TotalTimeSeconds = $totalTime
    return $results
}

# === Review Git Staged Files ===
function Invoke-AIReviewStaged {
    <#
    .SYNOPSIS
        Review all staged git files
    #>
    [CmdletBinding()]
    param()

    $stagedFiles = git diff --cached --name-only 2>$null
    if (-not $stagedFiles) {
        Write-Host "No staged files to review." -ForegroundColor Yellow
        return
    }

    $results = @()
    foreach ($file in $stagedFiles) {
        if (Test-Path $file) {
            Write-Host "`n━━━ Reviewing: $file ━━━" -ForegroundColor Cyan
            $result = Invoke-AICodeReview -FilePath $file
            $results += @{ File = $file; Result = $result }
        }
    }

    return $results
}

# === Export ===
Export-ModuleMember -Function @(
    'Invoke-QuickScan',
    'Invoke-DetailedReview',
    'Invoke-AccurateValidation',
    'Invoke-AICodeReview',
    'Invoke-AIReviewStaged'
)

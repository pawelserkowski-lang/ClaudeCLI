# ═══════════════════════════════════════════════════════════════════════════════
# SEMANTIC GIT COMMIT - AI-powered commit message generation
# ═══════════════════════════════════════════════════════════════════════════════

$script:CommitConfig = @{
    Model = 'llama3.2:3b'
    FastModel = 'llama3.2:1b'
    MaxDiffLines = 500
    MaxContextFiles = 5
    TimeoutMs = 20000
    CommitStyles = @{
        conventional = @{
            types = @('feat', 'fix', 'docs', 'style', 'refactor', 'test', 'chore', 'perf')
            format = '<type>(<scope>): <description>'
        }
        simple = @{
            format = '<action> <what>'
        }
        detailed = @{
            format = '<summary>\n\n<body>\n\n<footer>'
        }
    }
}

# === Get Project Context ===
function Get-ProjectContext {
    [CmdletBinding()]
    param(
        [int]$RecentCommits = 5
    )

    $context = @{
        RecentCommits = @()
        ProjectType = 'unknown'
        MainLanguage = 'unknown'
        HasTests = $false
    }

    # Get recent commits for style matching
    try {
        $commits = git log --oneline -n $RecentCommits 2>$null
        if ($commits) {
            $context.RecentCommits = $commits -split "`n"
        }
    } catch { }

    # Detect project type
    if (Test-Path 'package.json') {
        $context.ProjectType = 'node'
        $context.MainLanguage = 'javascript'
    } elseif (Test-Path 'requirements.txt' -or Test-Path 'setup.py' -or Test-Path 'pyproject.toml') {
        $context.ProjectType = 'python'
        $context.MainLanguage = 'python'
    } elseif (Test-Path 'Cargo.toml') {
        $context.ProjectType = 'rust'
        $context.MainLanguage = 'rust'
    } elseif (Test-Path 'go.mod') {
        $context.ProjectType = 'go'
        $context.MainLanguage = 'go'
    } elseif (Test-Path '*.csproj') {
        $context.ProjectType = 'dotnet'
        $context.MainLanguage = 'csharp'
    } elseif (Test-Path '*.psm1' -or Test-Path '*.ps1') {
        $context.ProjectType = 'powershell'
        $context.MainLanguage = 'powershell'
    }

    # Check for tests
    $context.HasTests = (Test-Path 'tests') -or (Test-Path 'test') -or
                        (Test-Path '__tests__') -or (Test-Path 'spec')

    return $context
}

# === Analyze Diff ===
function Get-DiffAnalysis {
    [CmdletBinding()]
    param(
        [switch]$Staged
    )

    $diffCmd = if ($Staged) { 'git diff --cached --stat' } else { 'git diff --stat' }
    $fullDiffCmd = if ($Staged) { 'git diff --cached' } else { 'git diff' }

    $stats = Invoke-Expression $diffCmd 2>$null
    $fullDiff = Invoke-Expression $fullDiffCmd 2>$null

    # Truncate if too long
    $diffLines = ($fullDiff -split "`n")
    if ($diffLines.Count -gt $script:CommitConfig.MaxDiffLines) {
        $fullDiff = ($diffLines[0..($script:CommitConfig.MaxDiffLines - 1)] -join "`n") +
                    "`n... (truncated, $($diffLines.Count - $script:CommitConfig.MaxDiffLines) more lines)"
    }

    # Parse stats
    $analysis = @{
        FilesChanged = 0
        Insertions = 0
        Deletions = 0
        FileTypes = @{}
        MainAction = 'update'
        Diff = $fullDiff
        Stats = $stats
    }

    if ($stats -match '(\d+) files? changed') {
        $analysis.FilesChanged = [int]$Matches[1]
    }
    if ($stats -match '(\d+) insertions?') {
        $analysis.Insertions = [int]$Matches[1]
    }
    if ($stats -match '(\d+) deletions?') {
        $analysis.Deletions = [int]$Matches[1]
    }

    # Determine main action
    if ($analysis.Insertions -gt 0 -and $analysis.Deletions -eq 0) {
        $analysis.MainAction = 'add'
    } elseif ($analysis.Deletions -gt 0 -and $analysis.Insertions -eq 0) {
        $analysis.MainAction = 'remove'
    } elseif ($analysis.Insertions -gt $analysis.Deletions * 2) {
        $analysis.MainAction = 'add'
    } elseif ($analysis.Deletions -gt $analysis.Insertions * 2) {
        $analysis.MainAction = 'remove'
    } else {
        $analysis.MainAction = 'update'
    }

    return $analysis
}

# === Generate Commit Message ===
function New-AICommitMessage {
    <#
    .SYNOPSIS
        Generate AI-powered commit message from staged changes
    .DESCRIPTION
        Analyzes git diff and project context to generate meaningful commit messages.
        Supports conventional commits, simple format, and detailed format.
    .PARAMETER Style
        Commit style: conventional (default), simple, or detailed
    .PARAMETER Staged
        Analyze staged changes (default: true)
    .PARAMETER Fast
        Use faster, smaller model
    .PARAMETER DryRun
        Only show message, don't commit
    .EXAMPLE
        New-AICommitMessage
    .EXAMPLE
        New-AICommitMessage -Style detailed -DryRun
    #>
    [CmdletBinding()]
    param(
        [ValidateSet('conventional', 'simple', 'detailed')]
        [string]$Style = 'conventional',

        [switch]$Staged = $true,
        [switch]$Fast,
        [switch]$DryRun,
        [switch]$AutoCommit
    )

    Write-Host "`n🔍 Analyzing changes..." -ForegroundColor Cyan

    # Get diff and context
    $diff = Get-DiffAnalysis -Staged:$Staged
    $context = Get-ProjectContext

    if (-not $diff.Diff -or $diff.FilesChanged -eq 0) {
        Write-Host "No changes to commit." -ForegroundColor Yellow
        return
    }

    Write-Host "  Files: $($diff.FilesChanged) | +$($diff.Insertions) -$($diff.Deletions)" -ForegroundColor DarkGray

    # Build prompt based on style
    $styleGuide = switch ($Style) {
        'conventional' {
            @"
Use Conventional Commits format: <type>(<scope>): <description>

Types: feat, fix, docs, style, refactor, test, chore, perf
- feat: new feature
- fix: bug fix
- docs: documentation only
- style: formatting, no code change
- refactor: code change that neither fixes nor adds
- test: adding tests
- chore: maintenance
- perf: performance improvement

Scope is optional but helpful (e.g., api, ui, auth)
Description should be imperative mood ("add" not "added")
"@
        }
        'simple' {
            "Use simple format: <verb> <what>. Be concise (max 50 chars)."
        }
        'detailed' {
            @"
Use detailed format:
Line 1: Short summary (max 50 chars)
Line 2: Blank
Line 3+: Detailed explanation of what and why

Include:
- What changed
- Why it was needed
- Any breaking changes
"@
        }
    }

    $recentCommitsStr = if ($context.RecentCommits) {
        "Recent commits for style reference:`n" + ($context.RecentCommits -join "`n")
    } else { "" }

    $prompt = @"
Generate a git commit message for these changes.

$styleGuide

$recentCommitsStr

Project: $($context.ProjectType) ($($context.MainLanguage))
Main action: $($diff.MainAction)
Stats: $($diff.Stats)

Diff:
$($diff.Diff)

Return ONLY the commit message, nothing else.
"@

    # Call AI
    $model = if ($Fast) { $script:CommitConfig.FastModel } else { $script:CommitConfig.Model }
    Write-Host "🤖 Generating with $model..." -ForegroundColor Cyan

    try {
        $body = @{
            model = $model
            prompt = $prompt
            stream = $false
            options = @{
                num_predict = 200
                temperature = 0.3
            }
        } | ConvertTo-Json -Depth 3

        $response = Invoke-RestMethod -Uri 'http://localhost:11434/api/generate' `
            -Method Post -Body $body -ContentType 'application/json' `
            -TimeoutSec ($script:CommitConfig.TimeoutMs / 1000)

        $message = $response.response.Trim()

        # Clean up message
        $message = $message -replace '```.*?```', ''  # Remove code blocks
        $message = $message -replace '^["'']|["'']$', ''  # Remove quotes
        $message = $message.Trim()

        Write-Host "`n╔════════════════════════════════════════════════════════╗" -ForegroundColor Green
        Write-Host "║              GENERATED COMMIT MESSAGE                  ║" -ForegroundColor Green
        Write-Host "╚════════════════════════════════════════════════════════╝" -ForegroundColor Green
        Write-Host $message -ForegroundColor White
        Write-Host ""

        if ($AutoCommit -and -not $DryRun) {
            Write-Host "Committing..." -ForegroundColor Yellow
            git commit -m $message
            Write-Host "✓ Committed!" -ForegroundColor Green
        } elseif (-not $DryRun) {
            Write-Host "Run with -AutoCommit to commit, or copy message above." -ForegroundColor DarkGray
        }

        return @{
            Message = $message
            Style = $Style
            Model = $model
            Diff = $diff
            Context = $context
        }

    } catch {
        Write-Error "Failed to generate commit message: $_"
        return $null
    }
}

# === Interactive Commit ===
function Invoke-SmartCommit {
    <#
    .SYNOPSIS
        Interactive AI-assisted commit workflow
    #>
    [CmdletBinding()]
    param()

    # Check for staged changes
    $staged = git diff --cached --name-only 2>$null
    if (-not $staged) {
        Write-Host "No staged changes. Stage files first with 'git add'" -ForegroundColor Yellow

        # Show unstaged changes
        $unstaged = git diff --name-only 2>$null
        if ($unstaged) {
            Write-Host "`nUnstaged changes:" -ForegroundColor Cyan
            $unstaged | ForEach-Object { Write-Host "  $_" -ForegroundColor Gray }
            Write-Host "`nStage all? (y/n): " -NoNewline -ForegroundColor Yellow
            $answer = Read-Host
            if ($answer -eq 'y') {
                git add -A
                Write-Host "✓ All files staged" -ForegroundColor Green
            } else {
                return
            }
        } else {
            return
        }
    }

    # Generate message
    $result = New-AICommitMessage -Style conventional

    if ($result) {
        Write-Host "`nCommit with this message? (y/n/e=edit): " -NoNewline -ForegroundColor Yellow
        $answer = Read-Host

        switch ($answer.ToLower()) {
            'y' {
                git commit -m $result.Message
                Write-Host "✓ Committed!" -ForegroundColor Green
            }
            'e' {
                Write-Host "Enter your message: " -ForegroundColor Yellow
                $customMsg = Read-Host
                if ($customMsg) {
                    git commit -m $customMsg
                    Write-Host "✓ Committed!" -ForegroundColor Green
                }
            }
            default {
                Write-Host "Commit cancelled." -ForegroundColor Yellow
            }
        }
    }
}

# === Amend with AI ===
function Update-LastCommitMessage {
    <#
    .SYNOPSIS
        Regenerate message for last commit (amend)
    #>
    [CmdletBinding()]
    param(
        [switch]$Force
    )

    $lastMsg = git log -1 --pretty=%B 2>$null
    Write-Host "Current message: $lastMsg" -ForegroundColor DarkGray

    # Get diff of last commit
    $diff = git diff HEAD~1 2>$null

    if (-not $Force) {
        Write-Host "`nRegenerate message? (y/n): " -NoNewline -ForegroundColor Yellow
        if ((Read-Host) -ne 'y') { return }
    }

    $result = New-AICommitMessage -DryRun
    if ($result) {
        Write-Host "`nAmend with new message? (y/n): " -NoNewline -ForegroundColor Yellow
        if ((Read-Host) -eq 'y') {
            git commit --amend -m $result.Message
            Write-Host "✓ Amended!" -ForegroundColor Green
        }
    }
}

# === Export ===
Export-ModuleMember -Function @(
    'Get-ProjectContext',
    'Get-DiffAnalysis',
    'New-AICommitMessage',
    'Invoke-SmartCommit',
    'Update-LastCommitMessage'
)

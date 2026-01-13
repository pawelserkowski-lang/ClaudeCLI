#Requires -Version 5.1
<#
.SYNOPSIS
    HYDRA Prompt Optimizer - Automatic prompt enhancement before AI calls
.DESCRIPTION
    Analyzes and improves prompts for better AI responses.
    Uses AIUtil-Validation for category detection, clarity scoring, and language detection.
.VERSION
    1.1.0
#>

# Import validation utilities
$utilPath = Join-Path (Split-Path $PSScriptRoot -Parent) 'utils\AIUtil-Validation.psm1'
if (Test-Path $utilPath) {
    Import-Module $utilPath -Force -ErrorAction SilentlyContinue
} else {
    Write-Warning "AIUtil-Validation.psm1 not found at: $utilPath"
}

$script:PromptPatterns = @{
    # === CODING ===
    code = @{
        keywords = @('write', 'implement', 'create function', 'code', 'script', 'program', 'class', 'method')
        enhancers = @(
            'Provide clean, well-documented code.',
            'Include error handling where appropriate.',
            'Follow best practices for the language.'
        )
        priority = 10
    }
    debug = @{
        keywords = @('debug', 'fix bug', 'error', 'exception', 'crash', 'not working', 'broken', 'fails')
        enhancers = @(
            'Identify the root cause of the issue.',
            'Explain why the error occurs.',
            'Provide a working solution with explanation.'
        )
        priority = 15
    }
    refactor = @{
        keywords = @('refactor', 'improve code', 'optimize code', 'clean up', 'restructure', 'simplify')
        enhancers = @(
            'Maintain existing functionality.',
            'Improve readability and maintainability.',
            'Explain the changes and their benefits.'
        )
        priority = 12
    }
    test = @{
        keywords = @('test', 'unit test', 'testing', 'spec', 'jest', 'pytest', 'mock', 'coverage')
        enhancers = @(
            'Cover edge cases and error scenarios.',
            'Use descriptive test names.',
            'Include setup and teardown if needed.'
        )
        priority = 11
    }
    review = @{
        keywords = @('review', 'code review', 'check code', 'audit', 'inspect', 'evaluate code')
        enhancers = @(
            'Check for bugs, security issues, and best practices.',
            'Suggest specific improvements.',
            'Rate the code quality.'
        )
        priority = 11
    }

    # === ANALYSIS ===
    analysis = @{
        keywords = @('analyze', 'compare', 'evaluate', 'assess', 'examine', 'investigate')
        enhancers = @(
            'Provide a structured analysis.',
            'Consider multiple perspectives.',
            'Support conclusions with reasoning.'
        )
        priority = 8
    }
    explain = @{
        keywords = @('explain', 'how does', 'what does', 'describe', 'clarify', 'elaborate')
        enhancers = @(
            'Start with a simple overview.',
            'Use analogies if helpful.',
            'Progress from basic to advanced concepts.'
        )
        priority = 9
    }
    research = @{
        keywords = @('research', 'find out', 'look up', 'search', 'discover', 'learn about')
        enhancers = @(
            'Provide accurate, verified information.',
            'Cite sources or explain reasoning.',
            'Cover the topic comprehensively.'
        )
        priority = 7
    }

    # === DATA ===
    data = @{
        keywords = @('data', 'dataset', 'csv', 'json', 'parse', 'extract', 'transform', 'process data')
        enhancers = @(
            'Handle edge cases and malformed data.',
            'Optimize for performance with large datasets.',
            'Validate data integrity.'
        )
        priority = 10
    }
    database = @{
        keywords = @('sql', 'query', 'database', 'table', 'select', 'insert', 'update', 'join', 'index')
        enhancers = @(
            'Write efficient, optimized queries.',
            'Consider indexing and performance.',
            'Handle NULL values appropriately.'
        )
        priority = 12
    }
    api = @{
        keywords = @('api', 'endpoint', 'rest', 'graphql', 'request', 'response', 'http', 'fetch', 'axios')
        enhancers = @(
            'Include proper error handling.',
            'Follow RESTful conventions.',
            'Document request/response formats.'
        )
        priority = 11
    }

    # === SECURITY ===
    security = @{
        keywords = @('security', 'secure', 'vulnerability', 'exploit', 'attack', 'protect', 'encrypt', 'auth')
        enhancers = @(
            'Follow security best practices.',
            'Identify potential vulnerabilities.',
            'Recommend mitigation strategies.'
        )
        priority = 14
    }

    # === OPTIMIZATION ===
    optimize = @{
        keywords = @('optimize', 'performance', 'speed up', 'faster', 'efficient', 'reduce', 'improve performance')
        enhancers = @(
            'Identify bottlenecks first.',
            'Measure before and after.',
            'Consider trade-offs (memory vs speed).'
        )
        priority = 11
    }

    # === CONVERSION ===
    convert = @{
        keywords = @('convert', 'transform', 'migrate', 'translate code', 'port', 'change format')
        enhancers = @(
            'Preserve original functionality.',
            'Handle edge cases in conversion.',
            'Validate output matches input semantics.'
        )
        priority = 10
    }
    translate = @{
        keywords = @('translate', 'translation', 'language', 'localize', 'i18n')
        enhancers = @(
            'Maintain original meaning and tone.',
            'Consider cultural context.',
            'Preserve formatting and structure.'
        )
        priority = 9
    }

    # === DOCUMENTATION ===
    docs = @{
        keywords = @('document', 'documentation', 'readme', 'comment', 'jsdoc', 'docstring', 'wiki')
        enhancers = @(
            'Be clear and concise.',
            'Include usage examples.',
            'Cover all public interfaces.'
        )
        priority = 8
    }

    # === DESIGN ===
    design = @{
        keywords = @('design', 'architecture', 'structure', 'pattern', 'schema', 'plan', 'diagram')
        enhancers = @(
            'Consider scalability and maintainability.',
            'Follow established design patterns.',
            'Document trade-offs and decisions.'
        )
        priority = 9
    }
    ui = @{
        keywords = @('ui', 'ux', 'interface', 'frontend', 'component', 'layout', 'style', 'css')
        enhancers = @(
            'Follow accessibility guidelines.',
            'Consider responsive design.',
            'Maintain consistent styling.'
        )
        priority = 10
    }

    # === DEVOPS ===
    devops = @{
        keywords = @('deploy', 'docker', 'kubernetes', 'ci/cd', 'pipeline', 'aws', 'azure', 'cloud', 'terraform')
        enhancers = @(
            'Follow infrastructure as code principles.',
            'Include rollback strategies.',
            'Consider security and access controls.'
        )
        priority = 10
    }
    config = @{
        keywords = @('config', 'configuration', 'setup', 'install', 'environment', 'settings', 'env')
        enhancers = @(
            'Provide step-by-step instructions.',
            'Include troubleshooting tips.',
            'Document all required variables.'
        )
        priority = 8
    }

    # === GENERAL ===
    question = @{
        keywords = @('what is', 'why', 'when', 'where', 'who', 'which', '?')
        enhancers = @(
            'Be concise but thorough.',
            'Provide examples if helpful.'
        )
        priority = 5
    }
    creative = @{
        keywords = @('write story', 'generate', 'brainstorm', 'imagine', 'creative', 'ideas', 'invent')
        enhancers = @(
            'Be creative and original.',
            'Explore unique angles.',
            'Think outside the box.'
        )
        priority = 7
    }
    task = @{
        keywords = @('do', 'execute', 'run', 'perform', 'make', 'build', 'create')
        enhancers = @(
            'Provide step-by-step instructions.',
            'Include verification steps.'
        )
        priority = 4
    }
    summary = @{
        keywords = @('summarize', 'summary', 'brief', 'tldr', 'overview', 'recap', 'condense')
        enhancers = @(
            'Be concise - focus on key points.',
            'Use bullet points for clarity.',
            'Highlight most important information.'
        )
        priority = 6
    }
    list = @{
        keywords = @('list', 'enumerate', 'show all', 'give me', 'what are', 'examples of')
        enhancers = @(
            'Organize items logically.',
            'Include brief descriptions.',
            'Prioritize most relevant items.'
        )
        priority = 5
    }
}

$script:ModelOptimizations = @{
    'llama3.2:1b' = @{ maxTokens = 512; style = 'concise'; prefix = '' }
    'llama3.2:3b' = @{ maxTokens = 2048; style = 'balanced'; prefix = '' }
    'qwen2.5-coder' = @{ maxTokens = 4096; style = 'technical'; prefix = 'You are an expert programmer. ' }
    'phi3:mini' = @{ maxTokens = 2048; style = 'balanced'; prefix = '' }
    'claude' = @{ maxTokens = 8192; style = 'detailed'; prefix = '' }
    'gpt-4o' = @{ maxTokens = 8192; style = 'detailed'; prefix = '' }
}

# Get-PromptCategory is now provided by AIUtil-Validation.psm1
# The function categorizes prompts by intent (code, analysis, creative, task, question, summary, general)

# Get-PromptClarity is now provided by AIUtil-Validation.psm1
# The function scores prompt clarity from 0-100 with optional detailed breakdown

# Helper function to get clarity with legacy format compatibility
function Get-PromptClarityLegacy {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Prompt)

    # Use the utility function with detailed output
    $result = Get-PromptClarity -Prompt $Prompt -Detailed

    # Convert to legacy format expected by Optimize-Prompt
    $quality = switch ($result.Score) {
        { $_ -ge 80 } { 'Good' }
        { $_ -ge 60 } { 'Fair' }
        { $_ -ge 40 } { 'Needs improvement' }
        default { 'Poor' }
    }

    return @{
        Score = $result.Score
        Issues = $result.Issues
        Suggestions = $result.Suggestions
        Quality = $quality
    }
}

# Get-PromptLanguage - wrapper around Get-CodeLanguage from AIUtil-Validation
# Detects programming language from prompt text
function Get-PromptLanguage {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Prompt)

    # Use the utility function for language detection
    $detected = Get-CodeLanguage -Code $Prompt

    # Return null if 'text' (unknown), otherwise return the language
    if ($detected -eq 'text') {
        return $null
    }
    return $detected
}

function Optimize-Prompt {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Prompt,
        [string]$Model = 'llama3.2:3b',
        [ValidateSet(
            'code', 'debug', 'refactor', 'test', 'review',
            'analysis', 'explain', 'research',
            'data', 'database', 'api',
            'security', 'optimize',
            'convert', 'translate',
            'docs', 'design', 'ui',
            'devops', 'config',
            'question', 'creative', 'task', 'summary', 'list',
            'general', 'auto'
        )]
        [string]$Category = 'auto',
        [switch]$AddExamples,
        [switch]$Detailed
    )

    if ($Category -eq 'auto') {
        # Use utility function for category detection
        $Category = Get-PromptCategory -Prompt $Prompt
    }

    # Use legacy helper for clarity (maintains backwards compatibility)
    $clarity = Get-PromptClarityLegacy -Prompt $Prompt
    # Use wrapper for language detection (uses Get-CodeLanguage internally)
    $language = Get-PromptLanguage -Prompt $Prompt

    $enhanced = $Prompt
    $enhancements = @()

    # Model prefix
    $modelKey = $script:ModelOptimizations.Keys | Where-Object { $Model -like "*$_*" } | Select-Object -First 1
    if ($modelKey -and $script:ModelOptimizations[$modelKey].prefix) {
        $enhanced = $script:ModelOptimizations[$modelKey].prefix + $enhanced
        $enhancements += 'Added model-specific prefix'
    }

    # Category enhancements
    if ($Category -ne 'general' -and $script:PromptPatterns.ContainsKey($Category)) {
        $categoryEnhancers = $script:PromptPatterns[$Category].enhancers
        if ($categoryEnhancers.Count -gt 0) {
            $enhancerText = $categoryEnhancers -join ' '
            $enhanced = "$enhanced`n`n$enhancerText"
            $enhancements += "Added $Category-specific instructions"
        }
    }

    # Language tag for code
    if ($Category -eq 'code' -and $language) {
        if ($enhanced -notmatch "\b$language\b") {
            $enhanced = "[$language] " + $enhanced
            $enhancements += "Added language tag: $language"
        }
    }

    # Structure wrapper for low clarity
    if ($clarity.Score -lt 60) {
        $enhanced = "Task: $enhanced`n`nPlease provide a clear, well-structured response."
        $enhancements += 'Added structure wrapper'
    }

    $result = @{
        OriginalPrompt = $Prompt
        OptimizedPrompt = $enhanced.Trim()
        Category = $Category
        Language = $language
        ClarityScore = $clarity.Score
        Enhancements = $enhancements
        WasEnhanced = $enhancements.Count -gt 0
    }

    if ($Detailed) {
        $result.ClarityAnalysis = $clarity
    }

    return $result
}

function Get-BetterPrompt {
    [CmdletBinding()]
    param([Parameter(Mandatory, ValueFromPipeline)][string]$Prompt)
    $result = Optimize-Prompt -Prompt $Prompt
    return $result.OptimizedPrompt
}

function Test-PromptQuality {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Prompt)

    # Use legacy helper for clarity (maintains hashtable format with Quality field)
    $clarity = Get-PromptClarityLegacy -Prompt $Prompt
    # Use utility function for category detection
    $category = Get-PromptCategory -Prompt $Prompt
    # Use wrapper for language detection
    $language = Get-PromptLanguage -Prompt $Prompt

    Write-Host "`n[Prompt Quality Report]" -ForegroundColor Cyan
    Write-Host '------------------------' -ForegroundColor DarkGray
    Write-Host 'Score: ' -NoNewline
    $color = if ($clarity.Score -ge 80) { 'Green' } elseif ($clarity.Score -ge 60) { 'Yellow' } else { 'Red' }
    Write-Host "$($clarity.Score)/100 ($($clarity.Quality))" -ForegroundColor $color
    Write-Host "Category: $category" -ForegroundColor Gray
    if ($language) { Write-Host "Language: $language" -ForegroundColor Gray }

    if ($clarity.Issues.Count -gt 0) {
        Write-Host "`nIssues:" -ForegroundColor Yellow
        $clarity.Issues | ForEach-Object { Write-Host "  - $_" -ForegroundColor Yellow }
    }

    if ($clarity.Suggestions.Count -gt 0) {
        Write-Host "`nSuggestions:" -ForegroundColor Cyan
        $clarity.Suggestions | ForEach-Object { Write-Host "  > $_" -ForegroundColor Cyan }
    }

    return $clarity
}

# Note: Get-PromptCategory, Get-PromptClarity, Get-CodeLanguage are now provided by AIUtil-Validation.psm1
# This module exports optimization functions that build on those utilities
Export-ModuleMember -Function @(
    'Get-PromptLanguage',      # Wrapper for Get-CodeLanguage (returns null instead of 'text')
    'Optimize-Prompt',          # Main prompt optimization function
    'Get-BetterPrompt',         # Quick one-liner enhancement
    'Test-PromptQuality'        # Visual quality report
)

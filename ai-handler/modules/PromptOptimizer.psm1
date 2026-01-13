#Requires -Version 5.1
<#
.SYNOPSIS
    HYDRA Prompt Optimizer - Automatic prompt enhancement before AI calls
.DESCRIPTION
    Analyzes and improves prompts for better AI responses
.VERSION
    1.0.0
#>

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

function Get-PromptCategory {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Prompt)

    $promptLower = $Prompt.ToLower()
    $candidates = @()

    foreach ($category in $script:PromptPatterns.Keys) {
        $matchCount = 0
        foreach ($keyword in $script:PromptPatterns[$category].keywords) {
            if ($promptLower -match [regex]::Escape($keyword)) {
                $matchCount++
            }
        }
        if ($matchCount -gt 0) {
            $priority = if ($script:PromptPatterns[$category].priority) { $script:PromptPatterns[$category].priority } else { 5 }
            $candidates += @{
                Category = $category
                Matches = $matchCount
                Priority = $priority
                Score = ($matchCount * 10) + $priority
            }
        }
    }

    if ($candidates.Count -eq 0) { return 'general' }

    # Sort by: matches first, then priority
    $best = $candidates | Sort-Object { $_.Score } -Descending | Select-Object -First 1
    return $best.Category
}

function Get-PromptClarity {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Prompt)

    $score = 100
    $issues = @()
    $suggestions = @()

    if ($Prompt.Length -lt 10) {
        $score -= 30
        $issues += 'Too short'
        $suggestions += 'Add more context or details'
    } elseif ($Prompt.Length -lt 30) {
        $score -= 15
        $issues += 'Brief prompt'
        $suggestions += 'Consider adding specifics'
    }

    $vagueWords = @('something', 'stuff', 'thing', 'it', 'this', 'that', 'etc', 'whatever')
    foreach ($word in $vagueWords) {
        if ($Prompt -match "\b$word\b") {
            $score -= 5
            $issues += "Vague term: '$word'"
        }
    }

    $specificIndicators = @('specifically', 'exactly', 'must', 'should', 'using', 'with', 'in')
    foreach ($indicator in $specificIndicators) {
        if ($Prompt -match "\b$indicator\b") {
            $score += 3
        }
    }

    if ($Prompt -notmatch '(for|to|because|since|using|with|in)\s+\w+') {
        $score -= 10
        $suggestions += 'Add context (for what purpose, using what)'
    }

    if ($Prompt -notmatch '(format|output|return|show|display|as|like)') {
        $suggestions += 'Consider specifying desired output format'
    }

    $score = [Math]::Max(0, [Math]::Min(100, $score))

    return @{
        Score = $score
        Issues = $issues
        Suggestions = $suggestions
        Quality = switch ($score) {
            { $_ -ge 80 } { 'Good' }
            { $_ -ge 60 } { 'Fair' }
            { $_ -ge 40 } { 'Needs improvement' }
            default { 'Poor' }
        }
    }
}

function Get-PromptLanguage {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Prompt)

    $languages = @{
        'python' = @('python', 'py', 'pip', 'pandas', 'numpy', 'django', 'flask')
        'javascript' = @('javascript', 'js', 'node', 'npm', 'react', 'vue', 'angular')
        'typescript' = @('typescript', 'ts', 'tsx')
        'powershell' = @('powershell', 'ps1', 'pwsh', 'cmdlet')
        'rust' = @('rust', 'cargo', 'rustc')
        'go' = @('golang', 'go ')
        'csharp' = @('c#', 'csharp', 'dotnet', '.net')
        'java' = @('java ', 'jvm', 'maven', 'gradle')
        'sql' = @('sql', 'query', 'select', 'database', 'mysql', 'postgres')
        'bash' = @('bash', 'shell', 'sh ', 'linux')
    }

    $promptLower = $Prompt.ToLower()
    foreach ($lang in $languages.Keys) {
        foreach ($keyword in $languages[$lang]) {
            if ($promptLower -match "\b$([regex]::Escape($keyword))\b") {
                return $lang
            }
        }
    }
    return $null
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
        $Category = Get-PromptCategory -Prompt $Prompt
    }

    $clarity = Get-PromptClarity -Prompt $Prompt
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

    $clarity = Get-PromptClarity -Prompt $Prompt
    $category = Get-PromptCategory -Prompt $Prompt
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

Export-ModuleMember -Function @(
    'Get-PromptCategory',
    'Get-PromptClarity',
    'Get-PromptLanguage',
    'Optimize-Prompt',
    'Get-BetterPrompt',
    'Test-PromptQuality'
)

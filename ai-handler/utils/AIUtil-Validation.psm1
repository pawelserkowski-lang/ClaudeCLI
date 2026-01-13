#Requires -Version 5.1
<#
.SYNOPSIS
    AI Utility Module for Prompt and Code Validation

.DESCRIPTION
    Provides unified validation functions for prompts and code detection,
    eliminating duplicate implementations across AI Handler modules.

.NOTES
    Module: AIUtil-Validation
    Version: 1.0.0
    Author: HYDRA System
    Created: 2026-01-13
#>

#region Pattern Dictionaries

# Prompt category patterns - ordered by specificity
$script:CategoryPatterns = @{
    code = @(
        '(?i)\b(write|create|implement|build|generate|code|function|class|method|script)\b'
        '(?i)\b(fix|debug|refactor|optimize|convert)\b.*\b(code|function|script|program)\b'
        '(?i)\b(python|javascript|typescript|powershell|rust|go|sql|csharp|java)\b.*\b(code|function|script)\b'
        '(?i)^(def|function|class|const|let|var|public|private)\s'
    )
    analysis = @(
        '(?i)\b(analyze|analyse|compare|contrast|evaluate|assess|review)\b'
        '(?i)\b(explain|describe|elaborate|break\s*down)\b.*\b(how|why|what)\b'
        '(?i)\b(pros?\s*(and|&)?\s*cons?|advantages?\s*(and|&)?\s*disadvantages?)\b'
        '(?i)\b(difference|similarities?)\s*(between|of)\b'
    )
    creative = @(
        '(?i)\b(brainstorm|imagine|creative|ideas?|suggest|propose)\b'
        '(?i)\b(story|narrative|poem|lyrics|slogan|tagline)\b'
        '(?i)\b(design|concept|vision|innovative)\b'
    )
    task = @(
        '(?i)^(do|execute|run|perform|setup|configure|install)\b'
        '(?i)\b(step[\s-]?by[\s-]?step|instructions?|guide|tutorial)\b'
        '(?i)\b(how\s+to|show\s+me\s+how)\b'
    )
    question = @(
        '(?i)^(what|who|where|when|why|how|which|is|are|can|could|would|should|does|do)\b'
        '(?i)\?$'
        '(?i)\b(tell\s+me|explain|define)\b'
    )
    summary = @(
        '(?i)\b(summarize|summarise|summary|tldr|tl;dr|brief|overview)\b'
        '(?i)\b(key\s+points?|main\s+(points?|ideas?))\b'
        '(?i)\b(in\s+short|briefly|concisely)\b'
    )
}

# Vague terms that reduce clarity score
$script:VagueTerms = @(
    'something'
    'stuff'
    'things?'
    'it'
    'that'
    'this'
    'etc\.?'
    'whatever'
    'somehow'
    'somewhat'
    'kind\s*of'
    'sort\s*of'
    'maybe'
    'probably'
    'might'
    'some'
    'any'
    'good'
    'bad'
    'nice'
    'cool'
    'awesome'
    'great'
)

# Specificity indicators that increase clarity score
$script:SpecificityIndicators = @(
    '\b\d+\b'                          # Numbers
    '\b[A-Z][a-z]+[A-Z]\w*\b'          # CamelCase identifiers
    '\b[a-z]+_[a-z]+\b'                # snake_case identifiers
    '\.(py|js|ts|ps1|rs|go|sql|cs|java|html|css)\b'  # File extensions
    '\b(function|class|method|variable|parameter|argument)\b'
    '\b(input|output|return|result)\b'
    '\b(api|endpoint|url|path|route)\b'
    '\b(database|table|column|query)\b'
    '"[^"]+"|''[^'']+'                 # Quoted strings
    '\b(must|shall|should|will|need)\b'
)

# Language detection patterns - ordered by uniqueness
$script:LanguagePatterns = @{
    powershell = @(
        '^\s*#Requires\s+-'
        '\$\w+\s*='
        '\b(Get|Set|New|Remove|Test|Invoke)-\w+'
        '\bparam\s*\('
        '\[Parameter\('
        '\bfunction\s+\w+-\w+'
        '\bWrite-(Host|Output|Error|Warning|Verbose)\b'
        '\bImport-Module\b'
        '\|\s*(ForEach|Where|Select|Sort)-Object\b'
        '\bbegin\s*\{|\bprocess\s*\{|\bend\s*\{'
    )
    python = @(
        '^\s*def\s+\w+\s*\('
        '^\s*class\s+\w+.*:'
        '^\s*import\s+\w+'
        '^\s*from\s+\w+\s+import\b'
        '\bself\.\w+'
        '^\s*if\s+__name__\s*==\s*[''"]__main__[''"]:'
        '\bprint\s*\('
        ':\s*$'
        '\b(True|False|None)\b'
        '\b(elif|except|finally|lambda|yield|async|await)\b'
        '\bdef\s+\w+\s*\([^)]*\)\s*->'
    )
    javascript = @(
        '\bfunction\s+\w+\s*\('
        '\bconst\s+\w+\s*='
        '\blet\s+\w+\s*='
        '\bvar\s+\w+\s*='
        '=>\s*[{(]?'
        '\bconsole\.(log|error|warn)\s*\('
        '\brequire\s*\([''"]'
        '\bmodule\.exports\b'
        '\basync\s+function\b'
        '\bawait\s+'
        '\bnew\s+Promise\s*\('
        '\.then\s*\('
        '\.catch\s*\('
    )
    typescript = @(
        '\binterface\s+\w+'
        '\btype\s+\w+\s*='
        ':\s*(string|number|boolean|any|void|never|unknown)\b'
        '\b(public|private|protected)\s+\w+:'
        '<\w+(\s*,\s*\w+)*>'
        '\bas\s+(string|number|boolean|any)\b'
        '\bimport\s+.*\s+from\s+[''"]'
        '\bexport\s+(interface|type|class|function|const)\b'
        '\benum\s+\w+\s*\{'
        '\bimplements\s+\w+'
    )
    rust = @(
        '\bfn\s+\w+\s*\('
        '\blet\s+mut\s+\w+'
        '\bimpl\s+\w+'
        '\bstruct\s+\w+'
        '\benum\s+\w+'
        '\bpub\s+(fn|struct|enum|mod)\b'
        '\buse\s+\w+::'
        '\bmatch\s+\w+\s*\{'
        '&str\b|&\[|&mut\b'
        '\bResult<|Option<|Vec<'
        '\bunwrap\(\)|expect\([''"]'
        '^\s*#\[derive\('
    )
    go = @(
        '\bpackage\s+\w+'
        '\bfunc\s+\w+\s*\('
        '\bfunc\s+\(\w+\s+\*?\w+\)\s+\w+'
        '\bimport\s+\('
        '\btype\s+\w+\s+struct\s*\{'
        '\btype\s+\w+\s+interface\s*\{'
        '\bgo\s+func\s*\('
        '\bchan\s+\w+'
        '\bdefer\s+'
        '\b:=\b'
        '\bfmt\.(Print|Sprintf|Errorf)\b'
        '\berr\s*!=\s*nil\b'
    )
    sql = @(
        '(?i)\bSELECT\s+.+\s+FROM\b'
        '(?i)\bINSERT\s+INTO\b'
        '(?i)\bUPDATE\s+\w+\s+SET\b'
        '(?i)\bDELETE\s+FROM\b'
        '(?i)\bCREATE\s+(TABLE|INDEX|VIEW|DATABASE)\b'
        '(?i)\bALTER\s+TABLE\b'
        '(?i)\bDROP\s+(TABLE|INDEX|VIEW)\b'
        '(?i)\bJOIN\s+\w+\s+ON\b'
        '(?i)\bWHERE\s+\w+\s*(=|<|>|LIKE|IN)\b'
        '(?i)\bGROUP\s+BY\b'
        '(?i)\bORDER\s+BY\b'
        '(?i)\bHAVING\b'
    )
    csharp = @(
        '\bnamespace\s+\w+'
        '\bclass\s+\w+\s*:'
        '\bpublic\s+(class|interface|struct|enum)\b'
        '\bprivate\s+(readonly\s+)?\w+\s+\w+'
        '\busing\s+System(\.\w+)*;'
        '\bvar\s+\w+\s*='
        '\basync\s+Task'
        '\bawait\s+\w+'
        '\bnew\s+\w+\s*\('
        '\bLINQ\b|\bIEnumerable<'
        '\b(get|set)\s*[{;]'
        '\[Attribute\]|\[\w+\('
    )
    java = @(
        '\bpublic\s+class\s+\w+'
        '\bprivate\s+\w+\s+\w+;'
        '\bimport\s+java\.'
        '\bpackage\s+\w+(\.\w+)*;'
        '\bpublic\s+static\s+void\s+main\s*\('
        '\bSystem\.out\.print'
        '\bextends\s+\w+'
        '\bimplements\s+\w+'
        '\b@Override\b'
        '\bnew\s+\w+<'
        '\bthrows\s+\w+Exception'
        '\btry\s*\{|catch\s*\(\w+Exception'
    )
    html = @(
        '<!DOCTYPE\s+html>'
        '<html[\s>]'
        '<head[\s>]'
        '<body[\s>]'
        '<div[\s>]|</div>'
        '<span[\s>]|</span>'
        '<p[\s>]|</p>'
        '<a\s+href='
        '<img\s+src='
        '<script[\s>]|</script>'
        '<style[\s>]|</style>'
        '<meta\s+'
        '<link\s+rel='
    )
    css = @(
        '^\s*\.\w+\s*\{'
        '^\s*#\w+\s*\{'
        '^\s*\w+\s*\{[^}]*\}'
        '\b(margin|padding|border|font|color|background):'
        '\b(display|position|width|height|flex|grid):'
        '@media\s*\('
        '@import\s+[''"]'
        '@keyframes\s+\w+'
        ':\s*(px|em|rem|%|vh|vw)\b'
        '\b(hover|active|focus|before|after)\b'
        ':root\s*\{'
        'var\(--\w+'
    )
}

#endregion

#region Functions

function Get-PromptCategory {
    <#
    .SYNOPSIS
        Categorizes a prompt by its intent.

    .DESCRIPTION
        Analyzes the prompt text using regex patterns to determine the most
        likely category of intent: code, analysis, creative, task, question,
        summary, or general.

    .PARAMETER Prompt
        The prompt text to categorize.

    .OUTPUTS
        [string] One of: code, analysis, creative, task, question, summary, general

    .EXAMPLE
        Get-PromptCategory -Prompt "Write a Python function to sort a list"
        # Returns: code

    .EXAMPLE
        Get-PromptCategory -Prompt "Compare REST and GraphQL APIs"
        # Returns: analysis

    .EXAMPLE
        "What is the capital of France?" | Get-PromptCategory
        # Returns: question
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory, ValueFromPipeline, Position = 0)]
        [AllowEmptyString()]
        [string]$Prompt
    )

    process {
        if ([string]::IsNullOrWhiteSpace($Prompt)) {
            return 'general'
        }

        $normalizedPrompt = $Prompt.Trim()

        # Track match scores for each category
        $scores = @{}

        foreach ($category in $script:CategoryPatterns.Keys) {
            $scores[$category] = 0
            foreach ($pattern in $script:CategoryPatterns[$category]) {
                if ($normalizedPrompt -match $pattern) {
                    $scores[$category]++
                }
            }
        }

        # Find category with highest score
        $maxScore = 0
        $bestCategory = 'general'

        foreach ($category in $scores.Keys) {
            if ($scores[$category] -gt $maxScore) {
                $maxScore = $scores[$category]
                $bestCategory = $category
            }
        }

        return $bestCategory
    }
}

function Get-PromptClarity {
    <#
    .SYNOPSIS
        Scores the clarity of a prompt from 0 to 100.

    .DESCRIPTION
        Evaluates prompt clarity based on multiple factors:
        - Length (too short or too long reduces score)
        - Presence of vague terms (reduces score)
        - Specificity indicators (increases score)
        - Structure and punctuation (affects score)

    .PARAMETER Prompt
        The prompt text to evaluate.

    .PARAMETER Detailed
        If specified, returns a detailed breakdown instead of just the score.

    .OUTPUTS
        [int] Score from 0-100, or [PSCustomObject] with detailed breakdown.

    .EXAMPLE
        Get-PromptClarity -Prompt "do something with the stuff"
        # Returns: 35

    .EXAMPLE
        Get-PromptClarity -Prompt "Write a Python function that sorts a list of integers in ascending order" -Detailed
        # Returns detailed breakdown with score, issues, and suggestions
    #>
    [CmdletBinding()]
    [OutputType([int], [PSCustomObject])]
    param(
        [Parameter(Mandatory, ValueFromPipeline, Position = 0)]
        [AllowEmptyString()]
        [string]$Prompt,

        [Parameter()]
        [switch]$Detailed
    )

    process {
        $issues = @()
        $suggestions = @()
        $score = 50  # Start at neutral

        if ([string]::IsNullOrWhiteSpace($Prompt)) {
            if ($Detailed) {
                return [PSCustomObject]@{
                    Score = 0
                    Issues = @('Empty prompt')
                    Suggestions = @('Provide a clear, specific prompt')
                    Breakdown = @{ Length = 0; Vagueness = 0; Specificity = 0 }
                }
            }
            return 0
        }

        $normalizedPrompt = $Prompt.Trim()
        $wordCount = ($normalizedPrompt -split '\s+').Count
        $charCount = $normalizedPrompt.Length

        # Length scoring
        $lengthScore = 0
        if ($charCount -lt 10) {
            $lengthScore = -20
            $issues += 'Prompt is too short'
            $suggestions += 'Add more detail about what you need'
        }
        elseif ($charCount -lt 30) {
            $lengthScore = -10
            $issues += 'Prompt could be more detailed'
        }
        elseif ($charCount -ge 30 -and $charCount -le 500) {
            $lengthScore = 15
        }
        elseif ($charCount -gt 500 -and $charCount -le 1000) {
            $lengthScore = 10
        }
        elseif ($charCount -gt 1000) {
            $lengthScore = 0
            $issues += 'Prompt is very long'
            $suggestions += 'Consider breaking into smaller, focused requests'
        }

        # Vagueness scoring
        $vagueCount = 0
        foreach ($term in $script:VagueTerms) {
            $matches = [regex]::Matches($normalizedPrompt, "\b$term\b", 'IgnoreCase')
            $vagueCount += $matches.Count
        }

        $vaguenessScore = 0
        if ($vagueCount -gt 0) {
            $vaguenessScore = -([Math]::Min($vagueCount * 5, 25))
            $issues += "Contains $vagueCount vague term(s)"
            $suggestions += 'Replace vague terms with specific details'
        }
        else {
            $vaguenessScore = 10
        }

        # Specificity scoring
        $specificCount = 0
        foreach ($pattern in $script:SpecificityIndicators) {
            $matches = [regex]::Matches($normalizedPrompt, $pattern, 'IgnoreCase')
            $specificCount += $matches.Count
        }

        $specificityScore = [Math]::Min($specificCount * 3, 25)
        if ($specificCount -eq 0) {
            $issues += 'Lacks specific details'
            $suggestions += 'Add specific names, values, or technical terms'
        }

        # Structure bonus
        $structureScore = 0
        if ($normalizedPrompt -match '[.!?]$') {
            $structureScore += 5  # Proper ending punctuation
        }
        if ($normalizedPrompt -match '\d') {
            $structureScore += 3  # Contains numbers (often specific)
        }
        if ($normalizedPrompt -match '"[^"]+"|''[^'']+') {
            $structureScore += 5  # Contains quoted terms
        }

        # Calculate final score
        $score = $score + $lengthScore + $vaguenessScore + $specificityScore + $structureScore
        $score = [Math]::Max(0, [Math]::Min(100, $score))

        if ($Detailed) {
            return [PSCustomObject]@{
                Score = $score
                Issues = $issues
                Suggestions = $suggestions
                Breakdown = @{
                    BaseScore = 50
                    LengthModifier = $lengthScore
                    VaguenessModifier = $vaguenessScore
                    SpecificityBonus = $specificityScore
                    StructureBonus = $structureScore
                    WordCount = $wordCount
                    CharCount = $charCount
                    VagueTermCount = $vagueCount
                    SpecificTermCount = $specificCount
                }
            }
        }

        return $score
    }
}

function Get-CodeLanguage {
    <#
    .SYNOPSIS
        Auto-detects the programming language of code.

    .DESCRIPTION
        Analyzes code using pattern matching to determine the most likely
        programming language. Supports: powershell, python, javascript,
        typescript, rust, go, sql, csharp, java, html, css.

    .PARAMETER Code
        The code text to analyze.

    .PARAMETER Detailed
        If specified, returns confidence scores for all detected languages.

    .OUTPUTS
        [string] Detected language name, or 'text' if unknown.
        [PSCustomObject] If Detailed, includes confidence breakdown.

    .EXAMPLE
        Get-CodeLanguage -Code "def hello(): print('world')"
        # Returns: python

    .EXAMPLE
        Get-CodeLanguage -Code '$x = Get-Process | Select-Object Name'
        # Returns: powershell

    .EXAMPLE
        @"
        function greet() {
            console.log('Hello');
        }
        "@ | Get-CodeLanguage -Detailed
        # Returns detailed breakdown with confidence scores
    #>
    [CmdletBinding()]
    [OutputType([string], [PSCustomObject])]
    param(
        [Parameter(Mandatory, ValueFromPipeline, Position = 0)]
        [AllowEmptyString()]
        [string]$Code,

        [Parameter()]
        [switch]$Detailed
    )

    process {
        if ([string]::IsNullOrWhiteSpace($Code)) {
            if ($Detailed) {
                return [PSCustomObject]@{
                    Language = 'text'
                    Confidence = 0
                    Scores = @{}
                }
            }
            return 'text'
        }

        # Track match scores for each language
        $scores = @{}

        foreach ($language in $script:LanguagePatterns.Keys) {
            $scores[$language] = 0
            foreach ($pattern in $script:LanguagePatterns[$language]) {
                try {
                    if ($Code -match $pattern) {
                        $scores[$language]++
                    }
                }
                catch {
                    # Skip invalid regex patterns silently
                }
            }
        }

        # Find language with highest score
        $maxScore = 0
        $detectedLanguage = 'text'

        foreach ($language in $scores.Keys) {
            if ($scores[$language] -gt $maxScore) {
                $maxScore = $scores[$language]
                $detectedLanguage = $language
            }
        }

        # Calculate confidence (based on match ratio)
        $patternCount = $script:LanguagePatterns[$detectedLanguage].Count
        $confidence = if ($patternCount -gt 0 -and $maxScore -gt 0) {
            [Math]::Min(100, [int](($maxScore / $patternCount) * 100 * 1.5))
        } else { 0 }

        if ($Detailed) {
            # Sort scores descending
            $sortedScores = @{}
            $scores.GetEnumerator() |
                Where-Object { $_.Value -gt 0 } |
                Sort-Object Value -Descending |
                ForEach-Object { $sortedScores[$_.Key] = $_.Value }

            return [PSCustomObject]@{
                Language = $detectedLanguage
                Confidence = $confidence
                Scores = $sortedScores
                MatchCount = $maxScore
                PatternCount = $patternCount
            }
        }

        return $detectedLanguage
    }
}

function Test-PromptValid {
    <#
    .SYNOPSIS
        Validates a prompt for basic requirements.

    .DESCRIPTION
        Performs basic validation checks on a prompt:
        - Not null or empty
        - Reasonable length (between min and max characters)
        - Contains meaningful content (not just whitespace/symbols)

    .PARAMETER Prompt
        The prompt text to validate.

    .PARAMETER MinLength
        Minimum required length in characters. Default: 3

    .PARAMETER MaxLength
        Maximum allowed length in characters. Default: 100000

    .PARAMETER Detailed
        If specified, returns validation details instead of boolean.

    .OUTPUTS
        [bool] True if valid, False otherwise.
        [PSCustomObject] If Detailed, includes validation breakdown.

    .EXAMPLE
        Test-PromptValid -Prompt "Hello world"
        # Returns: $true

    .EXAMPLE
        Test-PromptValid -Prompt ""
        # Returns: $false

    .EXAMPLE
        Test-PromptValid -Prompt "x" -Detailed
        # Returns object with IsValid=$false, Reason="Prompt too short"
    #>
    [CmdletBinding()]
    [OutputType([bool], [PSCustomObject])]
    param(
        [Parameter(Mandatory, ValueFromPipeline, Position = 0)]
        [AllowNull()]
        [AllowEmptyString()]
        [string]$Prompt,

        [Parameter()]
        [ValidateRange(1, 1000)]
        [int]$MinLength = 3,

        [Parameter()]
        [ValidateRange(100, 1000000)]
        [int]$MaxLength = 100000,

        [Parameter()]
        [switch]$Detailed
    )

    process {
        $isValid = $true
        $reason = $null
        $warnings = @()

        # Check null
        if ($null -eq $Prompt) {
            $isValid = $false
            $reason = 'Prompt is null'
        }
        # Check empty/whitespace
        elseif ([string]::IsNullOrWhiteSpace($Prompt)) {
            $isValid = $false
            $reason = 'Prompt is empty or whitespace only'
        }
        # Check minimum length
        elseif ($Prompt.Trim().Length -lt $MinLength) {
            $isValid = $false
            $reason = "Prompt too short (minimum $MinLength characters)"
        }
        # Check maximum length
        elseif ($Prompt.Length -gt $MaxLength) {
            $isValid = $false
            $reason = "Prompt too long (maximum $MaxLength characters)"
        }
        # Check for meaningful content (not just symbols)
        elseif ($Prompt.Trim() -match '^[\W\d_]+$') {
            $isValid = $false
            $reason = 'Prompt contains no meaningful text'
        }
        else {
            # Additional warnings (valid but could be improved)
            if ($Prompt.Trim().Length -lt 10) {
                $warnings += 'Prompt is very short, consider adding more detail'
            }
            if ($Prompt -match '^\s+|\s+$') {
                $warnings += 'Prompt has leading/trailing whitespace'
            }
            if ($Prompt -match '\s{3,}') {
                $warnings += 'Prompt contains excessive whitespace'
            }
        }

        if ($Detailed) {
            return [PSCustomObject]@{
                IsValid = $isValid
                Reason = $reason
                Warnings = $warnings
                Length = if ($Prompt) { $Prompt.Length } else { 0 }
                TrimmedLength = if ($Prompt) { $Prompt.Trim().Length } else { 0 }
                MinRequired = $MinLength
                MaxAllowed = $MaxLength
            }
        }

        return $isValid
    }
}

#endregion

#region Module Export

Export-ModuleMember -Function @(
    'Get-PromptCategory'
    'Get-PromptClarity'
    'Get-CodeLanguage'
    'Test-PromptValid'
)

#endregion

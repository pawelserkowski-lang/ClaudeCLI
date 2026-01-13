#Requires -Version 5.1
<#
.SYNOPSIS
    AI Utility Module - Code Validation Helpers
.DESCRIPTION
    Shared validation utilities for AI Handler modules including:
    - Language detection from code content
    - Language detection from file extensions
    - Code syntax patterns
.VERSION
    1.0.0
.AUTHOR
    HYDRA System
#>

#region Language Detection Patterns

# Patterns for detecting programming language from code content
$script:CodeLanguagePatterns = @{
    "powershell" = @('^\s*function\s+\w+', '\$\w+\s*=', '\|\s*ForEach-Object', 'Write-Host', 'param\s*\(', '\[CmdletBinding\(\)\]')
    "python" = @('^\s*def\s+\w+', '^\s*import\s+', '^\s*from\s+\w+\s+import', 'print\s*\(', '^\s*class\s+\w+:', '__init__')
    "javascript" = @('^\s*const\s+', '^\s*let\s+', '^\s*function\s+\w+\s*\(', '=>\s*\{', 'console\.log', '\.then\s*\(')
    "typescript" = @(':\s*(string|number|boolean|any)\b', '^\s*interface\s+', '^\s*type\s+\w+\s*=', '<\w+>')
    "rust" = @('^\s*fn\s+\w+', '^\s*let\s+mut\s+', '^\s*impl\s+', '^\s*struct\s+', '^\s*enum\s+', '&str', 'Vec<')
    "go" = @('^\s*func\s+', '^\s*package\s+', ':=', 'fmt\.Print')
    "sql" = @('^\s*SELECT\s+', '^\s*INSERT\s+', '^\s*UPDATE\s+', '^\s*CREATE\s+TABLE', '^\s*FROM\s+')
    "csharp" = @('^\s*using\s+System', '^\s*namespace\s+', '^\s*public\s+class', '^\s*private\s+', '^\s*void\s+', 'Console\.Write')
    "java" = @('^\s*public\s+class', '^\s*import\s+java\.', '^\s*private\s+', 'System\.out\.print', '^\s*package\s+\w+;')
    "html" = @('^\s*<!DOCTYPE', '<html', '<head>', '<body>', '<div', '<script', '<style')
    "css" = @('^\s*\.\w+\s*\{', '^\s*#\w+\s*\{', 'font-size:', 'background-color:', 'margin:', 'padding:')
}

# File extension to language mapping
$script:FileExtensionLanguages = @{
    ".py" = "python"
    ".pyw" = "python"
    ".js" = "javascript"
    ".jsx" = "javascript"
    ".mjs" = "javascript"
    ".ts" = "typescript"
    ".tsx" = "typescript"
    ".ps1" = "powershell"
    ".psm1" = "powershell"
    ".psd1" = "powershell"
    ".rs" = "rust"
    ".go" = "go"
    ".sql" = "sql"
    ".cs" = "csharp"
    ".java" = "java"
    ".html" = "html"
    ".htm" = "html"
    ".css" = "css"
    ".scss" = "css"
    ".sass" = "css"
    ".less" = "css"
    ".json" = "json"
    ".xml" = "xml"
    ".yaml" = "yaml"
    ".yml" = "yaml"
    ".md" = "markdown"
    ".sh" = "bash"
    ".bash" = "bash"
    ".zsh" = "bash"
    ".c" = "c"
    ".cpp" = "cpp"
    ".h" = "c"
    ".hpp" = "cpp"
    ".rb" = "ruby"
    ".php" = "php"
    ".swift" = "swift"
    ".kt" = "kotlin"
    ".kts" = "kotlin"
    ".scala" = "scala"
    ".r" = "r"
    ".R" = "r"
    ".lua" = "lua"
    ".pl" = "perl"
    ".pm" = "perl"
}

#endregion

#region Language Detection Functions

function Get-CodeLanguage {
    <#
    .SYNOPSIS
        Auto-detect programming language from code content
    .DESCRIPTION
        Analyzes code patterns to determine the programming language.
        Uses pattern matching against known language signatures.
    .PARAMETER Code
        The code content to analyze
    .RETURNS
        String representing the detected language (e.g., "python", "javascript")
        Returns "text" if no language is detected
    .EXAMPLE
        Get-CodeLanguage -Code "def hello(): print('world')"
        # Returns: "python"
    .EXAMPLE
        Get-CodeLanguage -Code "const x = () => console.log('hi')"
        # Returns: "javascript"
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [string]$Code
    )

    process {
        $scores = @{}
        foreach ($lang in $script:CodeLanguagePatterns.Keys) {
            $scores[$lang] = 0
            foreach ($pattern in $script:CodeLanguagePatterns[$lang]) {
                if ($Code -match $pattern) {
                    $scores[$lang]++
                }
            }
        }

        $detected = $scores.GetEnumerator() | Sort-Object Value -Descending | Select-Object -First 1

        if ($detected.Value -gt 0) {
            return $detected.Key
        }

        return "text"
    }
}

function Get-FileLanguage {
    <#
    .SYNOPSIS
        Detect programming language from file path (extension-based)
    .DESCRIPTION
        Determines the programming language based on file extension.
        More reliable than content-based detection for known file types.
    .PARAMETER FilePath
        Path to the file to analyze
    .RETURNS
        String representing the detected language
        Returns "unknown" if the extension is not recognized
    .EXAMPLE
        Get-FileLanguage -FilePath "C:\project\app.py"
        # Returns: "python"
    .EXAMPLE
        Get-FileLanguage -FilePath "script.ps1"
        # Returns: "powershell"
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [string]$FilePath
    )

    process {
        $ext = [System.IO.Path]::GetExtension($FilePath).ToLower()

        if ($script:FileExtensionLanguages.ContainsKey($ext)) {
            return $script:FileExtensionLanguages[$ext]
        }

        return "unknown"
    }
}

function Get-LanguageExtensions {
    <#
    .SYNOPSIS
        Get file extensions for a given programming language
    .PARAMETER Language
        The programming language name
    .RETURNS
        Array of file extensions for the language
    .EXAMPLE
        Get-LanguageExtensions -Language "python"
        # Returns: @(".py", ".pyw")
    #>
    [CmdletBinding()]
    [OutputType([string[]])]
    param(
        [Parameter(Mandatory)]
        [string]$Language
    )

    $extensions = @()
    foreach ($ext in $script:FileExtensionLanguages.Keys) {
        if ($script:FileExtensionLanguages[$ext] -eq $Language.ToLower()) {
            $extensions += $ext
        }
    }

    return $extensions
}

function Test-SupportedLanguage {
    <#
    .SYNOPSIS
        Check if a language is supported for analysis
    .PARAMETER Language
        The language name to check
    .RETURNS
        $true if the language has pattern definitions, $false otherwise
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory)]
        [string]$Language
    )

    return $script:CodeLanguagePatterns.ContainsKey($Language.ToLower())
}

function Get-SupportedLanguages {
    <#
    .SYNOPSIS
        Get list of all supported languages for pattern-based detection
    .RETURNS
        Array of supported language names
    #>
    [CmdletBinding()]
    [OutputType([string[]])]
    param()

    return @($script:CodeLanguagePatterns.Keys | Sort-Object)
}

#endregion

#region Exports

Export-ModuleMember -Function @(
    'Get-CodeLanguage',
    'Get-FileLanguage',
    'Get-LanguageExtensions',
    'Test-SupportedLanguage',
    'Get-SupportedLanguages'
)

#endregion

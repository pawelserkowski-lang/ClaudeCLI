# AI Handler Prompt Processor Hook
# Processes all user prompts through AI Handler pipeline
# Returns optimization metadata to Claude

param(
    [Parameter(ValueFromPipeline=$true)]
    [string]$InputJson
)

# Set encoding for proper output
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

# Parse input from Claude
try {
    $input = $InputJson | ConvertFrom-Json
    $userPrompt = $input.prompt
} catch {
    # If no JSON input, exit silently
    exit 0
}

# Skip processing for very short prompts or commands
if (-not $userPrompt -or $userPrompt.Length -lt 10 -or $userPrompt.StartsWith('/')) {
    exit 0
}

# Set encryption key
[Environment]::SetEnvironmentVariable('CLAUDECLI_ENCRYPTION_KEY', 'ClaudeCLI-2024', 'Process')

# Load AI Handler modules
$basePath = "C:\Users\BIURODOM\Desktop\ClaudeCLI\ai-handler"
try {
    Import-Module "$basePath\AIModelHandler.psm1" -Force -ErrorAction Stop 2>$null
    Import-Module "$basePath\modules\PromptOptimizer.psm1" -Force -ErrorAction SilentlyContinue 2>$null
} catch {
    exit 0
}

# Process prompt through AI Handler
try {
    # Get prompt analysis
    $category = Get-PromptCategory -Prompt $userPrompt -ErrorAction SilentlyContinue
    $clarity = Get-PromptClarity -Prompt $userPrompt -ErrorAction SilentlyContinue

    # Get system load for provider recommendation
    $cpu = (Get-CimInstance Win32_Processor -ErrorAction SilentlyContinue |
            Measure-Object -Property LoadPercentage -Average).Average
    $provider = if ($cpu -lt 70) { "ollama (local)" } elseif ($cpu -lt 90) { "hybrid" } else { "cloud" }

    # Build context hint for Claude
    $hint = @"

<ai-handler-context>
Prompt Analysis:
- Category: $category
- Clarity: $($clarity.Score)/100
- Recommended Provider: $provider
- CPU Load: $cpu%

AI Handler Ready:
- Use /ai for quick local queries (cost=$0)
- Use /ai-batch for parallel processing
- Models: llama3.2:3b (general), qwen2.5-coder:1.5b (code), phi3:mini (reasoning)
</ai-handler-context>
"@

    # Output hint for Claude to see
    Write-Output $hint

} catch {
    # Silent fail - don't interrupt user flow
    exit 0
}

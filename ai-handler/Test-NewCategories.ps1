#Requires -Version 5.1
Import-Module "$PSScriptRoot\modules\PromptOptimizer.psm1" -Force

$tests = @(
    'fix this bug in my code',
    'write unit tests for login',
    'optimize database query performance',
    'review my pull request',
    'explain async await in javascript',
    'convert json to csv format',
    'deploy to kubernetes cluster',
    'secure this api endpoint',
    'refactor this function for clarity',
    'create sql query to get active users',
    'design system architecture for microservices',
    'document this module with examples',
    'brainstorm ideas for new features',
    'summarize this article',
    'what is dependency injection',
    'translate this text to polish',
    'setup docker environment',
    'analyze performance metrics',
    'list all api endpoints',
    'create react component for dashboard'
)

Write-Host "`nNOWE KATEGORIE - TEST" -ForegroundColor Cyan
Write-Host ("=" * 60) -ForegroundColor DarkGray

foreach ($t in $tests) {
    $result = Optimize-Prompt -Prompt $t
    $cat = $result.Category.ToUpper().PadRight(12)
    $clarity = "$($result.ClarityScore)".PadLeft(3)
    Write-Host "[$cat] " -NoNewline -ForegroundColor Yellow
    Write-Host "($clarity) " -NoNewline -ForegroundColor Gray
    Write-Host $t -ForegroundColor White
}

Write-Host "`n" + ("=" * 60) -ForegroundColor DarkGray
Write-Host "Lacznie kategorii: $($script:PromptPatterns.Keys.Count)" -ForegroundColor Green

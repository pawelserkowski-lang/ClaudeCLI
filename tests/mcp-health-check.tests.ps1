Describe "mcp-health-check.ps1" {
    It "defines the CLAUDECLI_ROOT override" {
        (Get-Content -LiteralPath "mcp-health-check.ps1" -Raw) | Should BeLike "*CLAUDECLI_ROOT*"
    }

    It "supports JSON export parameters" {
        $content = Get-Content -LiteralPath "mcp-health-check.ps1" -Raw
        $content | Should BeLike "*ExportJsonPath*"
        $content | Should BeLike "*ExportCsvPath*"
    }

    It "initializes AI Handler on startup" {
        (Get-Content -LiteralPath "mcp-health-check.ps1" -Raw) | Should BeLike "*Initialize-AIHandler.ps1*"
    }
}

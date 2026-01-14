# Wrapper to start Hydra Client

$ErrorActionPreference = "Stop"
$script:Root = $PSScriptRoot

$clientModule = Join-Path $script:Root "src\Hydra.Client\Hydra.Client.psd1"

if (Test-Path $clientModule) {
    Import-Module $clientModule -Force
    Start-HydraChat
} else {
    Write-Error "Hydra Client module not found at $clientModule"
    exit 1
}
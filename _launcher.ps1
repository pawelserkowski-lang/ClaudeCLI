Set-Location 'C:\Users\BIURODOM\Desktop\ClaudeCLI'
Write-Host 'Starting Claude CLI...' -ForegroundColor Cyan
Write-Host 'Working directory: ' -NoNewline; Write-Host (Get-Location) -ForegroundColor Gray
Write-Host ''
try { claude } catch { Write-Host ('ERROR: ' + $_) -ForegroundColor Red }
Write-Host ''
Write-Host 'Claude exited. Press any key to close...' -ForegroundColor Yellow
$null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
# Install Cascadia Code Nerd Font
$ProgressPreference = 'SilentlyContinue'
$url = 'https://github.com/ryanoasis/nerd-fonts/releases/download/v3.3.0/CascadiaCode.zip'
$zip = "$env:TEMP\CascadiaCode.zip"
$extract = "$env:TEMP\CascadiaCode"

Write-Host "Downloading Cascadia Code NF..." -ForegroundColor Cyan
Invoke-WebRequest -Uri $url -OutFile $zip -UseBasicParsing
Write-Host "Extracting..." -ForegroundColor Cyan
Expand-Archive -Path $zip -DestinationPath $extract -Force

Write-Host "Installing fonts..." -ForegroundColor Cyan
$fonts = Get-ChildItem -Path $extract -Filter "*.ttf" -Recurse

$shellApp = New-Object -ComObject Shell.Application
$fontsFolder = $shellApp.Namespace(0x14)

foreach ($font in $fonts) {
    Write-Host "  Installing: $($font.Name)" -ForegroundColor Gray
    $fontsFolder.CopyHere($font.FullName, 0x10)
}

Write-Host "Done! Installed $($fonts.Count) font files." -ForegroundColor Green
Write-Host "Restart Windows Terminal to use 'CaskaydiaCove Nerd Font'" -ForegroundColor Yellow

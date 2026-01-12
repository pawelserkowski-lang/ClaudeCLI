#Requires -Version 7.0
<#
.SYNOPSIS
    Parallel file downloader with multi-connection support
.DESCRIPTION
    Downloads files using multiple connections per file and parallel downloads
#>

param(
    [Parameter(Mandatory)]
    [string[]]$Urls,
    
    [Parameter(Mandatory = $false)]
    [string]$OutputDir = (Get-Location).Path,
    
    [int]$ConnectionsPerFile = 8,
    [int]$ParallelDownloads = 4
)

$CoreCount = [Environment]::ProcessorCount
Write-Host "⬇️  Parallel Downloader - $($Urls.Count) files" -ForegroundColor Cyan

# Check for aria2c (best) or fall back to native
$useAria2 = Get-Command aria2c -ErrorAction SilentlyContinue

if ($useAria2) {
    Write-Host "Using aria2c with $ConnectionsPerFile connections per file" -ForegroundColor Green
    
    # Create input file for aria2c
    $inputFile = Join-Path $env:TEMP "aria2_input_$(Get-Random).txt"
    $Urls | ForEach-Object { $_ } | Set-Content $inputFile
    
    aria2c -i $inputFile `
           -d $OutputDir `
           -x $ConnectionsPerFile `
           -s $ConnectionsPerFile `
           -j $ParallelDownloads `
           --file-allocation=none `
           --console-log-level=warn
    
    Remove-Item $inputFile -Force
}
else {
    Write-Host "Using PowerShell parallel (install aria2c for faster downloads)" -ForegroundColor Yellow
    
    $results = $Urls | ForEach-Object -Parallel {
        $url = $_
        $outDir = $using:OutputDir
        
        try {
            $fileName = [System.IO.Path]::GetFileName([System.Uri]::new($url).LocalPath)
            if ([string]::IsNullOrEmpty($fileName)) { $fileName = "download_$(Get-Random)" }
            $outPath = Join-Path $outDir $fileName
            
            $webClient = [System.Net.WebClient]::new()
            $webClient.DownloadFile($url, $outPath)
            
            @{
                Url = $url
                Path = $outPath
                Success = $true
                Size = (Get-Item $outPath).Length
            }
        }
        catch {
            @{
                Url = $url
                Success = $false
                Error = $_.Exception.Message
            }
        }
    } -ThrottleLimit $ParallelDownloads
    
    # Summary
    $succeeded = ($results | Where-Object { $_.Success }).Count
    $failed = ($results | Where-Object { -not $_.Success }).Count
    $totalSize = ($results | Where-Object { $_.Success } | Measure-Object -Property Size -Sum).Sum
    
    Write-Host "`n✅ Downloaded: $succeeded | ❌ Failed: $failed | 📦 Total: $([Math]::Round($totalSize / 1MB, 2)) MB" -ForegroundColor Cyan
}

#Requires -Version 7.0
<#
.SYNOPSIS
    Parallel compression using all CPU cores
.DESCRIPTION
    Compress multiple items in parallel using 7-Zip with multithreading
#>

param(
    [Parameter(Mandatory)]
    [string[]]$Paths,
    
    [Parameter(Mandatory = $false)]
    [string]$OutputDir = (Get-Location).Path,
    
    [ValidateSet('zip', '7z', 'tar', 'gzip')]
    [string]$Format = '7z',
    
    [ValidateSet('fast', 'normal', 'ultra')]
    [string]$Level = 'normal'
)

$CoreCount = [Environment]::ProcessorCount
Write-Host "📦 Parallel Compressor - $($Paths.Count) items" -ForegroundColor Cyan

# Find 7-Zip
$7zPath = @(
    "C:\Program Files\7-Zip\7z.exe",
    "C:\Program Files (x86)\7-Zip\7z.exe",
    (Get-Command 7z -ErrorAction SilentlyContinue).Source
) | Where-Object { $_ -and (Test-Path $_) } | Select-Object -First 1

if (-not $7zPath) {
    Write-Host "❌ 7-Zip not found! Install with: choco install 7zip" -ForegroundColor Red
    exit 1
}

$levelMap = @{
    fast = "-mx1"
    normal = "-mx5"
    ultra = "-mx9"
}

$formatMap = @{
    zip = @{ Ext = ".zip"; Flags = "-tzip" }
    '7z' = @{ Ext = ".7z"; Flags = "-t7z" }
    tar = @{ Ext = ".tar"; Flags = "-ttar" }
    gzip = @{ Ext = ".tar.gz"; Flags = "-tgzip" }
}

$startTime = Get-Date

$results = $Paths | ForEach-Object -Parallel {
    $path = $_
    $outDir = $using:OutputDir
    $7z = $using:7zPath
    $fmt = $using:formatMap[$using:Format]
    $lvl = $using:levelMap[$using:Level]
    $cores = $using:CoreCount
    
    try {
        $name = [System.IO.Path]::GetFileNameWithoutExtension($path)
        $outFile = Join-Path $outDir "$name$($fmt.Ext)"
        
        $sizeBefore = if (Test-Path $path -PathType Container) {
            (Get-ChildItem $path -Recurse -File | Measure-Object -Property Length -Sum).Sum
        } else {
            (Get-Item $path).Length
        }
        
        # Run 7z with multithreading
        $output = & $7z a $fmt.Flags $lvl "-mmt=$cores" $outFile $path 2>&1
        
        $sizeAfter = (Get-Item $outFile -ErrorAction SilentlyContinue).Length
        $ratio = if ($sizeBefore -gt 0) { [Math]::Round(($sizeAfter / $sizeBefore) * 100, 1) } else { 0 }
        
        @{
            Source = $path
            Output = $outFile
            SizeBefore = $sizeBefore
            SizeAfter = $sizeAfter
            Ratio = $ratio
            Success = $LASTEXITCODE -eq 0
        }
    }
    catch {
        @{
            Source = $path
            Success = $false
            Error = $_.Exception.Message
        }
    }
} -ThrottleLimit ([Math]::Max(2, $CoreCount / 2))  # Limit parallel compressions since each uses all cores

$endTime = Get-Date
$duration = ($endTime - $startTime).TotalSeconds

# Results
Write-Host "`n📊 Compression Results:" -ForegroundColor Cyan
Write-Host "─" * 70

$totalBefore = 0
$totalAfter = 0

foreach ($result in $results) {
    if ($result.Success) {
        $totalBefore += $result.SizeBefore
        $totalAfter += $result.SizeAfter
        
        Write-Host "✅ $($result.Source)" -ForegroundColor Green
        Write-Host "   → $($result.Output)" -ForegroundColor Gray
        Write-Host "   📉 $([Math]::Round($result.SizeBefore / 1MB, 2))MB → $([Math]::Round($result.SizeAfter / 1MB, 2))MB ($($result.Ratio)%)" -ForegroundColor Cyan
    }
    else {
        Write-Host "❌ $($result.Source): $($result.Error)" -ForegroundColor Red
    }
}

Write-Host "`n─" * 70
$totalRatio = if ($totalBefore -gt 0) { [Math]::Round(($totalAfter / $totalBefore) * 100, 1) } else { 0 }
Write-Host "⏱️  Duration: $([Math]::Round($duration, 2))s" -ForegroundColor Cyan
Write-Host "📊 Total: $([Math]::Round($totalBefore / 1MB, 2))MB → $([Math]::Round($totalAfter / 1MB, 2))MB ($totalRatio%)" -ForegroundColor Green

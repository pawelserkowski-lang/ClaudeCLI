#Requires -Version 5.1
<#
.SYNOPSIS
    Builds HYDRA 10.0 installers
.DESCRIPTION
    Compiles NSIS installer for Windows and packages Linux/macOS scripts
.PARAMETER SkipNSIS
    Skip NSIS compilation (for testing)
.PARAMETER Version
    Version number (default: 10.0)
.EXAMPLE
    .\Build-Installer.ps1
#>

[CmdletBinding()]
param(
    [switch]$SkipNSIS,
    [string]$Version = "10.0"
)

$ErrorActionPreference = 'Stop'
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$projectRoot = Split-Path -Parent $scriptDir

Write-Host @"

    HYDRA Installer Builder
    =======================
    Version: $Version

"@ -ForegroundColor Cyan

# Create output directory
$outDir = Join-Path $scriptDir "dist"
if (-not (Test-Path $outDir)) {
    New-Item -ItemType Directory -Path $outDir | Out-Null
}

# Create assets if missing
$assetsDir = Join-Path $scriptDir "assets"
if (-not (Test-Path $assetsDir)) {
    New-Item -ItemType Directory -Path $assetsDir | Out-Null
}

# Create placeholder icon if missing
$iconPath = Join-Path $assetsDir "hydra.ico"
if (-not (Test-Path $iconPath)) {
    Write-Host "[Build] Creating placeholder icon..." -ForegroundColor Yellow
    # Create a simple ICO file (16x16 placeholder)
    $icoHeader = [byte[]]@(0,0,1,0,1,0,16,16,0,0,1,0,32,0,104,4,0,0,22,0,0,0)
    $bmpHeader = [byte[]]@(40,0,0,0,16,0,0,0,32,0,0,0,1,0,32,0,0,0,0,0,0,4,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0)
    # Purple pixels for HYDRA theme
    $pixels = @()
    for ($i = 0; $i -lt 256; $i++) {
        $pixels += @(128, 0, 128, 255)  # BGRA - Purple
    }
    $mask = [byte[]]::new(64)  # AND mask

    $ico = $icoHeader + $bmpHeader + $pixels + $mask
    [System.IO.File]::WriteAllBytes($iconPath, $ico)
    Write-Host "  Created: $iconPath" -ForegroundColor Green
}

# Step 1: Build NSIS Installer
if (-not $SkipNSIS) {
    Write-Host "`n[Build] Building Windows NSIS installer..." -ForegroundColor Cyan

    # Find NSIS
    $nsisPath = @(
        "C:\Program Files (x86)\NSIS\makensis.exe",
        "C:\Program Files\NSIS\makensis.exe",
        "$env:LOCALAPPDATA\NSIS\makensis.exe"
    ) | Where-Object { Test-Path $_ } | Select-Object -First 1

    if (-not $nsisPath) {
        Write-Host "[Build] NSIS not found. Install from: https://nsis.sourceforge.io/Download" -ForegroundColor Yellow
        Write-Host "[Build] Or install with: winget install NSIS.NSIS" -ForegroundColor Yellow

        $installNsis = Read-Host "Install NSIS now? [y/N]"
        if ($installNsis -eq 'y' -or $installNsis -eq 'Y') {
            Write-Host "[Build] Installing NSIS..." -ForegroundColor Cyan
            & winget install NSIS.NSIS --accept-source-agreements --accept-package-agreements
            $nsisPath = "C:\Program Files (x86)\NSIS\makensis.exe"
        } else {
            $SkipNSIS = $true
        }
    }

    if (-not $SkipNSIS -and (Test-Path $nsisPath)) {
        Write-Host "[Build] Using NSIS: $nsisPath" -ForegroundColor Gray

        $nsiScript = Join-Path $scriptDir "nsis\hydra-installer.nsi"

        # Update version in script
        $nsiContent = Get-Content $nsiScript -Raw
        $nsiContent = $nsiContent -replace '!define PRODUCT_VERSION ".*"', "!define PRODUCT_VERSION `"$Version`""
        $nsiContent | Set-Content $nsiScript -Encoding UTF8

        # Compile
        Write-Host "[Build] Compiling..." -ForegroundColor Gray
        & $nsisPath /V2 $nsiScript

        $exePath = Join-Path $scriptDir "HYDRA-$Version-Setup.exe"
        if (Test-Path $exePath) {
            Move-Item $exePath $outDir -Force
            Write-Host "[Build] Windows installer: $outDir\HYDRA-$Version-Setup.exe" -ForegroundColor Green
        }
    }
}

# Step 2: Package Linux/macOS scripts
Write-Host "`n[Build] Packaging Linux/macOS scripts..." -ForegroundColor Cyan

$unixPackage = Join-Path $outDir "hydra-$Version-unix"
if (Test-Path $unixPackage) { Remove-Item $unixPackage -Recurse -Force }
New-Item -ItemType Directory -Path $unixPackage | Out-Null

# Copy scripts
Copy-Item (Join-Path $scriptDir "scripts\install.sh") $unixPackage
Copy-Item (Join-Path $scriptDir "scripts\uninstall.sh") $unixPackage

# Create README for Unix
@"
HYDRA $Version - Linux/macOS Installation
==========================================

Quick Install:
  curl -fsSL https://raw.githubusercontent.com/pawelserkowski-lang/claudecli/master/installer/scripts/install.sh | bash

Manual Install:
  chmod +x install.sh
  ./install.sh

Uninstall:
  chmod +x uninstall.sh
  ./uninstall.sh

Requirements:
  - Git
  - Node.js 18+
  - Python 3.8+
  - Ollama (optional, for local AI)

"@ | Set-Content (Join-Path $unixPackage "README.txt")

# Create tarball
Write-Host "[Build] Creating tarball..." -ForegroundColor Gray
$tarPath = Join-Path $outDir "hydra-$Version-unix.tar.gz"
Push-Location $outDir
tar -czf "hydra-$Version-unix.tar.gz" "hydra-$Version-unix"
Pop-Location
Remove-Item $unixPackage -Recurse -Force

Write-Host "[Build] Unix package: $tarPath" -ForegroundColor Green

# Step 3: Create checksums
Write-Host "`n[Build] Creating checksums..." -ForegroundColor Cyan

$checksumFile = Join-Path $outDir "checksums.sha256"
$checksums = @()

Get-ChildItem $outDir -File | Where-Object { $_.Name -ne "checksums.sha256" } | ForEach-Object {
    $hash = (Get-FileHash $_.FullName -Algorithm SHA256).Hash.ToLower()
    $checksums += "$hash  $($_.Name)"
    Write-Host "  $($_.Name): $($hash.Substring(0, 16))..." -ForegroundColor Gray
}

$checksums | Set-Content $checksumFile
Write-Host "[Build] Checksums: $checksumFile" -ForegroundColor Green

# Summary
Write-Host @"

    ==========================================
    Build Complete!
    ==========================================

    Output directory: $outDir

    Files:
"@ -ForegroundColor Green

Get-ChildItem $outDir | ForEach-Object {
    $size = "{0:N2} KB" -f ($_.Length / 1KB)
    Write-Host "      $($_.Name) ($size)" -ForegroundColor White
}

Write-Host @"

    Next steps:
      1. Test installers locally
      2. Upload to GitHub Releases
      3. Update download links in README

"@ -ForegroundColor Cyan

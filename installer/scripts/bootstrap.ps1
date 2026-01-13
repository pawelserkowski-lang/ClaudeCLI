#Requires -Version 5.1
<#
.SYNOPSIS
    HYDRA 10.0 Cross-Platform Bootstrap
.DESCRIPTION
    Detects OS and runs appropriate installer
.EXAMPLE
    iwr -useb https://raw.githubusercontent.com/.../bootstrap.ps1 | iex
#>

$ErrorActionPreference = 'Stop'

Write-Host @"

    HYDRA 10.0 - Cross-Platform Bootstrap
    ======================================

"@ -ForegroundColor Magenta

# Detect platform
$isWindows = $env:OS -eq 'Windows_NT' -or $PSVersionTable.Platform -eq 'Win32NT' -or (-not $PSVersionTable.Platform)
$isLinux = $PSVersionTable.Platform -eq 'Unix' -and (Test-Path '/etc/os-release')
$isMacOS = $PSVersionTable.Platform -eq 'Unix' -and (Test-Path '/System/Library')

if ($isWindows) {
    Write-Host "[Bootstrap] Detected: Windows" -ForegroundColor Cyan

    # Check if running as admin
    $isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

    if (-not $isAdmin) {
        Write-Host "[Bootstrap] Requesting administrator privileges..." -ForegroundColor Yellow
        Start-Process powershell -Verb RunAs -ArgumentList "-ExecutionPolicy Bypass -Command `"iwr -useb 'https://raw.githubusercontent.com/pawelserkowski-lang/claudecli/master/installer/scripts/bootstrap.ps1' | iex`""
        exit
    }

    # Check for NSIS installer
    $installerPath = Join-Path $PSScriptRoot "..\HYDRA-10.0-Setup.exe"
    if (Test-Path $installerPath) {
        Write-Host "[Bootstrap] Found local installer, running..." -ForegroundColor Green
        Start-Process $installerPath -Wait
    } else {
        Write-Host "[Bootstrap] Downloading installer..." -ForegroundColor Cyan
        $downloadUrl = "https://github.com/pawelserkowski-lang/claudecli/releases/latest/download/HYDRA-10.0-Setup.exe"
        $tempPath = Join-Path $env:TEMP "HYDRA-Setup.exe"

        try {
            Invoke-WebRequest -Uri $downloadUrl -OutFile $tempPath -UseBasicParsing
            Write-Host "[Bootstrap] Running installer..." -ForegroundColor Green
            Start-Process $tempPath -Wait
            Remove-Item $tempPath -ErrorAction SilentlyContinue
        } catch {
            Write-Host "[Bootstrap] Download failed. Running manual setup..." -ForegroundColor Yellow
            # Fallback to script-based installation
            $initScript = "https://raw.githubusercontent.com/pawelserkowski-lang/claudecli/master/installer/scripts/Initialize-Hydra.ps1"
            Invoke-Expression (Invoke-WebRequest -Uri $initScript -UseBasicParsing).Content
        }
    }

} elseif ($isLinux -or $isMacOS) {
    $platform = if ($isLinux) { "Linux" } else { "macOS" }
    Write-Host "[Bootstrap] Detected: $platform" -ForegroundColor Cyan
    Write-Host "[Bootstrap] Running bash installer..." -ForegroundColor Green

    # Run bash installer
    $bashCmd = "curl -fsSL https://raw.githubusercontent.com/pawelserkowski-lang/claudecli/master/installer/scripts/install.sh | bash"
    & bash -c $bashCmd

} else {
    Write-Host "[Bootstrap] Unknown platform: $($PSVersionTable.Platform)" -ForegroundColor Red
    Write-Host "Please install manually from: https://github.com/pawelserkowski-lang/claudecli" -ForegroundColor Yellow
    exit 1
}

Write-Host "`n[Bootstrap] Done!" -ForegroundColor Green

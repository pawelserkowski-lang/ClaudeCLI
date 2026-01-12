# HYDRA 10.0 - MCP Health Check (Parallel Execution)
# Checks all MCP servers in parallel and restarts if needed
# Path: C:\Users\BIURODOM\Desktop\ClaudeCLI\mcp-health-check.ps1

#Requires -Version 5.1

param(
    [int]$TimeoutSeconds = 5
)

# Error handling zgodnie z Protocols (CLAUDE.md sekcja 6)
$ErrorActionPreference = "Stop"

# Absolute paths zgodnie z Best Practices (CLAUDE.md sekcja 7)
$ProjectRoot = "C:\Users\BIURODOM\Desktop\ClaudeCLI"

# Configuration - MCP servers (CLAUDE.md sekcja 1 - MCP Tools)
$mcpServers = @(
    @{
        Name = "Serena"
        Port = 9000
        Type = "Port"
        HealthUrl = "http://localhost:9000/sse"
    },
    @{
        Name = "Desktop-Commander"
        Port = 8100
        Type = "Stdio"
        ProcessName = "desktop-commander"
    },
    @{
        Name = "Playwright"
        Port = 5200
        Type = "Stdio"
        ProcessName = "playwright"
    }
)

function Write-ColorLog {
    param(
        [string]$Message,
        [ValidateSet("White", "Cyan", "Green", "Yellow", "Red", "Gray", "Magenta")]
        [string]$Color = "White"
    )
    Write-Host $Message -ForegroundColor $Color
}

# Header
Write-Host ""
Write-ColorLog "=============================================================" "Cyan"
Write-ColorLog "     HYDRA MCP Health Check (Parallel Mode)                " "Cyan"
Write-ColorLog "=============================================================" "Cyan"
Write-Host ""

try {
    # PARALLEL EXECUTION (CLAUDE.md sekcja 1 - Zasada Nadrzedna)
    # "Kazda operacja, ktora moze byc wykonana rownolegle, MUSI byc wykonana rownolegle."

    Write-ColorLog "Running parallel health checks on all MCP servers..." "Cyan"
    Write-Host ""

    # Start parallel jobs for all servers
    $jobs = @()

    foreach ($server in $mcpServers) {
        $job = Start-Job -ArgumentList $server, $TimeoutSeconds -ScriptBlock {
            param($server, $timeout)

            $result = @{
                Name = $server.Name
                Port = $server.Port
                Type = $server.Type
                Status = "Unknown"
                Message = ""
            }

            if ($server.Type -eq "Port" -and $server.Port) {
                # Test TCP port
                try {
                    $tcp = New-Object System.Net.Sockets.TcpClient
                    $asyncResult = $tcp.BeginConnect("127.0.0.1", $server.Port, $null, $null)
                    $success = $asyncResult.AsyncWaitHandle.WaitOne($timeout * 1000, $false)

                    if ($success) {
                        $tcp.EndConnect($asyncResult)
                        $tcp.Close()
                        $result.Status = "Healthy"
                        $result.Message = "Running on port $($server.Port)"
                    } else {
                        $tcp.Close()
                        $result.Status = "Down"
                        $result.Message = "Not responding on port $($server.Port)"
                    }
                } catch {
                    $result.Status = "Error"
                    $result.Message = $_.Exception.Message
                }
            } else {
                # Stdio server - starts with Claude automatically
                $result.Status = "Stdio"
                $result.Message = "Uses stdio transport (starts with Claude)"
            }

            return $result
        }

        $jobs += $job
        Write-ColorLog "  > Started check for $($server.Name)" "Gray"
    }

    Write-Host ""
    Write-ColorLog "Waiting for parallel checks to complete..." "Yellow"

    # Wait for all jobs to complete (parallel wait)
    $results = $jobs | Wait-Job | Receive-Job
    $jobs | Remove-Job

    Write-Host ""
    Write-ColorLog "=============================================================" "Gray"
    Write-ColorLog "RESULTS:" "Cyan"
    Write-ColorLog "=============================================================" "Gray"
    Write-Host ""

    # Display results
    $healthyCount = 0
    $downCount = 0
    $stdioCount = 0

    foreach ($result in $results) {
        $statusIcon = switch ($result.Status) {
            "Healthy" { "[OK]"; $healthyCount++ }
            "Down"    { "[XX]"; $downCount++ }
            "Stdio"   { "[--]"; $stdioCount++ }
            "Error"   { "[ER]"; $downCount++ }
            default   { "[??]" }
        }

        $color = switch ($result.Status) {
            "Healthy" { "Green" }
            "Down"    { "Red" }
            "Stdio"   { "Gray" }
            "Error"   { "Red" }
            default   { "Yellow" }
        }

        Write-ColorLog "$statusIcon $($result.Name)" $color
        Write-ColorLog "    $($result.Message)" "Gray"

        if ($result.Port) {
            Write-ColorLog "    Port: $($result.Port)" "Gray"
        }
        Write-Host ""
    }

    # Summary
    Write-ColorLog "=============================================================" "Gray"
    Write-ColorLog "SUMMARY:" "Cyan"
    Write-ColorLog "  * Healthy: $healthyCount" "Green"
    Write-ColorLog "  * Down: $downCount" "Red"
    Write-ColorLog "  * Stdio: $stdioCount" "Gray"
    Write-ColorLog "  * Total: $($results.Count)" "Cyan"
    Write-Host ""

    if ($downCount -gt 0) {
        Write-ColorLog "WARNING: Some MCP servers are down. They may need manual restart." "Yellow"
    } else {
        Write-ColorLog "SUCCESS: All MCP servers operational or managed by Claude." "Green"
    }

    Write-Host ""

} catch {
    Write-Host ""
    Write-ColorLog "=============================================================" "Red"
    Write-ColorLog "ERROR: $($_.Exception.Message)" "Red"
    Write-ColorLog "Stack Trace: $($_.ScriptStackTrace)" "Gray"
    Write-Host ""
    exit 1
}

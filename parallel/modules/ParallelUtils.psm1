#Requires -Version 7.0
<#
.SYNOPSIS
    ParallelUtils - Comprehensive parallel execution module for ClaudeCLI
.DESCRIPTION
    Provides utilities for maximizing CPU core utilization across various tasks
.AUTHOR
    ClaudeCLI HYDRA System
#>

# Get CPU core count for optimal parallelization
$script:CoreCount = [Environment]::ProcessorCount
$script:OptimalThrottle = [Math]::Max(1, $script:CoreCount)

#region Core Parallel Functions

function Get-ParallelConfig {
    <#
    .SYNOPSIS
        Returns optimal parallel configuration based on system
    #>
    [CmdletBinding()]
    param()
    
    @{
        CoreCount = $script:CoreCount
        OptimalThrottle = $script:OptimalThrottle
        RecommendedIOThrottle = [Math]::Min($script:CoreCount * 2, 32)
        RecommendedNetworkThrottle = [Math]::Min($script:CoreCount * 4, 64)
    }
}

function Invoke-Parallel {
    <#
    .SYNOPSIS
        Execute scriptblock in parallel across all CPU cores
    .PARAMETER InputObject
        Items to process
    .PARAMETER ScriptBlock
        Code to execute for each item
    .PARAMETER ThrottleLimit
        Max concurrent threads (default: CPU core count)
    .PARAMETER ArgumentList
        Additional arguments to pass
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [object[]]$InputObject,
        
        [Parameter(Mandatory)]
        [scriptblock]$ScriptBlock,
        
        [int]$ThrottleLimit = $script:OptimalThrottle,
        
        [object[]]$ArgumentList
    )
    
    begin {
        $items = [System.Collections.Generic.List[object]]::new()
    }
    
    process {
        foreach ($item in $InputObject) {
            $items.Add($item)
        }
    }
    
    end {
        $items | ForEach-Object -Parallel $ScriptBlock -ThrottleLimit $ThrottleLimit -ArgumentList $ArgumentList
    }
}

function Invoke-ParallelJobs {
    <#
    .SYNOPSIS
        Execute multiple independent jobs in parallel using ThreadJobs
    .PARAMETER Jobs
        Hashtable of job names and scriptblocks
    .PARAMETER Wait
        Wait for all jobs to complete
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [hashtable]$Jobs,
        
        [switch]$Wait
    )
    
    $threadJobs = @{}
    
    foreach ($jobName in $Jobs.Keys) {
        $threadJobs[$jobName] = Start-ThreadJob -Name $jobName -ScriptBlock $Jobs[$jobName]
    }
    
    if ($Wait) {
        $results = @{}
        $threadJobs.Values | Wait-Job | Out-Null
        foreach ($jobName in $threadJobs.Keys) {
            $results[$jobName] = Receive-Job -Job $threadJobs[$jobName]
            Remove-Job -Job $threadJobs[$jobName]
        }
        return $results
    }
    
    return $threadJobs
}

#endregion

#region File Operations

function Read-FilesParallel {
    <#
    .SYNOPSIS
        Read multiple files in parallel
    .PARAMETER Paths
        Array of file paths to read
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string[]]$Paths
    )
    
    $Paths | ForEach-Object -Parallel {
        @{
            Path = $_
            Content = if (Test-Path $_) { Get-Content $_ -Raw } else { $null }
            Exists = Test-Path $_
        }
    } -ThrottleLimit $script:OptimalThrottle
}

function Copy-FilesParallel {
    <#
    .SYNOPSIS
        Copy multiple files in parallel
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [hashtable[]]$FileMappings  # @{Source='...'; Destination='...'}
    )
    
    $FileMappings | ForEach-Object -Parallel {
        $mapping = $_
        Copy-Item -Path $mapping.Source -Destination $mapping.Destination -Force
        @{
            Source = $mapping.Source
            Destination = $mapping.Destination
            Success = $?
        }
    } -ThrottleLimit ($script:CoreCount * 2)
}

function Search-FilesParallel {
    <#
    .SYNOPSIS
        Search for pattern in multiple directories in parallel
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string[]]$Paths,
        
        [Parameter(Mandatory)]
        [string]$Pattern,
        
        [string]$FileFilter = "*.*"
    )
    
    $Paths | ForEach-Object -Parallel {
        $searchPath = $_
        $pattern = $using:Pattern
        $filter = $using:FileFilter
        
        Get-ChildItem -Path $searchPath -Filter $filter -Recurse -File -ErrorAction SilentlyContinue |
            Select-String -Pattern $pattern -ErrorAction SilentlyContinue |
            ForEach-Object {
                @{
                    File = $_.Path
                    Line = $_.LineNumber
                    Match = $_.Line.Trim()
                }
            }
    } -ThrottleLimit $script:OptimalThrottle
}

function Get-DirectorySizeParallel {
    <#
    .SYNOPSIS
        Calculate directory sizes in parallel
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string[]]$Paths
    )
    
    $Paths | ForEach-Object -Parallel {
        $path = $_
        $size = (Get-ChildItem -Path $path -Recurse -File -ErrorAction SilentlyContinue | 
                 Measure-Object -Property Length -Sum).Sum
        @{
            Path = $path
            SizeBytes = $size
            SizeMB = [Math]::Round($size / 1MB, 2)
            SizeGB = [Math]::Round($size / 1GB, 2)
        }
    } -ThrottleLimit $script:OptimalThrottle
}

#endregion

#region Process Management

function Invoke-CommandsParallel {
    <#
    .SYNOPSIS
        Execute multiple shell commands in parallel
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string[]]$Commands,
        
        [string]$WorkingDirectory = (Get-Location).Path
    )
    
    $Commands | ForEach-Object -Parallel {
        $cmd = $_
        $wd = $using:WorkingDirectory
        
        Push-Location $wd
        try {
            $output = Invoke-Expression $cmd 2>&1
            @{
                Command = $cmd
                Success = $LASTEXITCODE -eq 0 -or $?
                Output = $output
                ExitCode = $LASTEXITCODE
            }
        }
        catch {
            @{
                Command = $cmd
                Success = $false
                Output = $_.Exception.Message
                ExitCode = -1
            }
        }
        finally {
            Pop-Location
        }
    } -ThrottleLimit $script:OptimalThrottle
}

#endregion

#region Network Operations

function Invoke-WebRequestsParallel {
    <#
    .SYNOPSIS
        Make multiple HTTP requests in parallel
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string[]]$Urls,
        
        [string]$Method = 'GET',
        
        [hashtable]$Headers = @{}
    )
    
    $Urls | ForEach-Object -Parallel {
        $url = $_
        $method = $using:Method
        $headers = $using:Headers
        
        try {
            $response = Invoke-WebRequest -Uri $url -Method $method -Headers $headers -ErrorAction Stop
            @{
                Url = $url
                Success = $true
                StatusCode = $response.StatusCode
                Content = $response.Content
            }
        }
        catch {
            @{
                Url = $url
                Success = $false
                Error = $_.Exception.Message
            }
        }
    } -ThrottleLimit ([Math]::Min($script:CoreCount * 4, 64))
}

#endregion


#region Git Operations

function Invoke-GitParallel {
    <#
    .SYNOPSIS
        Execute git commands across multiple repositories in parallel
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string[]]$Repositories,
        
        [Parameter(Mandatory)]
        [string]$GitCommand
    )
    
    $Repositories | ForEach-Object -Parallel {
        $repo = $_
        $cmd = $using:GitCommand
        
        if (Test-Path (Join-Path $repo ".git")) {
            Push-Location $repo
            try {
                $output = git $cmd.Split(' ') 2>&1
                @{
                    Repository = $repo
                    Command = "git $cmd"
                    Success = $LASTEXITCODE -eq 0
                    Output = $output -join "`n"
                }
            }
            finally {
                Pop-Location
            }
        }
        else {
            @{
                Repository = $repo
                Success = $false
                Error = "Not a git repository"
            }
        }
    } -ThrottleLimit $script:OptimalThrottle
}

#endregion

#region Compression

function Compress-FilesParallel {
    <#
    .SYNOPSIS
        Compress multiple files/folders in parallel using 7-Zip
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [hashtable[]]$Items,  # @{Source='...'; Destination='...'}
        
        [ValidateSet('zip', '7z', 'tar', 'gzip')]
        [string]$Format = 'zip'
    )
    
    $7zPath = "C:\Program Files\7-Zip\7z.exe"
    if (-not (Test-Path $7zPath)) {
        $7zPath = "7z"  # Try PATH
    }
    
    $Items | ForEach-Object -Parallel {
        $item = $_
        $format = $using:Format
        $7z = $using:7zPath
        
        $ext = switch ($format) {
            'zip' { '.zip' }
            '7z' { '.7z' }
            'tar' { '.tar' }
            'gzip' { '.tar.gz' }
        }
        
        $dest = if ($item.Destination) { $item.Destination } else { "$($item.Source)$ext" }
        
        try {
            & $7z a -mmt=on "$dest" "$($item.Source)" 2>&1 | Out-Null
            @{
                Source = $item.Source
                Destination = $dest
                Success = $LASTEXITCODE -eq 0
            }
        }
        catch {
            @{
                Source = $item.Source
                Success = $false
                Error = $_.Exception.Message
            }
        }
    } -ThrottleLimit $script:OptimalThrottle
}

#endregion

# Export all functions
Export-ModuleMember -Function *

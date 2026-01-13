#Requires -Version 5.1
<#
.SYNOPSIS
    JSON I/O utility functions for AI Handler
.DESCRIPTION
    Provides reliable JSON read/write operations with atomic writes,
    PSObject to hashtable conversion, and error handling for the AI Handler system.
.VERSION
    1.0.0
.AUTHOR
    HYDRA System
#>

#region PSObject to Hashtable Conversion

function ConvertTo-Hashtable {
    <#
    .SYNOPSIS
        Converts PSCustomObject to hashtable recursively
    .DESCRIPTION
        PowerShell 5.1 compatible conversion from PSCustomObject (returned by ConvertFrom-Json)
        to native hashtables for easier manipulation.
    .PARAMETER InputObject
        The object to convert (PSCustomObject, array, or scalar)
    .OUTPUTS
        Hashtable or array of hashtables
    .EXAMPLE
        $json | ConvertFrom-Json | ConvertTo-Hashtable
    #>
    [CmdletBinding()]
    param(
        [Parameter(ValueFromPipeline)]
        $InputObject
    )

    process {
        if ($null -eq $InputObject) {
            return $null
        }

        if ($InputObject -is [System.Collections.IEnumerable] -and $InputObject -isnot [string]) {
            $collection = @(
                foreach ($object in $InputObject) {
                    ConvertTo-Hashtable $object
                }
            )
            return , $collection
        }
        elseif ($InputObject -is [psobject]) {
            $hash = @{}
            foreach ($property in $InputObject.PSObject.Properties) {
                $hash[$property.Name] = ConvertTo-Hashtable $property.Value
            }
            return $hash
        }
        else {
            return $InputObject
        }
    }
}

#endregion

#region JSON Read Operations

function Read-JsonFile {
    <#
    .SYNOPSIS
        Reads and parses a JSON file safely
    .DESCRIPTION
        Reads a JSON file with proper error handling and returns a hashtable.
        Returns $null if file doesn't exist or parsing fails.
    .PARAMETER Path
        Full path to the JSON file
    .PARAMETER AsHashtable
        Convert result to hashtable (default: true)
    .OUTPUTS
        Hashtable or PSCustomObject
    .EXAMPLE
        $config = Read-JsonFile -Path "C:\config.json"
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path,

        [switch]$AsHashtable = $true
    )

    if (-not (Test-Path $Path)) {
        Write-Verbose "File not found: $Path"
        return $null
    }

    try {
        $content = Get-Content $Path -Raw -ErrorAction Stop

        if ([string]::IsNullOrWhiteSpace($content)) {
            Write-Verbose "File is empty: $Path"
            return $null
        }

        $parsed = $content | ConvertFrom-Json -ErrorAction Stop

        if ($AsHashtable) {
            return $parsed | ConvertTo-Hashtable
        }

        return $parsed
    }
    catch {
        Write-Warning "Failed to read JSON from $Path`: $($_.Exception.Message)"
        return $null
    }
}

#endregion

#region JSON Write Operations

function Write-JsonFile {
    <#
    .SYNOPSIS
        Writes data to a JSON file with formatting
    .DESCRIPTION
        Serializes data to JSON and writes to file with specified depth.
        Uses UTF8 encoding without BOM for compatibility.
    .PARAMETER Path
        Full path to the output JSON file
    .PARAMETER Data
        Data to serialize (hashtable, PSCustomObject, array)
    .PARAMETER Depth
        JSON serialization depth (default: 10)
    .EXAMPLE
        Write-JsonFile -Path "C:\config.json" -Data $config
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path,

        [Parameter(Mandatory)]
        $Data,

        [int]$Depth = 10
    )

    try {
        $json = $Data | ConvertTo-Json -Depth $Depth -ErrorAction Stop
        $json | Set-Content $Path -Encoding UTF8 -ErrorAction Stop
        return $true
    }
    catch {
        Write-Warning "Failed to write JSON to $Path`: $($_.Exception.Message)"
        return $false
    }
}

function Write-AtomicFile {
    <#
    .SYNOPSIS
        Writes content to file atomically
    .DESCRIPTION
        Writes to a temporary file first, then moves to target location.
        Prevents partial writes and data corruption on failure.
    .PARAMETER Path
        Full path to the target file
    .PARAMETER Content
        Content to write (string)
    .EXAMPLE
        Write-AtomicFile -Path "C:\config.json" -Content $json
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path,

        [Parameter(Mandatory)]
        [string]$Content
    )

    $tempPath = "$Path.tmp.$([guid]::NewGuid().ToString('N').Substring(0,8))"

    try {
        # Write to temp file
        $Content | Set-Content $tempPath -Encoding UTF8 -ErrorAction Stop

        # Atomic move (replace if exists)
        Move-Item -Path $tempPath -Destination $Path -Force -ErrorAction Stop

        return $true
    }
    catch {
        # Cleanup temp file on failure
        if (Test-Path $tempPath) {
            Remove-Item $tempPath -Force -ErrorAction SilentlyContinue
        }
        Write-Warning "Atomic write failed for $Path`: $($_.Exception.Message)"
        return $false
    }
}

function Write-JsonFileAtomic {
    <#
    .SYNOPSIS
        Writes data to JSON file atomically
    .DESCRIPTION
        Combines JSON serialization with atomic file write for safe updates
        to configuration files.
    .PARAMETER Path
        Full path to the output JSON file
    .PARAMETER Data
        Data to serialize (hashtable, PSCustomObject, array)
    .PARAMETER Depth
        JSON serialization depth (default: 10)
    .EXAMPLE
        Write-JsonFileAtomic -Path "C:\config.json" -Data $config
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path,

        [Parameter(Mandatory)]
        $Data,

        [int]$Depth = 10
    )

    try {
        $json = $Data | ConvertTo-Json -Depth $Depth -ErrorAction Stop
        return Write-AtomicFile -Path $Path -Content $json
    }
    catch {
        Write-Warning "Failed to serialize JSON for $Path`: $($_.Exception.Message)"
        return $false
    }
}

#endregion

#region Exports

Export-ModuleMember -Function @(
    'ConvertTo-Hashtable',
    'Read-JsonFile',
    'Write-JsonFile',
    'Write-AtomicFile',
    'Write-JsonFileAtomic'
)

#endregion

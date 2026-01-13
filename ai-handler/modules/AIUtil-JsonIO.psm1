#Requires -Version 5.1
<#
.SYNOPSIS
    AI Utility Module - JSON I/O Operations
.DESCRIPTION
    Shared JSON utilities for AI Handler modules including:
    - Safe JSON file reading with error handling
    - JSON file writing with atomic operations
    - Cache management helpers
.VERSION
    1.0.0
.AUTHOR
    HYDRA System
#>

#region JSON Read Operations

function Read-JsonFile {
    <#
    .SYNOPSIS
        Safely read and parse a JSON file
    .DESCRIPTION
        Reads a JSON file with proper error handling and optional
        validation. Returns $null if file doesn't exist or is invalid.
    .PARAMETER Path
        Path to the JSON file
    .PARAMETER Default
        Default value to return if file doesn't exist or is invalid
    .PARAMETER ValidateSchema
        Optional hashtable defining required properties
    .RETURNS
        Parsed JSON as PSCustomObject or hashtable, or $Default on failure
    .EXAMPLE
        $config = Read-JsonFile -Path "config.json"
    .EXAMPLE
        $data = Read-JsonFile -Path "data.json" -Default @{}
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [string]$Path,

        [object]$Default = $null,

        [hashtable]$ValidateSchema
    )

    process {
        if (-not (Test-Path $Path)) {
            Write-Verbose "[JsonIO] File not found: $Path"
            return $Default
        }

        try {
            $content = Get-Content $Path -Raw -Encoding UTF8 -ErrorAction Stop

            if ([string]::IsNullOrWhiteSpace($content)) {
                Write-Verbose "[JsonIO] Empty file: $Path"
                return $Default
            }

            $parsed = $content | ConvertFrom-Json -ErrorAction Stop

            # Validate schema if provided
            if ($ValidateSchema) {
                foreach ($key in $ValidateSchema.Keys) {
                    if ($null -eq $parsed.$key) {
                        Write-Warning "[JsonIO] Missing required property '$key' in $Path"
                        return $Default
                    }
                }
            }

            return $parsed

        } catch {
            Write-Warning "[JsonIO] Failed to read JSON from '$Path': $($_.Exception.Message)"
            return $Default
        }
    }
}

function Read-JsonFileAsHashtable {
    <#
    .SYNOPSIS
        Read JSON file and convert to hashtable
    .DESCRIPTION
        Reads a JSON file and ensures the result is a hashtable
        for easier manipulation in PowerShell.
    .PARAMETER Path
        Path to the JSON file
    .PARAMETER Default
        Default hashtable to return on failure
    .RETURNS
        Hashtable representation of the JSON
    .EXAMPLE
        $config = Read-JsonFileAsHashtable -Path "config.json" -Default @{}
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [string]$Path,

        [hashtable]$Default = @{}
    )

    process {
        $parsed = Read-JsonFile -Path $Path -Default $null

        if ($null -eq $parsed) {
            return $Default
        }

        return ConvertTo-Hashtable -Object $parsed
    }
}

#endregion

#region JSON Write Operations

function Write-JsonFile {
    <#
    .SYNOPSIS
        Safely write object to JSON file
    .DESCRIPTION
        Writes an object as JSON to a file with proper encoding.
        Creates parent directories if they don't exist.
        Optionally uses atomic write (temp file + rename).
    .PARAMETER Path
        Path to the JSON file
    .PARAMETER Data
        Object to serialize to JSON
    .PARAMETER Depth
        JSON serialization depth (default: 10)
    .PARAMETER Atomic
        Use atomic write operation (write to temp, then rename)
    .PARAMETER Compress
        Output compressed JSON (no formatting)
    .RETURNS
        $true on success, $false on failure
    .EXAMPLE
        Write-JsonFile -Path "config.json" -Data $config
    .EXAMPLE
        Write-JsonFile -Path "data.json" -Data $data -Atomic -Depth 5
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory)]
        [string]$Path,

        [Parameter(Mandatory, ValueFromPipeline)]
        [object]$Data,

        [int]$Depth = 10,

        [switch]$Atomic,

        [switch]$Compress
    )

    process {
        try {
            # Ensure directory exists
            $directory = Split-Path $Path -Parent
            if ($directory -and -not (Test-Path $directory)) {
                New-Item -ItemType Directory -Path $directory -Force | Out-Null
                Write-Verbose "[JsonIO] Created directory: $directory"
            }

            # Convert to JSON
            $jsonContent = $Data | ConvertTo-Json -Depth $Depth -Compress:$Compress

            if ($Atomic) {
                # Atomic write: temp file then rename
                $tempPath = "$Path.tmp"
                $jsonContent | Set-Content $tempPath -Encoding UTF8 -ErrorAction Stop
                Move-Item $tempPath $Path -Force -ErrorAction Stop
            } else {
                $jsonContent | Set-Content $Path -Encoding UTF8 -ErrorAction Stop
            }

            Write-Verbose "[JsonIO] Wrote JSON to: $Path"
            return $true

        } catch {
            Write-Warning "[JsonIO] Failed to write JSON to '$Path': $($_.Exception.Message)"
            return $false
        }
    }
}

function Update-JsonFile {
    <#
    .SYNOPSIS
        Update specific properties in a JSON file
    .DESCRIPTION
        Reads a JSON file, updates specified properties, and writes back.
        Preserves existing properties that are not in the update.
    .PARAMETER Path
        Path to the JSON file
    .PARAMETER Updates
        Hashtable of properties to update
    .PARAMETER CreateIfNotExists
        Create the file if it doesn't exist
    .RETURNS
        $true on success, $false on failure
    .EXAMPLE
        Update-JsonFile -Path "config.json" -Updates @{ timeout = 30; retries = 5 }
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory)]
        [string]$Path,

        [Parameter(Mandatory)]
        [hashtable]$Updates,

        [switch]$CreateIfNotExists
    )

    # Read existing data
    $data = Read-JsonFileAsHashtable -Path $Path -Default @{}

    if ($data.Count -eq 0 -and -not (Test-Path $Path) -and -not $CreateIfNotExists) {
        Write-Warning "[JsonIO] File not found and CreateIfNotExists not set: $Path"
        return $false
    }

    # Apply updates
    foreach ($key in $Updates.Keys) {
        $data[$key] = $Updates[$key]
    }

    # Write back
    return Write-JsonFile -Path $Path -Data $data
}

#endregion

#region Cache Helpers

function Test-CacheValid {
    <#
    .SYNOPSIS
        Check if a cached JSON file is still valid
    .DESCRIPTION
        Validates cache based on timestamp and optional key matching.
    .PARAMETER Path
        Path to the cache file
    .PARAMETER MaxAgeHours
        Maximum age in hours (default: 24)
    .PARAMETER MatchKey
        Optional key name to match against MatchValue
    .PARAMETER MatchValue
        Value that MatchKey must equal for cache to be valid
    .RETURNS
        $true if cache is valid, $false otherwise
    .EXAMPLE
        if (Test-CacheValid -Path "cache.json" -MaxAgeHours 1) { ... }
    .EXAMPLE
        Test-CacheValid -Path "cache.json" -MatchKey "ProjectRoot" -MatchValue "C:\MyProject"
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory)]
        [string]$Path,

        [double]$MaxAgeHours = 24,

        [string]$MatchKey,

        [string]$MatchValue
    )

    if (-not (Test-Path $Path)) {
        return $false
    }

    try {
        $cached = Read-JsonFile -Path $Path

        if ($null -eq $cached) {
            return $false
        }

        # Check timestamp
        if ($cached.Timestamp) {
            $timestamp = [DateTime]::Parse($cached.Timestamp)
            $age = (Get-Date) - $timestamp

            if ($age.TotalHours -gt $MaxAgeHours) {
                Write-Verbose "[JsonIO] Cache expired (age: $([math]::Round($age.TotalHours, 1))h, max: ${MaxAgeHours}h)"
                return $false
            }
        }

        # Check key match
        if ($MatchKey -and $MatchValue) {
            if ($cached.$MatchKey -ne $MatchValue) {
                Write-Verbose "[JsonIO] Cache key mismatch: $MatchKey"
                return $false
            }
        }

        return $true

    } catch {
        Write-Verbose "[JsonIO] Cache validation failed: $($_.Exception.Message)"
        return $false
    }
}

function Clear-CacheFile {
    <#
    .SYNOPSIS
        Remove a cache file
    .PARAMETER Path
        Path to the cache file
    .RETURNS
        $true if file was removed or didn't exist, $false on error
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [string]$Path
    )

    process {
        if (-not (Test-Path $Path)) {
            return $true
        }

        try {
            Remove-Item $Path -Force -ErrorAction Stop
            Write-Verbose "[JsonIO] Removed cache: $Path"
            return $true
        } catch {
            Write-Warning "[JsonIO] Failed to remove cache '$Path': $($_.Exception.Message)"
            return $false
        }
    }
}

#endregion

#region Utility Functions

function ConvertTo-Hashtable {
    <#
    .SYNOPSIS
        Convert PSCustomObject to hashtable (recursive)
    .DESCRIPTION
        Recursively converts PSCustomObject from ConvertFrom-Json
        into a proper hashtable for easier manipulation.
    .PARAMETER Object
        The object to convert
    .RETURNS
        Hashtable representation of the object
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [object]$Object
    )

    process {
        if ($null -eq $Object) {
            return @{}
        }

        if ($Object -is [hashtable]) {
            return $Object
        }

        if ($Object -is [System.Collections.IEnumerable] -and $Object -isnot [string]) {
            # Return as array, converting each element
            return @($Object | ForEach-Object { ConvertTo-Hashtable -Object $_ })
        }

        if ($Object -is [PSCustomObject]) {
            $hash = @{}
            foreach ($property in $Object.PSObject.Properties) {
                $hash[$property.Name] = ConvertTo-Hashtable -Object $property.Value
            }
            return $hash
        }

        # Primitive type - return as-is
        return $Object
    }
}

#endregion

#region Exports

Export-ModuleMember -Function @(
    'Read-JsonFile',
    'Read-JsonFileAsHashtable',
    'Write-JsonFile',
    'Update-JsonFile',
    'Test-CacheValid',
    'Clear-CacheFile',
    'ConvertTo-Hashtable'
)

#endregion

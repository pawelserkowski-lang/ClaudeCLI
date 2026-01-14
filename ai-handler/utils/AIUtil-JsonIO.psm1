#Requires -Version 5.1
<#
.SYNOPSIS
    Atomic JSON I/O utilities for AI Handler modules.

.DESCRIPTION
    Provides reliable JSON read/write operations with proper error handling,
    atomic writes (temp file + rename), and PSObject-to-Hashtable conversion
    for PowerShell 5.1 compatibility.

.NOTES
    Module: AIUtil-JsonIO
    Author: HYDRA AI Handler
    Version: 1.0.0
#>

function Read-JsonFile {
    <#
    .SYNOPSIS
        Reads and parses a JSON file with error handling.

    .DESCRIPTION
        Safely reads a JSON file and returns its contents as a PowerShell object.
        If the file does not exist or cannot be parsed, returns the specified default value.

    .PARAMETER Path
        The full path to the JSON file to read.

    .PARAMETER Default
        The default value to return if the file does not exist or cannot be parsed.
        Defaults to an empty hashtable.

    .PARAMETER AsHashtable
        If specified, converts the parsed JSON to a hashtable instead of PSCustomObject.
        This provides PowerShell 5.1 compatibility where hashtables are required.

    .EXAMPLE
        $config = Read-JsonFile -Path "C:\config\settings.json"

    .EXAMPLE
        $state = Read-JsonFile -Path "C:\state.json" -Default @{ initialized = $false }

    .EXAMPLE
        $config = Read-JsonFile -Path "C:\config.json" -AsHashtable

    .OUTPUTS
        System.Object
        Returns the parsed JSON content or the default value on failure.
    #>
    [CmdletBinding()]
    [OutputType([object])]
    param(
        [Parameter(Mandatory = $true, Position = 0)]
        [ValidateNotNullOrEmpty()]
        [string]$Path,

        [Parameter(Mandatory = $false)]
        [object]$Default = @{},

        [Parameter(Mandatory = $false)]
        [switch]$AsHashtable
    )

    try {
        if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
            Write-Verbose "File not found: $Path - returning default value"
            return $Default
        }

        $content = Get-Content -LiteralPath $Path -Raw -Encoding UTF8 -ErrorAction Stop

        if ([string]::IsNullOrWhiteSpace($content)) {
            Write-Verbose "File is empty: $Path - returning default value"
            return $Default
        }

        $parsed = $content | ConvertFrom-Json -ErrorAction Stop

        # Convert to hashtable if requested (PS 5.1 compatibility)
        if ($AsHashtable) {
            return ConvertTo-Hashtable -InputObject $parsed
        }

        return $parsed
    }
    catch {
        Write-Warning "Failed to read JSON file '$Path': $($_.Exception.Message)"
        return $Default
    }
}

function Write-JsonFile {
    <#
    .SYNOPSIS
        Writes data to a JSON file atomically.

    .DESCRIPTION
        Performs an atomic write operation by first writing to a temporary file,
        then renaming it to the target path. This prevents data corruption if
        the write operation is interrupted.

    .PARAMETER Path
        The full path to the JSON file to write.

    .PARAMETER Data
        The data object to serialize as JSON.

    .PARAMETER Depth
        The maximum depth of nested objects to serialize.
        Defaults to 10.

    .EXAMPLE
        Write-JsonFile -Path "C:\config\settings.json" -Data $config

    .EXAMPLE
        Write-JsonFile -Path "C:\state.json" -Data $state -Depth 5

    .OUTPUTS
        System.Boolean
        Returns $true on success, $false on failure.
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory = $true, Position = 0)]
        [ValidateNotNullOrEmpty()]
        [string]$Path,

        [Parameter(Mandatory = $true, Position = 1)]
        [AllowNull()]
        [object]$Data,

        [Parameter(Mandatory = $false)]
        [ValidateRange(1, 100)]
        [int]$Depth = 10
    )

    $tempPath = $null

    try {
        # Ensure parent directory exists
        $parentDir = Split-Path -Path $Path -Parent
        if ($parentDir -and -not (Test-Path -LiteralPath $parentDir -PathType Container)) {
            New-Item -Path $parentDir -ItemType Directory -Force -ErrorAction Stop | Out-Null
            Write-Verbose "Created directory: $parentDir"
        }

        # Handle null data
        if ($null -eq $Data) {
            $Data = @{}
        }

        # Convert to JSON
        $json = $Data | ConvertTo-Json -Depth $Depth -ErrorAction Stop

        # Generate temp file path in same directory for atomic rename
        $tempFileName = ".tmp_$(Get-Random -Minimum 100000 -Maximum 999999)_$(Split-Path -Path $Path -Leaf)"
        $tempPath = Join-Path -Path $parentDir -ChildPath $tempFileName

        # Write to temp file
        $json | Out-File -LiteralPath $tempPath -Encoding UTF8 -Force -ErrorAction Stop

        # Atomic rename (move) - replace if exists
        if (Test-Path -LiteralPath $Path -PathType Leaf) {
            Remove-Item -LiteralPath $Path -Force -ErrorAction Stop
        }
        Move-Item -LiteralPath $tempPath -Destination $Path -Force -ErrorAction Stop

        Write-Verbose "Successfully wrote JSON to: $Path"
        return $true
    }
    catch {
        Write-Warning "Failed to write JSON file '$Path': $($_.Exception.Message)"

        # Clean up temp file if it exists
        if ($tempPath -and (Test-Path -LiteralPath $tempPath -PathType Leaf)) {
            try {
                Remove-Item -LiteralPath $tempPath -Force -ErrorAction SilentlyContinue
            }
            catch {
                Write-Verbose "Failed to clean up temp file: $tempPath"
            }
        }

        return $false
    }
}

function ConvertTo-Hashtable {
    <#
    .SYNOPSIS
        Converts a PSObject to a hashtable recursively.

    .DESCRIPTION
        Recursively converts a PSCustomObject (typically from ConvertFrom-Json)
        to a hashtable. This is necessary for PowerShell 5.1 compatibility where
        PSObjects cannot be used in all contexts where hashtables are expected.

    .PARAMETER InputObject
        The object to convert. Can be a PSCustomObject, array, or primitive value.

    .EXAMPLE
        $json = '{"name": "test", "nested": {"value": 123}}' | ConvertFrom-Json
        $hashtable = ConvertTo-Hashtable -InputObject $json

    .EXAMPLE
        $config = Read-JsonFile -Path "config.json" | ConvertTo-Hashtable

    .OUTPUTS
        System.Collections.Hashtable
        Returns a hashtable representation of the input object.
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true)]
        [AllowNull()]
        [object]$InputObject
    )

    process {
        # Handle null
        if ($null -eq $InputObject) {
            return $null
        }

        # Handle arrays
        if ($InputObject -is [System.Collections.IEnumerable] -and $InputObject -isnot [string] -and $InputObject -isnot [hashtable]) {
            $result = @()
            foreach ($item in $InputObject) {
                $result += ConvertTo-Hashtable -InputObject $item
            }
            return $result
        }

        # Handle PSCustomObject
        if ($InputObject -is [System.Management.Automation.PSCustomObject]) {
            $hashtable = @{}
            foreach ($property in $InputObject.PSObject.Properties) {
                $hashtable[$property.Name] = ConvertTo-Hashtable -InputObject $property.Value
            }
            return $hashtable
        }

        # Handle existing hashtables (recurse into values)
        if ($InputObject -is [hashtable]) {
            $hashtable = @{}
            foreach ($key in $InputObject.Keys) {
                $hashtable[$key] = ConvertTo-Hashtable -InputObject $InputObject[$key]
            }
            return $hashtable
        }

        # Return primitives and other types as-is
        return $InputObject
    }
}

# Export module members
Export-ModuleMember -Function @(
    'Read-JsonFile',
    'Write-JsonFile',
    'ConvertTo-Hashtable'
)

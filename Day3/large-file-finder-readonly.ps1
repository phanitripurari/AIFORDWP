[CmdletBinding(PositionalBinding = $false)]
param(
    # Root paths to scan. Defaults to current directory.
    [string[]]$TargetPaths = @('.'),

    # File size threshold in megabytes.
    [ValidateRange(1, 1048576)]
    [int]$ThresholdMB = 100,

    # Optional number of top results to display. 0 means all matches.
    [ValidateRange(0, 1000000)]
    [int]$Top = 0,

    # Include hidden/system files in the scan.
    [switch]$IncludeHidden,

    # Optional CSV export path for report output.
    [string]$CsvPath,

    # Captures unexpected positional arguments so we can return a clear usage error.
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$UnexpectedArgs
)

# Section: Logging helper.
# This script is read-only; output is informational and no file changes are made.
function Write-Info {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message
    )

    Write-Output ("[{0}] {1}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Message)
}

function Convert-BytesToMB {
    param(
        [Parameter(Mandatory = $true)]
        [Int64]$Bytes
    )

    return [Math]::Round(($Bytes / 1MB), 2)
}

# Section: Runtime preparation.
# Catch common invocation mistakes such as missing '-' before parameter names.
if ($UnexpectedArgs -and $UnexpectedArgs.Count -gt 0) {
    $joined = ($UnexpectedArgs -join ' ')
    throw "Unexpected argument(s): $joined. Use named parameters, for example: .\\large-file-finder-readonly.ps1 -TargetPaths 'C:\\SomePath' -ThresholdMB 250"
}

$thresholdBytes = [Int64]$ThresholdMB * 1MB
$resolvedTargets = New-Object System.Collections.Generic.List[string]

foreach ($path in $TargetPaths) {
    if ([string]::IsNullOrWhiteSpace($path)) {
        continue
    }

    try {
        $resolved = Resolve-Path -Path $path -ErrorAction Stop
        foreach ($item in $resolved) {
            $resolvedTargets.Add($item.Path)
        }
    }
    catch {
        Write-Info "WARN target path not found or inaccessible: $path"
    }
}

if ($resolvedTargets.Count -eq 0) {
    throw 'No valid target paths were resolved. Provide at least one accessible path.'
}

Write-Info "Large file scan started. ThresholdMB=$ThresholdMB Top=$Top IncludeHidden=$IncludeHidden"

# Section: Discovery.
# Enumerates files recursively and filters by threshold without modifying disk state.
$allCandidates = New-Object System.Collections.Generic.List[object]
$scannedFiles = 0
$scanErrors = 0

foreach ($target in $resolvedTargets) {
    Write-Info "Scanning path: $target"

    try {
        $enumerationParams = @{
            Path        = $target
            File        = $true
            Recurse     = $true
            ErrorAction = 'SilentlyContinue'
        }

        if ($IncludeHidden) {
            $enumerationParams['Force'] = $true
        }

        $files = Get-ChildItem @enumerationParams

        foreach ($file in $files) {
            $scannedFiles++

            if ($file.Length -ge $thresholdBytes) {
                $allCandidates.Add([pscustomobject]@{
                    FullName      = $file.FullName
                    SizeBytes     = [Int64]$file.Length
                    SizeMB        = Convert-BytesToMB -Bytes $file.Length
                    LastWriteTime = $file.LastWriteTime
                    Extension     = $file.Extension
                })
            }
        }
    }
    catch {
        $scanErrors++
        Write-Info "WARN scan error on '$target': $($_.Exception.Message)"
    }
}

# Section: Reporting.
$sorted = $allCandidates | Sort-Object -Property SizeBytes -Descending
$report = if ($Top -gt 0) { $sorted | Select-Object -First $Top } else { $sorted }

Write-Output ''
Write-Output '================ Large File Finder Report ================'
Write-Output ("ThresholdMB      : {0}" -f $ThresholdMB)
Write-Output ("ResolvedTargets  : {0}" -f $resolvedTargets.Count)
Write-Output ("FilesScanned     : {0}" -f $scannedFiles)
Write-Output ("MatchesFound     : {0}" -f $sorted.Count)
Write-Output ("ScanErrors       : {0}" -f $scanErrors)
Write-Output '=========================================================='
Write-Output ''

if (-not $report -or $report.Count -eq 0) {
    Write-Output 'No files met or exceeded the threshold.'
}
else {
    $report |
        Select-Object FullName, SizeMB, SizeBytes, LastWriteTime, Extension |
        Format-Table -AutoSize

    $totalBytes = ($report | Measure-Object -Property SizeBytes -Sum).Sum
    $totalMB = Convert-BytesToMB -Bytes ([Int64]$totalBytes)
    Write-Output ''
    Write-Output ("Displayed matches total size: {0} MB" -f $totalMB)
}

if (-not [string]::IsNullOrWhiteSpace($CsvPath)) {
    try {
        $csvParent = Split-Path -Path $CsvPath -Parent
        if (-not [string]::IsNullOrWhiteSpace($csvParent) -and -not (Test-Path -Path $csvParent)) {
            throw "CSV parent folder does not exist: $csvParent"
        }

        $report |
            Select-Object FullName, SizeMB, SizeBytes, LastWriteTime, Extension |
            Export-Csv -Path $CsvPath -NoTypeInformation -Encoding UTF8

        Write-Info "CSV report exported: $CsvPath"
    }
    catch {
        throw "Failed to export CSV report: $($_.Exception.Message)"
    }
}

Write-Info 'Large file scan finished.'

[CmdletBinding()]
param(
    # Dry run mode: prints what would be moved/deleted without changing files.
    [switch]$DryRun,

    # Only target files older than this many days. Default 0 means any age.
    [ValidateRange(0, 3650)]
    [int]$OlderThanDays = 0,

    # Target temp paths to scan for files.
    [string[]]$TargetPaths = @(
        $env:TEMP,
        'C:\Windows\Temp'
    ),

    # Root location used to store rollback data for each cleanup run.
    [string]$RollbackRoot = "$env:ProgramData\DWPTempCleanup\Rollback",

    # Folder where timestamped logs are written.
    [string]$LogDirectory = "$PSScriptRoot\Logs",

    # Rollback mode switch: restores files from a prior rollback batch id.
    [switch]$Rollback,

    # Rollback batch id to restore from (required when -Rollback is used).
    [string]$RollbackId
)

# Section: Utility helpers for logging, hashing, and lock detection.
# This section contains read/write helpers used consistently by cleanup and rollback flows.
function Write-Log {
    param(
        [string]$Level,
        [string]$Message
    )

    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $line = "[$timestamp] [$Level] $Message"
    Add-Content -Path $script:LogFilePath -Value $line
    Write-Output $line
}

function Get-PathHash {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    $sha1 = [System.Security.Cryptography.SHA1]::Create()
    try {
        $bytes = [System.Text.Encoding]::UTF8.GetBytes($Path.ToLowerInvariant())
        $hashBytes = $sha1.ComputeHash($bytes)
        return ([System.BitConverter]::ToString($hashBytes)).Replace('-', '').ToLowerInvariant()
    }
    finally {
        $sha1.Dispose()
    }
}

function Test-FileLocked {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    try {
        $stream = [System.IO.File]::Open($Path, 'Open', 'ReadWrite', 'None')
        $stream.Close()
        return $false
    }
    catch [System.IO.IOException] {
        return $true
    }
    catch [System.UnauthorizedAccessException] {
        # Treat access denied as non-removable for safe behavior.
        return $true
    }
}

# Section: Initialize folders, runtime context, and timestamped log file.
# This section prepares predictable run artifacts and a per-run summary object.
if (-not (Test-Path -Path $LogDirectory)) {
    New-Item -Path $LogDirectory -ItemType Directory -Force | Out-Null
}

$runTimestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$modeName = if ($Rollback) { 'rollback' } else { 'cleanup' }
$script:LogFilePath = Join-Path -Path $LogDirectory -ChildPath ("temp-cleanup-$modeName-$runTimestamp.log")
New-Item -Path $script:LogFilePath -ItemType File -Force | Out-Null

$summary = [ordered]@{
    Mode           = $modeName
    FilesScanned   = 0
    EligibleFiles  = 0
    DryRunListed   = 0
    Processed      = 0
    Restored       = 0
    LockedSkipped  = 0
    MissingSkipped = 0
    Failed         = 0
}

Write-Log -Level 'INFO' -Message "Run started. Mode=$modeName DryRun=$DryRun OlderThanDays=$OlderThanDays"

# Section: Parameter safety validation.
# This section enforces valid combinations so behavior is deterministic and idempotent.
if ($Rollback -and [string]::IsNullOrWhiteSpace($RollbackId)) {
    Write-Log -Level 'ERROR' -Message 'Rollback mode requires -RollbackId.'
    throw 'When using -Rollback, provide -RollbackId.'
}

if ($Rollback -and $DryRun) {
    Write-Log -Level 'ERROR' -Message 'Dry run and rollback cannot be combined.'
    throw 'Use either cleanup with -DryRun or rollback with -Rollback, not both.'
}

# Section: Rollback flow.
# This section restores files from a previous cleanup batch manifest and skips already-restored files.
if ($Rollback) {
    $batchFolder = Join-Path -Path $RollbackRoot -ChildPath $RollbackId
    $manifestPath = Join-Path -Path $batchFolder -ChildPath 'manifest.csv'

    if (-not (Test-Path -Path $manifestPath)) {
        Write-Log -Level 'ERROR' -Message "Manifest not found: $manifestPath"
        throw "Rollback manifest not found for batch id '$RollbackId'."
    }

    $entries = Import-Csv -Path $manifestPath
    Write-Log -Level 'INFO' -Message "Loaded rollback manifest entries: $($entries.Count)"

    foreach ($entry in $entries) {
        $backupPath = $entry.BackupPath
        $originalPath = $entry.OriginalPath

        try {
            if (-not (Test-Path -Path $backupPath)) {
                $summary.MissingSkipped++
                Write-Log -Level 'WARN' -Message "Backup missing, skip: $backupPath"
                continue
            }

            if (Test-Path -Path $originalPath) {
                $summary.MissingSkipped++
                Write-Log -Level 'INFO' -Message "Original already present, skip (idempotent): $originalPath"
                continue
            }

            $parent = Split-Path -Path $originalPath -Parent
            if (-not (Test-Path -Path $parent)) {
                New-Item -Path $parent -ItemType Directory -Force | Out-Null
            }

            Move-Item -Path $backupPath -Destination $originalPath -Force -ErrorAction Stop
            $summary.Restored++
            Write-Log -Level 'INFO' -Message "Restored: $originalPath"
        }
        catch {
            $summary.Failed++
            Write-Log -Level 'ERROR' -Message "Rollback failed for '$originalPath': $($_.Exception.Message)"
        }
    }

    Write-Log -Level 'INFO' -Message 'Rollback mode completed.'
}
else {
    # Section: Cleanup flow setup.
    # This section creates a unique rollback batch folder and manifest for recoverability.
    if (-not (Test-Path -Path $RollbackRoot)) {
        New-Item -Path $RollbackRoot -ItemType Directory -Force | Out-Null
    }

    $batchId = "batch-$runTimestamp"
    $batchFolder = Join-Path -Path $RollbackRoot -ChildPath $batchId
    $filesFolder = Join-Path -Path $batchFolder -ChildPath 'files'
    $manifestPath = Join-Path -Path $batchFolder -ChildPath 'manifest.csv'

    if (-not $DryRun) {
        New-Item -Path $filesFolder -ItemType Directory -Force | Out-Null
        Write-Log -Level 'INFO' -Message "Rollback batch created: $batchId"
    }

    $cutoff = (Get-Date).AddDays(-$OlderThanDays)
    Write-Log -Level 'INFO' -Message "File age cutoff timestamp: $cutoff"

    # Section: Candidate discovery.
    # This section scans target temp locations and gathers file candidates safely.
    $candidateFiles = @()

    foreach ($targetPath in $TargetPaths) {
        if ([string]::IsNullOrWhiteSpace($targetPath)) {
            continue
        }

        if (-not (Test-Path -Path $targetPath)) {
            Write-Log -Level 'WARN' -Message "Target path not found, skip: $targetPath"
            continue
        }

        if ($targetPath.StartsWith($RollbackRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
            Write-Log -Level 'WARN' -Message "Skipping rollback root path to avoid recursion: $targetPath"
            continue
        }

        try {
            $found = Get-ChildItem -Path $targetPath -File -Recurse -ErrorAction SilentlyContinue |
                Where-Object { $_.LastWriteTime -lt $cutoff }
            $candidateFiles += $found
            Write-Log -Level 'INFO' -Message "Scanned '$targetPath', found candidates: $($found.Count)"
        }
        catch {
            Write-Log -Level 'ERROR' -Message "Failed while scanning '$targetPath': $($_.Exception.Message)"
        }
    }

    $uniqueCandidates = $candidateFiles | Sort-Object -Property FullName -Unique
    $summary.FilesScanned = $candidateFiles.Count
    $summary.EligibleFiles = $uniqueCandidates.Count

    if ($DryRun) {
        # Section: Dry run reporting.
        # This section reports files that would be cleaned without changing endpoint state.
        foreach ($file in $uniqueCandidates) {
            $summary.DryRunListed++
            Write-Log -Level 'INFO' -Message "DRYRUN would remove: $($file.FullName)"
        }

        Write-Output ''
        Write-Output 'Dry run complete. No files were changed.'
    }
    else {
        # Section: Per-file cleanup with rollback tracking.
        # This section handles each file independently with lock checks and try/catch isolation.
        $manifestRows = New-Object System.Collections.Generic.List[Object]

        foreach ($file in $uniqueCandidates) {
            try {
                if (-not (Test-Path -Path $file.FullName)) {
                    $summary.MissingSkipped++
                    Write-Log -Level 'INFO' -Message "File already missing, skip (idempotent): $($file.FullName)"
                    continue
                }

                if (Test-FileLocked -Path $file.FullName) {
                    $summary.LockedSkipped++
                    Write-Log -Level 'WARN' -Message "Locked or inaccessible, skipped: $($file.FullName)"
                    continue
                }

                $pathHash = Get-PathHash -Path $file.FullName
                $backupPath = Join-Path -Path $filesFolder -ChildPath ("$pathHash-$($file.Name)")

                if (Test-Path -Path $backupPath) {
                    $summary.MissingSkipped++
                    Write-Log -Level 'INFO' -Message "Backup already exists, skip (idempotent): $backupPath"
                    continue
                }

                Move-Item -Path $file.FullName -Destination $backupPath -Force -ErrorAction Stop
                $summary.Processed++

                $manifestRows.Add([pscustomobject]@{
                    OriginalPath = $file.FullName
                    BackupPath   = $backupPath
                    LastWriteUtc = $file.LastWriteTimeUtc.ToString('o')
                    LengthBytes  = $file.Length
                })

                Write-Log -Level 'INFO' -Message "Moved to rollback store: $($file.FullName)"
            }
            catch {
                $summary.Failed++
                Write-Log -Level 'ERROR' -Message "Failed processing '$($file.FullName)': $($_.Exception.Message)"
            }
        }

        if ($manifestRows.Count -gt 0) {
            $manifestRows | Export-Csv -Path $manifestPath -NoTypeInformation -Encoding UTF8
            Write-Log -Level 'INFO' -Message "Rollback manifest written: $manifestPath"
            Write-Output "Rollback batch id: $batchId"
        }
        else {
            Write-Log -Level 'INFO' -Message 'No files moved; rollback manifest not created.'
        }
    }
}

# Section: Final summary output.
# This section prints a concise run summary and points to the log file.
Write-Output ''
Write-Output '================ Cleanup Summary ================'
Write-Output ("Mode              : {0}" -f $summary.Mode)
Write-Output ("FilesScanned      : {0}" -f $summary.FilesScanned)
Write-Output ("EligibleFiles     : {0}" -f $summary.EligibleFiles)
Write-Output ("DryRunListed      : {0}" -f $summary.DryRunListed)
Write-Output ("Processed         : {0}" -f $summary.Processed)
Write-Output ("Restored          : {0}" -f $summary.Restored)
Write-Output ("LockedSkipped     : {0}" -f $summary.LockedSkipped)
Write-Output ("MissingSkipped    : {0}" -f $summary.MissingSkipped)
Write-Output ("Failed            : {0}" -f $summary.Failed)
Write-Output ("LogFile           : {0}" -f $script:LogFilePath)
Write-Output '==============================================='

Write-Log -Level 'INFO' -Message 'Run finished.'
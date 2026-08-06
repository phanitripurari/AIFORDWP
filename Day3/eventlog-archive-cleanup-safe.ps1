[CmdletBinding()]
param(
    # Dry run mode reports how many records would be removed without changing any event logs.
    [switch]$DryRun,

    # Only target logs whose newest event is older than this many days.
    [ValidateRange(0, 3650)]
    [int]$OlderThanDays = 3,

    # Event logs to evaluate for archive and cleanup.
    [string[]]$LogNames = @(
        'Application',
        'System',
        'Setup'
    ),

    # Root folder used to store archived event log files and manifests.
    [string]$ArchiveRoot = "$env:ProgramData\DWPEventLogArchive",

    # Folder where timestamped run logs are written.
    [string]$LogDirectory = "$PSScriptRoot\Logs",

    # Rollback mode restores archived .evtx files to a recovery folder for the selected batch.
    [switch]$Rollback,

    # Rollback batch id to restore from when -Rollback is used.
    [string]$RollbackId
)

# Section: Helper functions for logging, directory creation, safe file names, and external command execution.
# This section centralizes repeated operations so cleanup and rollback paths behave consistently.
function Write-Log {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Level,

        [Parameter(Mandatory = $true)]
        [string]$Message
    )

    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $line = "[$timestamp] [$Level] $Message"
    Add-Content -Path $script:LogFilePath -Value $line
    Write-Output $line
}

function Ensure-Directory {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    if (-not (Test-Path -Path $Path)) {
        New-Item -Path $Path -ItemType Directory -Force | Out-Null
    }
}

function Convert-ToSafeFileName {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name
    )

    return ($Name -replace '[\\/:*?"<>|]', '_')
}

function Invoke-NativeCommand {
    param(
        [Parameter(Mandatory = $true)]
        [string]$FilePath,

        [Parameter(Mandatory = $true)]
        [string[]]$Arguments,

        [Parameter(Mandatory = $true)]
        [string]$Description
    )

    & $FilePath @Arguments 2>&1 | ForEach-Object {
        if ($_ -and $_.ToString().Trim().Length -gt 0) {
            Write-Log -Level 'INFO' -Message ("{0}: {1}" -f $Description, $_.ToString().Trim())
        }
    }

    if ($LASTEXITCODE -ne 0) {
        throw ("Native command failed for {0} with exit code {1}." -f $Description, $LASTEXITCODE)
    }
}

# Section: Runtime initialization.
# This section creates required folders, starts a timestamped log file, and initializes summary counters.
Ensure-Directory -Path $LogDirectory

$runTimestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$modeName = if ($Rollback) { 'rollback' } else { 'cleanup' }
$script:LogFilePath = Join-Path -Path $LogDirectory -ChildPath ("eventlog-archive-$modeName-$runTimestamp.log")
New-Item -Path $script:LogFilePath -ItemType File -Force | Out-Null

$summary = [ordered]@{
    Mode               = $modeName
    LogsEvaluated      = 0
    LogsEligible       = 0
    RecordsDryRun      = 0
    LogsArchived       = 0
    LogsCleared        = 0
    RollbackRecovered  = 0
    SkippedRecent      = 0
    SkippedIdempotent  = 0
    Failed             = 0
}

Write-Log -Level 'INFO' -Message "Run started. Mode=$modeName DryRun=$DryRun OlderThanDays=$OlderThanDays"

# Section: Parameter validation.
# This section enforces supported combinations so behavior stays predictable and safe.
if ($Rollback -and $DryRun) {
    Write-Log -Level 'ERROR' -Message 'Dry run and rollback cannot be used together.'
    throw 'Use either cleanup with -DryRun or rollback with -Rollback, not both.'
}

if ($Rollback -and [string]::IsNullOrWhiteSpace($RollbackId)) {
    Write-Log -Level 'ERROR' -Message 'Rollback mode requires -RollbackId.'
    throw 'When using -Rollback, provide -RollbackId.'
}

Ensure-Directory -Path $ArchiveRoot

# Section: Rollback flow.
# This section restores archived .evtx files from a prior batch into a recovery folder.
# Windows does not provide a safe native way to repopulate cleared live logs, so rollback preserves archived data for review.
if ($Rollback) {
    $batchFolder = Join-Path -Path $ArchiveRoot -ChildPath (Join-Path -Path 'Batches' -ChildPath $RollbackId)
    $manifestPath = Join-Path -Path $batchFolder -ChildPath 'manifest.csv'
    $recoveryFolder = Join-Path -Path $ArchiveRoot -ChildPath (Join-Path -Path 'Recovered' -ChildPath $RollbackId)

    if (-not (Test-Path -Path $manifestPath)) {
        Write-Log -Level 'ERROR' -Message "Rollback manifest not found: $manifestPath"
        throw "Rollback manifest not found for batch id '$RollbackId'."
    }

    Ensure-Directory -Path $recoveryFolder
    $entries = Import-Csv -Path $manifestPath
    Write-Log -Level 'INFO' -Message "Loaded rollback manifest entries: $($entries.Count)"

    foreach ($entry in $entries) {
        try {
            $sourceArchive = $entry.ArchivePath
            $destinationArchive = Join-Path -Path $recoveryFolder -ChildPath ([System.IO.Path]::GetFileName($sourceArchive))

            if (-not (Test-Path -Path $sourceArchive)) {
                $summary.Failed++
                Write-Log -Level 'ERROR' -Message "Archive file missing for rollback: $sourceArchive"
                continue
            }

            if (Test-Path -Path $destinationArchive) {
                $summary.SkippedIdempotent++
                Write-Log -Level 'INFO' -Message "Rollback recovery file already exists, skip: $destinationArchive"
                continue
            }

            Copy-Item -Path $sourceArchive -Destination $destinationArchive -Force -ErrorAction Stop
            $summary.RollbackRecovered++
            Write-Log -Level 'INFO' -Message "Recovered archive copy: $destinationArchive"
        }
        catch {
            $summary.Failed++
            Write-Log -Level 'ERROR' -Message "Rollback failed for archive '$($entry.ArchivePath)': $($_.Exception.Message)"
        }
    }
}
else {
    # Section: Cleanup setup.
    # This section prepares batch storage so archive exports and manifests are tracked per run.
    $batchId = "eventlog-batch-$runTimestamp"
    $batchesRoot = Join-Path -Path $ArchiveRoot -ChildPath 'Batches'
    $dailyArchiveRoot = Join-Path -Path $ArchiveRoot -ChildPath 'Daily'
    $batchFolder = Join-Path -Path $batchesRoot -ChildPath $batchId
    $manifestPath = Join-Path -Path $batchFolder -ChildPath 'manifest.csv'
    $archiveDate = Get-Date -Format 'yyyyMMdd'
    $cutoff = (Get-Date).AddDays(-$OlderThanDays)
    $manifestRows = New-Object System.Collections.Generic.List[Object]

    Ensure-Directory -Path $batchesRoot
    Ensure-Directory -Path $dailyArchiveRoot

    if (-not $DryRun) {
        Ensure-Directory -Path $batchFolder
    }

    Write-Log -Level 'INFO' -Message "Cutoff timestamp: $cutoff"

    # Section: Event log evaluation and optional archive/cleanup.
    # This section only archives and clears logs when the newest event is older than the cutoff, which makes whole-log cleanup safe.
    foreach ($logName in $LogNames) {
        $summary.LogsEvaluated++

        try {
            $logInfo = Get-WinEvent -ListLog $logName -ErrorAction Stop
            $newestEvent = Get-WinEvent -LogName $logName -MaxEvents 1 -ErrorAction SilentlyContinue

            if (-not $newestEvent) {
                $summary.SkippedRecent++
                Write-Log -Level 'INFO' -Message "Log is empty or unreadable, skip: $logName"
                continue
            }

            if ($newestEvent.TimeCreated -ge $cutoff) {
                $summary.SkippedRecent++
                Write-Log -Level 'INFO' -Message "Log contains recent events and is skipped for safety: $logName"
                continue
            }

            $summary.LogsEligible++
            $recordCount = if ($logInfo.RecordCount) { [int64]$logInfo.RecordCount } else { 0 }
            $summary.RecordsDryRun += $recordCount

            if ($DryRun) {
                Write-Log -Level 'INFO' -Message "DRYRUN would archive and clear $recordCount records from log '$logName'."
                continue
            }

            $safeName = Convert-ToSafeFileName -Name $logName
            $archivePath = Join-Path -Path $dailyArchiveRoot -ChildPath ("{0}-{1}.evtx" -f $safeName, $archiveDate)

            if (Test-Path -Path $archivePath) {
                $summary.SkippedIdempotent++
                Write-Log -Level 'INFO' -Message "Today's archive already exists for log '$logName', skip: $archivePath"
                continue
            }

            try {
                Invoke-NativeCommand -FilePath 'wevtutil.exe' -Arguments @('epl', $logName, $archivePath) -Description "Export log '$logName'"
                $summary.LogsArchived++
                Write-Log -Level 'INFO' -Message "Archived log '$logName' to $archivePath"
            }
            catch {
                $summary.Failed++
                Write-Log -Level 'ERROR' -Message "Archive failed for log '$logName': $($_.Exception.Message)"
                continue
            }

            try {
                Invoke-NativeCommand -FilePath 'wevtutil.exe' -Arguments @('cl', $logName) -Description "Clear log '$logName'"
                $summary.LogsCleared++
                Write-Log -Level 'INFO' -Message "Cleared log '$logName' after archive."

                $manifestRows.Add([pscustomobject]@{
                    BatchId          = $batchId
                    LogName          = $logName
                    ArchivePath      = $archivePath
                    ArchivedOn       = (Get-Date).ToString('o')
                    RecordCount      = $recordCount
                    NewestEventUtc   = $newestEvent.TimeCreated.ToUniversalTime().ToString('o')
                    CutoffUtc        = $cutoff.ToUniversalTime().ToString('o')
                })
            }
            catch {
                $summary.Failed++
                Write-Log -Level 'ERROR' -Message "Clear failed for log '$logName': $($_.Exception.Message)"
            }
        }
        catch {
            $summary.Failed++
            Write-Log -Level 'ERROR' -Message "Failed evaluating log '$logName': $($_.Exception.Message)"
        }
    }

    if (-not $DryRun) {
        if ($manifestRows.Count -gt 0) {
            $manifestRows | Export-Csv -Path $manifestPath -NoTypeInformation -Encoding UTF8
            Write-Log -Level 'INFO' -Message "Manifest written: $manifestPath"
            Write-Output "Rollback batch id: $batchId"
        }
        else {
            Write-Log -Level 'INFO' -Message 'No logs were archived and cleared; no manifest created.'
        }
    }
}

# Section: End-of-run summary.
# This section prints the final counters and the location of the timestamped run log.
Write-Output ''
Write-Output '=============== Event Log Cleanup Summary ==============='
Write-Output ("Mode              : {0}" -f $summary.Mode)
Write-Output ("LogsEvaluated     : {0}" -f $summary.LogsEvaluated)
Write-Output ("LogsEligible      : {0}" -f $summary.LogsEligible)
Write-Output ("RecordsDryRun     : {0}" -f $summary.RecordsDryRun)
Write-Output ("LogsArchived      : {0}" -f $summary.LogsArchived)
Write-Output ("LogsCleared       : {0}" -f $summary.LogsCleared)
Write-Output ("RollbackRecovered : {0}" -f $summary.RollbackRecovered)
Write-Output ("SkippedRecent     : {0}" -f $summary.SkippedRecent)
Write-Output ("SkippedIdempotent : {0}" -f $summary.SkippedIdempotent)
Write-Output ("Failed            : {0}" -f $summary.Failed)
Write-Output ("LogFile           : {0}" -f $script:LogFilePath)
Write-Output '========================================================='

Write-Log -Level 'INFO' -Message 'Run finished.'
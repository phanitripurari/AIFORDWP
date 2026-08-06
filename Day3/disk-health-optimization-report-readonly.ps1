[CmdletBinding(PositionalBinding = $false)]
param(
    # Optional drive letters to scope analysis, for example C,D.
    [string[]]$DriveLetters,

    # Skip per-volume fragmentation analysis (defrag /A /V) and only report scheduler status.
    [switch]$SkipVolumeAnalysis,

    # Optional JSON export path for the combined report data.
    [string]$JsonPath
)

# Section: Logging helper.
function Write-Info {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message
    )

    Write-Output ("[{0}] {1}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Message)
}

function Convert-BytesToGB {
    param(
        [Parameter(Mandatory = $true)]
        [Int64]$Bytes
    )

    return [Math]::Round(($Bytes / 1GB), 2)
}

function Get-DefragTaskStatus {
    $result = [ordered]@{
        Exists       = $false
        State        = 'Unknown'
        LastRunTime  = $null
        LastTaskResult = $null
        NextRunTime  = $null
        Error        = $null
    }

    try {
        $task = Get-ScheduledTask -TaskPath '\\Microsoft\\Windows\\Defrag\\' -TaskName 'ScheduledDefrag' -ErrorAction Stop
        $taskInfo = Get-ScheduledTaskInfo -TaskPath '\\Microsoft\\Windows\\Defrag\\' -TaskName 'ScheduledDefrag' -ErrorAction Stop

        $result.Exists = $true
        $result.State = [string]$task.State
        $result.LastRunTime = $taskInfo.LastRunTime
        $result.LastTaskResult = $taskInfo.LastTaskResult
        $result.NextRunTime = $taskInfo.NextRunTime
    }
    catch {
        $result.Error = $_.Exception.Message
    }

    return [pscustomobject]$result
}

function Get-VolumeOptimizationAnalysis {
    param(
        [Parameter(Mandatory = $true)]
        [string]$DriveLetter
    )

    $volumeId = "${DriveLetter}:"
    $analysis = [ordered]@{
        DriveLetter             = $DriveLetter
        AnalysisCommand         = "defrag.exe $volumeId /A /V"
        TotalFragmentationPct   = $null
        AverageFragmentsPerFile = $null
        Recommendation          = 'Unknown'
        Success                 = $false
        Notes                   = $null
    }

    try {
        # Read-only analysis mode. /A analyzes only and never performs defragmentation.
        $output = & defrag.exe $volumeId /A /V 2>&1
        $lines = @($output | ForEach-Object { $_.ToString() })
        $text = ($lines -join [Environment]::NewLine)

        $matchPct = [regex]::Match($text, 'Total fragmentation\s*=\s*(\d+)%', [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
        if ($matchPct.Success) {
            $analysis.TotalFragmentationPct = [int]$matchPct.Groups[1].Value
        }

        $matchAvg = [regex]::Match($text, 'Average fragments per file\s*=\s*([0-9\.]+)', [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
        if ($matchAvg.Success) {
            $analysis.AverageFragmentsPerFile = [double]$matchAvg.Groups[1].Value
        }

        if ($text -match 'do not need to defragment this volume') {
            $analysis.Recommendation = 'No defragmentation needed'
        }
        elseif ($text -match 'should defragment this volume') {
            $analysis.Recommendation = 'Defragmentation recommended'
        }
        elseif ($text -match 'solid state disk|SSD') {
            $analysis.Recommendation = 'SSD detected; defrag typically not required'
        }

        $analysis.Success = $true

        if ($lines.Count -gt 0) {
            $analysis.Notes = ($lines | Select-Object -Last 2) -join ' | '
        }
    }
    catch {
        $analysis.Notes = $_.Exception.Message
    }

    return [pscustomobject]$analysis
}

# Section: Start and collect disk/volume health.
Write-Info 'Disk health and optimization report started (read-only mode).'

$physicalDiskData = @()
$diskData = @()
$volumeData = @()
$optimizationData = @()

try {
    if (Get-Command -Name Get-PhysicalDisk -ErrorAction SilentlyContinue) {
        $physicalDiskData = Get-PhysicalDisk |
            Select-Object FriendlyName, MediaType, HealthStatus, OperationalStatus, Size,
            @{ Name = 'SizeGB'; Expression = { Convert-BytesToGB -Bytes ([int64]$_.Size) } }
    }
}
catch {
    Write-Info ("WARN unable to query physical disks: {0}" -f $_.Exception.Message)
}

try {
    $diskData = Get-Disk |
        Select-Object Number, FriendlyName, PartitionStyle, OperationalStatus, HealthStatus,
        @{ Name = 'SizeGB'; Expression = { Convert-BytesToGB -Bytes ([int64]$_.Size) } },
        @{ Name = 'AllocatedGB'; Expression = { Convert-BytesToGB -Bytes ([int64]$_.AllocatedSize) } }
}
catch {
    Write-Info ("WARN unable to query logical disks: {0}" -f $_.Exception.Message)
}

try {
    $allVolumes = Get-Volume | Where-Object {
        $_.DriveLetter -and $_.DriveType -eq 'Fixed'
    }

    if ($DriveLetters -and $DriveLetters.Count -gt 0) {
        $normalized = $DriveLetters | ForEach-Object { $_.Trim(':').ToUpperInvariant() }
        $allVolumes = $allVolumes | Where-Object { $normalized -contains $_.DriveLetter.ToUpperInvariant() }
    }

    $volumeData = $allVolumes |
        Select-Object DriveLetter, FileSystemLabel, FileSystem, HealthStatus, OperationalStatus,
        @{ Name = 'SizeGB'; Expression = { Convert-BytesToGB -Bytes ([int64]$_.Size) } },
        @{ Name = 'FreeGB'; Expression = { Convert-BytesToGB -Bytes ([int64]$_.SizeRemaining) } },
        @{ Name = 'FreePct'; Expression = {
            if ($_.Size -gt 0) {
                [Math]::Round((([double]$_.SizeRemaining / [double]$_.Size) * 100), 2)
            }
            else {
                0
            }
        } }
}
catch {
    Write-Info ("WARN unable to query volumes: {0}" -f $_.Exception.Message)
}

# Section: Collect optimization status.
$taskStatus = Get-DefragTaskStatus

if (-not $SkipVolumeAnalysis) {
    foreach ($vol in $volumeData) {
        $optimizationData += Get-VolumeOptimizationAnalysis -DriveLetter $vol.DriveLetter
    }
}

# Section: Report output.
Write-Output ''
Write-Output '================ Disk Health Reporter ==================='
Write-Output ("Timestamp                : {0}" -f (Get-Date).ToString('yyyy-MM-dd HH:mm:ss'))
Write-Output ("ReadOnlyGuarantee        : Analysis only. No defrag operation is executed.")
Write-Output ("VolumesAnalyzed          : {0}" -f ($(if ($SkipVolumeAnalysis) { 0 } else { $optimizationData.Count })))
Write-Output '========================================================='
Write-Output ''

Write-Output '--- Scheduled Optimization Task Status ---'
$taskStatus | Format-List
Write-Output ''

if ($physicalDiskData -and $physicalDiskData.Count -gt 0) {
    Write-Output '--- Physical Disk Health ---'
    $physicalDiskData |
        Select-Object FriendlyName, MediaType, HealthStatus, OperationalStatus, SizeGB |
        Format-Table -AutoSize
    Write-Output ''
}

if ($diskData -and $diskData.Count -gt 0) {
    Write-Output '--- Disk Objects ---'
    $diskData |
        Select-Object Number, FriendlyName, PartitionStyle, HealthStatus, OperationalStatus, SizeGB, AllocatedGB |
        Format-Table -AutoSize
    Write-Output ''
}

if ($volumeData -and $volumeData.Count -gt 0) {
    Write-Output '--- Volume Health ---'
    $volumeData |
        Select-Object DriveLetter, FileSystemLabel, FileSystem, HealthStatus, OperationalStatus, SizeGB, FreeGB, FreePct |
        Format-Table -AutoSize
    Write-Output ''
}
else {
    Write-Output 'No fixed volumes found for reporting.'
    Write-Output ''
}

if (-not $SkipVolumeAnalysis) {
    Write-Output '--- Volume Optimization Analysis (Read-Only) ---'
    if ($optimizationData -and $optimizationData.Count -gt 0) {
        $optimizationData |
            Select-Object DriveLetter, TotalFragmentationPct, AverageFragmentsPerFile, Recommendation, Success |
            Format-Table -AutoSize
    }
    else {
        Write-Output 'No optimization analysis data collected.'
    }
    Write-Output ''
}

if (-not [string]::IsNullOrWhiteSpace($JsonPath)) {
    try {
        $parent = Split-Path -Path $JsonPath -Parent
        if (-not [string]::IsNullOrWhiteSpace($parent) -and -not (Test-Path -Path $parent)) {
            throw "JSON parent folder does not exist: $parent"
        }

        $payload = [ordered]@{
            TimestampUtc      = (Get-Date).ToUniversalTime().ToString('o')
            ReadOnlyGuarantee = 'No defragmentation or optimization action was run. Analysis only.'
            TaskStatus        = $taskStatus
            PhysicalDisks     = $physicalDiskData
            Disks             = $diskData
            Volumes           = $volumeData
            Optimization      = $optimizationData
        }

        $payload | ConvertTo-Json -Depth 6 | Set-Content -Path $JsonPath -Encoding UTF8
        Write-Info ("JSON report exported: {0}" -f $JsonPath)
    }
    catch {
        throw ("Failed to export JSON report: {0}" -f $_.Exception.Message)
    }
}

Write-Info 'Disk health and optimization report finished.'

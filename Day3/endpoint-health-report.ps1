# Endpoint health report for DWP engineers.
# This script is strictly read-only: it only queries local system information and writes results to the console.

function Show-Section {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Title
    )

    Write-Output ""
    Write-Output ("=" * 72)
    Write-Output $Title
    Write-Output ("=" * 72)
}

# Section 1: Displays how long the endpoint has been running since the last boot.
Show-Section -Title '1. System Uptime'

$operatingSystem = Get-CimInstance -ClassName Win32_OperatingSystem
$lastBoot = $operatingSystem.LastBootUpTime
$uptime = (Get-Date) - $lastBoot

[pscustomobject]@{
    ComputerName = $env:COMPUTERNAME
    LastBootTime = $lastBoot
    UptimeDays   = [math]::Floor($uptime.TotalDays)
    UptimeHours  = $uptime.Hours
    UptimeMins   = $uptime.Minutes
} | Format-List

# Section 2: Shows free disk space for local fixed disks only.
Show-Section -Title '2. Free Disk Space'

Get-CimInstance -ClassName Win32_LogicalDisk -Filter "DriveType = 3" |
    Select-Object DeviceID,
                  VolumeName,
                  @{Name = 'SizeGB'; Expression = { [math]::Round($_.Size / 1GB, 2) }},
                  @{Name = 'FreeGB'; Expression = { [math]::Round($_.FreeSpace / 1GB, 2) }},
                  @{Name = 'FreePercent'; Expression = {
                      if ($_.Size -gt 0) {
                          [math]::Round(($_.FreeSpace / $_.Size) * 100, 2)
                      }
                      else {
                          $null
                      }
                  }} |
    Format-Table -AutoSize

# Section 3: Checks common Windows registry locations that indicate a reboot is pending.
# VERIFY BEFORE RUNNING: Confirm these registry paths match the reboot-detection standard used in your estate.
Show-Section -Title '3. Pending Reboot Status'

$pendingRebootChecks = @(
    [pscustomobject]@{
        Check  = 'Component Based Servicing'
        Result = Test-Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending'
    }
    [pscustomobject]@{
        Check  = 'Windows Update Auto Update'
        Result = Test-Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired'
    }
    [pscustomobject]@{
        Check  = 'Pending File Rename Operations'
        Result = $null -ne (Get-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager' -Name 'PendingFileRenameOperations' -ErrorAction SilentlyContinue)
    }
)

$rebootPending = ($pendingRebootChecks | Where-Object { $_.Result }).Count -gt 0

[pscustomobject]@{
    RebootPending = $rebootPending
} | Format-List

$pendingRebootChecks | Format-Table -AutoSize

# Build a process-to-path lookup once so the process sections can show full executable paths.
$processPathById = @{}
Get-CimInstance -ClassName Win32_Process |
    ForEach-Object {
        $processPathById[$_.ProcessId] = $_.ExecutablePath
    }

# Section 4: Lists the five processes using the most physical memory based on working set.
Show-Section -Title '4. Top 5 Processes by Memory (Working Set)'

Get-Process |
    Sort-Object -Property WorkingSet64 -Descending |
    Select-Object -First 5 ProcessName,
                  Id,
                  @{Name = 'WorkingSetMB'; Expression = { [math]::Round($_.WorkingSet64 / 1MB, 2) }},
                  @{Name = 'ExecutablePath'; Expression = {
                      if ($_.Path) {
                          $_.Path
                      }
                      elseif ($processPathById[$_.Id]) {
                          $processPathById[$_.Id]
                      }
                      else {
                          '[unavailable]'
                      }
                  }} |
    Format-Table -AutoSize

# Section 5: Lists the five processes with the highest cumulative CPU time reported by Get-Process.
# VERIFY BEFORE RUNNING: This uses cumulative CPU seconds since process start, not live CPU percentage.
Show-Section -Title '5. Top 5 Processes by CPU'

Get-Process |
    Sort-Object -Property CPU -Descending |
    Select-Object -First 5 ProcessName,
                  Id,
                  @{Name = 'CpuSeconds'; Expression = { [math]::Round($_.CPU, 2) }},
                  @{Name = 'ExecutablePath'; Expression = {
                      if ($_.Path) {
                          $_.Path
                      }
                      elseif ($processPathById[$_.Id]) {
                          $processPathById[$_.Id]
                      }
                      else {
                          '[unavailable]'
                      }
                  }} |
    Format-Table -AutoSize

# Section 6: Reads the five most recent error entries from the System event log.
Show-Section -Title '6. Last 5 System Log Errors'

Get-WinEvent -FilterHashtable @{ LogName = 'System'; Level = 2 } -MaxEvents 5 |
    Select-Object TimeCreated,
                  Id,
                  ProviderName,
                  LevelDisplayName,
                  Message |
    Format-List
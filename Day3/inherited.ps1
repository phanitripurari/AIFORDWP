<#
Purpose:
- Collect and display quick endpoint health data for a human operator.
- Show computer details, free disk space, top memory processes, recent system errors, and stale user profile count.

Author:
- DWP Engineering (refactored for readability)

How to run:
- Open PowerShell 5.1.
- Navigate to the script folder.
- Execute: .\inherited.ps1

Notes:
- This script is read-only and only prints results to the console.
#>

# Get basic computer system information (name and physical memory).
$computerSystem = Get-CimInstance Win32_ComputerSystem

# Get free space on the C: drive in bytes.
$cDriveFreeBytes = Get-PSDrive C | Select-Object -ExpandProperty Free

# Get the top five running processes by working set memory (highest first).
$topProcessesByWorkingSet = Get-Process | Sort-Object WS -Descending | Select-Object -First 5

# Get the last ten System log events and keep only Error-level entries (Level 2).
$recentSystemErrorEvents = Get-WinEvent -LogName System -MaxEvents 10 | Where-Object { $_.Level -eq 2 }

# Get user profiles and start filtering for non-special profiles that have not been used in over 90 days.
$staleUserProfiles = Get-CimInstance Win32_UserProfile | Where-Object {
     # Keep profiles that are not special/system profiles and were last used more than 90 days ago.
     -not $_.Special -and $_.LastUseTime -lt (Get-Date).AddDays(-90)
}

# Print the computer name and total physical memory.
Write-Host $computerSystem.Name $computerSystem.TotalPhysicalMemory

# Convert C: free space from bytes to GB (2 decimals) and print it.
Write-Host ([math]::Round($cDriveFreeBytes / 1GB, 2)) 'GB free'

# Print each process name with its working set memory value.
$topProcessesByWorkingSet | ForEach-Object { Write-Host $_.Name $_.WS }

# Print each error event timestamp and message.
$recentSystemErrorEvents | ForEach-Object { Write-Host $_.TimeCreated $_.Message }

# If stale profiles were found, print how many.
if ($staleUserProfiles.Count -gt 0) { Write-Host 'Stale profiles:' $staleUserProfiles.Count }
# Temp Cleanup Script (Safe, PowerShell 5.1)

This document explains how to use `temp-cleanup-safe.ps1`.

## What the script does

- Cleans temp files from configured folders.
- Supports `-DryRun` so you can preview files before any change.
- Only targets files older than `-OlderThanDays` (default `0`).
- Skips locked/in-use files and continues.
- Handles errors per file with `try/catch`.
- Logs all actions to a timestamped log file.
- Prints an end-of-run summary.
- Supports rollback by batch id.
- Is idempotent (safe to run repeatedly).

## Script location

- `Day3/temp-cleanup-safe.ps1`

## Parameters

- `-DryRun`
  - Preview mode. Lists files that would be removed.
  - No file changes are made.

- `-OlderThanDays <int>`
  - Only files with `LastWriteTime` older than this are targeted.
  - Default: `0`.

- `-TargetPaths <string[]>`
  - One or more folders to scan recursively.
  - Default: current user temp and `C:\Windows\Temp`.

- `-RollbackRoot <string>`
  - Where rollback batches are stored.
  - Default: `$env:ProgramData\DWPTempCleanup\Rollback`.

- `-LogDirectory <string>`
  - Folder for timestamped log files.
  - Default: `Day3\Logs` (script folder relative).

- `-Rollback`
  - Switches script to rollback mode.

- `-RollbackId <string>`
  - Batch id to restore from.
  - Required with `-Rollback`.

## Example commands

Dry run preview:

```powershell
.\Day3\temp-cleanup-safe.ps1 -DryRun -OlderThanDays 7
```

Cleanup execution:

```powershell
.\Day3\temp-cleanup-safe.ps1 -OlderThanDays 7
```

Cleanup with custom targets:

```powershell
.\Day3\temp-cleanup-safe.ps1 -OlderThanDays 14 -TargetPaths @($env:TEMP, 'C:\Windows\Temp', 'C:\Temp')
```

Rollback by batch id:

```powershell
.\Day3\temp-cleanup-safe.ps1 -Rollback -RollbackId batch-20260805-120300
```

## How rollback works

During cleanup (non-dry-run), files are moved into a rollback batch folder and recorded in `manifest.csv`.

- Batch folder format: `batch-yyyyMMdd-HHmmss`
- Manifest file: `<RollbackRoot>\<BatchId>\manifest.csv`

To restore, run the script with `-Rollback -RollbackId <BatchId>`.

## Notes

- Some files may be skipped if locked or inaccessible.
- The script logs each action and error line-by-line.
- Re-running cleanup or rollback is safe; existing/missing items are skipped and logged.
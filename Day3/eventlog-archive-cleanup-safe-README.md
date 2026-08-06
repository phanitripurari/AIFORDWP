# Event Log Archive and Cleanup Script

This document explains how to use `eventlog-archive-cleanup-safe.ps1`.

## What the script does

- Evaluates selected Windows event logs.
- Only targets logs whose newest event is older than `-OlderThanDays`.
- Supports `-DryRun` to report how many records would be archived and cleared.
- Archives eligible logs to dated `.evtx` files.
- Clears only those fully stale logs after a successful archive.
- Logs every action to a timestamped log file.
- Prints a summary at the end.
- Skips a log if today's archive file already exists.

## Important platform note

Windows provides safe native export and clear operations for event logs, but it does not provide a safe native method to repopulate a cleared live log channel in PowerShell 5.1.

Because of that:

- Cleanup mode archives a log and then clears it only when the entire log is older than the cutoff.
- Rollback mode recovers the archived `.evtx` files for the selected batch into a recovery folder.
- Rollback does **not** put cleared records back into the live Windows event log.

This is the safest viable endpoint behavior for this requirement.

## Script location

- `Day3/eventlog-archive-cleanup-safe.ps1`

## Parameters

- `-DryRun`
  - Reports the count of records that would be cleared.
  - Makes no changes.

- `-OlderThanDays <int>`
  - Default: `3`.
  - A log is only eligible if its newest event is older than this threshold.

- `-LogNames <string[]>`
  - Logs to evaluate.
  - Default: `Application`, `System`, `Setup`.

- `-ArchiveRoot <string>`
  - Root folder for archive files, manifests, and recovered rollback copies.
  - Default: `$env:ProgramData\DWPEventLogArchive`.

- `-LogDirectory <string>`
  - Directory for timestamped script logs.
  - Default: `Day3\Logs`.

- `-Rollback`
  - Runs recovery mode for a prior batch.

- `-RollbackId <string>`
  - Required with `-Rollback`.
  - Identifies the batch manifest to recover.

## Example usage

Dry run:

```powershell
.\Day3\eventlog-archive-cleanup-safe.ps1 -DryRun
```

Dry run with a 7-day threshold:

```powershell
.\Day3\eventlog-archive-cleanup-safe.ps1 -DryRun -OlderThanDays 7
```

Run cleanup:

```powershell
.\Day3\eventlog-archive-cleanup-safe.ps1 -OlderThanDays 7
```

Run cleanup for specific logs:

```powershell
.\Day3\eventlog-archive-cleanup-safe.ps1 -OlderThanDays 14 -LogNames @('Application', 'System')
```

Recover archived files from a prior batch:

```powershell
.\Day3\eventlog-archive-cleanup-safe.ps1 -Rollback -RollbackId eventlog-batch-20260805-140500
```

## Where archives and rollback data are stored

- Daily archives:
  - `<ArchiveRoot>\Daily\<LogName>-yyyyMMdd.evtx`

- Batch manifests:
  - `<ArchiveRoot>\Batches\<BatchId>\manifest.csv`

- Rollback recovery copies:
  - `<ArchiveRoot>\Recovered\<BatchId>`

## Idempotency behavior

- If today's archive file already exists for a log, that log is skipped.
- If rollback recovery files already exist for a batch, they are skipped.
- If a log contains newer events than the cutoff, it is skipped for safety.

## Output and logging

- Each run writes a timestamped log file.
- Each run prints a summary including the log file path.
- Cleanup mode prints the rollback batch id when a manifest is created.
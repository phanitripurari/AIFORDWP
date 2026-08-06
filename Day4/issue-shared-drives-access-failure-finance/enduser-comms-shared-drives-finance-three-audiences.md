# End-User Communications: Finance Shared Drives Incident (Three Audiences)

## Audience 1: Non-Technical Executive
Your access is restored and your data is safe. At about 08:00, Finance shared drives became unavailable for 45 users after a drive-mapping change from user sign-in mode to system mode, which failed and did not assign the drive. We applied the fix, restored service, and confirmed recovery at 09:00; users can access shared drives and no further issues were reported. No action is needed unless you still cannot access shared drives.

## Audience 2: Affected End-User Team (10 People)
Your access is restored and your data is safe. At about 08:00, shared drives stopped working for 45 Finance users because a new automatic setup method ran in the wrong sign-in mode, failed, and did not create the drive. We applied the fix, restored service, and confirmed recovery at 09:00; users can access shared drives and no further issues were reported. If you see this again, contact the Service Desk and share your device name.

## Audience 3: Engineer-to-Engineer Internal Note
Access is restored and data is safe.

Root cause:
- Drive mapping migrated from GPO logon script (USER context) to Intune PowerShell script (SYSTEM context).
- In incident window, script executed as SYSTEM and failed UNC access to \\finbridge-fs01\Finance; drive mapping was not assigned.

Supporting evidence:
- 08:00:01 ScriptRunner: Executing Map-FinBridgeDrives.ps1.
- 08:00:02 ScriptRunner: Context = SYSTEM.
- 08:00:03 ScriptRunner Warning: UNC not accessible from SYSTEM.
- 08:00:03 ScriptRunner Error: Exit code 1, "Network name cannot be found."
- 08:00:04 ScriptRunner: No retry configured.
- 08:00:06 GroupPolicy 1500 success (not a GP processing failure).
- 08:00:07 Ntfs Event 98: S: drive letter not assigned.

Exact action taken:
- Applied the suggested remediation path to correct the mapping approach and restore user access to Finance shared drives.
- Service confirmed restored at 09:00.

Config detail:
- Previous model: GPO logon mapping in USER context.
- Migrated model: Intune script mapping in SYSTEM context.
- Failure path: SYSTEM-context script to \\finbridge-fs01\Finance.

Verification:
- Verified affected users can access shared drives after fix.
- No issues reported after 09:00.

Preventive action needed:
- Enforce execution-context compatibility validation before GPO-to-Intune mapping migrations.
- Require pilot validation before broad Finance rollout.
- Add monitoring for mapping script failures (non-zero exits), UNC access warnings, and drive-letter assignment failures (for example Ntfs Event 98).
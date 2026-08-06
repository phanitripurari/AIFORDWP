# RCA Report: Finance Shared Drives Access Failure

## Document Control
- Incident type: Multi-user shared drive access failure
- Service context: Drive mapping and SMB UNC access for Finance shares
- Affected user group: Finance team
- Affected scope: DESKTOP-FB* devices, OU=Finance
- Affected user count: 45 users
- Incident date: 2024-03-15
- RCA prepared date: 2026-08-06
- Final status: Resolved
- Resolution confirmed at: 09:00

## Executive Summary
At approximately 08:00, Finance users lost access to mapped shared drives. Evidence shows the drive mapping process had been migrated from a GPO logon script running in USER context to an Intune PowerShell script running in SYSTEM context, and the script failed in SYSTEM context when accessing the Finance UNC path. The script failure prevented drive-letter assignment for users. The suggested resolution was applied, access was restored, and service was verified as working at 09:00 with no further issues reported.

## Scope and Impact
- Impacted users: all Finance users (45).
- Impacted endpoints: DESKTOP-FB* devices in OU=Finance.
- User impact: users could not access shared drives required for Finance workflows.
- Business impact: team-wide interruption to shared-drive-dependent tasks during incident window.

## Supporting Evidence

### Intune Management Extension Log (Incident Window)
- 08:00:01 - ScriptRunner Info
  - Executing script: Map-FinBridgeDrives.ps1.

- 08:00:02 - ScriptRunner Info
  - Script context: SYSTEM account.

- 08:00:03 - ScriptRunner Warning
  - Network path \\finbridge-fs01\Finance not accessible from SYSTEM context at execution time.

- 08:00:03 - ScriptRunner Error
  - Map-FinBridgeDrives.ps1 failed.
  - Exit code: 1.
  - Error: Network name cannot be found.

- 08:00:04 - ScriptRunner Info
  - No retry configured.

### System Log (Sample Affected Endpoint: DESKTOP-FB041)
- 08:00:05 - Service Control Manager Event 7036
  - Workstation service entered running state.

- 08:00:06 - GroupPolicy Event 1500
  - Group Policy settings processed successfully.
  - Confirms this incident is not a Group Policy processing failure.

- 08:00:07 - Ntfs Event 98 (Warning)
  - File system could not map drive letter S:.
  - Drive letter not assigned.

### Change Record Evidence
- 2024-03-14 23:30 migration note:
  - Drive mapping script moved from GPO logon script (runs as USER) to Intune PowerShell script (runs as SYSTEM).
  - Script was not updated to handle SYSTEM context.
  - UNC path access and mapped credentials were not available to SYSTEM at login time.

### Recovery Confirmation Evidence
- Suggested resolution path was applied.
- Incident marked resolved at 09:00.
- Verified users were able to access shared drives.
- No issues reported after recovery.

## Evidence-Based Interpretation
- The failure was tightly time-aligned with the execution of a SYSTEM-context mapping script.
- The script explicitly failed on UNC path access from SYSTEM context.
- Group Policy processing remained successful, isolating the incident to drive-mapping execution context and script behavior rather than GPO failure.
- Drive-letter assignment failure (Ntfs Event 98) is consistent with mapping script failure.

## Incident Timeline
- 2024-03-14 23:30 - Change implemented: mapping migrated from GPO USER logon script to Intune SYSTEM script.
- ~08:00 - Finance users begin reporting inability to access shared drives.
- 08:00:01 - Mapping script starts (ScriptRunner).
- 08:00:02 - Script context confirmed as SYSTEM.
- 08:00:03 - UNC access warning and script failure (exit code 1, network name cannot be found).
- 08:00:04 - No retry configured logged.
- 08:00:05 - Workstation service running state logged.
- 08:00:06 - GroupPolicy Event 1500 success logged (GP healthy).
- 08:00:07 - Ntfs Event 98 shows S: mapping not assigned.
- 08:xx-08:59 - Suggested resolution actions executed.
- 09:00 - Service restored and verified; users confirmed shared-drive access, no further issues reported.

## Root Cause Statement
The drive mapping process was migrated to an Intune PowerShell script running as SYSTEM, but the mapping logic/target UNC access path was not compatible with SYSTEM execution at login time. As a result, the script failed and mapped drive assignment for users did not occur.

## Contributing Factors
- Execution context changed from USER to SYSTEM during migration.
- Script was not updated for SYSTEM-context behavior before rollout.
- No retry was configured after initial mapping failure.
- Broad Finance targeting propagated the same failure condition to all in-scope users.

## 5 Whys Analysis
1. Why could Finance users not access shared drives?
- Because mapped drive letters required for Finance shares were not created successfully.

2. Why were mapped drives not created?
- Because the drive mapping script failed during execution.

3. Why did the script fail?
- Because it ran in SYSTEM context and could not access the target UNC path as executed.

4. Why was it running in SYSTEM context?
- Because the mapping method was migrated from GPO user logon script to Intune PowerShell script configured to run as SYSTEM.

5. Why did this reach production impact?
- Because the migrated script was not made context-compatible before rollout and failure handling/retry was not configured.

## Resolution Actions Applied
1. Applied the suggested resolution path to restore drive access.
2. Corrected the mapping approach so Finance users regained access to required shared drives.
3. Revalidated shared-drive access with affected users.
4. Confirmed incident resolution at 09:00.

## Validation of Recovery
- Functional validation: verified users were able to access shared drives.
- Service validation: no subsequent issues were reported after 09:00.
- Scope validation: recovery confirmed for affected Finance user population.

## Preventive Actions

### Immediate
1. Require execution-context validation for any login/mapping script migration before production enablement.
2. Add a mandatory pilot step with representative Finance users before broad assignment.

### Near-Term
1. Add script guardrails:
- Explicit context check and fail-fast logging.
- Controlled retry behavior when initial mapping fails.
2. Add deployment gate requiring proof of successful UNC access and drive-letter assignment in user session.

### Long-Term
1. Standardize a migration checklist for GPO-to-Intune script moves that includes context-compatibility testing.
2. Add monitoring and alerts for mapping script failures (non-zero exit), UNC access warnings, and drive-letter assignment failures (such as Ntfs Event 98).
3. Add known-error/runbook entry documenting this event signature and recovery pattern.

## Residual Risk and Follow-Up
- Residual risk: other scripts migrated from user context to SYSTEM may carry similar context assumptions.
- Follow-up actions:
  - Audit other mapped-drive or profile-dependent scripts for context compatibility.
  - Maintain pilot-first rollout for future script context migrations.
  - Archive logs and timeline artifacts with incident record for reuse in future triage.

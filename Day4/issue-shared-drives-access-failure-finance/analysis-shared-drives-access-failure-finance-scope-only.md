# Scope-Only Ranked Hypotheses: Finance Shared Drives Access Failure

## Scope Facts Used
- Symptom: Finance team cannot access shared drives (45 users).
- Who: all Finance users affected (DESKTOP-FB* devices, OU=Finance).
- Since: about 08:00 this morning.
- Change: drive mapping moved from GPO logon script (runs as user) to Intune PowerShell script (runs as SYSTEM).

## Ranked Top 5 Likely Causes (Most Probable First)

### 1) Drive mapping now runs in SYSTEM context, so mappings are created for local system session, not the signed-in user
Why this fits scope facts:
- The timing aligns exactly with the script migration at user sign-in time.
- The scope is all Finance users, which matches a centrally changed deployment behavior.
- GPO logon scripts typically map in user context; changing to SYSTEM is a high-probability behavioral break for user-visible mapped drives.

Single fastest check:
- On an affected endpoint, compare mapped drives in user session (`net use`) versus SYSTEM context (run `net use` as SYSTEM); if only SYSTEM has mappings or user has none, this is strongly supported.

### 2) Intune script uses user-only variables or user profile paths that are invalid in SYSTEM context
Why this fits scope facts:
- Migration changed execution identity, so references like user SID/profile/home path can fail silently or resolve incorrectly.
- Broad impact across one business unit is consistent with one shared script logic path.

Single fastest check:
- Review Intune script execution output/status for one affected device and look for variable/path resolution failures under SYSTEM (for example unresolved `%HOMEDRIVE%`, `%USERNAME%`, or profile path issues).

### 3) Mapped drives are created outside Explorer/user token context and are not visible to users due to session/token boundary
Why this fits scope facts:
- Even if mapping command succeeds technically, users may still not see mapped letters when created in a different logon session/token.
- This aligns with universal user-facing failure immediately after switching script host/context.

Single fastest check:
- On one affected device, verify whether UNC path access works directly (`\\fileserver\share`) while mapped drive letters are missing; if UNC works but drive letters do not appear, session-context mapping visibility is likely.

### 4) Intune assignment/detection targeted Finance OU devices correctly, but script lacks per-user re-run at each sign-in
Why this fits scope facts:
- GPO logon script ran at each user sign-in; Intune device script cadence differs and may not execute in the needed user timing.
- Team-wide onset near 08:00 suggests morning sign-ins exposed lack of per-user drive mapping refresh.

Single fastest check:
- Check Intune run history for affected devices to confirm last execution time and frequency; if script did not run at user sign-in or only ran once device-side, this hypothesis is supported.

### 5) Share permission path expects user Kerberos context, but SYSTEM computer account cannot establish equivalent access/mapping flow
Why this fits scope facts:
- Migration to SYSTEM changed security principal from user to computer account.
- If mapping logic validates path/access in SYSTEM, it may fail where user access would have succeeded, causing team-wide break after change.

Single fastest check:
- From an affected endpoint test access to the target share once as signed-in user and once as SYSTEM; if user can access UNC but SYSTEM cannot, principal-context mismatch is likely.

## Notes
- This is a scope-fact hypothesis ranking only; no single root cause is confirmed yet.
- The checks above are the fastest confirm-or-eliminate tests for each hypothesis.

---

## Update: Event Evidence Review (Incident Window)

### Evidence Set Reviewed
- Source logs: Intune Management Extension log and System log.
- Scope: all Finance users (DESKTOP-FB* devices, OU=Finance).
- Key migration note: 2024-03-14 23:30 move from GPO user logon script to Intune script running as SYSTEM.

Key entries used:
- 08:00:01 ScriptRunner Info: Executing Map-FinBridgeDrives.ps1.
- 08:00:02 ScriptRunner Info: Script context is SYSTEM account.
- 08:00:03 ScriptRunner Warning: UNC path \\finbridge-fs01\Finance not accessible from SYSTEM context.
- 08:00:03 ScriptRunner Error: script failed, exit code 1, network name cannot be found.
- 08:00:04 ScriptRunner Info: no retry configured.
- 08:00:06 GroupPolicy Event 1500: policy processed successfully.
- 08:00:07 Ntfs Event 98 Warning: could not map drive letter S:, letter not assigned.

### Hypothesis-by-Hypothesis Judgement Against Event Evidence

1) Drive mapping runs in SYSTEM context and not user context
- Judgement: Support
- Determining evidence:
	- 08:00:02 ScriptRunner confirms SYSTEM execution context.
	- 08:00:03 ScriptRunner shows mapping failure in that context.
	- 08:00:07 Ntfs Event 98 confirms S: drive was not assigned.

2) Script uses user-only variables/paths invalid under SYSTEM
- Judgement: Support
- Determining evidence:
	- 08:00:02 ScriptRunner confirms SYSTEM context.
	- 08:00:03 ScriptRunner warning/error indicates path access failure in SYSTEM.
	- Migration note states script was not updated to handle SYSTEM context.

3) Mapping created outside user token/session visibility
- Judgement: Support
- Determining evidence:
	- 08:00:02 ScriptRunner shows non-user context execution.
	- 08:00:07 Ntfs Event 98 indicates mapped letter not available.
	- 08:00:06 GroupPolicy 1500 success indicates issue is mapping path/context, not GPO failure.

4) Intune cadence/assignment issue (not re-running per user sign-in)
- Judgement: Neutral
- Determining evidence:
	- 08:00:01 confirms script did execute.
	- 08:00:04 no-retry configuration may contribute to persistence, but evidence does not establish cadence as primary cause.

5) Share access requires user context and SYSTEM cannot perform equivalent mapping/access
- Judgement: Support
- Determining evidence:
	- 08:00:03 ScriptRunner warning states UNC not accessible from SYSTEM context.
	- 08:00:03 ScriptRunner error reports network name cannot be found.
	- Migration note explicitly cites missing mapped credentials in SYSTEM at login time.

## Surviving Hypothesis

Drive mapping was migrated to SYSTEM execution context, but the mapping process requires signed-in user context for reliable UNC access and user-visible mapped drive creation.

## Resolution Steps (Detailed)

1. Restore service quickly
- Disable the Intune device script deployment that runs mapping as SYSTEM.
- Re-enable the previous user-context mapping method temporarily to recover user access.

2. Implement permanent user-context mapping
- Replace SYSTEM-based mapping with a user-context implementation executed at user sign-in.
- Ensure targeting is user-based for Finance users, not only device-based.

3. Update script behavior
- Add pre-check for required network readiness before mapping.
- Add retry logic (for example short delayed retries) to handle early logon timing.
- Keep mapping idempotent: clear stale letter if needed, map target letter, and validate result.

4. Validate configuration and rollout
- Pilot on a small Finance user set, then expand to full Finance scope after success.
- Confirm script run status reports success across targeted users.

5. Technical verification on endpoints
- Confirm mapped drive letter appears in signed-in user session.
- Confirm direct UNC and mapped drive both work for affected users.
- Confirm no repeat of ScriptRunner failure at 08:00:03 pattern and no new Ntfs Event 98 drive-letter failure.

6. Prevent recurrence
- Add a mandatory change gate: any migration from GPO user script to Intune must include execution-context compatibility validation.
- Add pre-production test cases for user vs SYSTEM context, sign-in timing, and share access behavior.
- Add alerting for mapping script non-zero exits and spikes in drive mapping failure events.
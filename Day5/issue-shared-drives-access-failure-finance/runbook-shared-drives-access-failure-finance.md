# Title: Runbook: Finance Shared Drives Access Failure
- Version: 1.0
- Date: 07/08/2026
- Author: Sathishbabu
- Reviewed: self
- Status: draft
- Change: initial version from RCA

# Runbook: Finance Shared Drives Access Failure

## Purpose
Restore Finance shared-drive access when mapped drives fail because the mapping process is running in SYSTEM context and cannot reach the Finance share during user sign-in.

## Scope
- In scope: Finance users and Finance endpoints (DESKTOP-FB* in OU=Finance).
- Incident signature:
  - Intune Management Extension script runs as SYSTEM.
  - Script warning indicates \\finbridge-fs01\Finance is not reachable from SYSTEM context.
  - Script exits non-zero (exit code 1).
  - Users do not receive mapped drive letter (for example S:).
- Out of scope:
  - General network outages affecting all departments.
  - Credential lockout incidents unrelated to drive mapping.

## Permission Flag Legend
- [ELEVATED] = requires admin permissions in Intune and/or Active Directory Group Policy.

## 1. Prerequisites
1. Confirm your incident scope includes Finance users only and that multiple users are affected.
2. Confirm you have access to Microsoft Intune admin center. [ELEVATED]
3. Confirm you have access to Group Policy Management Console (GPMC) for the Finance OU. [ELEVATED]
4. Confirm you can read logs on one affected endpoint (for example DESKTOP-FB041). [ELEVATED]
5. Open your incident ticket and communication channel before making changes.
6. Identify one test Finance user account for validation after each change.
7. Capture the current assignment state before changes:
   - Intune script name: Map-FinBridgeDrives.ps1.
   - Current run context setting.
   - Assigned Entra groups.

## 2. Procedure (Junior-Friendly)
Follow each step exactly in order. Do not skip ahead.

### Phase A: Confirm the Incident Signature
1. On an affected endpoint, open Event Viewer -> Windows Logs -> System and confirm GroupPolicy Event ID 1500 succeeded in the incident window. [ELEVATED]
   - Why this step matters: proves this is not a full Group Policy failure.
   - Expected result: Event 1500 success exists near incident time.
2. On the same endpoint, verify drive S: is not present in File Explorer.
   - Why this step matters: confirms user-facing symptom.
   - Expected result: S: is missing or inaccessible.
3. In Intune admin center, go to Devices -> Scripts and remediations -> Platform scripts -> Windows.
4. Open Map-FinBridgeDrives.ps1 and review Device status / Run status for incident timestamps. [ELEVATED]
   - Expected result: failures are present with non-zero exit and SYSTEM context behavior.
5. In Intune Management Extension logs on an affected endpoint, confirm warning/error sequence:
   - Script context: SYSTEM account.
   - Network path \\finbridge-fs01\Finance not accessible.
   - Exit code 1.
   - Expected result: all three indicators are present.

### Phase B: Contain Impact Quickly
6. In Intune admin center, open Devices -> Scripts and remediations -> Platform scripts -> Windows -> Map-FinBridgeDrives.ps1 -> Assignments. [ELEVATED]
7. Remove the broad Finance production assignment temporarily (or move assignment to a small pilot group only). [ELEVATED]
   - Expected result: no new production devices receive the failing SYSTEM-context run.
8. Post a user update in incident communications: "We identified a login drive-mapping issue and started recovery actions."

### Phase C: Apply Stable Mapping Method
Use only one approved stable path from your environment standard. Path 1 is preferred for this incident profile.

9. Preferred Path 1: Restore Finance drive mapping through user logon GPO.
   - Open Group Policy Management Console -> Forest -> Domains -> <your-domain> -> Group Policy Objects -> Finance Drive Mapping Policy. [ELEVATED]
   - Go to User Configuration -> Windows Settings -> Scripts (Logon/Logoff) -> Logon.
   - Confirm mapping script exists and points to approved script path.
   - Link/enable the policy on OU=Finance if it was removed.
   - Expected result: policy is enabled and applied to Finance users.
10. Alternative Path 2: Keep Intune, but run in user context.
    - Open Intune admin center -> Devices -> Scripts and remediations -> Platform scripts -> Windows -> Map-FinBridgeDrives.ps1 -> Properties. [ELEVATED]
    - Edit settings and set Run this script using the logged on credentials = Yes.
    - Save, then assign first to a pilot group (not all Finance users).
    - Expected result: script executes in user context for pilot users.
11. Force policy/script refresh on 1 to 3 pilot endpoints.
    - GPO path: run gpupdate /force in elevated command prompt. [ELEVATED]
    - Intune path: Company Portal sync or Intune device sync from portal. [ELEVATED]
    - Expected result: refresh completes successfully.
12. Sign out and sign in as a pilot Finance user.
    - Expected result: mapped drive (for example S:) appears and opens shared folders.

### Phase D: Controlled Reopen to Full Finance Scope
13. If pilot succeeds, expand assignment in stages:
    - Stage 1: 10 users.
    - Stage 2: 25 users.
    - Stage 3: all Finance users.
14. After each stage, wait 10 minutes and check service desk queue for new failures.
15. If no spike is detected, continue to next stage.
16. Update the incident ticket with timestamps for containment, pilot pass, and full restore.

## 3. Verification
1. Functional check with at least 5 Finance users across different devices.
   - Pass condition: all 5 users can open mapped drive and browse files.
2. Endpoint check on at least 3 Finance devices.
   - Pass condition: drive letter is present after sign-in.
3. Intune script check (if Intune path used).
   - Pass condition: run status shows Success for pilot/targeted users.
4. Event check on one sample endpoint.
   - Pass condition: no new mapping failure errors in incident window after fix.
5. Service desk check for 30 minutes after restore.
   - Pass condition: no new Finance shared-drive incidents.

## 4. Rollback (Specific Portal/Console Paths)
Use this immediately if user impact worsens after any remediation step.

1. Open Intune admin center -> Devices -> Scripts and remediations -> Platform scripts -> Windows -> Map-FinBridgeDrives.ps1 -> Assignments. [ELEVATED]
2. Remove all production assignments from Finance groups and keep only a disabled or empty assignment. [ELEVATED]
   - Expected result: failing script stops running for production users.
3. Open Group Policy Management Console -> Forest -> Domains -> <your-domain> -> Group Policy Objects -> Finance Drive Mapping Policy. [ELEVATED]
4. Navigate to User Configuration -> Windows Settings -> Scripts (Logon/Logoff) -> Logon.
5. Re-enable last known-good logon script entry and verify script path availability in SYSVOL. [ELEVATED]
   - Expected result: known-good user-context mapping method is active.
6. In GPMC, confirm policy link:
   - Group Policy Management -> Domains -> <your-domain> -> OU=Finance -> Linked Group Policy Objects.
   - Ensure Finance Drive Mapping Policy is linked and enabled.
7. On one pilot device in Finance OU, run gpupdate /force and sign out/sign in. [ELEVATED]
   - Expected result: mapped drive returns for pilot user.
8. After pilot success, communicate user instruction to reconnect/sign out-sign in.
9. Log rollback completion in ticket with this template:
   - "Rollback complete: Intune assignment removed, Finance GPO logon script restored, pilot validated, <UTC timestamp>."
10. Keep Intune script unassigned until post-incident review and change approval are complete.

## 5. Notes
- This incident is about execution context mismatch (SYSTEM versus signed-in user).
- Successful Group Policy processing does not guarantee drive mapping success if mapping moved to a different tool/context.
- Avoid all-user rollout for mapping changes without pilot validation.
- Related artifact:
  - Day4/issue-shared-drives-access-failure-finance/rca-shared-drives-access-failure-finance-2024-03-15.md
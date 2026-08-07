# KB: Finance Shared Drives Access Failure (Drive Mapping Context Mismatch)

- Version: 1.0
- Date: 07/08/2026
- Status: Draft

## Background
Finance users depend on mapped shared drives at sign-in for daily processing. In this incident class, mapping fails after migration from a user logon method (GPO) to an Intune script running in SYSTEM context. The script can fail before user-context network access is available, so drive letters are not created.

## Symptom
What users report:
- "My Finance drive is missing."
- "I signed in, but shared folders are not there."
- "Everyone on the team has the same issue."

What the engineer observes:
- Concentrated impact in Finance scope.
- Intune script run around login with failure status.
- Missing mapped drive letter (for example S:) on endpoints.
- Group Policy processing can still show success (Event ID 1500).

## Root Cause
Drive mapping was migrated from GPO user logon script to Intune PowerShell script running as SYSTEM. Script logic and target path access were not compatible with SYSTEM execution at login time, so mapping failed and no drive letter was assigned.

Evidence pattern to confirm:
- Intune script execution in SYSTEM context.
- Warning: \\finbridge-fs01\Finance not accessible from SYSTEM context.
- Script exit code 1.
- Endpoint shows no mapped S: drive for affected user.

## Detection (3-Minute Confirmation)
Target time: 3 minutes maximum.

1. Confirm user symptom in 20 seconds.
- On one affected device, open File Explorer and check if Finance mapped drive (for example S:) is missing or inaccessible.
- Pass condition: mapped drive is missing/inaccessible.

2. Open the exact endpoint log source in 30 seconds. [ELEVATED]
- Open Intune Management Extension log file: C:\ProgramData\Microsoft\IntuneManagementExtension\Logs\IntuneManagementExtension.log.
- Search the current incident window for script name Map-FinBridgeDrives.ps1.
- Pass condition: you find the script execution block for incident time.

3. Confirm the three required failure signals in 60 seconds.
- In the same script execution block, confirm all three strings:
  - context indicates SYSTEM account
  - "\\finbridge-fs01\Finance" with "not accessible"
  - non-zero exit (for example "Exit code: 1")
- Pass condition: all three signals appear in the same run window.

4. Rule out GP engine failure in 30 seconds. [ELEVATED]
- Open Event Viewer -> Windows Logs -> System -> Filter Current Log -> Event sources: GroupPolicy -> Event ID: 1500.
- Confirm Event ID 1500 success near incident time.
- Pass condition: Event ID 1500 success exists, indicating GP processed normally.

5. Confirm service-level scope in 40 seconds.
- In Intune admin center -> Devices -> Scripts and remediations -> Platform scripts -> Windows -> Map-FinBridgeDrives.ps1 -> Device status, check multiple Finance devices in same time window. [ELEVATED]
- Pass condition: multiple Finance devices show failure/non-zero run result in the same window.

Classification rule (binary):
- Confirm this incident as Finance shared-drive context mismatch only when all are true: S: missing + IME log shows SYSTEM context + path-not-accessible + exit code 1 + GP Event 1500 success + multi-device Finance failures.
- If any one item is missing, do not classify yet; continue with alternate diagnosis (network path outage, permissions, DFS/share availability, or profile-specific mapping issue).

## Resolution
Target time: 5 to 10 minutes to restore service.

### Rapid Path (Use This Order)
1. Start containment immediately in Intune: Intune admin center -> Devices -> Scripts and remediations -> Platform scripts -> Windows -> Map-FinBridgeDrives.ps1 -> Assignments -> Edit. [ELEVATED]
- Action: remove/pause broad Finance assignment (keep only empty or pilot scope), then Save.
- Expected result: no new devices receive failing SYSTEM-context runs.

2. Restore known-good user-context mapping via GPMC: Group Policy Management Console -> Domains -> <your-domain> -> Group Policy Objects -> Finance Drive Mapping Policy -> User Configuration -> Windows Settings -> Scripts (Logon/Logoff) -> Logon. [ELEVATED]
- Action: confirm approved mapping script is enabled and path is valid.
- Expected result: user logon script method is active.

3. Confirm OU link in GPMC: Group Policy Management -> Domains -> <your-domain> -> OU=Finance -> Linked Group Policy Objects. [ELEVATED]
- Action: ensure Finance Drive Mapping Policy is Linked = Yes and Enabled = Yes.
- Expected result: Finance users receive the restored policy.

4. Force one pilot refresh now: on 1 to 2 Finance endpoints run gpupdate /force, then sign out/sign in once. [ELEVATED]
- Expected result: mapped drive (S:) appears and opens \\finbridge-fs01\Finance.

5. Expand in two fast rings after pilot pass.
- Ring 1: first 10 users; Ring 2: remaining Finance users.
- Expected result: no new mapping failures during expansion window.

### If GPO Cannot Be Used (Fallback)
6. Intune admin center -> Devices -> Scripts and remediations -> Platform scripts -> Windows -> Map-FinBridgeDrives.ps1 -> Properties -> Edit settings. [ELEVATED]
- Action: set Run this script using the logged on credentials = Yes, Save, assign pilot first.
- Expected result: script runs in user context and creates S: for pilot users.

## Verification
Complete these checks in sequence; total check time target is under 3 minutes for initial restore confirmation.

1. Pilot functional check.
- On 2 pilot devices, sign in and open S: then open a known Finance folder.
- Pass condition: 2 of 2 succeed within 60 seconds each.

2. Quick portal health check.
- If Intune script is still used: Intune admin center -> Devices -> Scripts and remediations -> Platform scripts -> Windows -> Map-FinBridgeDrives.ps1 -> Device status. [ELEVATED]
- Pass condition: latest pilot runs show Success and no new non-zero exits.

3. Scope confirmation check.
- Service desk queue filter: Finance + shared drive + last 15 minutes.
- Pass condition: incident trend flat or dropping; no new spike.

4. Closure evidence check.
- Ticket must include UTC timestamps for: containment, pilot pass, ring expansion start, full restore confirmation.
- Pass condition: all four timestamps and chosen method (GPO or Intune user-context) are recorded.

## Rollback
Use rollback if new errors increase or pilot fails after remediation change.

1. Stop failing deployments first: Intune admin center -> Devices -> Scripts and remediations -> Platform scripts -> Windows -> Map-FinBridgeDrives.ps1 -> Assignments -> Edit -> remove all production Finance targets -> Save. [ELEVATED]
- Expected result: failing script no longer deploys to production users.

2. Re-enable known-good GPO mapping: Group Policy Management Console -> Domains -> <your-domain> -> Group Policy Objects -> Finance Drive Mapping Policy -> User Configuration -> Windows Settings -> Scripts (Logon/Logoff) -> Logon. [ELEVATED]
- Expected result: last known-good logon script is enabled.

3. Reconfirm OU link: Group Policy Management -> Domains -> <your-domain> -> OU=Finance -> Linked Group Policy Objects. [ELEVATED]
- Expected result: Finance Drive Mapping Policy is linked and enabled.

4. Validate rollback on one pilot endpoint: run gpupdate /force, sign out/sign in, verify S: access. [ELEVATED]
- Expected result: pilot endpoint mapping restored.

5. Trigger user recovery message and document.
- Send guidance to Finance users: sign out/sign in once to reload mapping.
- Ticket entry required: "Rollback complete: Intune production assignment removed; GPO mapping restored; pilot validated; <UTC timestamp>."

## Preventive Controls
1. Mandatory context check before production rollout.
- Owner: release engineer. Timing: before deployment. Mode: manual (automatable).
- Signal and pass: pre-release test on 3 pilot endpoints shows script runs in user context and creates S: drive in all 3 sessions; fail if any run executes as SYSTEM or any S: is missing.
- Action on fail: block release and return script to change author for context fix. Automation note: enforce with CI gate parsing test output. [REQUIRES: CI/CD gate for endpoint script validation]

2. Pilot-first assignment enforcement.
- Owner: change manager. Timing: during deployment. Mode: manual with portal evidence.
- Signal and pass: Stage 1 (10 users) for 30 minutes has Intune script success rate >= 95 percent and 0 new Finance drive incidents; fail if success < 95 percent or >= 1 incident.
- Action on fail: stop rollout, remove broad assignment, execute rollback path, and keep pilot-only scope.

3. Script guardrails in mapping script.
- Owner: DWP engineer. Timing: before deployment. Mode: automated at runtime.
- Signal and pass: script logs explicit Context=<User|System>, PathCheck=<OK|Fail>, RetryCount, and exits 0 only when S: mapping succeeds; fail on missing guardrail fields or non-zero exit.
- Action on fail: auto-write failure marker and notify service desk queue. [REQUIRES: standardized script logging schema and log ingestion]

4. Deployment gate evidence for path and drive creation.
- Owner: release engineer. Timing: before deployment. Mode: manual (automatable).
- Signal and pass: evidence pack contains timestamped proof for \\finbridge-fs01\Finance access and S: drive creation from 2 user sessions; fail if either proof artifact is missing.
- Action on fail: do not approve production assignment. Automation note: collect proofs via scripted test harness. [REQUIRES: evidence checklist in change template]

5. In-flight monitoring and alerting during rollout window.
- Owner: DWP engineer. Timing: during deployment. Mode: automated.
- Signal and pass: in 10-minute bins, Intune script non-zero exits remain < 3 across Finance scope and warnings containing "not accessible" for \\finbridge-fs01\Finance remain < 3; fail at either threshold.
- Action on fail: auto-page on-call and auto-open incident with severity according to major incident policy. [REQUIRES: Intune log forwarding + alert rules]

6. Audit similar migrated scripts for context risk.
- Owner: image owner. Timing: after deployment. Mode: manual (automatable).
- Signal and pass: 100 percent of scripts migrated USER->SYSTEM in last 90 days have recorded context-compatibility test evidence; fail if any script lacks evidence.
- Action on fail: freeze further script migrations until missing evidence is completed. Automation note: run weekly inventory query and exception report. [REQUIRES: script migration inventory process]

7. Pre-deployment smoke test gate (added gap layer).
- Owner: release engineer. Timing: before deployment. Mode: automated (manual fallback).
- Signal and pass: smoke test executes sign-in, validates S: exists, and opens \\finbridge-fs01\Finance on 1 canary device with 0 errors; fail on any mapping or open-path error.
- Action on fail: block release and require defect ticket before next window. [REQUIRES: canary smoke test job]

8. Post-deployment validation before change closure (added gap layer).
- Owner: change manager. Timing: after deployment. Mode: manual with scripted checks.
- Signal and pass: 5 of 5 user validations succeed, 3 of 3 sampled endpoints show mapped drive at first sign-in, and 30-minute queue check shows 0 new incidents; fail if any metric misses.
- Action on fail: keep change open, revert to containment state, and continue remediation.

9. Rollback trigger threshold (added gap layer).
- Owner: DWP engineer. Timing: during deployment. Mode: automated (manual fallback).
- Signal and pass: maintain non-zero script exits < 3 per 10 minutes and service desk reports < 3 Finance tickets per 15 minutes; fail if either threshold is met/exceeded.
- Action on fail: trigger rollback immediately (remove Intune assignment, restore GPO mapping), then notify change bridge. [REQUIRES: ITSM-volume alert and rollback runbook integration]

10. Knowledge update control (added gap layer).
- Owner: service desk lead. Timing: after deployment. Mode: manual.
- Signal and pass: runbook, L1 KB, and L2/L3 KB are updated and linked in the closed change within 2 business days; fail if any link/artifact is missing.
- Action on fail: reject change closure and open documentation action item. Automation note: enforce with mandatory closure checklist field.

## Related
- RCA source: Day4/issue-shared-drives-access-failure-finance/rca-shared-drives-access-failure-finance-2024-03-15.md
- Operational runbook: Day5/runbook-shared-drives-access-failure-finance.md
- End-user guide: Day5/kb-self-service-finance-shared-drives-access.md
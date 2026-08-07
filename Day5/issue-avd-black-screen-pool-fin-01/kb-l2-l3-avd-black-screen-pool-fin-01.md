# KB: AVD Black Screen After Login (POOL-FIN-01)

- Version: 1.0
- Date: 07/08/2026
- Status: Draft

## Background
Azure Virtual Desktop (AVD) provides Finance users with their daily working desktop. Users authenticate through AVD and are assigned to a desktop in the Finance pool. This service is business-critical during start-of-day because Finance teams depend on immediate desktop access for payment, reconciliation, and reporting workflows. A post-login black screen is a high-impact degradation because authentication appears successful but users cannot work.

## Symptom
What users report:
- "I can log in but I only see a black screen."
- "Sometimes it clears after around 30 seconds; sometimes it keeps disconnecting."
- "I can reconnect, but it happens again."

What the engineer observes:
- Issue concentrated on POOL-FIN-01.
- POOL-FIN-02 remains healthy during the same time window.
- Reconnect loops on affected users.
- Event sequence on affected hosts: Event 21 (logon success) -> Event 1000 (dwm.exe crash in igdumd64.dll) -> Event 9009 (DWM exit) -> Event 40 (session disconnect).

## Root Cause
A regression introduced by an overnight update on POOL-FIN-01 caused Desktop Window Manager (dwm.exe) to crash in igdumd64.dll with exception 0xc0000005 during post-login desktop rendering.

Evidence confirming root cause:
- Affected host (example SHFIN-01-A) in incident window:
  - Microsoft-Windows-TerminalServices-LocalSessionManager, Event ID 21, logon succeeded.
  - Application log, Source Application Error, Event ID 1000, Faulting application name = dwm.exe, Faulting module name = igdumd64.dll, Exception code = 0xc0000005.
  - Application log, Source Desktop Window Manager, Event ID 9009, DWM exited.
  - Microsoft-Windows-TerminalServices-LocalSessionManager, Event ID 40, user disconnected.
- Control host (example SHFIN-02-A, POOL-FIN-02) in same window:
  - Event ID 21 present.
  - Desktop Window Manager Event ID 9011 (start success) present.
  - No matching Application Error Event ID 1000 for dwm.exe + igdumd64.dll.

## Detection
Target time: under 3 minutes. Use commands, not Event Viewer clicking.

1. Open Azure Portal -> Azure Virtual Desktop -> Host pools -> POOL-FIN-01 -> Session hosts -> click symptomatic VM (example SHFIN-01-A) -> Run command -> RunPowerShellScript. [ELEVATED]
- Exact log location to query: Application log.
- Expected result: RunPowerShellScript pane is open on SHFIN-01-A.

2. Run this command on SHFIN-01-A to find Application Event 1000 with the required faulting module:
`Get-WinEvent -FilterHashtable @{LogName='Application'; Id=1000; StartTime=(Get-Date).AddHours(-6)} | Where-Object { $_.Message -match 'Faulting application name:\s*dwm.exe' -and $_.Message -match 'Faulting module name:\s*igdumd64.dll' } | Select-Object -First 5 TimeCreated, Id, ProviderName, Message | Format-List` [ELEVATED]
- Exact fields to confirm in output Message:
  - Event ID: 1000
  - Faulting application name: dwm.exe
  - Faulting module name: igdumd64.dll
- Expected result: At least 1 matching event is returned.

3. Run this command on SHFIN-01-A to find Application Event 9009:
`Get-WinEvent -FilterHashtable @{LogName='Application'; ProviderName='Microsoft-Windows-Desktop Window Manager'; Id=9009; StartTime=(Get-Date).AddHours(-6)} | Select-Object -First 5 TimeCreated, Id, ProviderName, Message | Format-List` [ELEVATED]
- Exact fields to confirm:
  - Event ID: 9009
  - ProviderName: Microsoft-Windows-Desktop Window Manager
- Expected result: At least 1 matching event is returned, with timestamps close to Event 1000.

4. Open Azure Portal -> Azure Virtual Desktop -> Host pools -> POOL-FIN-02 -> Session hosts -> click control VM (example SHFIN-02-A) -> Run command -> RunPowerShellScript. [ELEVATED]
- Exact log location to query: Application log.
- Expected result: RunPowerShellScript pane is open on SHFIN-02-A.

5. Run this command on SHFIN-02-A to confirm healthy baseline Event 9011:
`Get-WinEvent -FilterHashtable @{LogName='Application'; ProviderName='Microsoft-Windows-Desktop Window Manager'; Id=9011; StartTime=(Get-Date).AddHours(-6)} | Select-Object -First 5 TimeCreated, Id, ProviderName, Message | Format-List` [ELEVATED]
- Exact field to confirm:
  - Event ID: 9011
- Expected result: At least 1 Event 9011 is returned.

6. Run this command on SHFIN-02-A to confirm absence of the crash signature:
`(Get-WinEvent -FilterHashtable @{LogName='Application'; Id=1000; StartTime=(Get-Date).AddHours(-6)} | Where-Object { $_.Message -match 'Faulting application name:\s*dwm.exe' -and $_.Message -match 'Faulting module name:\s*igdumd64.dll' } | Measure-Object).Count` [ELEVATED]
- Exact field condition:
  - Event ID 1000 where module is igdumd64.dll
- Expected result: Count = 0.

Classification rule before acting:
- Confirm this incident only when POOL-FIN-01 has Application Event 1000 (dwm.exe + igdumd64.dll) and Application Event 9009, while POOL-FIN-02 shows Application Event 9011 and zero matching Event 1000 signature.

## Resolution
Target time: 5 to 10 minutes for containment plus canary recovery.

Set these variables once in Azure CLI:
```bash
RG="<resource-group>"
HP_BAD="POOL-FIN-01"
HP_GOOD="POOL-FIN-02"
CANARY="SHFIN-01-A"
BASELINE_IMAGE="10.0.22621.2861-build-20240313"
```

1. Open Azure Portal path Azure Virtual Desktop -> Host pools -> POOL-FIN-01 -> Session hosts and identify all session host names. [ELEVATED]
- Option to set in this page: Allow new session.
- Azure CLI fast path:
```bash
az desktopvirtualization session-host list -g "$RG" --host-pool-name "$HP_BAD" --query "[].name" -o tsv
```
- Expected result: Full list of POOL-FIN-01 session hosts is visible.

2. Set Allow new session = No on all POOL-FIN-01 session hosts from Azure Portal path Azure Virtual Desktop -> Host pools -> POOL-FIN-01 -> Session hosts. [ELEVATED]
- Azure CLI fast path:
```bash
for h in $(az desktopvirtualization session-host list -g "$RG" --host-pool-name "$HP_BAD" --query "[].name" -o tsv); do
  az desktopvirtualization session-host update -g "$RG" --host-pool-name "$HP_BAD" --name "$h" --allow-new-session false
done
```
- Expected result: Every POOL-FIN-01 host shows Allow new session = No.

3. Set Allow new session = Yes on healthy POOL-FIN-02 hosts from Azure Portal path Azure Virtual Desktop -> Host pools -> POOL-FIN-02 -> Session hosts. [ELEVATED]
- Azure CLI fast path:
```bash
for h in $(az desktopvirtualization session-host list -g "$RG" --host-pool-name "$HP_GOOD" --query "[?status=='Available'].name" -o tsv); do
  az desktopvirtualization session-host update -g "$RG" --host-pool-name "$HP_GOOD" --name "$h" --allow-new-session true
done
```
- Expected result: Healthy POOL-FIN-02 hosts show Allow new session = Yes and receive new logons.

4. Choose canary host SHFIN-01-A from Azure Portal path Azure Virtual Desktop -> Host pools -> POOL-FIN-01 -> Session hosts. [ELEVATED]
- Azure CLI fast check:
```bash
az desktopvirtualization session-host show -g "$RG" --host-pool-name "$HP_BAD" --name "$CANARY"
```
- Expected result: Canary host selected and recorded in incident ticket.

5. Start canary image rollback to baseline in your image platform from Azure Portal path Resource groups -> <resource-group> -> Virtual machines -> SHFIN-01-A -> Settings/Operations -> Image/Reimage workflow (or your approved image-management console mapped to this VM). [ELEVATED]
- Required option: select baseline image version 10.0.22621.2861-build-20240313.
- Expected result: Canary image rollback job enters Running then Succeeded.

6. Confirm canary VM health in Azure Portal path Virtual machines -> SHFIN-01-A -> Overview. [ELEVATED]
- Required fields: Provisioning state, Power state.
- Azure CLI fast path:
```bash
az vm get-instance-view -g "$RG" -n "$CANARY" --query "{power:instanceView.statuses[?starts_with(code,'PowerState/')].displayStatus|[0],provisioning:provisioningState}" -o table
```
- Expected result: Provisioning state = Succeeded and Power state = VM running.

7. Reopen only canary in Azure Portal path Azure Virtual Desktop -> Host pools -> POOL-FIN-01 -> Session hosts by setting SHFIN-01-A Allow new session = Yes and all others remain No. [ELEVATED]
- Azure CLI fast path:
```bash
az desktopvirtualization session-host update -g "$RG" --host-pool-name "$HP_BAD" --name "$CANARY" --allow-new-session true
```
- Expected result: Only canary can accept new sessions in POOL-FIN-01.

8. Validate canary crash signature is gone by running command in Azure Portal path Virtual machines -> SHFIN-01-A -> Run command -> RunPowerShellScript. [ELEVATED]
- Azure CLI fast path:
```bash
az vm run-command invoke -g "$RG" -n "$CANARY" --command-id RunPowerShellScript --scripts "(Get-WinEvent -FilterHashtable @{LogName='Application'; Id=1000; StartTime=(Get-Date).AddMinutes(-15)} | Where-Object { $_.Message -match 'Faulting application name:\s*dwm.exe' -and $_.Message -match 'Faulting module name:\s*igdumd64.dll' } | Measure-Object).Count"
```
- Expected result: Count = 0.

9. Apply baseline image rollback to remaining POOL-FIN-01 hosts using the same image workflow used in Step 5. [ELEVATED]
- Required option: baseline image version 10.0.22621.2861-build-20240313.
- Expected result: All remaining rollback jobs complete Succeeded.

10. Reopen all POOL-FIN-01 hosts in Azure Portal path Azure Virtual Desktop -> Host pools -> POOL-FIN-01 -> Session hosts by setting Allow new session = Yes. [ELEVATED]
- Azure CLI fast path:
```bash
for h in $(az desktopvirtualization session-host list -g "$RG" --host-pool-name "$HP_BAD" --query "[].name" -o tsv); do
  az desktopvirtualization session-host update -g "$RG" --host-pool-name "$HP_BAD" --name "$h" --allow-new-session true
done
```
- Expected result: POOL-FIN-01 is reopened for normal routing.

## Verification
1. Verify session host state in Azure Portal path Azure Virtual Desktop -> Host pools -> POOL-FIN-01 -> Session hosts. [ELEVATED]
- Required fields: Status and Allow new session.
- Azure CLI fast path:
```bash
az desktopvirtualization session-host list -g "$RG" --host-pool-name "$HP_BAD" --query "[].{Host:name,Status:status,AllowNewSession:allowNewSession}" -o table
```
- Pass condition: All hosts show Status = Available and AllowNewSession = true.

2. Run 5 sequential user logins to Finance desktop mapped to POOL-FIN-01.
- Pass condition: 5 of 5 logins complete in 60 seconds or less and remain stable for 2 minutes.

3. Run 3 reconnect cycles from active sessions.
- Pass condition: 3 of 3 reconnects return desktop in 30 seconds or less.

4. Verify Event 1000 signature absence on each previously affected host from Application log. [ELEVATED]
- Azure CLI fast path example per host:
```bash
az vm run-command invoke -g "$RG" -n "<vm-name>" --command-id RunPowerShellScript --scripts "(Get-WinEvent -FilterHashtable @{LogName='Application'; Id=1000; StartTime=(Get-Date).AddMinutes(-30)} | Where-Object { $_.Message -match 'Faulting application name:\s*dwm.exe' -and $_.Message -match 'Faulting module name:\s*igdumd64.dll' } | Measure-Object).Count"
```
- Pass condition: Count = 0 on every previously affected host.

5. Verify Event 9009 absence on each previously affected host from Application log. [ELEVATED]
- Azure CLI fast path example per host:
```bash
az vm run-command invoke -g "$RG" -n "<vm-name>" --command-id RunPowerShellScript --scripts "(Get-WinEvent -FilterHashtable @{LogName='Application'; ProviderName='Microsoft-Windows-Desktop Window Manager'; Id=9009; StartTime=(Get-Date).AddMinutes(-30)} | Measure-Object).Count"
```
- Pass condition: Count = 0 on every previously affected host.

6. Verify healthy control baseline on POOL-FIN-02 from Application log. [ELEVATED]
- Azure CLI fast path on one control host:
```bash
az vm run-command invoke -g "$RG" -n "SHFIN-02-A" --command-id RunPowerShellScript --scripts "(Get-WinEvent -FilterHashtable @{LogName='Application'; ProviderName='Microsoft-Windows-Desktop Window Manager'; Id=9011; StartTime=(Get-Date).AddMinutes(-30)} | Measure-Object).Count"
```
- Pass condition: Event 9011 count is 1 or more.

7. Confirm no new service desk incidents for POOL-FIN-01 black screen for 30 minutes after reopen.
- Pass condition: Zero new incidents.

## Rollback
Use this if user impact increases after any remediation step.

1. Close POOL-FIN-01 immediately from Azure Portal path Azure Virtual Desktop -> Host pools -> POOL-FIN-01 -> Session hosts -> set Allow new session = No for all hosts. [ELEVATED]
- Azure CLI fast path:
```bash
for h in $(az desktopvirtualization session-host list -g "$RG" --host-pool-name "$HP_BAD" --query "[].name" -o tsv); do
  az desktopvirtualization session-host update -g "$RG" --host-pool-name "$HP_BAD" --name "$h" --allow-new-session false
done
```
- Expected result: POOL-FIN-01 accepts zero new sessions.

2. Open POOL-FIN-02 healthy capacity from Azure Portal path Azure Virtual Desktop -> Host pools -> POOL-FIN-02 -> Session hosts -> set Allow new session = Yes on Status = Available hosts. [ELEVATED]
- Azure CLI fast path:
```bash
for h in $(az desktopvirtualization session-host list -g "$RG" --host-pool-name "$HP_GOOD" --query "[?status=='Available'].name" -o tsv); do
  az desktopvirtualization session-host update -g "$RG" --host-pool-name "$HP_GOOD" --name "$h" --allow-new-session true
done
```
- Expected result: New users are redirected to POOL-FIN-02.

3. Notify active POOL-FIN-01 users from Azure Portal path Azure Virtual Desktop -> Host pools -> POOL-FIN-01 -> User sessions -> select sessions -> Send message. [ELEVATED]
- Message title: Service recovery
- Message body: Service recovery in progress. Please disconnect and reconnect in 2 minutes.
- Expected result: Users receive redirect message.

4. Revert all changed POOL-FIN-01 hosts to baseline image from Azure Portal path Virtual machines -> <host> -> Settings/Operations -> Image/Reimage workflow (or approved image-management console mapped to this VM). [ELEVATED]
- Required option: select baseline image version 10.0.22621.2861-build-20240313.
- Expected result: Reversion jobs move to Succeeded.

5. Confirm host runtime health from Azure Portal path Virtual machines -> <host> -> Overview. [ELEVATED]
- Required fields: Provisioning state = Succeeded, Power state = VM running.
- Azure CLI fast path:
```bash
az vm get-instance-view -g "$RG" -n "<vm-name>" --query "{power:instanceView.statuses[?starts_with(code,'PowerState/')].displayStatus|[0],provisioning:provisioningState}" -o table
```
- Expected result: Reverted hosts are healthy.

6. Keep POOL-FIN-01 closed until canary passes event checks from Application log. [ELEVATED]
- Azure CLI fast checks on canary:
```bash
az vm run-command invoke -g "$RG" -n "$CANARY" --command-id RunPowerShellScript --scripts "(Get-WinEvent -FilterHashtable @{LogName='Application'; Id=1000; StartTime=(Get-Date).AddMinutes(-15)} | Where-Object { $_.Message -match 'Faulting module name:\s*igdumd64.dll' } | Measure-Object).Count"
az vm run-command invoke -g "$RG" -n "$CANARY" --command-id RunPowerShellScript --scripts "(Get-WinEvent -FilterHashtable @{LogName='Application'; ProviderName='Microsoft-Windows-Desktop Window Manager'; Id=9009; StartTime=(Get-Date).AddMinutes(-15)} | Measure-Object).Count"
```
- Expected result: Both counts are 0 before reopening.

7. Escalate with full evidence set after rollback containment.
- Required evidence fields: host name, timestamps, Event IDs 21, 40, 1000, 9009, 9011, Kernel-General 1, and actions taken.
- Expected result: AVD platform owner and EUC image engineering owner acknowledge next steps.

## Preventive
Implement the following specific controls:

1. Owner: DWP engineer. Timing: during deployment. Mode: automated.
Signal and pass: Application log Event ID 1000 with Message containing both dwm.exe and igdumd64.dll stays below 2 events per VM per 10 minutes.
Fail: 2 or more matching events on any single VM in 10 minutes.
Action on fail: auto-page on-call, auto-create incident, and auto-run containment to set POOL-FIN-01 Allow new session = No. [REQUIRES: Azure Monitor Scheduled Query Rule, Action Group, Automation Runbook]

2. Owner: DWP engineer. Timing: during deployment login window. Mode: automated.
Signal and pass: Application log Provider Microsoft-Windows-Desktop Window Manager Event ID 9009 stays below 3 events per VM per 10 minutes.
Fail: 3 or more Event 9009 on any VM in 10 minutes.
Action on fail: auto-tag incident as Potential Black Screen Regression and notify change bridge. [REQUIRES: Azure Monitor Scheduled Query Rule + ITSM integration]

3. Owner: release engineer and image owner. Timing: before deployment. Mode: automated.
Signal and pass: pre-release soak run has zero Application Event 1000 matches (dwm.exe plus igdumd64.dll) and zero Event 9009 during scripted login/reconnect tests.
Fail: any matching Event 1000 or any Event 9009 during soak.
Action on fail: pipeline blocks promotion to production ring and requires defect ticket plus re-test evidence. [REQUIRES: CI/CD gate with event collection step]

4. Owner: change manager. Timing: during deployment. Mode: manual with automated checks.
Signal and pass: Ring 0 (1 host, 2 hours) and Ring 1 (20 percent hosts, 4 hours) both complete with Event 1000 count = 0 and Event 9009 below threshold.
Fail: threshold breach in Ring 0 or Ring 1.
Action on fail: stop change, set Allow new session = No on affected ring, and execute rollback trigger immediately.

5. Owner: DWP engineer. Timing: during and after deployment. Mode: automated.
Signal and pass: POOL-FIN-01 vs POOL-FIN-02 dashboard shows no abnormal delta for Event IDs 21, 40, 1000, 9009, 9011 across 15-minute bins.
Fail: POOL-FIN-01 crosses defined error budget delta against POOL-FIN-02 baseline.
Action on fail: auto-alert and mandatory incident triage within 10 minutes. [REQUIRES: cross-pool telemetry dashboard]

6. Owner: image owner. Timing: before deployment. Mode: automated.
Signal and pass: approved baseline version 10.0.22621.2861-build-20240313 remains pinned and drift check reports zero unauthorized version changes.
Fail: unauthorized version drift detected on image artifact or deployment manifest.
Action on fail: block release approval and require image governance sign-off.

7. Owner: DWP engineer. Timing: before deployment. Mode: manual (automatable).
Signal and pass: smoke test on canary host produces Event 9011 at login and zero Event 1000/9009 in first 15 minutes.
Fail: missing Event 9011 or any Event 1000/9009 appears.
Action on fail: do not start rollout; raise defect and hold change window. Automation note: schedule the smoke script via Azure VM Run Command and parse counts automatically.

8. Owner: change manager. Timing: after deployment, before closing change. Mode: manual with scripted evidence.
Signal and pass: 5/5 test logins succeed, 3/3 reconnects succeed, Event 1000 count = 0, Event 9009 count = 0 for 30 minutes on affected pool.
Fail: any functional test failure or non-zero event count.
Action on fail: keep change open, return POOL-FIN-01 to restricted state, and continue remediation.

9. Owner: change manager and DWP engineer. Timing: during deployment. Mode: automated (or manual fallback).
Signal and pass: rollback trigger fires when Event 1000 >= 2 per VM per 10 minutes or Event 9009 >= 3 per VM per 10 minutes.
Fail: threshold exceeded and no rollback started within 5 minutes.
Action on fail: manual emergency rollback sequence is executed and incident severity is raised to major.

10. Owner: service desk lead. Timing: after deployment and after incident closure. Mode: manual (automatable).
Signal and pass: runbook, L1 KB, and L2/L3 checklist are updated within 2 business days and linked in change record.
Fail: documentation not updated by deadline.
Action on fail: block next similar change until knowledge artifacts are updated. [REQUIRES: documented KB update workflow]

## Related
- Day4 issue analysis: Day4/issue-avd-black-screen-pool-fin-01/avd-black-screen-ranked-hypothesis-pool-fin.md
- Known error note: Day4/issue-avd-black-screen-pool-fin-01/known-error-avd-black-screen-pool-fin-01.md
- Closure note: Day4/issue-avd-black-screen-pool-fin-01/closure-note-avd-black-screen-pool-fin-01.md
- RCA source: Day4/issue-avd-black-screen-pool-fin-01/rca-avd-black-screen-pool-fin-01-2024-03-15.md
- Operational runbook: Day5/runbook-avd-black-screen-pool-fin-01.md

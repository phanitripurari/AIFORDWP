# Title: Runbook: AVD Black Screen After Login (POOL-FIN-01)
- Version: 1.0
- Date: 07/08/2026
- Author: Sathishbabu
- Reviewed: self
- Status: draft
- Change: initial version from RCA

# Runbook: AVD Black Screen After Login (POOL-FIN-01)

## Purpose
Restore user access when users can authenticate to AVD but see a black screen after login on POOL-FIN-01, with DWM crashes tied to `igdumd64.dll`.

## Scope
- In scope: POOL-FIN-01 only.
- Control baseline: POOL-FIN-02 (known-good behavior during incident).
- Trigger signature:
  - `TerminalServices-LocalSessionManager` Event ID 21 (logon success), followed by
  - `Application Error` Event ID 1000 (`dwm.exe` faulting module `igdumd64.dll`, often exception `0xc0000005`), followed by
  - `Desktop Window Manager` Event ID 9009 and session disconnects.

## Permission Flag Legend
- `[ELEVATED]` = requires elevated permissions (Azure RBAC and/or local admin).

## 1. Prerequisites
1. Confirm you have Azure access to subscription/resource group hosting POOL-FIN-01 and POOL-FIN-02. `[ELEVATED]`
2. Confirm you have permission to update AVD host pool session host settings (drain mode, assignment). `[ELEVATED]`
3. Confirm you have permission to restart/reimage session host VMs or apply approved image rollback. `[ELEVATED]`
4. Confirm you have permission to read Windows Event Logs on session hosts (remote Event Viewer or Log Analytics). `[ELEVATED]`
5. Open Azure Portal in a browser session connected to the production tenant.
6. Open your approved incident channel (Teams bridge / ticket) for timestamped updates.
7. Identify the affected host pool as `POOL-FIN-01` and unaffected control pool as `POOL-FIN-02`.
8. Record the pre-update known-good image reference: `10.0.22621.2861-build-20240313`.
9. Have at least one test account available for login validation in Finance AVD.

## 2. Procedure
1. In Azure Portal, open Azure Virtual Desktop -> Host pools -> POOL-FIN-01 -> Session hosts. `[ELEVATED]`
   - Expected result: The Session hosts grid for POOL-FIN-01 is visible and lists all hosts.
2. In the POOL-FIN-01 Session hosts grid, set Allow new session to No for every host. `[ELEVATED]`
   - Expected result: Every POOL-FIN-01 host shows Allow new session = No.
3. In Azure Portal, open Azure Virtual Desktop -> Host pools -> POOL-FIN-02 -> Session hosts. `[ELEVATED]`
   - Expected result: The Session hosts grid for POOL-FIN-02 is visible.
4. In the POOL-FIN-02 Session hosts grid, set Allow new session to Yes for every healthy host. `[ELEVATED]`
   - Expected result: Healthy POOL-FIN-02 hosts show Allow new session = Yes.
5. In Azure Portal, open Azure Virtual Desktop -> Host pools -> POOL-FIN-01 -> Session hosts, then click one symptomatic host VM name (example: SHFIN-01-A). `[ELEVATED]`
   - Expected result: The VM resource page for the selected host opens.
6. On the host VM page, click Run command -> RunPowerShellScript. `[ELEVATED]`
   - Expected result: The Run command blade opens for that VM.
7. Run this command in RunPowerShellScript: `Get-WinEvent -FilterHashtable @{LogName='Application'; Id=1000; StartTime=(Get-Date).AddHours(-6)} | Where-Object { $_.Message -match 'dwm.exe' -and $_.Message -match 'igdumd64.dll' } | Select-Object -First 5 TimeCreated, Id, ProviderName, Message | Format-List` . `[ELEVATED]`
   - Expected result: Output includes at least one Event ID 1000 entry mentioning both dwm.exe and igdumd64.dll.
8. Run this command in RunPowerShellScript: `Get-WinEvent -FilterHashtable @{LogName='System'; ProviderName='Microsoft-Windows-TerminalServices-LocalSessionManager'; Id=21; StartTime=(Get-Date).AddHours(-6)} | Select-Object -First 5 TimeCreated, Id, Message | Format-List` . `[ELEVATED]`
   - Expected result: Output includes Event ID 21 logon success entries in the same incident window.
9. Run this command in RunPowerShellScript: `Get-WinEvent -FilterHashtable @{LogName='Application'; ProviderName='Microsoft-Windows-Desktop Window Manager'; Id=9009; StartTime=(Get-Date).AddHours(-6)} | Select-Object -First 5 TimeCreated, Id, Message | Format-List` . `[ELEVATED]`
   - Expected result: Output includes Event ID 9009 entries close in time to Event ID 1000 entries.
10. In Azure Portal, open Azure Virtual Desktop -> Host pools -> POOL-FIN-01 -> Session hosts and choose one canary host for first rollback (example: SHFIN-01-A). `[ELEVATED]`
   - Expected result: One canary host is identified and documented in the incident ticket.
11. On the canary host VM page, open Help -> Reset password and confirm local admin credential access is valid before image action. `[ELEVATED]`
   - Expected result: Credential validation succeeds or existing credential is confirmed usable.
12. In your standard image-management console, assign image version `10.0.22621.2861-build-20240313` to the canary host and start redeploy/reimage. `[ELEVATED]`
   - Expected result: Job status shows Started and then Succeeded for the canary host image action.
13. In Azure Portal, wait for canary host VM provisioning state to show Succeeded and power state to show Running. `[ELEVATED]`
   - Expected result: Canary host is online with successful provisioning status.
14. In Azure Virtual Desktop -> Host pools -> POOL-FIN-01 -> Session hosts, set Allow new session to Yes only for the canary host. `[ELEVATED]`
   - Expected result: Canary host shows Yes and all other POOL-FIN-01 hosts remain No.
15. From an AVD client, sign in once with the test account and launch the Finance desktop assigned to POOL-FIN-01.
   - Expected result: Desktop appears within 60 seconds with no black screen and no forced disconnect.
16. On the canary host VM Run command blade, run: `Get-WinEvent -FilterHashtable @{LogName='Application'; Id=1000; StartTime=(Get-Date).AddMinutes(-15)} | Where-Object { $_.Message -match 'dwm.exe' -and $_.Message -match 'igdumd64.dll' } | Measure-Object` . `[ELEVATED]`
   - Expected result: Count is 0.
17. In your standard image-management console, apply image version `10.0.22621.2861-build-20240313` to all remaining POOL-FIN-01 hosts. `[ELEVATED]`
   - Expected result: Every remaining host image job completes with Succeeded status.
18. In Azure Virtual Desktop -> Host pools -> POOL-FIN-01 -> Session hosts, set Allow new session to Yes for all hosts after image jobs succeed. `[ELEVATED]`
   - Expected result: Every POOL-FIN-01 host shows Allow new session = Yes.
19. Post a ticket update with exact UTC timestamps for: drain start, reroute complete, canary success, full reopen.
   - Expected result: Ticket timeline is complete and auditable.

## 3. Verification
1. In Azure Portal, open Azure Virtual Desktop -> Host pools -> POOL-FIN-01 -> Session hosts and verify every host shows Status = Available and Allow new session = Yes. `[ELEVATED]`
   - Expected result: 100 percent of POOL-FIN-01 hosts are Available and accepting sessions.
2. Execute five sequential test logins to the Finance desktop that maps to POOL-FIN-01.
   - Expected result: 5 of 5 logins reach a usable desktop in 60 seconds or less and remain connected for 2 minutes.
3. Perform three reconnect tests from an active POOL-FIN-01 session by disconnecting and reconnecting through AVD client.
   - Expected result: 3 of 3 reconnects return to desktop in 30 seconds or less with no black screen.
4. On each previously affected host, run: `Get-WinEvent -FilterHashtable @{LogName='Application'; Id=1000; StartTime=(Get-Date).AddMinutes(-30)} | Where-Object { $_.Message -match 'dwm.exe' -and $_.Message -match 'igdumd64.dll' } | Measure-Object` . `[ELEVATED]`
   - Expected result: Count is 0 on every checked host.
5. On each previously affected host, run: `Get-WinEvent -FilterHashtable @{LogName='Application'; ProviderName='Microsoft-Windows-Desktop Window Manager'; Id=9009; StartTime=(Get-Date).AddMinutes(-30)} | Measure-Object` . `[ELEVATED]`
   - Expected result: Count is 0 during the verification window.
6. In ticketing/helpdesk queue, filter incidents for keywords "AVD" and "black screen" in the last 30 minutes.
   - Expected result: No new incidents for POOL-FIN-01 are present.
7. Set incident status to Recovered only after Steps 1 through 6 pass.
   - Expected result: Recovery decision is evidence-based and documented.

## 4. Rollback (3-Minute Emergency Containment)
Use this only when user impact increases after any procedure change. Goal: stop new impact within 3 minutes.

1. Start a 3-minute timer.
   - Expected result: You have a visible countdown running.
2. In Azure Portal, open Azure Virtual Desktop -> Host pools -> POOL-FIN-01 -> Session hosts. `[ELEVATED]`
   - Expected result: POOL-FIN-01 host list is visible.
3. In POOL-FIN-01 Session hosts, select all hosts. `[ELEVATED]`
   - Expected result: Every host row is selected.
4. Click Allow new session -> No. `[ELEVATED]`
   - Expected result: Every POOL-FIN-01 host shows Allow new session = No.
5. In Azure Portal, open Azure Virtual Desktop -> Host pools -> POOL-FIN-02 -> Session hosts. `[ELEVATED]`
   - Expected result: POOL-FIN-02 host list is visible.
6. In POOL-FIN-02 Session hosts, select all healthy hosts (Status = Available). `[ELEVATED]`
   - Expected result: Only healthy POOL-FIN-02 hosts are selected.
7. Click Allow new session -> Yes. `[ELEVATED]`
   - Expected result: Selected POOL-FIN-02 hosts show Allow new session = Yes.
8. In Azure Virtual Desktop -> Host pools -> POOL-FIN-01 -> User sessions, select all active sessions and click Send message. `[ELEVATED]`
   - Expected result: Broadcast dialog opens for all selected sessions.
9. Send this exact message: `Service recovery in progress. Please disconnect and reconnect in 2 minutes.`
   - Expected result: Azure Portal confirms message sent successfully.
10. In the incident ticket, post this exact line: `Emergency rollback executed: POOL-FIN-01 drained; POOL-FIN-02 opened; user redirect message sent; <UTC timestamp>.`
   - Expected result: Ticket audit trail contains a timestamped containment entry.
11. Run one test login from AVD client using a test account.
   - Expected result: Session lands on POOL-FIN-02 and desktop loads in 60 seconds or less.

If Steps 1 through 11 complete within 3 minutes, containment is successful.

Immediate follow-up after containment:
1. Keep all POOL-FIN-01 hosts at Allow new session = No until platform owner approval. `[ELEVATED]`
   - Expected result: No new user sessions can enter POOL-FIN-01.
2. Escalate to AVD platform owner and EUC image engineering owner with host list changed during incident.
   - Expected result: Named owners acknowledge in ticket/bridge.
3. Begin image reversion only under owner direction using baseline `10.0.22621.2861-build-20240313`. `[ELEVATED]`
   - Expected result: Reversion work starts under controlled ownership.

## 5. Notes
- This incident pattern is a post-authentication failure; successful credential logon does not mean desktop rendering is healthy.
- Strongest signature is sequence: Event 21 -> Event 1000 (`dwm.exe`/`igdumd64.dll`) -> Event 9009 -> disconnect.
- Keep POOL-FIN-02 as control evidence whenever POOL-FIN-01 is suspected.
- Do not reopen the full pool after a single successful login; complete canary validation first.
- During business-start window, prioritize containment (drain + reroute) before deep diagnostics.
- Related incident artifacts:
  - `Day4/issue-avd-black-screen-pool-fin-01/avd-black-screen-ranked-hypothesis-pool-fin.md`
  - `Day4/issue-avd-black-screen-pool-fin-01/known-error-avd-black-screen-pool-fin-01.md`
  - `Day4/issue-avd-black-screen-pool-fin-01/closure-note-avd-black-screen-pool-fin-01.md`
  - `Day4/issue-avd-black-screen-pool-fin-01/rca-avd-black-screen-pool-fin-01-2024-03-15.md`

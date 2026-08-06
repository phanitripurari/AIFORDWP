# AVD Incident Analysis and Hypothesis (Day 4)

## Scope Facts
- Symptom: black screen post-login; clears after ~30s for some users, persists for others.
- Who: approximately 40% of users on POOL-FIN-01.
- Control group: POOL-FIN-02 is completely unaffected.
- Since: approximately 07:00 this morning.
- Change: overnight image update to POOL-FIN-01 at 02:00; POOL-FIN-02 was not updated.

## Key Weighting Logic
The strongest discriminator is the control-group signal:
- Updated pool (POOL-FIN-01) shows impact.
- Non-updated pool (POOL-FIN-02) shows no impact.

This pattern strongly favors a pool-local, image-linked regression over tenant-wide AVD, identity, or broad network causes.

## Most Consistent Cause With the Timing/Control Clue
1. Image-introduced regression in logon or shell initialization on POOL-FIN-01.

Why this is most consistent:
- Fault onset follows the 02:00 update window.
- Impact is isolated to the updated pool.
- Unchanged pool remains clean, acting as an internal control.

## Re-ranked Top 5 Likely Causes (most probable first)
1. Image-introduced logon/shell regression in POOL-FIN-01
- Why it fits: Exact change boundary alignment (updated pool affected, non-updated pool unaffected).
- Fastest check: Revert one affected host to the previous image and perform a test login; if symptom disappears, this is strongly confirmed.

2. FSLogix/profile attach behavior changed by the new image
- Why it fits: Post-login black screen with mixed user outcomes matches profile attach latency/failure patterns; image-side service/config differences can trigger this only on updated hosts.
- Fastest check: Review FSLogix Operational log on an affected POOL-FIN-01 host at login time for attach/mount timeout or access errors.

3. Startup policy/script/service ordering issue introduced in the image
- Why it fits: New image can alter startup sequence and hold users at black screen; partial impact across users is plausible.
- Fastest check: Correlate Winlogon and GroupPolicy Operational events during a failing login on POOL-FIN-01 for stalled script/policy stages.

4. Graphics/rendering stack regression from updated driver/settings
- Why it fits: Black screen with delayed recovery can result from display pipeline initialization issues introduced in the updated image.
- Fastest check: Apply a known-safe rendering policy setting on one affected host and retest login for immediate behavior change.

5. AVD agent/bootloader version mismatch packaged in the new image
- Why it fits: Image update may carry agent component drift; can stall session initialization post-login on updated hosts only.
- Fastest check: Compare agent and bootloader versions on POOL-FIN-01 against POOL-FIN-02 and supported baseline.

## Position Statement
No single root cause is committed yet. Current hypothesis prioritization is explicitly weighted by the update timing and unaffected control pool evidence.

## Event Evidence Addendum (Affected Host vs Unaffected Control)

### Source and Window
- Affected host: SHFIN-01-A (POOL-FIN-01).
- Time window reviewed: 07:00-07:30.
- Log sources: Application and System.
- Control host: SHFIN-02-A (POOL-FIN-02, pre-update image).

### Key Event Details Used in Analysis
- 07:02:10 - TerminalServices-LocalSessionManager Event 21: session logon succeeded (FINBRIDGE\mlopez, Session 3).
- 07:02:14 - Kernel-General Event 1: host boot time recorded as 02:03:11 (post overnight update restart).
- 07:02:16 - Application Error Event 1000: dwm.exe crash; faulting module igdumd64.dll; exception 0xc0000005.
- 07:02:17 - TerminalServices-LocalSessionManager Event 40: session disconnected (Reason code 0).
- 07:02:18 - Desktop Window Manager Event 9009: DWM exited (0x40010004).
- 07:02:44 - TerminalServices-LocalSessionManager Event 21: session logon succeeded (reconnect).
- 07:02:46 - Application Error Event 1000: repeated dwm.exe crash in igdumd64.dll.
- 07:02:47 - TerminalServices-LocalSessionManager Event 40: session disconnected again.
- 07:03:01 - Desktop Window Manager Event 9009: DWM exited again.
- 07:03:10 - TerminalServices-LocalSessionManager Event 21: second reconnect logon succeeded.
- 07:08:22 - TerminalServices-LocalSessionManager Event 21: logon succeeded (FINBRIDGE\akapoor, Session 5).
- 07:08:24 - Application Error Event 1000: repeated dwm.exe crash in igdumd64.dll.

Control comparison:
- 07:01:44 - TerminalServices-LocalSessionManager Event 21: logon succeeded on SHFIN-02-A.
- 07:01:46 - Desktop Window Manager Event 9011: DWM started successfully.
- No Application Error Event 1000 in the same window on control host.

## Hypothesis-to-Evidence Assessment (From Event Review)

1. Image-introduced logon or shell regression in POOL-FIN-01
- Judgement: Supports.
- Determining evidence: Event 1 at 07:02:14 (post-update reboot context) plus repeated failure sequence after logon (Event 1000 at 07:02:16 and 07:02:46) present only on updated pool host; clean DWM start on control host (Event 9011 at 07:01:46).

2. FSLogix or profile attach issue triggered by new image
- Judgement: Contradicts.
- Determining evidence: Session logon succeeds first (Event 21 at 07:02:10 and 07:02:44), followed immediately by DWM/graphics fault signature (Event 1000 dwm.exe -> igdumd64.dll at 07:02:16 and 07:02:46); no FSLogix event evidence in supplied extract.

3. Startup policy, script, or service ordering issue introduced in image
- Judgement: Neutral.
- Determining evidence: Extract is dominated by graphics-specific crash chain (Event 1000 and Event 9009), but does not include policy/script telemetry to confirm or eliminate this path.

4. Graphics or rendering stack regression from updated driver/settings
- Judgement: Supports.
- Determining evidence: Repeated Application Error Event 1000 for dwm.exe faulting in igdumd64.dll at 07:02:16, 07:02:46, and 07:08:24; followed by DWM exits (Event 9009 at 07:02:18 and 07:03:01); absent on unaffected control host.

5. AVD agent or bootloader version mismatch packaged in the new image
- Judgement: Neutral.
- Determining evidence: Event sequence shows successful session logons (Event 21) with failures aligned to DWM crash moments; no direct agent/bootloader event IDs are present in the supplied set.

## Survived Hypothesis After Elimination
Graphics or rendering stack regression introduced by the POOL-FIN-01 image update, with DWM (dwm.exe) crashing in Intel graphics module igdumd64.dll.

## Detailed Resolution Steps

1. Stabilize service immediately
- Drain or temporarily remove affected POOL-FIN-01 session hosts from new user assignments.
- Route users to POOL-FIN-02 or another known-good fallback pool.

2. Confirm scope on hosts
- On each affected host, validate the repeating chain: Event 21 (logon success) -> Event 1000 (dwm.exe/igdumd64.dll crash) -> Event 9009 (DWM exit) -> Event 40 (disconnect).

3. Execute fastest safe rollback
- Reimage one POOL-FIN-01 canary host to the previous known-good image.
- Run controlled user logon test.
- If symptom clears, perform phased rollback on remaining affected hosts.

4. Apply driver-focused fix path
- In a maintenance image clone, roll back or replace Intel graphics driver version 31.0.101.4146 with the last known-good approved version.
- Reboot and run repeated multi-user logon tests.

5. Apply temporary rendering mitigation during transition
- Enforce known-safe rendering policy settings to reduce hardware-accelerated rendering risk in remote sessions.
- Reboot hosts and validate change in black-screen behavior.

6. Rebuild and redeploy corrected image
- Build a corrected golden image with known-good graphics driver and current validated platform components.
- Deploy in rings/canary batches to POOL-FIN-01 and monitor after each wave.

7. Validate recovery and close technical risk
- No new Event 1000 dwm.exe/igdumd64.dll entries during observation window.
- No recurring Event 9009 DWM exits tied to logon.
- User black-screen rate returns to baseline.

8. Add prevention controls
- Add pre-production soak gate to fail image promotion if DWM crash signature is detected.
- Add automated monitoring query for Event 1000 (dwm.exe + igdumd64.dll) and alert on threshold breach.

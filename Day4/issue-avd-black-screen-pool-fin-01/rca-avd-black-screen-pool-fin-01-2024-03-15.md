# RCA Report: AVD Black Screen on POOL-FIN-01

## Document Control
- Incident type: Major service degradation (AVD user logon experience)
- Service: Azure Virtual Desktop (Finance pools)
- Affected pool: POOL-FIN-01
- Unaffected control pool: POOL-FIN-02
- Incident date: 2024-03-15
- RCA prepared date: 2026-08-06
- Final status: Resolved

## Executive Summary
Between approximately 07:00 and 10:00, users connecting to POOL-FIN-01 experienced black screen immediately after successful login. For some users the black screen cleared after about 30 seconds; for others it persisted and forced reconnect/disconnect cycles. Approximately 40 percent of users on POOL-FIN-01 were affected. POOL-FIN-02 was fully unaffected.

The issue correlated strongly with an overnight image update applied at 02:00 to POOL-FIN-01 only. Event evidence from an affected session host showed repeated Desktop Window Manager (dwm.exe) crashes faulting in Intel graphics module igdumd64.dll (exception 0xc0000005), aligned with user disconnects. The applied remediation addressed this graphics/rendering regression path. Service recovery was confirmed at 10:00, with verified successful user logins to POOL-FIN-01 and no further issues reported.

## Scope and Impact
- User impact: Post-login black screen on AVD sessions.
- Scale: Around 40 percent of users on POOL-FIN-01.
- Business effect: Interrupted access to Finance virtual desktops, repeated reconnect attempts, productivity loss during peak start-of-day window.
- Blast radius: Single host pool (POOL-FIN-01).

## What Changed
- 02:00 overnight image update was deployed to POOL-FIN-01.
- POOL-FIN-02 did not receive this update and remained on pre-update image.

## Supporting Evidence

### Affected Host Evidence (SHFIN-01-A, 07:00-07:30)
- 07:02:10 - TerminalServices-LocalSessionManager Event 21
  - Session logon succeeded (FINBRIDGE\\mlopez, Session 3).
- 07:02:14 - Kernel-General Event 1
  - Host boot time recorded as 02:03:11 (restart after overnight update).
- 07:02:16 - Application Error Event 1000
  - Faulting app: dwm.exe (10.0.22621.2861)
  - Faulting module: igdumd64.dll (31.0.101.4146)
  - Exception: 0xc0000005
- 07:02:17 - TerminalServices-LocalSessionManager Event 40
  - Session disconnected (FINBRIDGE\\mlopez, reason code 0).
- 07:02:18 - Desktop Window Manager Event 9009
  - DWM exited with 0x40010004.
- 07:02:44 - TerminalServices-LocalSessionManager Event 21
  - Session logon succeeded (reconnect).
- 07:02:46 - Application Error Event 1000
  - Repeated dwm.exe crash in igdumd64.dll.
- 07:02:47 - TerminalServices-LocalSessionManager Event 40
  - Session disconnected.
- 07:03:01 - Desktop Window Manager Event 9009
  - DWM exited again.
- 07:03:10 - TerminalServices-LocalSessionManager Event 21
  - Logon succeeded (second reconnect).
- 07:08:22 - TerminalServices-LocalSessionManager Event 21
  - Logon succeeded (FINBRIDGE\\akapoor, Session 5).
- 07:08:24 - Application Error Event 1000
  - Repeated dwm.exe crash in igdumd64.dll.

### Unaffected Control Evidence (SHFIN-02-A, POOL-FIN-02)
- Image: 10.0.22621.2861-build-20240313 (pre-update).
- 07:01:44 - TerminalServices-LocalSessionManager Event 21
  - Session logon succeeded.
- 07:01:46 - Desktop Window Manager Event 9011
  - DWM started successfully.
- No Application Error Event 1000 entries in the same window.

### Evidence-Based Interpretation
- Authentication and session initiation succeeded (multiple Event 21).
- Failure occurred post-login in the desktop rendering path (Event 1000 dwm.exe -> igdumd64.dll, then Event 9009 and disconnects).
- The control pool did not exhibit this signature, strengthening image-local causality.

## Incident Timeline
- 02:00 - Overnight image update applied to POOL-FIN-01.
- 02:03 - Affected host reboot observed (Kernel-General Event 1 boot time 02:03:11).
- ~07:00 - User impact begins (reported black screen post-login).
- 07:02-07:08 - Repeated on-host evidence captured:
  - Logon success events, followed by dwm.exe crashes in igdumd64.dll, DWM exits, and disconnects.
- During incident window - POOL-FIN-02 remains healthy with normal DWM startup.
- 10:00 - Resolution verified:
  - Users successfully logging in to POOL-FIN-01.
  - No further black screen reports.

## Root Cause Statement
A graphics/rendering regression introduced by the updated POOL-FIN-01 image caused Desktop Window Manager (dwm.exe) to crash in Intel graphics user-mode module igdumd64.dll, producing black screen behavior after successful user authentication.

## Contributing Factors
- Image update was deployed to production pool without sufficient render-path soak coverage for this driver/module combination.
- Canary controls did not detect or block the DWM crash signature before broad user exposure.
- Early-morning user concurrency increased visibility and impact soon after business start.

## 5 Whys Analysis
1. Why did users see black screens after login?
- Because desktop composition failed during session initialization, causing a blank or unstable user desktop.

2. Why did desktop composition fail?
- Because dwm.exe crashed repeatedly on affected hosts.

3. Why did dwm.exe crash?
- Because dwm.exe faulted in igdumd64.dll (Intel graphics module) with access violation 0xc0000005.

4. Why was that faulty rendering path present in production?
- Because the overnight image update introduced a graphics stack state (driver/settings combination) that was unstable under AVD session conditions.

5. Why was the unstable state not caught before rollout?
- Because pre-production validation and promotion gates did not include sufficient detection for DWM/graphics crash signatures under representative AVD login load.

## Resolution Actions Applied
- Service stabilization and corrective actions were applied to the affected pool using the approved rendering/driver remediation path.
- Post-change verification confirmed:
  - Successful user logins to POOL-FIN-01.
  - No new incident reports after 10:00.

## Validation of Recovery
- Functional: Verified users can log in to POOL-FIN-01 without black screen symptom.
- Operational: No active user-reported failures after 10:00.
- Comparative: Behavior aligned with previously unaffected baseline pool.

## Preventive and Corrective Actions (CAPA)

### Immediate (0-7 days)
1. Add active detection for Event 1000 where faulting app is dwm.exe and module is igdumd64.dll on AVD hosts.
2. Add incident alert thresholds for repeated Event 9009 DWM exits tied to user logon windows.
3. Require staged rollout ring in POOL-FIN-01 with explicit stop/go criteria before full host update.

### Near-Term (1-4 weeks)
1. Introduce image promotion gate that fails release if DWM crash signatures appear during soak tests.
2. Expand pre-prod test pack to include repeated AVD logon cycles, reconnect scenarios, and concurrent session density tests.
3. Pin known-good graphics driver baseline in image pipeline and enforce version drift checks.

### Long-Term (1-2 quarters)
1. Build automated canary telemetry dashboard comparing updated pool versus control pool for crash/event deltas.
2. Implement policy-as-code for rollout controls: mandatory canary duration, error-budget threshold, and auto-rollback triggers.
3. Add formal release checklist requiring sign-off on graphics/rendering health under representative Finance workloads.

## Ownership and Follow-Up
- Incident manager: To be recorded.
- AVD platform owner: To be recorded.
- EUC image engineering owner: To be recorded.
- CAPA review date: To be scheduled.
- Evidence attachments:
  - Event log extract from SHFIN-01-A and SHFIN-02-A.
  - Prior hypothesis analysis document in Day4.

## Lessons Learned
- A clean control pool is high-value evidence for narrowing causality quickly.
- Successful authentication does not rule out severe post-login platform faults.
- Graphics stack regressions can present as user-profile-like symptoms; event sequencing is decisive for differential diagnosis.

# AVD Incident Communications - Three Audiences

## Audience 1 - Non-Technical Executive (under 80 words)
Your access and data are safe. Between about 07:00 and 10:00, around 40% of users in POOL-FIN-01 saw a black screen after sign-in; for some it cleared in about 30 seconds, for others it continued. A 02:00 overnight image update affected only POOL-FIN-01, while POOL-FIN-02 was unaffected. We applied the fix and verified normal logins by 10:00 with no further issues. No action is needed.

## Audience 2 - Affected End-User Team (under 100 words)
Hi team, today between about 07:00 and 10:00 an overnight 02:00 update to POOL-FIN-01 caused a black screen right after sign-in for about 40% of users in that pool (it cleared in about 30 seconds for some and lasted for others), while POOL-FIN-02 was unaffected; we applied the fix and verified successful logins by 10:00 with no further issues. If you see the same issue again, reconnect once, then report it immediately with the time and a screenshot. Please contact the IT Service Desk.

## Audience 3 - Engineer-to-Engineer Internal Note
Incident summary:
- Window: approximately 07:00 to 10:00.
- Scope: approximately 40% user impact on POOL-FIN-01 only.
- Symptom: post-logon black screen; cleared after about 30 seconds for some users, persisted for others.
- Control: POOL-FIN-02 unaffected.

Root cause:
- Image-linked graphics/rendering regression on POOL-FIN-01 after 02:00 image update.
- On affected host SHFIN-01-A, repeated crash chain observed:
1. LSM Event 21 (logon success) at 07:02:10 / 07:02:44 / 07:03:10 / 07:08:22
2. Application Error Event 1000 at 07:02:16 / 07:02:46 / 07:08:24
3. Faulting app: dwm.exe 10.0.22621.2861
4. Faulting module: igdumd64.dll 31.0.101.4146
5. Exception: 0xc0000005
6. DWM Event 9009 exits at 07:02:18 and 07:03:01
7. LSM Event 40 disconnects at 07:02:17 and 07:02:47
- Control host SHFIN-02-A (pre-update image 10.0.22621.2861-build-20240313) showed normal DWM start (Event 9011 at 07:01:46) and no Event 1000 in-window.

Exact action taken:
- Applied approved rendering/driver remediation path on POOL-FIN-01 affected hosts (service stabilization plus corrective graphics-path fix).

Verification:
- By 10:00, verified users logging into POOL-FIN-01 successfully, with no further black-screen reports.

Preventive actions required:
1. Alerting for Event 1000 where dwm.exe faults in igdumd64.dll.
2. Alerting thresholds for repeated Event 9009 DWM exits near logon window.
3. Mandatory staged rollout/canary ring with stop-go criteria before full pool rollout.
4. Image promotion gate to fail if DWM crash signature appears during soak tests.
5. Pin known-good graphics driver baseline and enforce version-drift checks in image pipeline.

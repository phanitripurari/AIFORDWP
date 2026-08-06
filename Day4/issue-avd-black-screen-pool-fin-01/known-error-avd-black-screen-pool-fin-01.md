Symptom     : Users on POOL-FIN-01 see a black screen after successful login. For some users it clears after about 30 seconds; for others it persists and can lead to reconnect or disconnect cycles.

Cause       : A graphics/rendering regression introduced by the updated POOL-FIN-01 image caused Desktop Window Manager (dwm.exe) to crash in Intel module igdumd64.dll with exception 0xc0000005. This was verified in affected host event logs.

Scope       : Approximately 40% of users on POOL-FIN-01 were affected between about 07:00 and 10:00. POOL-FIN-02 was unaffected during the same window.

Workaround  : Apply service stabilization on the affected pool using the approved rendering/driver remediation path used in the incident. During the incident, this was the operational path used to restore stable user access.

Permanent fix: Keep the corrective rendering/driver state that removed the DWM crash condition on POOL-FIN-01, and enforce image-pipeline controls from CAPA. These controls include canary-gated rollout and image promotion gates for DWM crash signatures.

How to spot it: On affected hosts, look for the repeated sequence: TerminalServices LSM Event 21 (logon success), Application Error Event 1000 (faulting app dwm.exe, faulting module igdumd64.dll, exception 0xc0000005), Desktop Window Manager Event 9009 (DWM exited), and TerminalServices LSM Event 40 (disconnect). In this incident, the same signature appeared around 07:02-07:08 on SHFIN-01-A, while SHFIN-02-A showed DWM Event 9011 start success and no Event 1000 in-window.

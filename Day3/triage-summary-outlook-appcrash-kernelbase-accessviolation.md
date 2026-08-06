# Triage Summary - Outlook APPCRASH (Event ID 1000/1001/1026)

## Summary (one line)
Outlook crashed repeatedly within minutes with an access violation (0xc0000005) in KERNELBASE.dll, with matching fault offset and .NET unhandled exception evidence, indicating a repeatable client-side fault path (most likely add-in or profile/data interaction).

## Impact (who/how many/business urgency)
- Affected application: Microsoft Outlook (desktop), version 16.0.17126.20132.
- Affected user count: at least one endpoint/user (provided data scope).
- Business impact: medium-high because email/calendar access is interrupted and repeated crashes prevent normal work.
- Urgency: high for the affected user; medium for fleet until scope is confirmed.

## Known facts
- Event source: Application Error.
- Event ID: 1000 (Error), observed at 2024-03-15 09:14:22 and 09:17:45.
- Faulting app: OUTLOOK.EXE 16.0.17126.20132.
- Faulting module: KERNELBASE.dll 10.0.22621.3155.
- Exception code: 0xc0000005 (access violation).
- Fault offset: 0x000000000003a4b2 (same on repeated crash).
- WER event: Event ID 1001 (Information), APPCRASH fault bucket 1847362910.
- .NET Runtime event: Event ID 1026 (Error) reports unhandled System.AccessViolationException and process termination.

## Reconstructed timeline
1. 09:13:44 - Outlook process starts.
2. 09:14:22 - First Application Error 1000 crash (access violation in KERNELBASE.dll).
3. 09:17:45 - Second Application Error 1000 crash with same module and fault offset.
4. 09:18:01 - Windows Error Reporting 1001 logs APPCRASH bucket.
5. 09:18:05 - .NET Runtime 1026 confirms unhandled System.AccessViolationException.

## Technical interpretation
- Exception 0xc0000005 indicates invalid memory access (read/write/execute violation).
- Same app version, module version, and fault offset across crashes strongly suggest a deterministic trigger rather than random transient instability.
- KERNELBASE.dll is frequently where exceptions are surfaced, but not always the true root-cause component. The originating fault is often upstream (for example: Outlook add-in, MAPI provider, profile corruption, data file issue, or third-party integration).
- Presence of .NET Runtime 1026 with System.AccessViolationException supports an unmanaged or interop boundary failure path (native code or COM interop called from managed components).

## Most likely cause
- Primary hypothesis: Faulty or incompatible Outlook COM add-in/integration triggering a repeatable memory access violation during startup or early mailbox initialization.
- Secondary hypothesis: Corrupted Outlook profile, OST/PST data structure issue, or mailbox object state causing repeatable crash on load.
- Lower-probability hypothesis: Office build defect specific to this release path and user workload pattern.

## Confidence
- Confidence in crash classification (repeatable access violation): high.
- Confidence in precise root component (add-in vs profile/data vs build defect): medium pending isolation tests.

## First diagnostic step
Start Outlook in safe mode (which suppresses COM add-ins) and compare behavior:
- If stable in safe mode, isolate add-ins by staged re-enable to identify offender.
- If still crashing in safe mode, prioritize profile rebuild, OST refresh, and Office repair/update path checks.

## Recommended diagnostic workflow
1. Launch Outlook with safe mode (`outlook.exe /safe`) and verify whether crash reproduces.
2. Capture add-in inventory and disable all non-Microsoft add-ins; re-enable one at a time.
3. Create a fresh Outlook profile and test with same mailbox.
4. Rebuild OST (if Exchange/365 cached mode) and retest.
5. Run Office Quick Repair, then Online Repair if needed.
6. Confirm Office channel/build health and apply latest supported updates.
7. Review Reliability Monitor and collect correlated Application/System events around crash timestamps.
8. If reproducible after above steps, collect dump (WER/local dump) for stack-level root cause and vendor escalation.

## Immediate mitigation options
- Temporary workaround: use Outlook on the web while desktop client is stabilized.
- Keep nonessential add-ins disabled for affected user(s) until fault source is confirmed.
- If incident expands, use rapid communication to impacted teams with known workaround and ETA for fix path.

## Data still needed to finalize RCA
- User identity and machine name.
- Whether crash occurs only with one mailbox/profile or multiple profiles.
- Add-in list and recent changes (new install/update).
- Office update channel and patch cadence.
- Dump file or Watson details mapped to fault bucket 1847362910.

## Root cause statement (current, provisional)
Outlook desktop on Office 16.0.17126.20132 is encountering a repeatable access violation (0xc0000005) surfaced in KERNELBASE.dll at a constant offset, with .NET unhandled AccessViolation evidence, most likely triggered by a client-side extension or profile/data initialization path.

## Next action owner suggestions
- EUC/Service Desk: safe mode validation and add-in isolation.
- Messaging/Endpoint Engineering: profile/data remediation and Office build validation.
- Problem Management: monitor for recurrence pattern by same fault bucket across devices.

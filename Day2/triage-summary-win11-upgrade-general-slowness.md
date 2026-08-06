# Triage Summary - T-1006

## Summary (one line)
User reports broad performance degradation ('everything is slow') beginning after Windows 11 upgrade two days ago, indicating likely post-upgrade performance stabilization or resource bottleneck issue (to-verify).

## Impact (who/how many/business urgency)
- Affected user(s): one reported user (to-verify).
- Scope: currently a single incident; monitor for pattern among recent Windows 11 upgrades (to-verify).
- Business urgency: medium-high due to ongoing productivity impact across multiple tasks.

## Known facts
- Ticket ID: T-1006.
- Device state: upgraded to Windows 11.
- Timing: upgrade occurred two days ago.
- Symptom: user reports general slowness across activities.

## Missing information to gather
- Specific slow workflows/apps (startup, sign-in, Outlook, browser, file operations, Teams) (to-verify).
- Whether slowness is constant or time-based (e.g., after boot, during updates, intermittent) (to-verify).
- Device model, RAM, storage type/capacity free space, and CPU baseline (to-verify).
- Whether background indexing/sync/security scans are still elevated post-upgrade (to-verify).
- Whether third-party startup apps/services increased after upgrade (to-verify).
- Whether network slowness is perceived as system slowness (to-verify).
- Whether other recently upgraded users on same hardware report similar behavior (to-verify).

## Likely category
- Endpoint Performance > Windows 11 post-upgrade degradation (to-verify).

## First diagnostic step
Capture a quick performance baseline on the affected device (CPU, memory, disk active time, and top processes during reported slowness) to determine whether the bottleneck is compute, storage, or background activity before deeper remediation (to-verify).

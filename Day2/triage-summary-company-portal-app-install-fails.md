# Triage Summary - T-1004

## Summary (one line)
Company app fails to install from Company Portal with error 0x87D1041C, indicating a potential app assignment, detection, dependency, or client-side deployment issue (to-verify).

## Impact (who/how many/business urgency)
- Affected user(s): at least one reported user/device (to-verify).
- Scope: currently one ticket; potential wider impact if the same app package or assignment is affected for a group (to-verify).
- Business urgency: medium to high depending on whether the app is business-critical for the user role (to-verify).

## Known facts
- Ticket ID: T-1004.
- Symptom: app install fails in Company Portal.
- Reported error code: 0x87D1041C.
- Platform context: Company Portal app deployment flow.

## Missing information to gather
- Exact app name and version requested (to-verify).
- Whether failure occurs on one device or multiple devices/users (to-verify).
- Device enrollment/compliance state at time of install attempt (to-verify).
- Whether the app is required, available, or uninstall/reinstall scenario (to-verify).
- Whether device has required dependencies/prerequisites and sufficient disk space (to-verify).
- Whether network restrictions/proxy/VPN were present during install (to-verify).
- Timestamp of failure and relevant client-side install logs per internal procedure (to-verify).

## Likely category
- Endpoint Management > Intune/Company Portal > Application deployment failure (to-verify).

## First diagnostic step
Validate scope and assignment first: confirm the same app install outcome on a second similarly targeted device/user and verify that the affected device is correctly targeted and compliant in endpoint management; then review client-side deployment status for this specific app attempt (to-verify).

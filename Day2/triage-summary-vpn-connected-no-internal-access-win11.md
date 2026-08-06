# Triage Summary - T-1008

## Summary (one line)
VPN reports connected but internal resources are unreachable after Windows 11 upgrade, indicating likely routing, DNS resolution, policy, or adapter interaction issue (to-verify).

## Impact (who/how many/business urgency)
- Affected user(s): one reported user (to-verify).
- Scope: currently one ticket; possible wider pattern for recent Windows 11 upgraded VPN users (to-verify).
- Business urgency: high because user cannot access internal business services while remote.

## Known facts
- Ticket ID: T-1008.
- Symptom: VPN establishes connection.
- Symptom: no internal resources reachable while connected.
- Timing/context: reported after Windows 11 upgrade.

## Missing information to gather
- Which internal resources fail (file shares, intranet, line-of-business apps, remote management endpoints) (to-verify).
- Whether issue is name-resolution only or both name and direct IP path (to-verify).
- Whether split tunneling/full tunneling is expected for this user profile (to-verify).
- Whether problem occurs on all networks (home, hotspot, office internet) (to-verify).
- Whether user can reach internet normally during VPN session (to-verify).
- VPN client version and whether profile/policy was updated post-upgrade (to-verify).
- Whether other recently upgraded users with same VPN profile are impacted (to-verify).

## Likely category
- Network Access > VPN > Connected-no-access post-OS-upgrade issue (to-verify).

## First diagnostic step
Run a connectivity split check while VPN is connected: test internal resource access by hostname and by known internal IP target (per approved internal test list) to quickly determine whether the primary failure is DNS resolution or route/path reachability (to-verify).

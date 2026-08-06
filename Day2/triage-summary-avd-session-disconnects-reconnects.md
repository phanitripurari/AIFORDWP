# Triage Summary - T-1003

## Summary (one line)
AVD session disconnects after approximately 10 minutes and then reconnects, indicating a potential session stability, network path, or policy timeout issue (to-verify).

## Impact (who/how many/business urgency)
- Affected user(s): at least one reported user (to-verify).
- Scope: currently one ticket; could affect additional users on same host pool, region, or network segment (to-verify).
- Business urgency: medium-high due to repeated interruption to user workflow and potential data-entry disruption.

## Known facts
- Ticket ID: T-1003.
- Service context: Azure Virtual Desktop (AVD).
- Symptom: session disconnects and then reconnects.
- Pattern: roughly every 10 minutes (as reported; to-verify).

## Missing information to gather
- Exact impacted user(s), business unit, and criticality of role (to-verify).
- Whether issue occurs for one user or multiple users in same host pool (to-verify).
- Time window and consistency: every session, specific times of day, or intermittent (to-verify).
- Connection path details: office network, VPN, home network, wired/wireless (to-verify).
- Affected client type and version: Windows app/web client/thin client (to-verify).
- Whether reconnect is automatic and how long outage lasts each cycle (to-verify).
- Whether audio/video/USB redirection is in use when disconnect occurs (to-verify).
- Whether there were recent policy, host image, or network changes before onset (to-verify).

## Likely category
- End User Compute > Virtual Desktop > AVD session stability/disconnects (to-verify).

## First diagnostic step
Establish scope and isolate client versus platform quickly: check whether another user on the same host pool and network path reproduces the ~10-minute disconnect pattern; if not reproducible broadly, prioritize user network/client diagnostics, and if reproducible, escalate toward host pool/session host policy or platform investigation (to-verify).

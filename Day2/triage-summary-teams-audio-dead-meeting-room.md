# Triage Summary - T-1005

## Summary (one line)
Teams audio is not working on three machines in the same meeting room, suggesting a shared room audio path, peripheral, or local configuration issue (to-verify).

## Impact (who/how many/business urgency)
- Affected user(s): multiple users via three meeting-room machines.
- Scope: confirmed on three endpoints in one location; possible room-wide common-cause impact.
- Business urgency: high due to direct disruption of meetings and collaboration.

## Known facts
- Ticket ID: T-1005.
- Application: Microsoft Teams.
- Symptom: audio is dead (no usable audio path) on three machines.
- Location pattern: all affected machines are in the same meeting room.

## Missing information to gather
- Whether issue is input, output, or both (to-verify).
- Whether failure affects Teams only or all system audio on each machine (to-verify).
- Shared hardware details: dock, speakerphone, USB audio device, cabling, room AV controller (to-verify).
- Whether recent updates/driver changes or room equipment changes occurred (to-verify).
- Whether the same user account works with audio in another room/device (to-verify).
- Whether Teams device settings auto-switch to wrong endpoint at meeting start (to-verify).
- Exact time of onset and whether issue is persistent or intermittent (to-verify).

## Likely category
- Collaboration Tools > Teams > Meeting room audio/peripheral issue (to-verify).

## First diagnostic step
Perform a shared-path isolation check in the room: test system audio and Teams test call on one affected machine with room peripherals connected, then repeat with a known-good headset directly on that machine to distinguish room hardware path issues from endpoint/software issues (to-verify).

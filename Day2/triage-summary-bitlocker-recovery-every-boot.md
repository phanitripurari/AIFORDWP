# Triage Summary - T-1001

## Summary (one line)
New Windows 11 laptop prompts for BitLocker recovery key on every boot, indicating persistent startup trust validation failure (to-verify).

## Impact (who/how many/business urgency)
- Affected user(s): single reported user with a new laptop (to-verify).
- Scope: currently one device/ticket; risk of wider impact if image or policy baseline issue exists (to-verify).
- Business urgency: high for end-user productivity because repeated recovery prompts block normal startup workflow.

## Known facts
- Ticket ID: T-1001.
- Device: new Windows 11 laptop.
- Symptom: BitLocker recovery key prompt appears every boot.
- Frequency: every boot (as reported by requester; to-verify).

## Missing information to gather
- User identity, department, and whether VIP/critical role is affected (to-verify).
- Exact device identifier (asset tag/hostname) and hardware model (to-verify).
- When issue started: first boot only or after updates/BIOS changes (to-verify).
- Whether any recent firmware/BIOS/TPM/security policy changes were applied (to-verify).
- Whether Secure Boot, TPM state, or boot order changed recently (to-verify).
- Whether recovery key entered is accepted and system then boots normally (to-verify).
- Whether the same behavior occurs on AC vs battery and on docked vs undocked boot (to-verify).
- Whether similar reports exist for other newly built devices (to-verify).

## Likely category
- Endpoint Security > Encryption > BitLocker recovery loop (to-verify).

## First diagnostic step
Confirm the recovery loop pattern on the affected device and capture baseline state: verify if recovery prompt appears on each restart after a successful unlock, then collect BitLocker protection status and TPM health details using approved internal troubleshooting procedure (to-verify).

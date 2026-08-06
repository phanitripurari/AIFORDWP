# RCA: RDP Connection Failure and Account Lockout (FINBRIDGE\\bwalker)

## Incident Summary

- Incident type: Remote Desktop (RDP) connection failure followed by account lockout.
- User account: `FINBRIDGE\\bwalker`.
- Source client IP: `10.10.5.44`.
- Time window analyzed: 14:01:02 to 14:22:09 on 2024-03-15.
- Outcome: Repeated failed remote interactive logons led to lockout; successful RDP logon occurred later after account state/credentials were corrected.

## Event ID Meaning in This Incident

### System Event ID 56 (TermDD)
What it records:
- Terminal Server security layer/protocol stream error causing client disconnect.

How it appears here:
- At 14:01:02, disconnect from `10.10.5.44` coincides with invalid-credential sequence.
- In this context, likely secondary/symptomatic to failed authentication exchange rather than a sustained transport outage.

### System Event ID 140 (RemoteDesktopServices-RdpCoreTS)
What it records:
- RDP connection failed because username or password was incorrect.

How it appears here:
- At 14:01:02, explicit credential failure from `10.10.5.44`.

### Security Event ID 4625 (Audit Failure)
What it records:
- Failed logon attempt with reason, account, logon type, and source.

How it appears here:
- At 14:01:04, 14:03:18, and 14:05:33, account `FINBRIDGE\\bwalker` failed logon type 10 (RemoteInteractive) from `10.10.5.44` with reason "Unknown username or bad password".

### Security Event ID 4740 (Audit Failure)
What it records:
- Account lockout event including caller computer/source.

How it appears here:
- At 14:05:34, `FINBRIDGE\\bwalker` was locked out; caller/source is `10.10.5.44`.

### System Event ID 131 (RemoteDesktopServices-RdpCoreTS)
What it records:
- Server accepted a new TCP connection from client.

How it appears here:
- At 14:22:07, new TCP connection accepted from `10.10.5.44`, indicating connectivity path was available.

### Security Event ID 4624 (Audit Success)
What it records:
- Successful logon.

How it appears here:
- At 14:22:09, successful logon type 10 for `FINBRIDGE\\bwalker` from `10.10.5.44`.

## Reconstructed Sequence (Plain English)

1. At 14:01:02, an RDP attempt from `10.10.5.44` failed authentication (Event 140), with a TermDD protocol/security-layer disconnect logged at the same second (Event 56).
2. Between 14:01:04 and 14:05:33, three Security 4625 failures occurred for `FINBRIDGE\\bwalker` (logon type 10), each with bad-credential reason.
3. At 14:05:34, account lockout policy triggered (Event 4740), tying lockout to source `10.10.5.44`.
4. At 14:22:07, server accepted a fresh TCP RDP connection from the same client IP (Event 131).
5. At 14:22:09, RDP sign-in succeeded (Event 4624), confirming service/network path and account usability after credential/account-state correction.

## Most Likely Root Cause

Primary cause:
- Repeated incorrect RDP credentials for `FINBRIDGE\\bwalker` from client `10.10.5.44` triggered account lockout policy, causing connection failures until lockout was cleared and valid credentials were used.

Why this is most likely:
- Multiple sequential 4625 failures with explicit bad-credential reason.
- Immediate 4740 lockout after final failed attempt.
- Later successful 4624 from same IP indicates infrastructure path was functioning and issue resolved with account/credential state change.

## Role of the TermDD Event 56

- Event 56 is treated as a correlated symptom during failed security negotiation/authentication.
- The later successful RDP from the same source IP reduces likelihood of persistent RDP transport/TLS/network root cause in this incident.

## 5-Why Analysis

1. Why did the user fail to connect over RDP?
- Authentication failed for remote interactive logon (4625/140).

2. Why did authentication fail?
- Incorrect username/password was presented multiple times.

3. Why did failures continue?
- Repeated retries from the same client occurred before correction.

4. Why did the incident escalate to complete access denial?
- Domain/account lockout threshold was reached, producing Event 4740.

5. Why was access restored later?
- Account lockout was no longer in effect and/or correct credentials were entered, leading to Event 4624 success.

## Corrective Actions (Immediate)

- Confirm account lockout status and unlock account per policy-controlled process.
- Ensure user enters current password and correct domain format (`FINBRIDGE\\bwalker`).
- Instruct user to avoid repeated retries after 1-2 failures and contact support immediately.

## Preventive Actions (Recommended)

- Validate endpoint `10.10.5.44` for stale cached credentials, saved RDP credential entries, or automation repeatedly submitting old passwords.
- Add proactive monitoring/alerting for clustered 4625 (type 10) events followed by 4740 for same account/source.
- Provide quick user guidance for password-change scenarios and RDP saved-credential refresh steps.
- Review lockout policy thresholds versus operational risk (security maintained, reduce avoidable self-lockouts where appropriate).

## Confidence and Limitations

- Confidence in root cause classification: High.
- Limitations:
  - No full domain controller event set provided for broader correlation.
  - No explicit evidence in provided logs showing whether unlock was manual vs automatic lockout duration expiry.
  - No endpoint-side credential manager/RDP client logs included.

## Root Cause Statement

`FINBRIDGE\\bwalker` experienced RDP connection failure because repeated bad-credential remote interactive logon attempts from `10.10.5.44` triggered account lockout policy (Event 4740). Access was restored once lockout/credential conditions were corrected, as evidenced by subsequent successful logon from the same source.

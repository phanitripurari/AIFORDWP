# RCA Report: User Logon Failure (FINBRIDGE\cthompson)

## Document Control
- Incident type: Single-user logon failure
- Service context: Domain interactive logon
- Affected user: FINBRIDGE\cthompson
- Affected endpoint observed: DESKTOP-FB022
- Incident date: 2024-03-15
- RCA prepared date: 2026-08-06
- Final status: Resolved

## Executive Summary
From approximately 08:40, user FINBRIDGE\cthompson could not log in. Security logs show repeated wrong-password authentication failures followed by account lockout. The issue was resolved at 09:09 after the account was enabled and successful interactive logon was verified on DESKTOP-FB022, with no further issues reported.

## Scope and Impact
- Impacted user count: one user only (FINBRIDGE\cthompson).
- User experience: unable to complete interactive login.
- Business impact: user access interruption for the affected individual.

## Supporting Evidence

### Failure Evidence (08:44-08:46)
- 08:44:01 - Security Event 4776 Audit Failure
  - Domain credential validation failed for FINBRIDGE\cthompson.
  - Error code: 0xC000006A (wrong password).
  - Source workstation: DESKTOP-FB022.
- 08:44:03 - Security Event 4625 Audit Failure
  - Failure reason: unknown user name or bad password.
  - Logon type: 2 (Interactive).
  - Source: DESKTOP-FB022.
- 08:44:28 - Security Event 4625 Audit Failure
  - Failure reason: unknown user name or bad password.
  - Logon type: 2 (Interactive).
  - Source: DESKTOP-FB022.
- 08:44:55 - Security Event 4625 Audit Failure
  - Failure reason: unknown user name or bad password.
  - Logon type: 2 (Interactive).
  - Source: DESKTOP-FB022.
- 08:44:56 - Security Event 4740 Audit Failure
  - User account locked out: FINBRIDGE\cthompson.
  - Caller computer: DESKTOP-FB022.
- 08:45:10 - Security Event 4625 Audit Failure
  - Failure reason: account locked out.
  - Logon type: 7 (Unlock attempt).
  - Source: DESKTOP-FB022.
- 08:45:44 - Security Event 4771 Audit Failure
  - Kerberos pre-authentication failed.
  - Failure code: 0x18 (wrong password).
  - Source IP: 10.10.8.112.
- 08:46:01 - Security Event 4771 Audit Failure
  - Kerberos pre-authentication failed.
  - Failure code: 0x18 (wrong password).
  - Source IP: 10.10.8.112.
- 08:46:33 - Security Event 4771 Audit Failure
  - Kerberos pre-authentication failed.
  - Failure code: 0x18 (wrong password).
  - Source IP: 10.10.8.112.

### Recovery Evidence (09:08-09:09)
- 09:08:14 - Security Event 4722 Audit Success
  - User account enabled: FINBRIDGE\cthompson.
  - Action performed by: FINBRIDGE\helpdesk-admin.
- 09:09:01 - Security Event 4624 Audit Success
  - Successful logon for FINBRIDGE\cthompson.
  - Logon type: 2 (Interactive).
  - Source: DESKTOP-FB022.

## Evidence-Based Interpretation
- The failure sequence shows repeated wrong-password attempts leading to lockout.
- Authentication failures continued briefly from another source IP after lockout window began.
- Account enablement was followed by successful interactive logon, matching reported service recovery at 09:09.

## Incident Timeline
- ~08:40 - User reports inability to log in.
- 08:44:01 - First captured wrong-password failure (Event 4776).
- 08:44:03 to 08:44:55 - Repeated bad password failures (Event 4625).
- 08:44:56 - Account lockout recorded (Event 4740).
- 08:45:10 - Locked-out login attempt observed (Event 4625, locked out).
- 08:45:44 to 08:46:33 - Additional wrong-password Kerberos pre-auth failures from 10.10.8.112 (Event 4771).
- 09:08:14 - Account enabled by helpdesk admin (Event 4722).
- 09:09:01 - Successful interactive login (Event 4624).
- 09:09 - Resolution confirmed; user verified working and no further issues reported.

## Root Cause Statement
User FINBRIDGE\cthompson was unable to log in due to repeated wrong-password authentication attempts that resulted in account lockout.

## Contributing Factors
- Multiple bad password attempts were generated from DESKTOP-FB022.
- Additional wrong-password Kerberos pre-authentication attempts were observed from source IP 10.10.8.112.

## 5 Whys Analysis
1. Why could the user not log in?
- Because authentication attempts were failing and the account became locked out.

2. Why were authentication attempts failing?
- Because submitted credentials were incorrect, as shown by wrong-password failure codes.

3. Why did the account become locked?
- Because repeated bad password attempts crossed lockout policy threshold.

4. Why did failures continue after initial lockout event?
- Because additional authentication attempts were still occurring from observed sources during the same window.

5. Why was access restored?
- Because the account was enabled by helpdesk admin and a subsequent interactive login succeeded.

## Resolution Actions Applied
- Suggested resolution path was applied.
- Helpdesk performed account enablement (Event 4722 at 09:08:14).
- User then completed successful interactive logon (Event 4624 at 09:09:01).

## Validation of Recovery
- Technical verification: successful logon event present for FINBRIDGE\cthompson.
- User verification: user confirmed working.
- Stability signal: no further issues reported after 09:09.

## Preventive Actions

### Immediate
1. On future lockout incidents, check for all active bad-attempt sources (workstation and alternate IP sources) before closing.
2. Require confirmation of successful interactive logon event (4624) after account recovery action.

### Near-Term
1. Add lockout triage checklist to incident template: review Event 4776, 4625, 4740, and 4771 in time order.
2. Capture and document all bad-attempt source systems/IPs in ticket notes for follow-up endpoint review.

### Long-Term
1. Add knowledge base known-error entry for single-user lockout pattern with exact event signature and recovery validation step.
2. Add lightweight monitoring/report for repeated wrong-password plus lockout event chains on high-use endpoints.

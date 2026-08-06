Symptom     : User FINBRIDGE\cthompson is unable to complete interactive login. During the incident window, login attempts failed and access was interrupted.

Cause       : Repeated wrong-password authentication attempts for FINBRIDGE\cthompson resulted in account lockout. This is verified by Event 4776 (0xC000006A), repeated Event 4625 bad-password failures, and Event 4740 lockout.

Scope       : Affected scope was one user only: FINBRIDGE\cthompson. Observed systems in evidence were DESKTOP-FB022 and additional failed Kerberos attempts from source IP 10.10.8.112.

Workaround  : Restore access by enabling the user account as performed in the incident (Event 4722 at 09:08:14 by FINBRIDGE\helpdesk-admin). Verify immediate recovery with successful interactive login (Event 4624 at 09:09:01 from DESKTOP-FB022).

Permanent fix: Use the incident preventive control for recurrence: identify and address all active bad-attempt sources before closure, then confirm successful Event 4624 login. Also apply the documented lockout triage checklist and source capture steps in the incident process.

How to spot it: Look for the event chain in time order: Event 4776 wrong password (0xC000006A), repeated Event 4625 bad-password failures, Event 4740 account lockout, and Event 4771 Kerberos pre-auth failure code 0x18 (wrong password). Recovery signature is Event 4722 account enabled followed by Event 4624 successful interactive logon.

# RCA: User Lockout Incident (jsmith)

## Incident Summary

- Incident type: User account lockout
- User: `jsmith`
- Time window analyzed: 08:02:14 to 08:23:44 (about 22 minutes)
- Source endpoint in all failed attempts: `DESKTOP-FB001`

## Event ID Meaning

### Event ID 4625 (Audit Failure)

What it records:
- A failed logon attempt.
- Includes failure reason (for example bad password or locked account), source machine, and logon type.

How it appears in this incident:
- 08:02:14: Bad password on interactive logon (type 2).
- 08:04:22: Another bad password on interactive logon (type 2).
- 08:07:45: Failed unlock attempt because account was already locked (type 7).

### Event ID 4740 (Audit Failure)

What it records:
- An account was locked out by lockout policy.
- Includes the caller/source computer where triggering attempts came from.

How it appears in this incident:
- 08:06:01: Account `jsmith` locked out; caller/source is `DESKTOP-FB001`.

### Event ID 4722 (Audit Success)

What it records:
- A user account was enabled/unlocked by an administrator action.
- Includes who performed the action.

How it appears in this incident:
- 08:22:10: Account enabled by `FINBRIDGE\helpdesk-admin`.

### Event ID 4624 (Audit Success)

What it records:
- A successful logon.
- Includes logon type and target account.

How it appears in this incident:
- 08:23:44: `jsmith` successfully logged on interactively (type 2).

## Reconstructed Sequence (Plain English)

1. At 08:02, the user account `jsmith` had a failed interactive sign-in on `DESKTOP-FB001` due to bad credentials.
2. At 08:04, another failed interactive sign-in occurred from the same machine for the same reason.
3. At 08:06, the domain/account lockout threshold was reached and `jsmith` was locked out (Event 4740), with `DESKTOP-FB001` identified as the calling computer.
4. At 08:07, an unlock-style attempt (logon type 7) failed because the account was already in locked state.
5. At 08:22, helpdesk admin re-enabled/unlocked the account.
6. At 08:23, user `jsmith` logged on successfully, indicating credentials and account status were then valid.

## Most Likely Cause of Lockout

Most likely cause:
- Repeated incorrect interactive password entry (or stale cached credentials used interactively) on `DESKTOP-FB001` triggered account lockout policy.

Evidence from events:
- Two consecutive Event 4625 entries with failure reason "Unknown username or bad password" from `DESKTOP-FB001` at 08:02 and 08:04.
- Event 4740 at 08:06 explicitly states account lockout and identifies caller `DESKTOP-FB001`.
- Event 4625 at 08:07 with failure reason "Account locked out" confirms the account state after threshold breach.
- Event 4624 success after helpdesk unlock indicates issue was lock state/credential attempts rather than persistent identity disablement.

## 5-Why Analysis

1. Why was `jsmith` unable to access the machine?
- The account became locked (Event 4740).

2. Why did the account become locked?
- The lockout threshold was exceeded by failed sign-in attempts (Event 4625 bad password entries before lockout).

3. Why were there repeated failed sign-in attempts?
- The credentials used at the endpoint were incorrect at least twice in succession (same account, same source, interactive logon).

4. Why were incorrect credentials being used on that endpoint?
- Most probable operational causes: user password entry error, keyboard/layout mismatch, or stale credentials entered at sign-in/unlock prompt.
- This incident data alone cannot conclusively distinguish among these sub-causes.

5. Why did this become a user-impacting incident instead of a self-correcting error?
- Lockout policy correctly enforced account protection once threshold was reached, and user access was blocked until administrative intervention (Event 4722).

## Root Cause Statement

`jsmith` was locked out due to repeated bad-password interactive sign-in attempts originating from `DESKTOP-FB001`, which triggered account lockout policy, requiring helpdesk administrative unlock before successful access was restored.

## Contributing Factors

- No evidence of immediate user-side correction before threshold was reached.
- Continued attempt post-lockout (unlock logon type 7) suggests user was still attempting access while account remained locked.

## Corrective and Preventive Actions

Immediate corrective actions:
- Helpdesk unlock/re-enable completed (observed via Event 4722).
- User successfully logged in after unlock (Event 4624).

Preventive actions:
- Confirm lockout threshold and reset window are aligned with security policy and user experience needs.
- Educate user to stop retrying after one or two failures and contact support early.
- Check keyboard layout/input language on lock screen for the affected endpoint.
- Verify no saved/stale credentials are being auto-submitted from local credential stores or sign-in helpers on the endpoint.
- Monitor for repeated 4625 bursts from the same endpoint/account pair to trigger proactive support outreach.

## Confidence and Limitations

- Confidence in primary cause: High.
- Limitation: Only a subset of event lines was provided; no DC-side full security log set, Kerberos/NTLM detail, or endpoint credential manager traces were included.

# User Logon Incident Analysis and Hypothesis (Scope-Only)

## Scope Facts Used
- Symptom: user cthompson not able to login.
- Who: cthompson only (single-user impact).
- Since: approximately 08:40 this morning.
- Change: nil.

## Ranked Top 5 Likely Causes (Most Probable First)

1. User account authentication issue (bad password, account lockout, expired/disabled account)
- Why this fits scope facts: The incident is isolated to one user with no broader change signal, which strongly aligns with a user-specific identity state.
- Fastest check: Check identity sign-in and account status for cthompson at/after 08:40 (lockout, disabled, password/credential failure reason).

2. MFA or Conditional Access challenge failure for this user
- Why this fits scope facts: A single-user failure with no platform change often maps to per-user MFA method issues, device compliance mismatch, or policy outcome specific to that identity/session context.
- Fastest check: Review cthompson sign-in result details for CA/MFA outcome and specific failure reason at first failed attempt after 08:40.

3. Local client/session token issue on cthompson device
- Why this fits scope facts: One-user impact and no reported service-wide change is consistent with stale token/cache or local client state corruption on that endpoint.
- Fastest check: Have cthompson attempt login from an alternate client path (web vs desktop app, or second device) and compare result immediately.

4. User-specific profile/session initialization failure after authentication
- Why this fits scope facts: Login failure perception can be user-specific if authentication succeeds but session initialization for that user fails; single-user scope is compatible with this pattern.
- Fastest check: Verify whether authentication succeeds in logs and then check session-host events for that user around 08:40 for post-auth session/profile errors.

5. User-specific network/path constraint at time of login (DNS, VPN, proxy, local connectivity)
- Why this fits scope facts: A local path issue can affect only one user and appear suddenly without environment change.
- Fastest check: Test cthompson login from an alternate network path (for example, hotspot) to quickly confirm or eliminate endpoint network dependency.

## Position Statement
This is a scope-based probability ranking only. No single root cause is selected yet, and each hypothesis requires the corresponding fastest check above.

## Event Evidence Addendum (08:44-09:12)

### Evidence Source
- Security Event Log on DESKTOP-FB022.
- Window reviewed: 2024-03-15 08:44 to 09:12.

### Key Events Captured
- 08:44:01 - Event 4776 Audit Failure: credential validation failed for FINBRIDGE\cthompson; error 0xC000006A (wrong password); source workstation DESKTOP-FB022.
- 08:44:03 - Event 4625 Audit Failure: unknown user name or bad password; logon type 2; source DESKTOP-FB022.
- 08:44:28 - Event 4625 Audit Failure: unknown user name or bad password; logon type 2; source DESKTOP-FB022.
- 08:44:55 - Event 4625 Audit Failure: unknown user name or bad password; logon type 2; source DESKTOP-FB022.
- 08:44:56 - Event 4740 Audit Failure: user account FINBRIDGE\cthompson locked out; caller computer DESKTOP-FB022.
- 08:45:10 - Event 4625 Audit Failure: failure reason account locked out; logon type 7; source DESKTOP-FB022.
- 08:45:44 - Event 4771 Audit Failure: Kerberos pre-auth failed; failure code 0x18 (wrong password); source IP 10.10.8.112.
- 08:46:01 - Event 4771 Audit Failure: Kerberos pre-auth failed; failure code 0x18; source IP 10.10.8.112.
- 08:46:33 - Event 4771 Audit Failure: Kerberos pre-auth failed; failure code 0x18; source IP 10.10.8.112.

## Hypothesis-to-Evidence Assessment

1. User account authentication issue (bad password, lockout, expired/disabled)
- Judgement: Supports.
- Determining evidence: Event 4776 at 08:44:01 (wrong password), Event 4625 at 08:44:03/08:44:28/08:44:55 (bad password), Event 4740 at 08:44:56 (account lockout), and Event 4625 at 08:45:10 (account locked out).

2. MFA or Conditional Access challenge failure
- Judgement: Contradicts.
- Determining evidence: All supplied failures are password/lockout/Kerberos events (4776/4625/4740/4771) from 08:44:01 through 08:46:33; no MFA/CA failure event appears in the evidence set.

3. Local client/session token issue on cthompson device
- Judgement: Neutral.
- Determining evidence: Failures do occur on DESKTOP-FB022, but repeated wrong-password pre-auth failures also occur from 10.10.8.112 (Event 4771 at 08:45:44/08:46:01/08:46:33), so evidence is not limited to a single local endpoint state.

4. User-specific profile/session initialization failure after authentication
- Judgement: Contradicts.
- Determining evidence: Evidence shows pre-auth and authentication failures (Event 4776/4625/4771) and lockout (Event 4740), with no successful authentication followed by post-auth profile/session failure events.

5. User-specific network/path constraint at time of login
- Judgement: Neutral.
- Determining evidence: Multiple source points are visible (DESKTOP-FB022 and 10.10.8.112), but failure codes explicitly indicate wrong password and lockout rather than direct transport/path error signatures.

## Survived Hypothesis After Elimination
User account authentication failure leading to account lockout for FINBRIDGE\cthompson, driven by repeated wrong-password attempts.

## Detailed Resolution Steps

1. Contain relock trigger sources
- Identify and stop repeated bad-credential retries before unlock.
- Investigate both observed sources: DESKTOP-FB022 and 10.10.8.112 for stored or automated credential use.

2. Validate account state
- Confirm lockout state, bad password count, and last bad password timestamp for FINBRIDGE\cthompson.
- Confirm account is not additionally disabled or expired.

3. Reset credentials
- Perform controlled password reset for cthompson via approved process.
- Communicate temporary credential via approved secure channel and enforce standard password-change policy at next sign-in where required.

4. Clear stale credentials on all active endpoints/sources
- Remove saved credentials tied to domain and business apps from Credential Manager on DESKTOP-FB022.
- Re-authenticate primary apps after reset (for example, Microsoft 365 apps) so old credentials are not retried.
- Apply same cleanup on system/source associated with 10.10.8.112.

5. Unlock and controlled test
- Unlock account only after cleanup is complete.
- Run single controlled interactive login test and verify success.

6. Verify stability and close
- Monitor for absence of new Event 4740 lockout and absence of repeated wrong-password failures (4776/4625/4771) for a short observation period.
- Confirm user can sign in normally and mark incident resolved when stable.

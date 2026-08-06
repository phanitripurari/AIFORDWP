# End-User Communications: Win11 Floor 3 Login/GPO Incident (Three Audiences)

## Shared Facts (Applied Consistently Across All Three Versions)
- Incident started around 07:55 on 2024-03-15.
- Three Windows 11 machines on Floor 3 were affected.
- Cause: central address-assignment settings still pointed affected machines to an old retired name-lookup service after the overnight change.
- Correct setting in use is 10.10.0.10; old retired setting observed on affected machines was 10.10.3.250.
- Fix applied: central assignment corrected and affected machines refreshed.
- Service verified restored at 10:00.
- Access restored; no data loss observed from this incident.

## Audience 1: Non-Technical Executive (Under 80 Words)
Your access is restored, and your data is safe. Around 07:55 this morning, three Windows 11 PCs on Floor 3 could not sign in correctly because they received an outdated network lookup setting after an overnight infrastructure change. We corrected the central setting, refreshed the affected PCs, and confirmed full recovery at 10:00. No data loss was observed. You do not need to do anything unless you still cannot sign in.

## Audience 2: Affected End-User Team (10 People, Non-Technical, Under 100 Words)
Hi team, your access is back and your data is safe. Around 07:55 this morning, three Floor 3 Windows 11 PCs were given an old network sign-in lookup setting after overnight changes, which caused sign-in and policy loading to fail. We fixed the central setting, refreshed the affected PCs, and confirmed everything was back to normal at 10:00, with no data loss observed. If you see this again, restart once and then contact the Service Desk with your PC name and floor location.

## Audience 3: Engineer-to-Engineer Internal Note
Root cause:
- Floor 3 DHCP scope configuration (Option 006 path) still referenced retired DNS target 10.10.3.250 after overnight decommission activity.
- Affected set: 3 Win11 endpoints on Floor 3 starting ~07:55.
- Control endpoint (same OU) had correct DNS 10.10.0.10 and remained healthy.

Exact action taken:
- Updated central assignment config to remove retired DNS value(s) and set active DNS to 10.10.0.10.
- Refreshed affected clients: ipconfig /release, /renew, /flushdns, /registerdns.
- Re-ran policy/domain path checks and confirmed recovery.

Config detail captured:
- Wrong observed on affected: 10.10.3.250.
- Correct target: 10.10.0.10.

Verification:
- Affected hosts recovered sign-in/policy processing.
- Incident resolved and confirmed at 10:00.
- No data loss observed.

Preventive action required:
- Add mandatory post-change validation that DHCP scope DNS options match active DNS before decommission closure.
- Add subnet canary checks and alerting for retired DNS values being assigned.

# Known Error Record: Win11 Login / Group Policy Failure (Floor 3)

Symptom: Users on affected Floor 3 Windows 11 machines could not sign in correctly and Group Policy processing failed around startup/login. On DESKTOP-FB031, policy retrieval failed with SYSVOL access errors and no domain controller connectivity during the incident window.

Cause: The Floor 3 DHCP scope still referenced a decommissioned DNS server after the overnight DNS migration. Affected endpoints received invalid DNS settings, which prevented domain controller name resolution and caused Netlogon and Group Policy failures.

Scope: Three Windows 11 machines on Floor 3 were affected during the incident (including DESKTOP-FB031), while DESKTOP-FB029 in the same OU was unaffected. Impact was limited to endpoints that received the retired DNS value; service was confirmed restored at 10:00.

Workaround: Correct DHCP DNS option values for the Floor 3 scope to active DNS and remove retired DNS entries, then refresh affected clients (release/renew/flush/register). After refresh, validate DC discovery and force Group Policy update to restore service.

Permanent fix: Update and enforce the DNS decommission process so DHCP Option 006 is verified for all impacted scopes before change closure. Add subnet canary validation and monitoring for retired DNS values being assigned.

How to spot it: Look for Netlogon Event 5719, GroupPolicy Events 1058/1030/1129, DNS Client Event 1014, and DHCP Client Event 50036 showing assignment of retired DNS (for this incident, 10.10.3.250 instead of 10.10.0.10). Typical messages include "no domain controller available," DNS timeout/no response for FINBRIDGE-DC01.finbridge.local, and inability to access \\FINBRIDGE-DC01\sysvol\finbridge.local\Policies\...\gpt.ini.
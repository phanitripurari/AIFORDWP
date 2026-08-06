# RCA Report: Win11 Login Failure / Group Policy Failure (Floor 3)

## Document Control
- Incident type: Multi-endpoint domain logon and Group Policy processing failure
- Service context: Active Directory authentication and GPO retrieval
- Affected platform: Windows 11 endpoints (Floor 3 subnet)
- Affected endpoints (known): DESKTOP-FB031 plus two additional Win11 machines (3 affected total)
- Comparator endpoint: DESKTOP-FB029 (same OU, unaffected)
- Incident date: 2024-03-15
- RCA prepared date: 2026-08-06
- Final status: Resolved
- Resolution confirmed at: 10:00

## Executive Summary
At approximately 07:55, three Win11 machines on Floor 3 began showing login/GPO failure symptoms. Event evidence on DESKTOP-FB031 shows domain controller discovery and Group Policy processing failed because DNS queries for domain resources were not answered. DHCP logs and host events confirm affected machines were assigned a decommissioned Floor 3 DNS server, while an unaffected same-OU endpoint received the correct new DNS server and processed policy successfully. After updating DHCP DNS scope configuration and refreshing client leases/resolver state, service recovered and was confirmed resolved at 10:00.

## Scope and Impact
- Impacted endpoint count: 3 Win11 machines (Floor 3 subnet).
- Non-impacted control in same OU: DESKTOP-FB029.
- User impact: domain-dependent sign-in and policy processing failures on affected endpoints.
- Business impact: access disruption and degraded endpoint manageability for affected users.

## Supporting Evidence

### Affected Host Evidence: DESKTOP-FB031
Startup window examined: 07:40-07:55

- 07:40:08 - Netlogon Event 5719 (Error)
  - Unable to set up secure channel to domain FINBRIDGE.
  - No domain controller available.
  - DNS query for FINBRIDGE-DC01.finbridge.local returned no response.

- 07:40:09 - GroupPolicy Event 1058 (Error)
  - Failed to access SYSVOL gpt.ini path:
  - \\FINBRIDGE-DC01\sysvol\finbridge.local\Policies\{3A1B2C4D-E5F6-7890-ABCD-EF1234567890}\gpt.ini
  - Error code: 0x3 (path not found).

- 07:40:10 - GroupPolicy Event 1030 (Warning)
  - Cannot query list of Group Policy objects.
  - Error code: 0x546.

- 07:40:12 - GroupPolicy Event 1129 (Error)
  - Group Policy failed due to no network connectivity to a domain controller.

- 07:41:05 - DNS Client Event 1014 (Warning)
  - Name resolution timed out for FINBRIDGE-DC01.finbridge.local.
  - None of configured DNS servers responded.

- 07:42:18 - DHCP Client Event 50036 (Information)
  - Lease obtained from DHCP server 10.10.0.1.
  - DNS assigned by DHCP: 10.10.3.250.
  - 10.10.3.250 is the old/decommissioned DNS server.

- 07:44:01 - GroupPolicy Event 1129 (Error)
  - Repeated no-DC-connectivity policy failure.

### Comparator Evidence: DESKTOP-FB029 (Same OU, Unaffected)

- 07:40:05 - DHCP Client Event 50036
  - DNS assigned: 10.10.0.10 (correct new DNS).

- 07:40:11 - GroupPolicy Event 1500 (Information)
  - Group Policy processed successfully.

### DHCP Configuration Comparison Evidence
- Affected set (FB055-057): DNS assigned as decommissioned Floor 3 DNS.
- Unaffected control (FB058/FB029 equivalent pattern): DNS assigned 10.10.0.10.
- Administrative finding: DHCP scope for Floor 3 subnet was not updated after DNS decommission wave.

## Evidence-Based Elimination of Initial Hypotheses

1. Affected clients point to decommissioned DNS
- Judgement: Supported
- Determining evidence: DHCP Event 50036 at 07:42:18 plus DNS timeout Event 1014 at 07:41:05.

2. DHCP scope serves stale DNS to subset
- Judgement: Supported
- Determining evidence: Affected DHCP assignment (07:42:18, Event 50036) versus unaffected correct assignment (07:40:05, Event 50036).

3. DNS forwarding/conditional forwarder break
- Judgement: Contradicted
- Determining evidence: Unaffected host received correct DNS and succeeded GPO (07:40:11, Event 1500).

4. Floor network ACL/VLAN/firewall blocked DC services
- Judgement: Contradicted
- Determining evidence: Primary failure chain is resolver assignment and DNS timeout (Events 50036 and 1014), with successful same-OU comparator.

5. Stale local cache/lease only
- Judgement: Contradicted
- Determining evidence: Fresh DHCP lease delivered incorrect DNS at 07:42:18 (Event 50036), indicating active configuration issue.

## Incident Timeline
- 2024-03-14 02:00 - Floor 3 local DNS decommissioned during migration wave.
- ~07:55 - Incident symptom recognized: affected Win11 machines reporting no Group Policy/login issues.
- 07:40:08 - Netlogon 5719 on FB031: no DC available; DNS query no response.
- 07:40:09 to 07:40:12 - GroupPolicy 1058/1030/1129 failure chain starts on FB031.
- 07:41:05 - DNS Client 1014 timeout on FB031 for DC FQDN.
- 07:42:18 - DHCP 50036 on FB031 shows old DNS server assignment.
- 07:44:01 - GroupPolicy 1129 repeats on FB031.
- 07:40:05 to 07:40:11 (control path) - FB029 receives correct DNS and logs successful GPO processing.
- 08:xx-09:xx - Remediation actions applied: DHCP Option 006 corrected, endpoint lease/DNS refresh performed, policy/connectivity retested.
- 10:00 - Issue confirmed resolved.

## Root Cause Statement
The Floor 3 DHCP scope retained decommissioned DNS server entries after the overnight DNS migration, causing affected endpoints to receive invalid DNS configuration. This prevented domain controller name resolution, which then caused Netlogon secure-channel failures and Group Policy processing failures during login/startup.

## Contributing Factors
- DNS decommission and DHCP scope update were not fully synchronized in the same change window.
- Partial endpoint protection from manual pre-configuration masked broad DHCP misconfiguration risk.
- No enforced pre-close validation that all impacted scopes had correct DHCP Option 006 values.

## 5 Whys Analysis
1. Why did users on affected Win11 machines experience login/GPO failure?
- Because endpoints could not reach domain services required for authentication and Group Policy processing.

2. Why could endpoints not reach domain services?
- Because domain controller names could not be resolved (DNS queries timed out/no response).

3. Why did DC name resolution fail?
- Because affected endpoints were assigned a decommissioned DNS server IP.

4. Why were endpoints assigned a decommissioned DNS server?
- Because the Floor 3 DHCP scope Option 006 still referenced old DNS after the decommission.

5. Why was DHCP scope not corrected before/with DNS cutover completion?
- Because change control/checklist execution did not enforce a hard dependency check between DNS decommission tasks and DHCP scope option validation for all impacted subnets.

## Resolution Actions Applied
1. Corrected DHCP scope Option 006 for Floor 3 subnet to active DNS server values (including 10.10.0.10 as primary).
2. Removed decommissioned DNS entries from applicable DHCP option levels/reservations.
3. Refreshed affected client network state:
- ipconfig /release
- ipconfig /renew
- ipconfig /flushdns
- ipconfig /registerdns
4. Revalidated domain/GPO path:
- DC discovery and DNS SRV lookups succeeded.
- Group Policy processing resumed.
5. Recovery confirmed at 10:00.

## Validation of Recovery
- Technical validation:
  - Correct DNS assignment observed after DHCP correction.
  - DNS resolution for DC resources recovered.
  - GroupPolicy success events observed after remediation window.
- Operational validation:
  - Affected users regained expected access.
  - No further no-DC/GPO failure pattern reported after 10:00.

## Preventive Actions

### Immediate
1. Add mandatory DHCP Option 006 verification to all DNS decommission execution checklists.
2. Require a subnet-by-subnet canary validation before declaring migration completion.

### Near-Term
1. Implement automated DHCP config audit to detect retired DNS IPs in active scopes/reservations.
2. Add post-change health checks that query:
- Netlogon 5719 spikes
- GroupPolicy 1058/1030/1129 spikes
- DNS Client 1014 spikes
3. Add explicit rollback trigger if impacted endpoint samples fail DC SRV lookup or GPO processing.

### Long-Term
1. Standardize dependency-gated change workflow:
- DNS decommission cannot close until DHCP option verification is attested for all affected VLANs/subnets.
2. Build CMDB-linked migration map so DNS and DHCP owners review and sign off jointly.
3. Add continuous compliance reporting for endpoint DNS settings vs approved baseline.

## Residual Risk and Follow-Up
- Residual risk: other subnets may still contain retired DNS values if not yet audited.
- Follow-up owner actions:
  - Complete enterprise-wide DHCP Option 006 audit.
  - Archive before/after scope exports as permanent evidence.
  - Update known-error/runbook documentation with this incident signature.

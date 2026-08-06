# Scope-Only Ranked Hypotheses: Win11 Login Failure / No Group Policy (Floor 3)

## Scope Facts Used
- Symptom: three Win11 machines on Floor 3 show no Group Policy; login failure symptom under investigation.
- Who: `DESKTOP-FB031` affected; `DESKTOP-FB029` in same OU is unaffected.
- Since: about 07:55 this morning.
- Change: Floor 3 local DNS was decommissioned overnight on 2024-03-14.

## Ranked Top 5 Likely Causes (Most Probable First)

### 1) Affected clients still point to decommissioned Floor 3 DNS (primary or only resolver)
Why this fits scope facts:
- Timing aligns directly with the overnight DNS decommission and morning onset.
- "No Group Policy" commonly occurs when clients cannot resolve AD/DC records (`_ldap._tcp`, `_kerberos`) due to wrong DNS.
- Same OU with one unaffected machine supports a client/network-specific resolver issue rather than OU policy configuration.

Single fastest check:
- On an affected machine run `ipconfig /all` and verify DNS server list; if it contains the retired Floor 3 DNS IP, this hypothesis is strongly confirmed.

### 2) DHCP scope/reservation on Floor 3 is serving stale DNS options to only a subset of clients
Why this fits scope facts:
- Explains why only some Floor 3 machines fail while another in same OU works.
- Matches abrupt start time after overnight infrastructure change.
- Produces the same AD name-resolution failure pattern that blocks GPO processing and can impact domain logon.

Single fastest check:
- Compare `ipconfig /all` DNS servers on one affected host versus `DESKTOP-FB029`; if affected hosts have different/stale DNS values, this cause is likely.

### 3) DNS forwarding/conditional forwarding path for AD zones broke during DNS decommission
Why this fits scope facts:
- Can create partial impact where some clients resolve AD names (cached/alternate path) and others fail.
- Directly tied to the documented DNS change window.
- Would manifest first as policy retrieval/logon problems on startup when fresh queries are needed.

Single fastest check:
- From an affected machine run `nslookup -type=SRV _ldap._tcp.dc._msdcs.<your-domain>` using current default DNS; failure or timeout quickly confirms DNS path breakage.

### 4) Floor 3 network path change (ACL/VLAN/firewall) now blocks access to DC services, with DNS decommission as the trigger event
Why this fits scope facts:
- A floor-specific infrastructure change can impact only a subset of machines.
- GPO and logon require connectivity to DC services (LDAP/Kerberos/SMB); blocked ports mimic "no policy" symptoms.
- Same OU unaffected is still possible if unaffected host is on a different switch/VLAN/port profile.

Single fastest check:
- From an affected client test DC reachability with `nltest /dsgetdc:<your-domain>`; if DC cannot be located/contacted while unaffected can, network path issue is strongly indicated.

### 5) Affected clients have stale local network state after change (old lease/DNS cache) while unaffected host refreshed cleanly
Why this fits scope facts:
- Explains small blast radius and same-OU mixed behavior.
- Fits exact morning onset after overnight change if affected endpoints retained old resolver/network info.
- Can block domain resource resolution until lease/cache refresh.

Single fastest check:
- On one affected machine run `ipconfig /release` then `ipconfig /renew` and `ipconfig /flushdns`, then `gpupdate /force`; if policy retrieval immediately recovers, stale local state is likely.

## Notes
- This is a scope-fact hypothesis ranking only; no single root cause is confirmed yet.
- The checks above are intentionally the quickest binary checks to confirm or eliminate each hypothesis.

---

## Update: Event Evidence Review (Incident Window)

### Evidence Set Reviewed
- Source host: `DESKTOP-FB031` (affected)
- Window: `2024-03-15 07:40-07:55`
- Comparator: `DESKTOP-FB029` (same OU, unaffected)

Key entries used:
- `07:40:08` Netlogon `5719` (Error): no secure channel to domain; DNS query for DC returned no response.
- `07:40:09` GroupPolicy `1058` (Error): cannot access SYSVOL `gpt.ini` path.
- `07:40:10` GroupPolicy `1030` (Warning): cannot query GPO list.
- `07:40:12` GroupPolicy `1129` (Error): no network connectivity to a domain controller.
- `07:41:05` DNS Client `1014` (Warning): name resolution timeout; configured DNS servers did not respond.
- `07:42:18` DHCP Client `50036` (Info): lease received; DNS assigned `10.10.3.250` (old/decommissioned DNS).
- `07:44:01` GroupPolicy `1129` (Error): repeated no-DC-connectivity policy failure.

Comparison entries:
- `07:40:05` FB029 DHCP Client `50036`: DNS assigned `10.10.0.10` (correct new DNS).
- `07:40:11` FB029 GroupPolicy `1500` (Info): Group Policy processed successfully.

### Hypothesis-by-Hypothesis Judgement Against Event Evidence

1) Affected clients still point to decommissioned Floor 3 DNS
- Judgement: **Support**
- Determining evidence:
	- DHCP `50036` at `07:42:18` assigns old DNS `10.10.3.250`.
	- DNS timeout `1014` at `07:41:05`.
	- Netlogon failure `5719` at `07:40:08`.

2) DHCP scope/reservation on Floor 3 is serving stale DNS to a subset
- Judgement: **Support**
- Determining evidence:
	- Affected FB031 DHCP `50036` at `07:42:18`: old DNS.
	- Unaffected FB029 DHCP `50036` at `07:40:05`: correct DNS.
	- FB029 GroupPolicy success `1500` at `07:40:11` confirms mixed outcome consistent with subset assignment.

3) DNS forwarding/conditional forwarding path broke during decommission
- Judgement: **Contradict**
- Determining evidence:
	- FB029 receives correct DNS at `07:40:05` (`50036`) and succeeds policy processing at `07:40:11` (`1500`).
	- Affected failures line up with wrong DNS assignment instead.

4) Floor 3 network path blocks DC services (ACL/VLAN/firewall)
- Judgement: **Contradict**
- Determining evidence:
	- DNS assignment and resolution failures (`50036` at `07:42:18`, `1014` at `07:41:05`) explain no-DC symptoms without requiring a DC-port block.
	- Same-OU unaffected comparator has successful policy event `1500` at `07:40:11`.

5) Stale local client lease/cache state after change
- Judgement: **Contradict**
- Determining evidence:
	- Fresh DHCP lease event `50036` at `07:42:18` actively delivered old DNS, indicating live config issue rather than only stale local cache.

## Surviving Hypothesis

DHCP scope for the Floor 3 subnet still references decommissioned DNS server(s), causing affected endpoints to receive invalid DNS configuration, fail DC name resolution, and then fail Group Policy and logon-related domain operations.

## Resolution Steps (Detailed)

1. Incident control and change record
- Open/attach change record and freeze additional Floor 3 DNS/network changes until validation is complete.
- Record impacted hosts and subnet for traceability.

2. Correct DHCP DNS options
- On authoritative DHCP for Floor 3 scope, update Option `006` (DNS Servers):
	- Remove decommissioned DNS IP(s) (including `10.10.3.250` and any retired Floor 3 DNS values).
	- Add active DNS (`10.10.0.10` as primary, plus approved secondary if defined).
- Verify effective values at:
	- Server-level options
	- Scope-level options
	- Reservation-level options
- If DHCP failover exists, force/schedule replication and validate both partners show identical Option `006` values.

3. Fix endpoint-level DNS drift (if present)
- Check affected machines for static adapter DNS overrides.
- Standardize to DHCP-managed DNS or approved static DNS baseline per policy.

4. Force lease and resolver refresh on affected hosts
- Run on each affected endpoint:
	- `ipconfig /release`
	- `ipconfig /renew`
	- `ipconfig /flushdns`
	- `ipconfig /registerdns`
- Confirm `ipconfig /all` now shows correct DNS server(s).

5. Validate domain connectivity and policy processing
- `nltest /dsgetdc:finbridge.local` (DC discovery succeeds)
- `nslookup -type=SRV _ldap._tcp.dc._msdcs.finbridge.local` (valid SRV responses)
- `gpupdate /force` (completes without repeated 1058/1030/1129 failures)
- Validate access to `\\FINBRIDGE-DC01\sysvol\finbridge.local\Policies\`.

6. Event-log acceptance criteria
- Confirm affected hosts stop generating:
	- Netlogon `5719`
	- DNS Client `1014` for DC names
	- GroupPolicy `1058`, `1030`, `1129`
- Confirm successful Group Policy processing events after fix window.

7. Prevent recurrence
- Update DNS decommission checklist to include mandatory DHCP Option `006` verification before closure.
- Add pre/post-change validation for each impacted subnet using canary endpoints.
- Add monitoring for leases assigning retired DNS IPs and spikes of 5719/1129.

8. Closure evidence package
- Before/after DHCP option export or screenshots.
- Before/after `ipconfig /all` from one affected and one unaffected host.
- Successful `nltest`, `nslookup`, and `gpupdate` outputs.
- Timeline showing event-error cessation after DHCP correction.
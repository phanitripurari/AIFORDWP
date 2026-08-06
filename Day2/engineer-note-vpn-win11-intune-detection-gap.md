Root cause: Win11 upgrade removed legacy VPN client; Intune did not re-deploy new client due to detection-rule gap.

Action taken:
1. Manually removed stale VPN registry entries under HKLM\SOFTWARE\<vendor>.
2. Force-triggered Intune sync.
3. New VPN client deployed.
4. Split-tunnel config applied.

Verification:
1. Connectivity confirmed to all internal subnets.
2. No data loss.

Preventive action needed:
1. Fix detection-rule gap so Win11-upgraded devices correctly trigger Intune re-deployment of the new VPN client.

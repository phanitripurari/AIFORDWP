# Known Error Record: Finance Shared Drives Access Failure

Symptom: Finance users could not access mapped shared drives, and required drive letters were not assigned. During the incident window, users experienced loss of shared-drive-dependent access until remediation was applied.

Cause: The drive mapping process was migrated from a GPO logon script running in USER context to an Intune PowerShell script running in SYSTEM context. The script failed UNC access in SYSTEM context (\\finbridge-fs01\Finance), so mapping did not complete.

Scope: All Finance users were affected (45 users) on DESKTOP-FB* devices in OU=Finance. Incident onset was around 08:00 on 2024-03-15.

Workaround: Apply the remediation path used in the incident to restore access by correcting the mapping approach and rerunning mapping in the appropriate user session path. Confirm user shared-drive access after remediation.

Permanent fix: Implement a user-context-compatible mapping design for Finance shared drives and enforce execution-context validation before production migration. Add pilot validation before broad rollout.

How to spot it: Intune Management Extension ScriptRunner entries show SYSTEM execution and mapping failure: 08:00:02 context SYSTEM, 08:00:03 UNC not accessible and exit code 1 with "Network name cannot be found." System log signals include GroupPolicy Event 1500 success (showing GP is fine) and Ntfs Event 98 indicating drive letter S: was not assigned.
# Triage Summary - T-1007

## Summary (one line)
OneDrive is stuck on 'processing changes' since migration and user reports files missing locally, suggesting sync engine state, path conflict, or migration mapping issue (to-verify).

## Impact (who/how many/business urgency)
- Affected user(s): at least one reported user (to-verify).
- Scope: currently one ticket; potential broader post-migration sync impact if pattern repeats (to-verify).
- Business urgency: high because perceived missing local files may block daily work and create data-loss concern.

## Known facts
- Ticket ID: T-1007.
- Application: OneDrive.
- Symptom 1: stuck at 'processing changes'.
- Symptom 2: files missing locally.
- Context: issue started after migration.

## Missing information to gather
- Whether files are missing only locally or also absent in OneDrive web view (to-verify).
- Which folders are affected (Desktop/Documents/known folders/shared libraries) (to-verify).
- Available local disk space and Files On-Demand status (to-verify).
- Whether any sync errors, rename conflicts, or path length issues are shown (to-verify).
- Whether user has signed out/in of OneDrive client since migration (to-verify).
- Whether the issue affects one user or multiple migrated users (to-verify).
- Approximate count/size of affected files and last known good sync time (to-verify).

## Likely category
- Collaboration and Storage > OneDrive > Post-migration sync/stale state issue (to-verify).

## First diagnostic step
Determine data location first: verify file presence in OneDrive web for the affected account and compare with local sync scope on the device; this quickly separates sync-client state issues from potential migration/data-location issues (to-verify).

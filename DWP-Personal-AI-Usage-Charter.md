# Personal AI Usage Charter (DWP Endpoint Engineer, Public AI Assistants)

## Purpose
Use public AI tools to improve speed and quality of endpoint support work while protecting security, privacy, and service integrity.

## Scope
This charter applies to day-to-day desktop and endpoint engineering activities (Windows builds, software packaging, troubleshooting, scripting, and service desk support) when using public AI assistants.

## 1. Appropriate DWP Tasks for Public LLM Help
Use public AI assistants for low-risk, non-sensitive tasks such as:

1. Drafting and improving generic PowerShell, batch, or command-line scripts using placeholder data only.
2. Explaining Windows and endpoint concepts (startup performance, logs, services, profiles, Intune and GPO behavior).
3. Creating troubleshooting checklists and runbooks for common issues (slow device, app launch failures, update errors).
4. Writing user-facing communications and knowledge article drafts with no identifiable user or system details.
5. Translating technical notes into plain English for handover documentation.
6. Building test plans, rollback plans, and validation steps for endpoint changes.
7. Reviewing script structure for readability, error handling, and idempotency before internal testing.

## 2. Tasks Not Appropriate for Public LLMs
Do not use public AI assistants for any task that exposes DWP-sensitive information or delegates decision-making that requires trusted internal context:

1. Sharing incident tickets, logs, screenshots, or transcripts containing real user, device, or case identifiers.
2. Sharing internal hostnames, IP ranges, AD structure, tenant details, security tooling details, or architecture specifics.
3. Uploading scripts or configs that contain secrets, tokens, certificates, private keys, or privileged command patterns tied to production.
4. Asking AI to decide production changes without internal CAB or change controls and peer review.
5. Using AI outputs directly on production endpoints without local verification and approved change process.
6. Entering unpublished policy, vulnerability, or threat information into public tools.

## 3. Data-Handling Rule for End-User PII and Credentials
Non-negotiable rule: never input real end-user PII, credentials, or secrets into a public AI assistant.

1. Remove or replace names, emails, phone numbers, usernames, staff IDs, case IDs, device serials, and exact timestamps with placeholders.
2. Redact organization identifiers and environment details that could reveal DWP internal systems.
3. Never paste passwords, MFA codes, API keys, tokens, certificates, connection strings, or recovery codes.
4. If a prompt cannot be made safe through redaction, do not use public AI for that task.
5. When in doubt, treat data as sensitive and keep work fully inside approved DWP tooling.

## 4. Personal Generate Then Verify Rule for Scripts and System Changes
Treat AI output as a draft, not an instruction.

1. Generate: ask AI for a first draft script or change with clear assumptions and safety checks.
2. Review: read every line and confirm commands, parameters, side effects, required privileges, and rollback path.
3. Static checks: run linting and security sanity checks (unsafe deletes, wildcard scope, privilege escalation, external downloads).
4. Test safely: execute in a lab or test endpoint or isolated pilot group first; never first-run in production.
5. Verify outcomes: confirm expected behavior, performance impact, logs and events, and no regression in core apps.
6. Control changes: use normal DWP change process, peer sign-off, and documented rollback before broader deployment.
7. Record evidence: document prompt intent, edits made, test results, and final approved version in internal records.

## Working Principle
Public AI can accelerate drafting and learning, but accountability remains with the engineer. The engineer is responsible for data protection, technical correctness, and safe operational change on every endpoint action.

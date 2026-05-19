---
title: Expose logs and translate backend errors without leaking backend details
status: needs-triage
type: issue
category: enhancement
labels:
  - needs-triage
  - afk
  - sand
  - sandbox-vm
  - logs
  - sandbox-backend
  - apple-container
created: 2026-05-19
---

## Parent

- `issues/sand/prd-sand-sandbox-vm.md`

## What to build

Implement `sand <name> logs` and the backend error translation path so failed starts, applies, runs, and backend service issues are diagnosable without leaking raw Apple `container` mechanics into the Control Surface or scattering backend calls through CLI commands.

## Acceptance criteria

- [ ] `sand <name> logs` exposes useful minimal runtime/backend logs for a Sandbox VM.
- [ ] Backend service failures are reported clearly in user-facing language.
- [ ] Apple `container` command failures are translated into domain/user-facing errors.
- [ ] The CLI layer does not call Apple `container` directly.
- [ ] Backend details remain behind a deep `SandboxBackend` module.
- [ ] No display-layer workaround hides a failed hard backend requirement.
- [ ] Apple `container` error translation has deterministic fixture-backed tests.
- [ ] Acceptance is demonstrated with real backend failure or fixture-backed reproduction plus at least one real Apple backend log/error path.

## Definition of Done

- [ ] Relevant deterministic tests are added or updated and `swift test` passes.
- [ ] Fixture-backed tests are allowed for error translation, but at least one real Apple backend log/error path is recorded.
- [ ] Fake/in-memory backends are allowed only in tests and cannot be selected by user-facing CLI flags, environment variables, or hidden fallbacks.
- [ ] CLI command handlers do not call Apple `container` directly; backend interaction goes through `SandboxBackend`.
- [ ] No display-layer workaround hides a failed backend, logging, or error-translation requirement.

## Blocked by

- `issues/sand/005-start-stop-delete-guest-state.md`

---
title: Open real Sandbox Sessions as the Sandbox User
status: done
type: issue
category: enhancement
labels:
  - needs-triage
  - afk
  - sand
  - sandbox-vm
  - shell
  - sandbox-session
  - apple-container
created: 2026-05-19
---

## Parent

- `issues/sand/prd-sand-sandbox-vm.md`

## What to build

Implement `sand <name> shell` as an interactive Sandbox Session into the real Sandbox Guest. The session should feel like entering a small Linux computer: non-root daily user, no login prompt, easy guest administration through passwordless sudo, and concurrent terminals supported.

## Acceptance criteria

- [x] `sand <name> shell` opens an interactive shell inside the real Sandbox Guest.
- [x] The shell runs as the non-root Sandbox User.
- [x] Opening a shell does not prompt for a guest username or password.
- [x] Passwordless sudo works inside the Sandbox Guest.
- [x] Multiple Sandbox Sessions can coexist against the same Sandbox VM.
- [x] Normal Sandbox Sessions are not serialized behind Lifecycle Mutation locks.
- [x] Acceptance is demonstrated against the real Apple backend.

## Definition of Done

- [x] Relevant deterministic tests are added or updated and `swift test` passes.
- [x] Backend-dependent acceptance evidence uses the real Apple backend.
- [x] Fake/in-memory backends are allowed only in tests and cannot be selected by user-facing CLI flags, environment variables, or hidden fallbacks.
- [x] CLI command handlers do not call Apple `container` directly; backend interaction goes through `SandboxBackend`.
- [x] No display-layer workaround hides a failed session, user, sudo, concurrency, or credential-prompt requirement.

## Evidence

- Deterministic tests: `swift test` — 58 tests passing.
- Real backend validation: `docs/validation/shell-sessions-sandbox-user/RESULTS.md`
- Raw log: `docs/validation/shell-sessions-sandbox-user/run-20260518-232548.log`

## Blocked by

- `issues/sand/006-run-opaque-workload-commands.md`

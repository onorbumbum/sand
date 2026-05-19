---
title: Open real Sandbox Sessions as the Sandbox User
status: needs-triage
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

- [ ] `sand <name> shell` opens an interactive shell inside the real Sandbox Guest.
- [ ] The shell runs as the non-root Sandbox User.
- [ ] Opening a shell does not prompt for a guest username or password.
- [ ] Passwordless sudo works inside the Sandbox Guest.
- [ ] Multiple Sandbox Sessions can coexist against the same Sandbox VM.
- [ ] Normal Sandbox Sessions are not serialized behind Lifecycle Mutation locks.
- [ ] Acceptance is demonstrated against the real Apple backend.

## Definition of Done

- [ ] Relevant deterministic tests are added or updated and `swift test` passes.
- [ ] Backend-dependent acceptance evidence uses the real Apple backend.
- [ ] Fake/in-memory backends are allowed only in tests and cannot be selected by user-facing CLI flags, environment variables, or hidden fallbacks.
- [ ] CLI command handlers do not call Apple `container` directly; backend interaction goes through `SandboxBackend`.
- [ ] No display-layer workaround hides a failed session, user, sudo, concurrency, or credential-prompt requirement.

## Blocked by

- `issues/sand/006-run-opaque-workload-commands.md`

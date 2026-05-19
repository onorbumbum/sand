---
title: Run opaque Workload Commands end-to-end in the Sandbox Guest
status: needs-triage
type: issue
category: enhancement
labels:
  - needs-triage
  - afk
  - sand
  - sandbox-vm
  - workload-command
  - apple-container
created: 2026-05-19
---

## Parent

- `issues/sand/prd-sand-sandbox-vm.md`

## What to build

Implement `sand <name> run <command> [args...]` as the generic Workload Command path into a real Sandbox Guest. `sand` should handle lifecycle and backend execution, but it must not understand or special-case the workload's own flags.

## Acceptance criteria

- [ ] `sand <name> run <command> [args...]` executes the command inside the real Sandbox Guest.
- [ ] Running a command auto-starts the Sandbox VM when it is stopped.
- [ ] Workload Command arguments are passed through unchanged, including flags that belong to the workload.
- [ ] Pi is not special-cased in command parsing or execution.
- [ ] Missing commands in the Sandbox Image fail clearly with a user-facing error.
- [ ] `run` behaves naturally for the current terminal for normal interactive and redirected command usage.
- [ ] Acceptance is demonstrated against the real Apple backend.

## Definition of Done

- [ ] Relevant deterministic tests are added or updated and `swift test` passes.
- [ ] Backend-dependent acceptance evidence uses the real Apple backend.
- [ ] Fake/in-memory backends are allowed only in tests and cannot be selected by user-facing CLI flags, environment variables, or hidden fallbacks.
- [ ] CLI command handlers do not call Apple `container` directly; backend interaction goes through `SandboxBackend`.
- [ ] No display-layer workaround hides a failed command execution, auto-start, TTY, or missing-command requirement.

## Blocked by

- `issues/sand/005-start-stop-delete-guest-state.md`

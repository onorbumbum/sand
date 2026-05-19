---
title: Start, stop, and delete while preserving real Guest State semantics
status: needs-triage
type: issue
category: enhancement
labels:
  - needs-triage
  - afk
  - sand
  - sandbox-vm
  - lifecycle
  - guest-state
  - apple-container
created: 2026-05-19
---

## Parent

- `issues/sand/prd-sand-sandbox-vm.md`

## What to build

Complete the basic lifecycle semantics for a real Sandbox VM. Start and stop should behave like powering a small Linux computer on and off, preserving Guest State. Delete should be the only v1 destructive reset-like flow and should protect the user with a prompt unless forced.

## Acceptance criteria

- [ ] `sand <name> start` starts the real Sandbox VM.
- [ ] `sand <name> stop` stops the real Sandbox VM without resetting Guest State.
- [ ] A marker written inside Guest State survives stop/start.
- [ ] `sand delete <name>` prompts before deleting by default.
- [ ] `sand delete <name> --force` skips confirmation for scripted use.
- [ ] Delete removes Host Metadata for the Sandbox VM.
- [ ] Delete removes backend resources and Guest State for the Sandbox VM.
- [ ] Concurrent Lifecycle Mutations for the same Sandbox VM are serialized and cannot corrupt Host Metadata or backend state.
- [ ] There is no separate `reset` command in the v1 command surface.
- [ ] Acceptance is demonstrated against the real Apple backend.

## Definition of Done

- [ ] Relevant deterministic tests are added or updated and `swift test` passes.
- [ ] Backend-dependent acceptance evidence uses the real Apple backend.
- [ ] Fake/in-memory backends are allowed only in tests and cannot be selected by user-facing CLI flags, environment variables, or hidden fallbacks.
- [ ] CLI command handlers do not call Apple `container` directly; backend interaction goes through `SandboxBackend`.
- [ ] No display-layer workaround hides a failed lifecycle, locking, deletion, or Guest State requirement.

## Blocked by

- `issues/sand/004-create-list-status-spec.md`

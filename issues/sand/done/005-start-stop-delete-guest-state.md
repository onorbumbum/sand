---
title: Start, stop, and delete while preserving real Guest State semantics
status: done
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

- [x] `sand <name> start` starts the real Sandbox VM.
- [x] `sand <name> stop` stops the real Sandbox VM without resetting Guest State.
- [x] A marker written inside Guest State survives stop/start.
- [x] `sand delete <name>` prompts before deleting by default.
- [x] `sand delete <name> --force` skips confirmation for scripted use.
- [x] Delete removes Host Metadata for the Sandbox VM.
- [x] Delete removes backend resources and Guest State for the Sandbox VM.
- [x] Concurrent Lifecycle Mutations for the same Sandbox VM are serialized and cannot corrupt Host Metadata or backend state.
- [x] There is no separate `reset` command in the v1 command surface.
- [x] Acceptance is demonstrated against the real Apple backend.

## Definition of Done

- [x] Relevant deterministic tests are added or updated and `swift test` passes.
- [x] Backend-dependent acceptance evidence uses the real Apple backend.
- [x] Fake/in-memory backends are allowed only in tests and cannot be selected by user-facing CLI flags, environment variables, or hidden fallbacks.
- [x] CLI command handlers do not call Apple `container` directly; backend interaction goes through `SandboxBackend`.
- [x] No display-layer workaround hides a failed lifecycle, locking, deletion, or Guest State requirement.

## Evidence

- Deterministic tests: `swift test` — 56 tests passing.
- Real backend validation: `docs/validation/start-stop-delete-guest-state/RESULTS.md`
- Raw log: `docs/validation/start-stop-delete-guest-state/run-20260518-230533.log`

## Blocked by

- `issues/sand/004-create-list-status-spec.md`

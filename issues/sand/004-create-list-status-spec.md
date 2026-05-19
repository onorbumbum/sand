---
title: Create, list, status, and spec for a real stopped Sandbox VM
status: done
type: issue
category: enhancement
labels:
  - needs-triage
  - afk
  - sand
  - sandbox-vm
  - lifecycle
  - apple-container
created: 2026-05-19
---

## Parent

- `issues/sand/prd-sand-sandbox-vm.md`

## What to build

Implement the first complete management path for a real Sandbox VM: create a named Sandbox VM with no Allowed Folders, persist its Sandbox Spec and Host Metadata, provision real backend/Guest State resources, leave it stopped, and inspect it through `list`, `status`, and `spec`.

## Acceptance criteria

- [x] `sand create <name>` creates real Host Metadata under `~/.sand/`.
- [x] `sand create <name>` provisions real backend resources and Guest State.
- [x] `sand create <name>` leaves the Sandbox VM stopped.
- [x] Sandbox Names are globally unique per Host Mac user and duplicate names are rejected clearly.
- [x] `--cpus`, `--memory`, and `--image` work at create time.
- [x] A Sandbox VM can be created with no Allowed Folders.
- [x] `sand list` shows concise Sandbox Status for created sandboxes.
- [x] `sand <name> status` shows useful configuration and real backend status without dumping raw backend structures.
- [x] `sand <name> spec` prints the active Sandbox Spec.
- [x] Acceptance is demonstrated against the real Apple backend.

## Definition of Done

- [x] Relevant deterministic tests are added or updated and `swift test` passes.
- [x] Backend-dependent acceptance evidence uses the real Apple backend.
- [x] Fake/in-memory backends are allowed only in tests and cannot be selected by user-facing CLI flags, environment variables, or hidden fallbacks.
- [x] CLI command handlers do not call Apple `container` directly; backend interaction goes through `SandboxBackend`.
- [x] No display-layer workaround hides a failed backend, Guest State, spec, metadata, or status requirement.

## Evidence

- Deterministic tests: `swift test` — 51 tests passing.
- Real backend validation: `docs/validation/create-list-status-spec/RESULTS.md`
- Raw log: `docs/validation/create-list-status-spec/run-20260518-225306.log`

## Blocked by

- `issues/sand/001a-domain-contracts-deterministic-tests.md`
- `issues/sand/002-developer-ready-sandbox-image.md`
- `issues/sand/003-doctor-command.md`

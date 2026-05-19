---
title: Create, list, status, and spec for a real stopped Sandbox VM
status: needs-triage
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

- [ ] `sand create <name>` creates real Host Metadata under `~/.sand/`.
- [ ] `sand create <name>` provisions real backend resources and Guest State.
- [ ] `sand create <name>` leaves the Sandbox VM stopped.
- [ ] Sandbox Names are globally unique per Host Mac user and duplicate names are rejected clearly.
- [ ] `--cpus`, `--memory`, and `--image` work at create time.
- [ ] A Sandbox VM can be created with no Allowed Folders.
- [ ] `sand list` shows concise Sandbox Status for created sandboxes.
- [ ] `sand <name> status` shows useful configuration and real backend status without dumping raw backend structures.
- [ ] `sand <name> spec` prints the active Sandbox Spec.
- [ ] Acceptance is demonstrated against the real Apple backend.

## Definition of Done

- [ ] Relevant deterministic tests are added or updated and `swift test` passes.
- [ ] Backend-dependent acceptance evidence uses the real Apple backend.
- [ ] Fake/in-memory backends are allowed only in tests and cannot be selected by user-facing CLI flags, environment variables, or hidden fallbacks.
- [ ] CLI command handlers do not call Apple `container` directly; backend interaction goes through `SandboxBackend`.
- [ ] No display-layer workaround hides a failed backend, Guest State, spec, metadata, or status requirement.

## Blocked by

- `issues/sand/001a-domain-contracts-deterministic-tests.md`
- `issues/sand/002-developer-ready-sandbox-image.md`
- `issues/sand/003-doctor-command.md`

---
title: Complete Allowed Folder lifecycle, policy, and real access behavior
status: needs-triage
type: issue
category: enhancement
labels:
  - needs-triage
  - afk
  - sand
  - sandbox-vm
  - allowed-folder
  - host-safe-file-ownership
  - apple-container
created: 2026-05-19
---

## Parent

- `issues/sand/prd-sand-sandbox-vm.md`

## What to build

Implement the full Allowed Folder lifecycle and policy end-to-end against the real backend. Allowed Folders are the only Host Mac filesystem surface visible to a Sandbox VM, so this slice must prove both the CLI policy and the actual guest-visible read/write behavior.

## Acceptance criteria

- [ ] `sand folders add <name> <host-path> rw|ro|read-write|read-only` works.
- [ ] `sand folders list <name>` shows host path, Guest Path, and Access Mode.
- [ ] `sand folders remove <name> <host-path>` removes an Allowed Folder and applies the change.
- [ ] `rw` and `ro` inputs normalize to canonical `read-write` and `read-only` values in the Sandbox Spec.
- [ ] Default Guest Paths are derived under `/workspace`.
- [ ] `--as <guest-path>` overrides the default Guest Path.
- [ ] Adding an existing host folder updates Access Mode or Guest Path idempotently.
- [ ] Duplicate Guest Paths are rejected.
- [ ] Overlapping host folders are rejected in v1.
- [ ] Symlink realpath validation prevents bypassing duplicate or overlap checks.
- [ ] Display paths are preserved for human-friendly output while validation uses resolved real paths.
- [ ] Read-write Allowed Folders preserve Host-Safe File Ownership for guest-created and guest-modified files.
- [ ] Read-only Allowed Folders are readable from the Sandbox Guest and reject writes from the Sandbox Guest.
- [ ] Config changes apply immediately when the Sandbox VM is stopped.
- [ ] Config changes that interrupt a running Sandbox VM ask first.
- [ ] Folder policy behavior has deterministic tests independent of Apple `container`.
- [ ] Real backend evidence proves the actual mount/access behavior; mocks do not certify read-only, read-write, or Host-Safe File Ownership.
- [ ] Acceptance is demonstrated against the real Apple backend.

## Definition of Done

- [ ] Relevant deterministic tests are added or updated and `swift test` passes.
- [ ] Backend-dependent acceptance evidence uses the real Apple backend.
- [ ] Fake/in-memory backends are allowed only in tests and cannot be selected by user-facing CLI flags, environment variables, or hidden fallbacks.
- [ ] CLI command handlers do not call Apple `container` directly; backend interaction goes through `SandboxBackend`.
- [ ] No display-layer workaround hides a failed access mode, ownership, symlink, overlap, or apply requirement.

## Blocked by

- `issues/sand/007-shell-sessions-sandbox-user.md`

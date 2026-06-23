---
title: Size a macOS Sandbox VM and clone from a clean one
status: ready-for-agent
type: issue
category: enhancement
labels:
  - ready-for-agent
  - afk
  - sand
  - sandbox-vm
  - macos
  - tart
  - disk
created: 2026-06-22
---

## Parent

- `issues/sand/prd-macos-sandbox-vm-tart-backend.md`

## What to build

Give macOS sandboxes a create-time Disk Size so a VM can be sized for Xcode, and let a new macOS sandbox Clone copy-on-write from an existing clean sandbox (not just a registry image). The parser learns the additive macOS-only `disk: <size>` key (default ~100GB), rejected on Linux specs because disk provisioning is a macOS-only concern. Disk Size is grow-only: a Clone's disk must be greater than or equal to its source because APFS cannot reliably shrink the system container, and there is no in-place resize after create. `sand create <name> --from <local-sandbox>` clones an existing stopped macOS sandbox via `tart clone`. `sand <name> status` shows the disk size.

## Acceptance criteria

- [ ] `sand create <name> --os macos --disk <size>` provisions a macOS VM with that disk size.
- [ ] `disk:` is accepted in a macOS spec and rejected in a Linux spec.
- [ ] Disk Size defaults to ~100GB on macOS when unspecified.
- [ ] `sand create <name> --from <local-sandbox>` clones an existing stopped macOS sandbox copy-on-write.
- [ ] A Clone's disk must be greater than or equal to its source (grow-only); a smaller disk is rejected.
- [ ] In-place disk resize after create is rejected.
- [ ] `sand <name> status` shows the disk size.
- [ ] Deterministic tests cover `disk` parse on macOS, rejection on Linux, grow-only-on-clone, and no-in-place-resize, mirroring the existing `validateUpdate` immutability tests.
- [ ] Acceptance is demonstrated against real Tart on Apple Silicon.

## Definition of Done

- [ ] Deterministic tests are added/updated and `swift test` passes.
- [ ] Backend-dependent acceptance evidence uses real Tart, not a fake.
- [ ] Disk rules live in the domain/spec layer, not in CLI display code.
- [ ] The schema change is additive with no `schemaVersion` bump.

## Blocked by

- `issues/sand/023-clone-and-shell-macos-sandbox.md`

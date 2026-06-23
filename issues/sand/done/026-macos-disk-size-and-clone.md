---
title: Size a macOS Sandbox VM and clone from a clean one
status: done
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

Give macOS sandboxes a create-time Disk Size so a VM can be sized for Xcode, and let a new macOS sandbox Clone copy-on-write from an existing clean sandbox (not just a registry image). The parser learns the additive macOS-only `disk: <size>` key (default 64GB), rejected on Linux specs because disk provisioning is a macOS-only concern. Disk Size is grow-only: a Clone's disk must be greater than or equal to its source because APFS cannot reliably shrink the system container, and there is no in-place resize after create. `sand create <name> --from <local-sandbox>` clones an existing stopped macOS sandbox via `tart clone`. `sand <name> status` shows the disk size.

## Acceptance criteria

- [x] `sand create <name> --os macos --disk <size>` provisions a macOS VM with that disk size.
- [x] `disk:` is accepted in a macOS spec and rejected in a Linux spec.
- [x] Disk Size defaults to 64GB on macOS when unspecified.
- [x] `sand create <name> --from <local-sandbox>` clones an existing stopped macOS sandbox copy-on-write.
- [x] A Clone's disk must be greater than or equal to its source (grow-only); a smaller disk is rejected.
- [x] In-place disk resize after create is rejected.
- [x] `sand <name> status` shows the disk size.
- [x] Deterministic tests cover `disk` parse on macOS, rejection on Linux, grow-only-on-clone, and no-in-place-resize, mirroring the existing `validateUpdate` immutability tests.
- [x] Acceptance is demonstrated against real Tart on Apple Silicon.

## Definition of Done

- [x] Deterministic tests are added/updated and `swift test` passes.
- [x] Backend-dependent acceptance evidence uses real Tart, not a fake.
- [x] Disk rules live in the domain/spec layer, not in CLI display code.
- [x] The schema change is additive with no `schemaVersion` bump.

## Progress

### 2026-06-23 08:49 PDT — Completed disk sizing and local macOS clone

- Added `DiskSize` to the v1 spec as an additive macOS-only field; macOS defaults to `64GB`, Linux specs reject `disk`, and update validation rejects in-place disk edits.
- Added local macOS clone validation in lifecycle: `--from <local-sandbox>` resolves stored stopped macOS sandboxes, clones via Tart's existing clone path, and rejects shrink-on-clone.
- Added `--disk` CLI parsing, status disk output, and Tart `set --disk-size` provisioning.
- Deterministic evidence: `swift test` passed with 103 tests.
- Real Tart evidence on Apple Silicon: `uname -m` returned `arm64`, Tart `2.32.1`; cloned cached `ghcr.io/cirruslabs/macos-sequoia-xcode:latest` to a local clean VM, cloned that local VM to a work VM, ran `tart set <work> --disk-size 150`, observed both stopped with `Source: local` and work `Disk: 150`, then deleted both.

### 2026-06-23 08:51 PDT — Changed default macOS disk to 64GB

- Updated the macOS disk default from `100GB` to `64GB` in the spec layer.
- Updated deterministic tests and Tart provisioning expectations.
- Deterministic evidence: `swift test` passed with 103 tests.

## Blocked by

- `issues/sand/023-clone-and-shell-macos-sandbox.md`

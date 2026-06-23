---
title: Reconcile and run the macOS Sandbox VM lifecycle
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
  - lifecycle
created: 2026-06-22
---

## Parent

- `issues/sand/prd-macos-sandbox-vm-tart-backend.md`

## What to build

Complete the declarative lifecycle for macOS sandboxes so apply/start/stop/delete behave consistently with Linux while respecting macOS reality. `sand apply` reconciles Shared Folder changes via a stop/update/restart with the disk untouched, preserving Guest State, and rejects CPU, memory, image, and guest-OS changes (immutability uniform across backends). Start/stop preserves Guest State (the whole VM disk) — like powering a Mac off and on. Delete removes the VM and its Host Metadata, including the injected SSH private key, so deletion is complete. `sand <name> logs` surfaces backend failures. Outbound-Only Networking holds: Tart's NAT keeps SSH reachable from the Host Mac only, never the LAN.

This slice carries the `os`-immutable validation rule (joining the existing image/cpu/memory immutable set in `validateUpdate`).

## Acceptance criteria

- [ ] `sand apply` on a macOS sandbox reconciles Shared Folder changes via stop/update/restart with the disk untouched and Guest State preserved.
- [ ] apply rejects CPU, memory, image, and `os` changes on macOS, matching Linux immutability.
- [ ] `os` is immutable after create.
- [ ] Start/stop preserves Guest State across launches.
- [ ] `sand delete` removes the macOS VM and all its Host Metadata, including the injected private key.
- [ ] macOS resource defaults are 4 CPU / 16GB; CPU and memory are immutable after create.
- [ ] `sand <name> logs` surfaces a failed macOS backend operation.
- [ ] Outbound-Only Networking is verified host-only via Tart's NAT.
- [ ] Lifecycle behavior is tested through `LifecycleCoordinator` with the recording fake backend and fake resolver (auto-start, prompts, mutation serialization, immutability rejections) with no live VM.
- [ ] Acceptance is demonstrated against real Tart on Apple Silicon.

## Definition of Done

- [ ] Deterministic tests are added/updated and `swift test` passes.
- [ ] Backend-dependent acceptance evidence uses real Tart, not a fake.
- [ ] Immutability and apply semantics are enforced in the domain/spec layer, not in CLI display code.
- [ ] No display-layer workaround hides a failed lifecycle, Guest State, or metadata requirement.

## Blocked by

- `issues/sand/023-clone-and-shell-macos-sandbox.md`

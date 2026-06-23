---
title: Reconcile and run the macOS Sandbox VM lifecycle
status: done
type: issue
category: enhancement
labels:
  - done
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

- [x] `sand apply` on a macOS sandbox reconciles Shared Folder changes via stop/update/restart with the disk untouched and Guest State preserved.
- [x] apply rejects CPU, memory, image, and `os` changes on macOS, matching Linux immutability.
- [x] `os` is immutable after create.
- [x] Start/stop preserves Guest State across launches.
- [x] `sand delete` removes the macOS VM and all its Host Metadata, including the injected private key.
- [x] macOS resource defaults are 4 CPU / 16GB; CPU and memory are immutable after create.
- [x] `sand <name> logs` surfaces a failed macOS backend operation.
- [x] Outbound-Only Networking is verified host-only via Tart's NAT.
- [x] Lifecycle behavior is tested through `LifecycleCoordinator` with the recording fake backend and fake resolver (auto-start, prompts, mutation serialization, immutability rejections) with no live VM.
- [x] Acceptance is demonstrated against real Tart on Apple Silicon.

## Definition of Done

- [x] Deterministic tests are added/updated and `swift test` passes.
- [x] Backend-dependent acceptance evidence uses real Tart, not a fake.
- [x] Immutability and apply semantics are enforced in the domain/spec layer, not in CLI display code.
- [x] No display-layer workaround hides a failed lifecycle, Guest State, or metadata requirement.

## Progress

### 2026-06-23 08:33 PDT — macOS lifecycle complete with real Tart acceptance

Added spec-layer immutability for image and guest OS alongside CPU/memory, macOS spec/generated defaults of 4 CPU / 16GB, deterministic LifecycleCoordinator coverage for macOS defaults and manual image/OS edits before backend calls, and Tart backend coverage for delete removing the injected keypair. Tart starts now use durable root disk sync options and graceful stop timeout for lifecycle state preservation.

`swift test` passes: 96 tests, 0 failures. Real Tart acceptance passed on Apple Silicon with `sand025accept` and `ghcr.io/cirruslabs/macos-sequoia-xcode:latest`: create/status/spec showed macOS 4 CPU / 16GB, Tart returned private NAT IP `192.168.65.2`, a persisted guest file under `/Users/Shared` survived apply stop/restart and explicit stop/start, a running Shared Folder add prompted then reconciled via stop/restart without deleting the VM, the guest wrote through the shared folder to the host, logs surfaced the clone command, and `sand delete --force` removed both the Tart VM and `~/.sand/tart/sand025accept` key metadata in the temporary acceptance HOME.

## Blocked by

- `issues/sand/done/023-clone-and-shell-macos-sandbox.md` — completed

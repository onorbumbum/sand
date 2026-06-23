---
title: Clone a macOS Sandbox VM and shell into it frictionlessly
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
  - backend
  - lifecycle
created: 2026-06-22
---

## Parent

- `issues/sand/prd-macos-sandbox-vm-tart-backend.md`

## What to build

The keystone tracer bullet for macOS support: one thin thread through every layer that proves a macOS Sandbox VM can be created and entered exactly like a Linux one. `sand create <name> --os macos --from <registry-image>` clones a prebuilt image via `tart clone` (copy-on-write, seconds), generates a per-sandbox SSH keypair, injects the public key into the guest's `authorized_keys`, and stores the private key in Host Metadata under `~/.sand/`. `sand <name> shell` and `sand <name> run <cmd>` then connect over hidden SSH (`tart ip` + ssh) as the Sandbox User with no username/password prompt. `sand list` and `sand <name> status` show the guest OS.

This slice builds *just enough* of each layer to make the path work, leaving them to be thickened by later slices:

- **Spec:** teach `SandboxSpec.parseYAML` the additive `os: linux|macos` key (default `linux`, so existing specs stay valid), with no `schemaVersion` bump.
- **Backend selection:** introduce a `BackendResolver` injected into `LifecycleCoordinator`, replacing the single hardcoded backend in `main.swift`. The resolver is the one place guest-OS-to-backend mapping lives; macOS resolves to a new `TartCLIBackend`, Linux to the existing `AppleContainerCLIBackend`. The coordinator stays backend-agnostic.
- **Tart backend:** a `TartCLIBackend` implementing the existing `SandboxBackend` protocol — `tart clone`, SSH key injection, `tart ip` + ssh for shell/run, and `tart` stderr → user-facing error translation.
- **Doctor:** a just-enough `tart` presence check so `--os macos` without `tart` fails with the actionable `brew install cirruslabs/cli/tart` message. (Version/os-relevance detail is fine to include here.)

The baked-in image `admin`/`admin` password is documented break-glass only; all sand sessions use the injected key.

## Acceptance criteria

- [ ] `sand create <name> --os macos --from <registry-image>` clones a prebuilt image via `tart clone` and leaves the sandbox stopped.
- [ ] A per-sandbox SSH keypair is generated at create; the public key is injected into the guest and the private key is stored in Host Metadata under `~/.sand/`.
- [ ] `sand <name> shell` opens an interactive session as the Sandbox User with no username/password prompt; stopped sandboxes auto-start.
- [ ] `sand <name> run <cmd>` executes an opaque Workload Command on the macOS guest, matching the Linux run model.
- [ ] `sand list` and `sand <name> status` show macOS sandboxes with their guest OS.
- [ ] `sand <name> logs` surfaces a failed clone or start.
- [ ] Existing Linux specs with no `os` field still parse unchanged and resolve to the Apple `container` backend.
- [ ] `--os macos` without `tart` on PATH fails with an actionable install message.
- [ ] Deterministic tests cover: `os` default/parse; resolver routing (macOS→Tart, Linux→container) via a fake resolver/fake backends through `LifecycleCoordinator`; Tart command construction for clone, run, and key injection; and `tart` error translation from stderr fixtures.
- [ ] `ArchitectureBoundaryTests` is extended to assert no `tart` strings appear outside the Tart backend module.
- [ ] Acceptance is demonstrated against real Tart on Apple Silicon.

## Definition of Done

- [ ] Deterministic tests are added/updated and `swift test` passes.
- [ ] Backend-dependent acceptance evidence uses real Tart, not a fake.
- [ ] Fake/in-memory backends are usable only in tests and cannot be selected via user-facing flags, env vars, or hidden fallbacks.
- [ ] CLI handlers do not call `tart` directly; backend interaction goes through `SandboxBackend`.
- [ ] No Linux behavior is removed or changed; the schema change is additive.

## Blocked by

- `issues/sand/022-tart-backend-validation-spike.md`

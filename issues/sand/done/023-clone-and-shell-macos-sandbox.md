---
title: Clone a macOS Sandbox VM and shell into it frictionlessly
status: done
type: issue
category: enhancement
labels:
  - done
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

- [x] `sand create <name> --os macos --from <registry-image>` clones a prebuilt image via `tart clone` and leaves the sandbox stopped.
- [x] A per-sandbox SSH keypair is generated at create; the public key is injected into the guest and the private key is stored in Host Metadata under `~/.sand/`.
- [x] `sand <name> shell` opens an interactive session as the Sandbox User with no username/password prompt; stopped sandboxes auto-start.
- [x] `sand <name> run <cmd>` executes an opaque Workload Command on the macOS guest, matching the Linux run model.
- [x] `sand list` and `sand <name> status` show macOS sandboxes with their guest OS.
- [x] `sand <name> logs` surfaces a failed clone or start.
- [x] Existing Linux specs with no `os` field still parse unchanged and resolve to the Apple `container` backend.
- [x] `--os macos` without `tart` on PATH fails with an actionable install message.
- [x] Deterministic tests cover: `os` default/parse; resolver routing (macOS→Tart, Linux→container) via a fake resolver/fake backends through `LifecycleCoordinator`; Tart command construction for clone, run, and key injection; and `tart` error translation from stderr fixtures.
- [x] `ArchitectureBoundaryTests` is extended to assert no `tart` strings appear outside the Tart backend module.
- [x] Acceptance is demonstrated against real Tart on Apple Silicon.

## Definition of Done

- [x] Deterministic tests are added/updated and `swift test` passes.
- [x] Backend-dependent acceptance evidence uses real Tart, not a fake.
- [x] Fake/in-memory backends are usable only in tests and cannot be selected via user-facing flags, env vars, or hidden fallbacks.
- [x] CLI handlers do not call `tart` directly; backend interaction goes through `SandboxBackend`.
- [x] No Linux behavior is removed or changed; the schema change is additive.

## Progress

### 2026-06-23 00:02 PDT — Deterministic tracer implemented; real Tart acceptance still incomplete

Implemented the additive `os: linux|macos` spec field, guest-OS backend resolver, Tart CLI backend skeleton, macOS create/run/shell/status/logs paths, Tart readiness check, CLI `--os macos --from <registry-image>`, and status/list OS display. Added deterministic coverage for OS parsing/defaulting, resolver routing through `LifecycleCoordinator`, Tart clone/key-injection/run/status command construction, Tart missing-executable/error translation, and the architecture boundary forbidding raw `"tart"` CLI strings outside `TartCLIBackend.swift`. `swift test` passes: 88 tests, 0 failures.

Real Tart acceptance was attempted with `sand023accept` using `ghcr.io/cirruslabs/macos-sequoia-xcode:latest`, but the initial `tart clone` did not complete within the final 10-minute wait and was killed. Cleanup confirmed no running Tart VM remains and the temporary sand metadata was removed. Issue remains incomplete until `sand create ... --os macos --from ...`, `sand run`, and shell acceptance complete against real Tart.

### 2026-06-23 01:17 PDT — Real Tart acceptance passed

Fixed the live-acceptance defects found on Apple Silicon: parse Tart's actual capitalized JSON status keys; keep legacy Linux `allowedFolders` specs listable; wait for SSH before macOS run/shell; sync injected `authorized_keys` before stopping the clone; and use `/Users/admin` as the macOS no-shared-folder fallback because the Cirrus guest root filesystem is read-only and cannot provide `/workspace`.

`swift test` passes: 90 tests, 0 failures. Real Tart acceptance passed with `sand023accept` and `ghcr.io/cirruslabs/macos-sequoia-xcode:latest`: create completed in 23s from cached OCI data, status/list showed `macos` and `stopped`, keypair existed under `~/.sand/tart/sand023accept/`, `sand run sand023accept /bin/zsh -lc 'whoami; sw_vers -productVersion; pwd'` returned `admin`, `15.7.3`, `/Users/admin`, piped `sand shell sand023accept` exited 0 with no password prompt, logs showed the clone command, and cleanup removed the local Tart VM and temporary sand metadata.

## Blocked by

- `issues/sand/done/022-tart-backend-validation-spike.md` — completed

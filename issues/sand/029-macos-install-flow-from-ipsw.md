---
title: Build a self-made macOS base from IPSW
status: ready-for-agent
type: issue
category: enhancement
labels:
  - ready-for-agent
  - hitl
  - sand
  - sandbox-vm
  - macos
  - tart
  - install-flow
created: 2026-06-22
---

## Parent

- `issues/sand/prd-macos-sandbox-vm-tart-backend.md`

## What to build

Give the user a high-trust alternative to prebuilt registry images: a self-built macOS base via the macOS Install Flow. `sand create <name> --os macos` (no `--from`) wraps `tart create --from-ipsw` (~30 min), then sets resources, enables SSH, and configures the Sandbox User, so the resulting base is reachable with the same frictionless session path as a cloned sandbox. Document the macOS Setup Checklist — the optional, one-time, Apple-ID-gated steps (sign into Apple ID, install full Xcode, install simulator runtimes, and only if automatic signing is wanted, enable Xcode automatic signing), done once via `sand <name> gui` on a sandbox the user then clones from; the result persists in Guest State and into every Clone.

This path contains irreducibly manual Apple-ID steps and is deliberately kept off the feasibility critical path.

## Acceptance criteria

- [ ] `sand create <name> --os macos` with no `--from` runs the macOS Install Flow via `tart create --from-ipsw`.
- [ ] The install flow sets resources, enables SSH, and configures the Sandbox User.
- [ ] The self-built base is reachable via `sand <name> shell` with the same injected-key, zero-prompt session path as a cloned sandbox.
- [ ] No third-party virtualization GUI app is required; the only dependency is the Tart CLI.
- [ ] The macOS Setup Checklist is documented as an optional one-time `gui` step whose result persists in Guest State and Clones, not a per-build gate.
- [ ] Deterministic tests assert the Tart backend emits the correct `tart create --from-ipsw` and post-create configuration intent.
- [ ] Acceptance is demonstrated against real Tart on Apple Silicon.

## Definition of Done

- [ ] Deterministic tests are added/updated and `swift test` passes.
- [ ] Backend-dependent acceptance evidence uses real Tart, not a fake.
- [ ] The install flow goes through `SandboxBackend`; no reimplementation of install in-process.
- [ ] Apple-ID-gated steps are documented, not falsely automated.

## Blocked by

- `issues/sand/023-clone-and-shell-macos-sandbox.md`

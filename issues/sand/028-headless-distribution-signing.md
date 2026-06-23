---
title: Sign a build for distribution headlessly inside a macOS Sandbox VM
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
  - signing
created: 2026-06-22
---

## Parent

- `issues/sand/prd-macos-sandbox-vm-tart-backend.md`

## What to build

Let the user code-sign builds for distribution (TestFlight, App Store, ad-hoc, enterprise) inside a macOS sandbox without any interactive Apple-ID login — the standard CI signing model. Inject the developer's certificate (`.p12`) and provisioning profile into the Sandbox Guest's keychain as a Signing Credentials Guest Secret (same shape as the SSH-key injection), so `xcodebuild` signs headlessly. The signing identity is never mounted from or shared with the Host Mac keychain. Building and running in the Simulator needs no signing or Apple ID at all. Apple-ID login for *automatic* signing management remains an optional one-time `gui` step (covered by the Setup Checklist slice), not a per-build gate.

Physical-device deploy/debug stays out of scope — Apple's Virtualization Framework has no USB passthrough for macOS guests.

## Acceptance criteria

- [ ] A `.p12` certificate and provisioning profile can be injected into the guest keychain as a Guest Secret, not mounted from the host keychain.
- [ ] `xcodebuild` signs a build for distribution headlessly, with no interactive Apple-ID login.
- [ ] Building and running in the Simulator works with no signing and no Apple ID.
- [ ] Injected Signing Credentials are treated as a Guest Secret stored in Guest State, never copied from or shared with the Host Mac.
- [ ] Documentation states that physical-device deploy/debug is unsupported (no VF USB passthrough) and that `gui` gives VM desktop access, not host-device forwarding.
- [ ] Acceptance is demonstrated against real Tart on Apple Silicon (a signed artifact is produced).

## Definition of Done

- [ ] Deterministic tests are added/updated and `swift test` passes.
- [ ] Backend-dependent acceptance evidence uses real Tart, not a fake.
- [ ] Signing Credentials are handled as a Guest Secret; the host keychain is never mounted.
- [ ] No interactive Apple-ID login is required for distribution signing.

## Blocked by

- `issues/sand/023-clone-and-shell-macos-sandbox.md`

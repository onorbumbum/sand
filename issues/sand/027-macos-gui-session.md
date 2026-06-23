---
title: Open a GUI Session on a macOS Sandbox VM
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
  - gui
created: 2026-06-22
---

## Parent

- `issues/sand/prd-macos-sandbox-vm-tart-backend.md`

## What to build

Give macOS sandboxes a graphical desktop connection for the Apple-ID-gated work no tool can automate. `sand <name> gui` runs the VM with Tart's VNC server (`tart run --vnc`) and launches the host macOS Screen Sharing app pointed at the resulting VNC address. The command is macOS-only and errors clearly on a Linux sandbox, keeping the command surface honest about what each guest supports. The baked-in image password is the documented break-glass credential for `gui` only.

## Acceptance criteria

- [ ] `sand <name> gui` on a macOS sandbox runs `tart run --vnc` and opens the host Screen Sharing app pointed at the VNC address.
- [ ] `sand <name> gui` on a Linux sandbox is rejected with a clear macOS-only message.
- [ ] Deterministic tests assert the Tart backend emits the correct `tart run --vnc` invocation and that `gui` is rejected for Linux guests.
- [ ] Acceptance is demonstrated against real Tart on Apple Silicon (a desktop session opens).

## Definition of Done

- [ ] Deterministic tests are added/updated and `swift test` passes.
- [ ] Backend-dependent acceptance evidence uses real Tart, not a fake.
- [ ] CLI handlers do not call `tart` directly; the VNC/Screen Sharing invocation goes through `SandboxBackend`.
- [ ] No embedded VNC viewer is built; the host Screen Sharing app is used.

## Blocked by

- `issues/sand/023-clone-and-shell-macos-sandbox.md`

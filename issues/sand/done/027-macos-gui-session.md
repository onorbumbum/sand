---
title: Open a GUI Session on a macOS Sandbox VM
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
  - gui
created: 2026-06-22
---

## Parent

- `issues/sand/prd-macos-sandbox-vm-tart-backend.md`

## What to build

Give macOS sandboxes a graphical desktop connection for the Apple-ID-gated work no tool can automate. `sand <name> gui` runs the VM with Tart's VNC server (`tart run --vnc`) and launches the host macOS Screen Sharing app pointed at the resulting VNC address. The command is macOS-only and errors clearly on a Linux sandbox, keeping the command surface honest about what each guest supports. The baked-in image password is the documented break-glass credential for `gui` only.

## Acceptance criteria

- [x] `sand <name> gui` on a macOS sandbox runs `tart run --vnc` and opens the host Screen Sharing app pointed at the VNC address.
- [x] `sand <name> gui` on a Linux sandbox is rejected with a clear macOS-only message.
- [x] Deterministic tests assert the Tart backend emits the correct `tart run --vnc` invocation and that `gui` is rejected for Linux guests.
- [x] Acceptance is demonstrated against real Tart on Apple Silicon (a desktop session opens).

## Definition of Done

- [x] Deterministic tests are added/updated and `swift test` passes.
- [x] Backend-dependent acceptance evidence uses real Tart, not a fake.
- [x] CLI handlers do not call `tart` directly; the VNC/Screen Sharing invocation goes through `SandboxBackend`.
- [x] No embedded VNC viewer is built; the host Screen Sharing app is used.

## Progress

### 2026-06-23 09:06 PDT — Completed macOS GUI session

- Added `gui` to the `SandboxBackend`/`SandboxApplication` boundary so CLI/lifecycle code stays backend-agnostic.
- Added `sand <name> gui` routing.
- Added lifecycle rejection for Linux sandboxes: `gui is macOS-only; Sandbox VM uses linux.`
- Implemented Tart GUI sessions as `tart run --vnc --root-disk-opts sync=full ...`, including configured shared-folder `--dir` mounts, followed by opening `vnc://admin@<ip>` with the host Screen Sharing app.
- Deterministic evidence: `swift test` passed with 106 tests; Tart backend test asserts the exact `run --vnc` argv and Screen Sharing URL, lifecycle test asserts Linux rejection.
- Real Tart evidence on Apple Silicon: created `sand027accept` from cached `ghcr.io/cirruslabs/macos-sequoia-xcode:latest` with `--disk 150GB`; `./.build/debug/sand sand027accept gui` exited 0, status showed the VM running, `ps` showed `/System/Applications/Utilities/Screen Sharing.app/Contents/MacOS/Screen Sharing`, and Tart was running `tart run --vnc --root-disk-opts sync=full sand027accept`. Temporary VM and metadata were deleted afterward.

## Blocked by

- `issues/sand/023-clone-and-shell-macos-sandbox.md`

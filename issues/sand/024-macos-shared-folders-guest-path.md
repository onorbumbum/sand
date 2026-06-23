---
title: Use a host folder inside a macOS Sandbox VM
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
  - shared-folders
created: 2026-06-22
---

## Parent

- `issues/sand/prd-macos-sandbox-vm-tart-backend.md`

## What to build

Make Shared Folders work on macOS guests so the mental model is backend-agnostic. The chosen Guest Path is preserved even though macOS virtiofs mounts at the OS-fixed `/Volumes/My Shared Files/<tag>` location: the Tart backend mounts the host folder read-write or read-only via `tart run --dir`, then creates a guest-side symlink from the Guest Path to the fixed virtiofs location, so the user never sees `/Volumes/My Shared Files`. `--as` overrides and Working Directory Mapping behave identically to Linux. Host-Safe File Ownership holds for free because virtiofs writes land on the host owned by the host user — confirmed in the spike, not engineered. Read-only Shared Folders genuinely block guest writes.

The Guest Path symlink is verified at the Tart backend command-construction level (the symlink command is emitted); `FolderPolicy` stays backend-agnostic.

## Acceptance criteria

- [ ] A read-write Shared Folder on a macOS sandbox appears at the same chosen/derived Guest Path as it would on Linux.
- [ ] The fixed `/Volumes/My Shared Files/<tag>` virtiofs location is hidden behind a backend-managed guest-side symlink.
- [ ] `--as` overrides set the Guest Path identically across backends.
- [ ] Working Directory Mapping starts sessions in the corresponding Guest Path when the host current directory is inside a Shared Folder.
- [ ] Files created from the guest through a read-write Shared Folder are owned and editable/deletable by the host user without sudo.
- [ ] Read-only Shared Folders block guest writes.
- [ ] Deterministic tests assert the Tart backend emits the correct `--dir` (rw/ro) and the `/Volumes` symlink command for a given folder intent.
- [ ] Acceptance is demonstrated against real Tart on Apple Silicon.

## Definition of Done

- [ ] Deterministic tests are added/updated and `swift test` passes.
- [ ] Backend-dependent acceptance evidence uses real Tart, not a fake.
- [ ] The Guest Path symlink lives in the Tart backend; `FolderPolicy` remains backend-agnostic.
- [ ] No `chmod`-after-every-run, rsync, or display-layer workaround substitutes for real virtiofs ownership behavior.

## Blocked by

- `issues/sand/023-clone-and-shell-macos-sandbox.md`

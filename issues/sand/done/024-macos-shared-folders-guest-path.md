---
title: Use a host folder inside a macOS Sandbox VM
status: done
type: issue
category: enhancement
labels:
  - done
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

- [x] A read-write Shared Folder on a macOS sandbox appears at the same chosen/derived Guest Path as it would on Linux.
- [x] The fixed `/Volumes/My Shared Files/<tag>` virtiofs location is hidden behind a backend-managed guest-side symlink.
- [x] `--as` overrides set the Guest Path identically across backends.
- [x] Working Directory Mapping starts sessions in the corresponding Guest Path when the host current directory is inside a Shared Folder.
- [x] Files created from the guest through a read-write Shared Folder are owned and editable/deletable by the host user without sudo.
- [x] Read-only Shared Folders block guest writes.
- [x] Deterministic tests assert the Tart backend emits the correct `--dir` (rw/ro) and the `/Volumes` symlink command for a given folder intent.
- [x] Acceptance is demonstrated against real Tart on Apple Silicon.

## Definition of Done

- [x] Deterministic tests are added/updated and `swift test` passes.
- [x] Backend-dependent acceptance evidence uses real Tart, not a fake.
- [x] The Guest Path symlink lives in the Tart backend; `FolderPolicy` remains backend-agnostic.
- [x] No `chmod`-after-every-run, rsync, or display-layer workaround substitutes for real virtiofs ownership behavior.

## Progress

### 2026-06-23 08:08 PDT — macOS Shared Folders complete

Implemented Tart `--dir` construction for read-write and read-only Shared Folders, backend-managed symlinks from the chosen Guest Path to `/Volumes/My Shared Files/<share-name>`, and synthetic root links for macOS's read-only root volume so `/workspace/<folder>` works like Linux. `FolderPolicy` remains backend-agnostic; the backend receives the full spec at start so it can mount folders without leaking Tart details upward.

`swift test` passes: 92 tests, 0 failures. Real Tart acceptance passed on Apple Silicon with `sand024accept`: `/tmp/sand024-rw` mounted at `/workspace/sand024-rw`, Working Directory Mapping started `sand run` in `/workspace/sand024-rw/subdir`, guest writes landed on the host as `onorbumbum` and were editable/deletable without sudo, and a read-only folder mounted with `--as /Users/admin/reference` blocked guest writes.

## Blocked by

- `issues/sand/done/023-clone-and-shell-macos-sandbox.md` — completed

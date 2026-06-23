---
title: Map Host Mac working directories for run and shell
status: done
type: issue
category: enhancement
labels:
  - afk
  - sand
  - sandbox-vm
  - working-directory-mapping
  - apple-container
created: 2026-05-19
---

## Parent

- `issues/sand/prd-sand-sandbox-vm.md`

## What to build

Implement Working Directory Mapping for real `run` and `shell` sessions. When the Host Mac current directory is inside an Allowed Folder, the Sandbox Session should start at the corresponding Guest Path. When it is outside all Allowed Folders, `sand` should warn and start in the configured default location.

## Acceptance criteria

- [x] From inside an Allowed Folder, `sand <name> run pwd` starts at the mapped Guest Path.
- [x] Nested Host Mac directories map to the corresponding nested Guest Path.
- [x] Symlinked Host Mac cwd paths map correctly using resolved real paths.
- [x] From outside all Allowed Folders, `sand` emits a clear warning.
- [x] From outside all Allowed Folders, commands start in `/workspace` or the Sandbox User home.
- [x] `sand <name> shell` uses the same Working Directory Mapping behavior as `run`.
- [x] Working Directory Mapping behavior has deterministic tests independent of Apple `container`.
- [x] Acceptance is demonstrated against the real Apple backend.

## Definition of Done

- [x] Relevant deterministic tests are added or updated and `swift test` passes.
- [x] Backend-dependent acceptance evidence uses the real Apple backend.
- [x] Fake/in-memory backends are allowed only in tests and cannot be selected by user-facing CLI flags, environment variables, or hidden fallbacks.
- [x] CLI command handlers do not call Apple `container` directly; backend interaction goes through `SandboxBackend`.
- [x] No display-layer workaround hides a failed path mapping, symlink, warning, or default-directory requirement.

## Evidence

- Deterministic tests: `swift test` — 66 tests passing.
- Real backend validation: `docs/validation/working-directory-mapping/RESULTS.md`
- Raw log: `docs/validation/working-directory-mapping/run-20260518-234712.log`

## Blocked by

- `issues/sand/008-allowed-folder-lifecycle-policy.md` (done)

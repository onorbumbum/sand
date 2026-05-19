---
title: Map Host Mac working directories for run and shell
status: needs-triage
type: issue
category: enhancement
labels:
  - needs-triage
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

- [ ] From inside an Allowed Folder, `sand <name> run pwd` starts at the mapped Guest Path.
- [ ] Nested Host Mac directories map to the corresponding nested Guest Path.
- [ ] Symlinked Host Mac cwd paths map correctly using resolved real paths.
- [ ] From outside all Allowed Folders, `sand` emits a clear warning.
- [ ] From outside all Allowed Folders, commands start in `/workspace` or the Sandbox User home.
- [ ] `sand <name> shell` uses the same Working Directory Mapping behavior as `run`.
- [ ] Working Directory Mapping behavior has deterministic tests independent of Apple `container`.
- [ ] Acceptance is demonstrated against the real Apple backend.

## Definition of Done

- [ ] Relevant deterministic tests are added or updated and `swift test` passes.
- [ ] Backend-dependent acceptance evidence uses the real Apple backend.
- [ ] Fake/in-memory backends are allowed only in tests and cannot be selected by user-facing CLI flags, environment variables, or hidden fallbacks.
- [ ] CLI command handlers do not call Apple `container` directly; backend interaction goes through `SandboxBackend`.
- [ ] No display-layer workaround hides a failed path mapping, symlink, warning, or default-directory requirement.

## Blocked by

- `issues/sand/008-allowed-folder-lifecycle-policy.md`

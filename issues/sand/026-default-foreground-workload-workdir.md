---
title: Default Foreground Workload workdir from first read-write Allowed Folder
status: needs-triage
type: issue
category: enhancement
labels:
  - needs-triage
  - sand
  - sandbox-vm
  - ephemeral
  - workload-command
  - allowed-folders
  - swift
created: 2026-06-03
---

## Parent

- `issues/sand/prd-ephemeral-sandbox-runs.md`

## What to build

Make Ephemeral Sandbox Runs safe for output-producing work by defaulting the Foreground Workload working directory to the first read-write Allowed Folder's effective Guest Path when no explicit workload `workdir` is provided. If there is no read-write Allowed Folder and no explicit `workdir`, fail before provisioning.

## Acceptance criteria

- [ ] A workload-level `workdir` remains optional in the Ephemeral Spec.
- [ ] When `workdir` is omitted, the effective Foreground Workload working directory is the first read-write Allowed Folder's Guest Path after folder defaulting.
- [ ] Read-only Allowed Folders are not used as the implicit workload working directory.
- [ ] If there is no read-write Allowed Folder and no explicit workload `workdir`, validation fails before provisioning or active metadata creation.
- [ ] The selected effective workload working directory is used in the backend run request.
- [ ] Deterministic tests cover explicit workdir, default from first read-write folder, read-only-only failure, and no-folder failure.

## Blocked by

- `issues/sand/025-ephemeral-allowed-folders-concrete-spec.md`

---
title: Default Foreground Workload workdir from first read-write Allowed Folder
status: done
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

- [x] A workload-level `workdir` remains optional in the Ephemeral Spec.
- [x] When `workdir` is omitted, the effective Foreground Workload working directory is the first read-write Allowed Folder's Guest Path after folder defaulting.
- [x] Read-only Allowed Folders are not used as the implicit workload working directory.
- [x] If there is no read-write Allowed Folder and no explicit workload `workdir`, validation fails before provisioning or active metadata creation.
- [x] The selected effective workload working directory is used in the backend run request.
- [x] Deterministic tests cover explicit workdir, default from first read-write folder, read-only-only failure, and no-folder failure.

## Blocked by

- `issues/sand/025-ephemeral-allowed-folders-concrete-spec.md`

### 2026-06-02 23:01 PDT — RUN-ONLY: defaulted workload workdir from first read-write folder

- Files shipped: `Sources/SandCore/Ephemeral/EphemeralRunCoordinator.swift`, `Tests/SandCoreTests/EphemeralRunCoordinatorTests.swift`
- Verification: `swift test --filter EphemeralRunCoordinatorTests` PASS (9 tests); `swift test` PASS (96 tests); `python -m pytest` FAIL/NOT APPLICABLE (collected 0 Python tests, exit 5); `make docs-check` FAIL (pre-existing stale managed-doc hashes in README/docs)
- TDD evidence: RED `swift test --filter EphemeralRunCoordinatorTests` failed as expected with missing `workload.workdir` on omitted-workdir specs; GREEN `swift test --filter EphemeralRunCoordinatorTests` passed after defaulting/failure behavior; refactor `swift test --filter EphemeralRunCoordinatorTests` passed after review/no extra refactor
- ACs completed: all six acceptance criteria
- HITL/default decisions: **No human available; chose the safer validation default of failing omitted-workdir/no-read-write-folder specs during planning before run-record, active metadata, or backend side effects.** Explicit `workdir` still allows no-folder specs; omitted `workdir` defaults only from read-write folders and skips read-only folders.

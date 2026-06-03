---
title: Resolve Ephemeral Allowed Folders into a concrete Sandbox Spec
status: done
type: issue
category: enhancement
labels:
  - needs-triage
  - sand
  - sandbox-vm
  - ephemeral
  - allowed-folders
  - swift
created: 2026-06-03
---

## Parent

- `issues/sand/prd-ephemeral-sandbox-runs.md`

## What to build

Allow Ephemeral Specs to describe temporary Sandbox VM template fields and Allowed Folders, then resolve those folder intents into a concrete Sandbox Spec using existing folder rules after pre-run planning. The generated concrete Sandbox Spec should contain resolved host paths and be suitable for temporary active Host Metadata.

## Acceptance criteria

- [x] Ephemeral Specs may include image, resources, and Allowed Folders; omitted image/resources use normal Sandbox VM defaults.
- [x] Ephemeral Allowed Folders support read-write and read-only Access Modes plus optional Guest Paths.
- [x] Relative `hostPath` values resolve relative to the Ephemeral Spec directory; absolute paths remain absolute; `~/...` expands to the Host Mac home directory.
- [x] Default Guest Paths use the display host path's last component consistently with normal folder behavior.
- [x] FolderPolicy is reused so duplicate Guest Paths, overlapping resolved host folders, access modes, and other folder rules stay consistent with durable Sandbox VMs.
- [x] The generated concrete Sandbox Spec records resolved paths, while the source Ephemeral Spec remains user-authored intent.
- [x] Deterministic tests cover relative/absolute/home paths, ro/rw modes, guest path defaulting, duplicate Guest Paths, overlap rejection, and generated spec contents.

## Blocked by

- `issues/sand/023-ephemeral-spec-shape-validation.md`
- `issues/sand/024-generated-ephemeral-identity-and-name.md`

## Progress

### 2026-06-02 22:54 PDT — RUN-ONLY: concrete ephemeral allowed folders

- Files shipped: `Sources/SandCore/Ephemeral/EphemeralRunCoordinator.swift`, `Tests/SandCoreTests/EphemeralRunCoordinatorTests.swift`, `issues/sand/done/025-ephemeral-allowed-folders-concrete-spec.md`
- Verification: `swift test --filter EphemeralRunCoordinatorTests` PASS (6 tests); `swift test` PASS (93 tests); `python -m pytest` collected 0 Python tests and exited 5 (not applicable in this Swift package).
- TDD evidence: RED `swift test --filter EphemeralRunCoordinatorTests` failed with generated specs missing allowed folders plus duplicate/overlap not rejected; GREEN `swift test --filter EphemeralRunCoordinatorTests` passed (6 tests); refactor `swift test --filter EphemeralRunCoordinatorTests` passed (6 tests, no production refactor needed after green).
- ACs completed: image/resources/Allowed Folders in Ephemeral Specs; ro/rw modes plus optional guest paths; relative/absolute/home host path resolution; default guest paths from display host path; FolderPolicy reuse for access modes, duplicate guest paths, and overlap rejection; generated concrete Sandbox Spec records resolved paths while source spec remains authored intent; deterministic coverage for required path/mode/defaulting/rejection/generated-spec cases.
- HITL/default decisions: **No human available; kept workload workdir explicitly authored for this slice** because workload workdir defaulting is assigned to a separate follow-up issue, and **treated `python -m pytest` exit 5 as not-applicable evidence** because the repo is a Swift package with no Python tests.

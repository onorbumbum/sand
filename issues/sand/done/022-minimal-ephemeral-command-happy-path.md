---
title: Add minimal explicit Ephemeral Sandbox Run happy path
status: done
type: issue
category: enhancement
labels:
  - needs-triage
  - sand
  - sandbox-vm
  - ephemeral
  - automation
  - swift
  - macos
created: 2026-06-03
---

## Parent

- `issues/sand/prd-ephemeral-sandbox-runs.md`

## What to build

Add the thinnest complete Ephemeral Sandbox Run path: `sand ephemeral --from <ephemeral-spec.yaml>` reads a minimal Ephemeral Spec with an explicit Foreground Workload working directory, creates a temporary Sandbox VM, runs the Foreground Workload, stops and deletes the Sandbox VM, records the attempt, and prints the final result plus Ephemeral Run Record path.

This slice should prove the explicit command and bounded create-run-stop-delete lifecycle without adding hooks, folder defaulting, CLI workload overrides, or full failure semantics yet.

## Acceptance criteria

- [x] `sand ephemeral --from <ephemeral-spec.yaml>` is routed as a top-level Ephemeral Command, not as a sandbox-first action.
- [x] A minimal Ephemeral Spec with `schemaVersion: 1`, an explicit workload command, and an explicit workload `workdir` can run end to end through fakeable application boundaries.
- [x] The Ephemeral Sandbox Run creates temporary active Host Metadata, provisions, starts, runs the Foreground Workload, attempts stop, deletes the Sandbox VM, and removes active Host Metadata on success.
- [x] The Foreground Workload runs through the existing backend run path and uses normal Workload Command IO/TTY behavior rather than a special Pi or ephemeral backend operation.
- [x] A basic Ephemeral Run Record is created and the final CLI output includes successful status and the run record path.
- [x] Normal durable Sandbox VM commands remain available and unchanged by the new command route.
- [x] Deterministic tests cover the happy path with fake backend, fake Host Metadata, and fake run record storage.

## Blocked by

None - can start immediately

## Progress

### 2026-06-02 21:35 PDT — RUN-ONLY: minimal ephemeral happy path shipped

- Files shipped: `Sources/SandCore/Ephemeral/EphemeralRunCoordinator.swift`, `Sources/SandCore/CLI/CLICommandRouter.swift`, `Sources/SandCore/CLI/SandboxApplication.swift`, `Sources/SandCore/Lifecycle/LifecycleCoordinator.swift`, `Tests/SandCoreTests/EphemeralRunCoordinatorTests.swift`, `Tests/SandCoreTests/CLICommandRouterTests.swift`, `Tests/SandCoreTests/TestSupport.swift`, `scripts/generate-cli-reference.sh`, `docs/docs-input-manifest.txt`, `docs/cli-reference.md`, generated docs hash refreshes.
- Verification: `swift test --filter 'EphemeralRunCoordinatorTests|CLICommandRouterTests/testEphemeralFromSpecRoutesAsExplicitTopLevelCommand'` passed (2 tests); `swift test` passed (83 tests); `python -m pytest` ran the requested verification command but collected 0 Python tests and exited 5 because this is a Swift package; `make docs-check` passed.
- TDD evidence: RED `swift test --filter 'EphemeralRunCoordinatorTests|CLICommandRouterTests/testEphemeralFromSpecRoutesAsExplicitTopLevelCommand'` failed to compile for missing `EphemeralRunCoordinator`, `EphemeralRunRequest`, `EphemeralRunIdentity`, `EphemeralRunRecordStore`, and `EphemeralRunResult`; GREEN same command passed (2 tests); refactor same targeted command passed after documentation/manifest refresh.
- ACs completed: all seven acceptance criteria.
- HITL/default decisions: **Kept scope to explicit spec workload + explicit workdir only** to honor the issue’s “no hooks, folder defaulting, CLI workload overrides, or full failure semantics yet” boundary; **treated `python -m pytest` exit 5 as not-applicable evidence rather than a product failure** because no Python tests exist in this Swift repo and the repo-native Swift/docs gates passed.

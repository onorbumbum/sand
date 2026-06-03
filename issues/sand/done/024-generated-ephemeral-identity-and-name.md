---
title: Generate Ephemeral Run identity and Sandbox Name
status: done
type: issue
category: enhancement
labels:
  - needs-triage
  - sand
  - sandbox-vm
  - ephemeral
  - host-metadata
  - swift
created: 2026-06-03
---

## Parent

- `issues/sand/prd-ephemeral-sandbox-runs.md`

## What to build

Allocate Ephemeral Run identity in one place after a valid Ephemeral Run Plan exists: run ID, generated Sandbox Name, and run record path. The generated Sandbox Name should use the optional `namePrefix`, default to `ephemeral`, include timestamp plus short random suffix, validate like any Sandbox Name, and be recorded before hooks run.

## Acceptance criteria

- [x] `namePrefix` is optional and defaults to `ephemeral`.
- [x] Generated Sandbox Names include the prefix, a timestamp, and a short random suffix to reduce collisions while remaining human-readable.
- [x] Generated Sandbox Names must pass normal Sandbox Name validation.
- [x] Identity allocation happens after valid run planning and before Before Provision Hooks.
- [x] EphemeralRunRecordStore allocates run ID, generated Sandbox Name, and record path as one DRY operation.
- [x] The generated Sandbox Name is written to the Ephemeral Run Record before hooks run.
- [x] Deterministic tests cover default prefix, custom prefix, invalid prefix, name validation, uniqueness shape, and record-store allocation behavior.

## Blocked by

- `issues/sand/022-minimal-ephemeral-command-happy-path.md`
- `issues/sand/023-ephemeral-spec-shape-validation.md`

## Progress

### 2026-06-02 22:48 PDT — RUN-ONLY: generated ephemeral identity and record metadata

- Files shipped: `Sources/SandCore/Ephemeral/EphemeralRunCoordinator.swift`, `Tests/SandCoreTests/EphemeralRunRecordStoreTests.swift`
- Verification: `swift test --filter EphemeralRunRecordStoreTests` PASS (5 tests); `swift test --filter EphemeralRun` PASS (8 tests); `swift test` PASS (90 tests); `python -m pytest` collected 0 tests and exited 5; `make check` ran `swift test` PASS then failed pre-existing Documentation Freshness Gate hash mismatch.
- TDD evidence: RED `swift test --filter EphemeralRunRecordStoreTests` failed to compile because deterministic timestamp/suffix injection did not exist; GREEN `swift test --filter EphemeralRunRecordStoreTests` passed; refactor `swift test --filter EphemeralRun` passed.
- ACs completed: all seven acceptance criteria.
- HITL/default decisions: **No human available; treated `python -m pytest` exit 5 (no Python tests in Swift repo) and stale docs-check hashes as verification environment/pre-existing repo issues, not feature blockers. Did not refresh generated docs because this issue did not touch documented CLI behavior.**

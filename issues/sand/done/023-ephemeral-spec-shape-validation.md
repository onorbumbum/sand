---
title: Validate Ephemeral Spec shape before side effects
status: done
type: issue
category: enhancement
labels:
  - needs-triage
  - sand
  - sandbox-vm
  - ephemeral
  - validation
  - swift
created: 2026-06-03
---

## Parent

- `issues/sand/prd-ephemeral-sandbox-runs.md`

## What to build

Make Ephemeral Spec parsing and run planning fail fast before any host hooks, run records, active Host Metadata, or backend resources are touched when the user-authored Ephemeral Spec is malformed or incomplete.

## Acceptance criteria

- [x] Ephemeral Spec shape validation supports `schemaVersion: 1` and rejects unsupported schema versions with a clear validation error.
- [x] Missing effective Foreground Workload, empty command strings, unsupported command-list shorthand, malformed command shapes, and unsupported Ephemeral Spec fields fail before side effects.
- [x] User-authored `resolvedHostPath` in Ephemeral Allowed Folders is rejected before side effects.
- [x] Invalid `namePrefix` values fail validation rather than being silently sanitized.
- [x] Malformed specs do not create an Ephemeral Run Record, do not run Before Provision Hooks, do not create active Host Metadata, and do not call the backend.
- [x] EphemeralSpec and EphemeralRunPlan are separate from SandboxSpec while sharing parsing/value helpers only where that keeps real shared rules DRY.
- [x] Deterministic tests cover valid defaults, malformed YAML/spec shape, unsupported fields, rejected `resolvedHostPath`, command validation, and absence of side effects.

## Blocked by

- `issues/sand/022-minimal-ephemeral-command-happy-path.md`

## Progress

### 2026-06-02 22:36 PDT — RUN-ONLY: Ephemeral Spec shape validation shipped

- Files shipped: `Sources/SandCore/Ephemeral/EphemeralRunCoordinator.swift`, `Sources/SandCore/Spec/SandboxSpec.swift`, `Sources/SandCore/Spec/YAMLValueParsing.swift`, `Tests/SandCoreTests/EphemeralRunCoordinatorTests.swift`, `README.md`, `docs/cli-reference.md`, `docs/onboarding.md`, `docs/developer-guide.md`, `issues/sand/done/023-ephemeral-spec-shape-validation.md`
- Verification: `swift test --filter EphemeralRunCoordinatorTests` passed (3 tests); `swift test` passed (85 tests); `python -m pytest` collected 0 Python tests and exited 5 in this Swift package; `make docs-check` passed after refreshing generated docs/hash metadata.
- TDD evidence: RED `swift test --filter EphemeralRunCoordinatorTests` failed for unsupported command-list shorthand, malformed command shape side effects, rejected `resolvedHostPath`, and invalid `namePrefix` error shape; GREEN same command passed (3 tests); refactor `swift test --filter EphemeralRunCoordinatorTests` passed (3 tests).
- ACs completed: schema v1/unsupported version validation; malformed workload/command/unsupported fields fail before side effects; user-authored `resolvedHostPath` rejected; invalid `namePrefix` fails validation; no run record/metadata/backend side effects for malformed specs; separate `EphemeralSpec` and `EphemeralRunPlan` with shared YAML parsing helpers; deterministic coverage for defaults and invalid shapes.
- HITL/default decisions: **Kept workload `workdir` explicitly required for this slice** because defaulting from Allowed Folders is assigned to follow-up issue 026; **treated `python -m pytest` exit 5 as not-applicable evidence rather than a Swift product failure** because the repository has no Python tests and Swift/docs gates passed.

---
title: Enforce Ephemeral Sandbox Run cleanup semantics and result precedence
status: done
type: issue
category: enhancement
labels:
  - needs-triage
  - sand
  - sandbox-vm
  - ephemeral
  - cleanup
  - failure-handling
  - swift
created: 2026-06-03
---

## Parent

- `issues/sand/prd-ephemeral-sandbox-runs.md`

## What to build

Make the EphemeralRunCoordinator own the full create-run-stop-post-work-delete saga for failure cases, including which cleanup actions are attempted, which hooks are skipped, what final status is reported, and which failure controls the final process exit code.

## Acceptance criteria

- [x] Before Provision Hook failure aborts before provisioning, skips After Stop Hooks, records failure, and returns failure status.
- [x] Provisioning or start failure before the Foreground Workload starts skips After Stop Hooks but still attempts cleanup of any partially created resources.
- [x] Foreground Workload nonzero exit still triggers stop, After Stop Hooks, delete, and a final failure report.
- [x] Stop failure does not prevent After Stop Hooks or delete from being attempted.
- [x] After Stop Hook failure stops remaining after-stop hooks but still attempts delete.
- [x] Delete failure records manual cleanup guidance, including the generated Sandbox Name and cleanup command.
- [x] Final CLI output includes run status, run record path, failed phase, and exit code for failed runs.
- [x] Final process exit code follows phase priority, with cleanup/delete failures overriding earlier workload failures when they require immediate attention.
- [x] Deterministic coordinator tests cover before-hook failure, provision failure, start failure, workload nonzero, stop failure, after-stop failure, delete failure, and result precedence.

## Blocked by

- `issues/sand/022-minimal-ephemeral-command-happy-path.md`
- `issues/sand/028-before-provision-hooks.md`
- `issues/sand/029-after-stop-hooks.md`

## Progress

### 2026-06-02 23:29 PDT — RUN-ONLY: blocked by prerequisite issue 029

- Files shipped: `issues/sand/030-ephemeral-failure-cleanup-result-precedence.md`
- Verification: blocker check only; `issues/sand/029-after-stop-hooks.md` still exists outside `issues/sand/done`, so implementation was not started per run-only instructions.
- TDD evidence: RED not run because blocker gate failed; GREEN not run because blocker gate failed; refactor not run.
- ACs completed: none.
- HITL/default decisions: **Stopped at blocker gate** because the safer default in AFK run-only mode is to respect `Blocked by` exactly and avoid implementing on top of incomplete prerequisite issue 029.

### 2026-06-03 00:09 PDT — RUN-ONLY: completed ephemeral failure cleanup precedence

- Files shipped: `Sources/SandCore/Ephemeral/EphemeralRunCoordinator.swift`, `Tests/SandCoreTests/EphemeralRunCoordinatorTests.swift`, `scripts/generate-cli-reference.sh`, `docs/cli-reference.md`, `README.md`, `docs/onboarding.md`, `docs/developer-guide.md`, `issues/sand/030-ephemeral-failure-cleanup-result-precedence.md`
- Verification: `swift test --filter EphemeralRunCoordinatorTests` passed (24 tests); `swift test` passed (113 tests); `make docs-check` passed; `make check` passed; `python -m pytest` collected 0 Python tests and exited 5 (`no tests ran`) in this Swift repo.
- TDD evidence: RED `swift test --filter EphemeralRunCoordinatorTests` failed to compile because `EphemeralRunResult` lacked `failedPhase` and `manualCleanupGuidance`; GREEN `swift test --filter EphemeralRunCoordinatorTests` passed (24 tests); refactor `swift test --filter EphemeralRunCoordinatorTests` passed after separating metadata creation from provisioning cleanup.
- ACs completed: before-provision failure; provision/start cleanup without after-stop hooks; workload nonzero cleanup/reporting; stop failure continuation; after-stop failure short-circuit plus delete; delete manual cleanup guidance; failed output phase/exit code; result precedence; deterministic coordinator coverage.
- HITL/default decisions: **Treated `python -m pytest` exit 5 as a repo/tooling mismatch rather than a behavior regression** because this is a Swift/XCTest package with no Python tests; kept `swift test` and `make check` as the authoritative repo gates.

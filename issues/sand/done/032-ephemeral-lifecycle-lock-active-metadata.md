---
title: Scope lifecycle locks and active metadata for Ephemeral Sandbox Runs
status: done
type: issue
category: enhancement
labels:
  - needs-triage
  - sand
  - sandbox-vm
  - ephemeral
  - host-metadata
  - lifecycle
  - swift
created: 2026-06-03
---

## Parent

- `issues/sand/prd-ephemeral-sandbox-runs.md`

## What to build

Make Ephemeral Sandbox Runs visible and safe while active without blocking unrelated work for the whole Foreground Workload. Temporary active specs should reuse Host Metadata behavior, appear in normal listings while active, and be removed after successful delete.

## Acceptance criteria

- [x] Temporary active Sandbox Specs are written through HostMetadataStore before backend provisioning.
- [x] Active ephemeral Sandbox VMs appear in `sand list` while running or otherwise active.
- [x] Active temporary specs are removed after successful delete, while Ephemeral Run Records remain inspectable.
- [x] Duplicate Sandbox Name protection is reused through Host Metadata rather than custom ephemeral-only checks.
- [x] Lifecycle mutation locks are held during active metadata/backend mutation phases but not during the full Foreground Workload lifetime.
- [x] MVP behavior does not specially hide or protect the generated ephemeral Sandbox Name from normal commands while active.
- [x] Deterministic tests verify active metadata ordering, list visibility, cleanup removal, duplicate protection, and lock enter/exit boundaries around long-running workload execution.

## Blocked by

- `issues/sand/022-minimal-ephemeral-command-happy-path.md`
- `issues/sand/030-ephemeral-failure-cleanup-result-precedence.md`

## Progress

### 2026-06-02 23:33 PDT — RUN-ONLY: blocked by open dependency

- Files shipped: `issues/sand/032-ephemeral-lifecycle-lock-active-metadata.md`
- Verification: blocker check only — `issues/sand/030-ephemeral-failure-cleanup-result-precedence.md` still exists outside `issues/sand/done`; implementation/tests intentionally not run.
- TDD evidence: RED not run; GREEN not run; refactor not run because the issue is blocked by an open local dependency.
- ACs completed: none
- HITL/default decisions: **Stopped instead of implementing** because run-only instructions require marking blocked when a `Blocked by` local issue still exists outside done.

### 2026-06-03 00:23 PDT — RUN-ONLY: active metadata and scoped lifecycle locks shipped

- Files shipped: `Sources/SandCore/Ephemeral/EphemeralRunCoordinator.swift`, `Tests/SandCoreTests/EphemeralRunCoordinatorTests.swift`, `README.md`, `docs/cli-reference.md`, `docs/onboarding.md`, `docs/developer-guide.md`, `issues/sand/done/032-ephemeral-lifecycle-lock-active-metadata.md`
- Verification: `swift test --filter EphemeralRunCoordinatorTests/testLifecycleLockCoversStartupMutationsButExitsBeforeForegroundWorkload` passed; `swift test --filter EphemeralRunCoordinatorTests` passed (27 tests); `swift test` passed (117 tests); `make docs-check` passed; `make check` passed; `python -m pytest` collected 0 Python tests and exited 5 (`no tests ran`) in this Swift repo.
- TDD evidence: RED `swift test --filter EphemeralRunCoordinatorTests/testLifecycleLockCoversStartupMutationsButExitsBeforeForegroundWorkload` failed because startup metadata/provision/start used three separate lock scopes; GREEN same command passed after scoping startup Host Metadata create + backend provision + backend start under one lifecycle lock and keeping the Foreground Workload outside the lock; refactor `swift test --filter EphemeralRunCoordinatorTests` passed with no further production refactor needed.
- ACs completed: temporary active specs through HostMetadataStore before provisioning; `sand list` visibility while active; active spec removal after successful delete with run record retained; duplicate name protection through Host Metadata; lifecycle lock boundaries around mutation phases only; no special hide/protect behavior for generated names; deterministic coverage for ordering/list/cleanup/duplicate/lock boundaries.
- HITL/default decisions: **Treated stale `status: blocked` as resolved** because both local blockers now exist under `issues/sand/done`; **treated `python -m pytest` exit 5 as a repo/tooling mismatch rather than a behavior regression** because the repo is a Swift/XCTest package with no Python tests and the repo-native `swift test`/`make check` gates passed.

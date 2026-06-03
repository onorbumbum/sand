---
title: Run Before Provision Hooks before resolving folders and provisioning
status: done
type: issue
category: enhancement
labels:
  - needs-triage
  - sand
  - sandbox-vm
  - ephemeral
  - lifecycle-hooks
  - host-mac
  - swift
created: 2026-06-03
---

## Parent

- `issues/sand/prd-ephemeral-sandbox-runs.md`

## What to build

Add optional Before Provision Hooks that run on the Host Mac before Allowed Folder path resolution and backend provisioning, so an ephemeral workflow can prepare host-side folders or inputs before they are mounted into the Sandbox VM.

## Acceptance criteria

- [x] Ephemeral Specs may omit Before Provision Hooks or provide an empty list.
- [x] Before Provision Hooks use the same structured command shape as the Foreground Workload: non-empty `command` plus optional `args` defaulting to empty.
- [x] Before Provision Hooks run as Host Mac commands relative to the directory containing the Ephemeral Spec.
- [x] Hook commands resolve through PATH, inherit the `sand` process environment, and use captured non-interactive IO.
- [x] Hook stdout and stderr are written to run-record files and referenced by events without automatic redaction.
- [x] Folder path resolution happens after successful Before Provision Hooks, allowing hooks to create referenced folders.
- [x] Before Provision Hook failure aborts before provisioning, skips After Stop Hooks, records the failure, and does not create backend resources.
- [x] Deterministic tests use a HostCommandRunner port to verify ordering, working directory, command shape, IO capture, environment behavior, and failure aborts.

## Blocked by

- `issues/sand/025-ephemeral-allowed-folders-concrete-spec.md`

## Progress

### 2026-06-02 23:25 PDT — RUN-ONLY: Before Provision Hooks shipped

- Files shipped: `Sources/SandCore/Ephemeral/EphemeralRunCoordinator.swift`, `Tests/SandCoreTests/EphemeralRunCoordinatorTests.swift`, `README.md`, `docs/cli-reference.md`, `docs/onboarding.md`, `docs/developer-guide.md`, `issues/sand/028-before-provision-hooks.md`
- Verification: `swift test --filter EphemeralRunCoordinatorTests` passed (15 tests); `make check` passed (`swift test` 104 tests + docs-check); `python -m pytest` passed with 0 collected tests.
- TDD evidence: RED `swift test --filter EphemeralRunCoordinatorTests/testBeforeProvisionHooksAreOptionalAndUseStructuredCommandShape` failed to compile on missing `HostCommandRequest`/host-hook API; GREEN `swift test --filter EphemeralRunCoordinatorTests` passed; refactor reran `swift test --filter EphemeralRunCoordinatorTests`, `make check`, and `python -m pytest` after tightening PATH/error handling.
- ACs completed: all eight acceptance criteria checked above.
- HITL/default decisions: **No human available; kept scope to Before Provision Hooks only.** After Stop Hooks are not implemented here; failure semantics verify no backend provisioning/stop/post-work path is entered, matching the issue's before-provision slice without expanding into the later after-stop feature.

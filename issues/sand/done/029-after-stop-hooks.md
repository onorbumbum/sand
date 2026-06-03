---
title: Run After Stop Hooks after workload exit and stop attempt
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

Add optional After Stop Hooks that run on the Host Mac after the Foreground Workload exits and after `sand` attempts to stop the Sandbox VM, so host-visible outputs can be copied, archived, committed, uploaded, or otherwise processed before deletion completes.

## Acceptance criteria

- [x] Ephemeral Specs may omit After Stop Hooks or provide an empty list.
- [x] After Stop Hooks use the same structured command shape as the Foreground Workload: non-empty `command` plus optional `args` defaulting to empty.
- [x] After Stop Hooks run as Host Mac commands relative to the directory containing the Ephemeral Spec with inherited environment, PATH resolution, and captured non-interactive IO.
- [x] After Stop Hooks run after the stop attempt even when the Foreground Workload exits nonzero.
- [x] After Stop Hooks run after the stop attempt even when the stop attempt fails.
- [x] After Stop Hooks do not run when Before Provision Hooks fail or when provisioning/start fails before the Foreground Workload starts.
- [x] After Stop Hook failure stops remaining after-stop hooks but still allows delete to be attempted.
- [x] Deterministic coordinator tests verify ordering around workload exit, stop attempt, hook output capture, nonzero workload, stop failure, and hook failure.

## Blocked by

- `issues/sand/028-before-provision-hooks.md`

## Progress

### 2026-06-02 23:27 PDT — RUN-ONLY: blocked by issue 28

- Files shipped: `issues/sand/029-after-stop-hooks.md`
- Verification: blocker check only — `issues/sand/028-before-provision-hooks.md` still exists outside `issues/sand/done`, so implementation and tests were intentionally skipped per run-only instructions.
- TDD evidence: RED not run (blocked before implementation); GREEN not run (blocked before implementation); refactor not run.
- ACs completed: none.
- HITL/default decisions: **Stopped instead of implementing because the safer/default run-only rule says unresolved local blockers prevent code changes.**

### 2026-06-02 23:59 PDT — RUN-ONLY: implemented after-stop hooks

- Files shipped: `Sources/SandCore/Ephemeral/EphemeralRunCoordinator.swift`, `Tests/SandCoreTests/EphemeralRunCoordinatorTests.swift`, `Tests/SandCoreTests/TestSupport.swift`, `scripts/generate-cli-reference.sh`, `docs/cli-reference.md`, `README.md`, `docs/onboarding.md`, `docs/developer-guide.md`, `issues/sand/done/029-after-stop-hooks.md`
- Verification: `swift test --filter EphemeralRunCoordinatorTests` PASS (20 tests); `python -m pytest` collected 0 tests / exit 5 (repo has no pytest suite); `make check` PASS (`swift test` 109 tests + docs-check)
- TDD evidence: RED `swift test --filter EphemeralRunCoordinatorTests` failed to compile for missing `afterStopHooks`/fake backend failure controls; GREEN `swift test --filter EphemeralRunCoordinatorTests` passed 20 tests; refactor `swift test --filter EphemeralRunCoordinatorTests` and `make check` passed after shared hook runner/docs refresh
- ACs completed: all eight acceptance criteria checked above
- HITL/default decisions: **Cleared stale blocked status because `issues/sand/028-before-provision-hooks.md` is now in `issues/sand/done/`; treated `python -m pytest` exit 5 as a non-applicable generic gate because this Swift repo has no pytest tests, and used `make check` as the repo-native completion gate.**

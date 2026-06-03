---
title: Support CLI Foreground Workload override after double dash
status: done
type: issue
category: enhancement
labels:
  - needs-triage
  - sand
  - sandbox-vm
  - ephemeral
  - cli
  - workload-command
  - swift
created: 2026-06-03
---

## Parent

- `issues/sand/prd-ephemeral-sandbox-runs.md`

## What to build

Support the explicit override form `sand ephemeral --from <ephemeral-spec.yaml> -- <command> [args...]` so users can reuse an Ephemeral Spec while changing only the Foreground Workload command for a run.

## Acceptance criteria

- [x] CLI parsing recognizes `--` as the boundary between `sand ephemeral` options and the override Workload Command.
- [x] When an override is present, the effective Foreground Workload command and args come from the CLI rather than the YAML workload command.
- [x] A CLI override preserves the YAML workload `workdir` when the YAML workload has one.
- [x] A CLI override is allowed when the YAML has no workload, as long as the effective plan is otherwise valid.
- [x] Workload arguments after `--` are passed through opaquely and are not parsed as `sand` flags.
- [x] Missing workload after a trailing `--` fails before side effects.
- [x] Deterministic CLI router and planning tests cover overrides, preserved workdir, YAML-without-workload, and opaque arguments.

## Blocked by

- `issues/sand/022-minimal-ephemeral-command-happy-path.md`
- `issues/sand/023-ephemeral-spec-shape-validation.md`
- `issues/sand/026-default-foreground-workload-workdir.md`

## Progress

### 2026-06-02 23:09 PDT — RUN-ONLY: CLI workload override shipped

- Files shipped: `Sources/SandCore/CLI/CLICommandRouter.swift`, `Tests/SandCoreTests/CLICommandRouterTests.swift`, `Tests/SandCoreTests/EphemeralRunCoordinatorTests.swift`, `README.md`, `docs/cli-reference.md`, `docs/onboarding.md`, `docs/developer-guide.md`, `scripts/generate-cli-reference.sh`
- Verification: `swift test --filter 'CLICommandRouterTests|EphemeralRunCoordinatorTests'` passed (21 tests); `swift test` passed (100 tests); `python -m pytest` collected 0 tests and exited 5 (repo is Swift; no Python test failures); `make docs-check` passed.
- TDD evidence: RED `swift test --filter 'CLICommandRouterTests|EphemeralRunCoordinatorTests'` failed as expected on double-dash ephemeral override routing/trailing-`--` assertions; GREEN same command passed (21 tests); refactor no code restructuring needed, same targeted command passed again.
- ACs completed: all seven acceptance criteria.
- HITL/default decisions: **No human available; treated `python -m pytest` exit 5 as a non-behavior gate anomaly because the repository has no Python tests, then ran the relevant Swift test suite and docs gate.**

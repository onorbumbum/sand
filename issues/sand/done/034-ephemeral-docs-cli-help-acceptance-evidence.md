---
title: Update documentation, CLI help, and final Ephemeral Sandbox Run acceptance evidence
status: done
type: issue
category: enhancement
labels:
  - needs-triage
  - sand
  - sandbox-vm
  - ephemeral
  - docs
  - acceptance-evidence
  - swift
  - macos
created: 2026-06-03
---

## Parent

- `issues/sand/prd-ephemeral-sandbox-runs.md`

## What to build

Finish the Ephemeral Sandbox Runs feature by making the command discoverable, refreshing Generated Documentation with current behavior, running the Documentation Freshness Gate, and capturing live acceptance evidence for successful and failing bounded workflows.

## Acceptance criteria

- [x] Top-level help and command-specific help document `sand ephemeral --from <ephemeral-spec.yaml> [-- <workload override...>]` accurately.
- [x] README, CLI Reference, Onboarding Guide, Developer Guide, and any other Generated Documentation with Documentation Impact are refreshed or explicitly verified as unchanged.
- [x] Documentation references the durable-vs-ephemeral boundary and ADR `docs/adr/0001-separate-ephemeral-spec-from-sandbox-spec.md` where appropriate.
- [x] `swift test`, `make docs-check`, and `make check` pass.
- [x] Live validation includes a successful Ephemeral Sandbox Run where Before Provision creates a folder, the Foreground Workload writes through a read-write Allowed Folder, After Stop processes host-visible output, the Sandbox VM is deleted, and a run record remains.
- [x] Live validation includes a nonzero Foreground Workload proving stop, hooks, delete, final failure report, and run record behavior still happen.
- [x] Interactive-compatible workload behavior is smoke-tested if practical, relying on existing normal workload IO/TTY behavior rather than transcript capture.
- [x] Final acceptance evidence is recorded in the issue or linked artifact with command output, run record paths, and cleanup status.

## Blocked by

- `issues/sand/022-minimal-ephemeral-command-happy-path.md`
- `issues/sand/023-ephemeral-spec-shape-validation.md`
- `issues/sand/024-generated-ephemeral-identity-and-name.md`
- `issues/sand/025-ephemeral-allowed-folders-concrete-spec.md`
- `issues/sand/026-default-foreground-workload-workdir.md`
- `issues/sand/027-ephemeral-cli-workload-override.md`
- `issues/sand/028-before-provision-hooks.md`
- `issues/sand/029-after-stop-hooks.md`
- `issues/sand/030-ephemeral-failure-cleanup-result-precedence.md`
- `issues/sand/031-full-ephemeral-run-record-artifacts.md`
- `issues/sand/032-ephemeral-lifecycle-lock-active-metadata.md`
- `issues/sand/033-durable-lifecycle-non-regression-v1-omissions.md`

## Progress

### 2026-06-02 23:38 PDT — RUN-ONLY: blocked by incomplete prerequisite issues

- Files shipped: `issues/sand/034-ephemeral-docs-cli-help-acceptance-evidence.md`
- Verification: blocker check only; implementation intentionally skipped because blockers still exist outside `issues/sand/done`.
- TDD evidence: RED not run; GREEN not run; refactor not run because issue is blocked before implementation by explicit `Blocked by` rules.
- ACs completed: none.
- HITL/default decisions: **Chose the safe run-only default to stop before implementation** because blockers `issues/sand/029-after-stop-hooks.md`, `issues/sand/030-ephemeral-failure-cleanup-result-precedence.md`, `issues/sand/031-full-ephemeral-run-record-artifacts.md`, `issues/sand/032-ephemeral-lifecycle-lock-active-metadata.md`, and `issues/sand/033-durable-lifecycle-non-regression-v1-omissions.md` still exist outside `issues/sand/done`.

### 2026-06-03 00:48 PDT — RUN-ONLY: shipped final ephemeral docs and acceptance evidence

- Files shipped: `Sources/SandCore/CLI/CLICommandRouter.swift`, `Sources/SandCore/Backend/SandboxBackend.swift`, `Sources/SandCore/Backend/AppleContainerCLIBackend.swift`, `Sources/SandCore/Ephemeral/EphemeralRunCoordinator.swift`, `Tests/SandCoreTests/CLICommandRouterTests.swift`, `Tests/SandCoreTests/AppleContainerCLIBackendDoctorTests.swift`, `scripts/generate-cli-reference.sh`, `README.md`, `docs/cli-reference.md`, `docs/onboarding.md`, `docs/developer-guide.md`, this issue file.
- Verification: `swift test --filter CLICommandRouterTests --filter AppleContainerCLIBackendDoctorTests --filter EphemeralRunCoordinatorTests` → pass, 56 tests; `swift test` → pass, 124 tests; `make docs-check` → pass; `make check` → pass; `python -m pytest` → exit 5 because this Swift repo has 0 Python tests collected.
- TDD evidence: RED `swift test --filter CLICommandRouterTests/testTopLevelHelpAndVersionPrintWithoutCallingApplication --filter CLICommandRouterTests/testSupportedCommandHelpPrintsWithoutCallingApplication` → failed on missing exact ephemeral help text; RED `swift test --filter AppleContainerCLIBackendDoctorTests/testForegroundRunCanAvoidReplacingSandProcessSoEphemeralCleanupCanResume` → compile failure for missing non-replacing foreground run path; GREEN same targeted commands → pass; refactor `swift test --filter CLICommandRouterTests` → pass, 12 tests; no speculative refactor beyond splitting inherited backend IO modes.
- ACs completed: all 8 acceptance criteria.
- Live success evidence: command `.build/debug/sand ephemeral --from /tmp/sand-issue34/happy/ephemeral-spec.yaml` exited 0 with `Ephemeral run status: success` and `Run record: /Users/onorbumbum/.sand/ephemeral-runs/20260603-004557-f12441`; Before Provision created `/tmp/sand-issue34/happy/work`; workload wrote `/tmp/sand-issue34/happy/work/workload.txt` containing `workload-output`; After Stop wrote `/tmp/sand-issue34/happy/work/after-stop.txt` containing `workload-output` and `after-stop-ok`; `result.json` records `status: success`, `exitCode: 0`, and sandbox `issue34success-20260603-004557-f12441`; post-delete status check exited 1 with `sand: sandbox not found: issue34success-20260603-004557-f12441`.
- Live nonzero evidence: command `.build/debug/sand ephemeral --from /tmp/sand-issue34/failure/ephemeral-spec.yaml` exited 7 with `Ephemeral run status: failure`, `Failed phase: workload`, `Exit code: 7`, and `Run record: /Users/onorbumbum/.sand/ephemeral-runs/20260603-004605-ffdd7d`; workload wrote `/tmp/sand-issue34/failure/work/failure.txt`; After Stop wrote `/tmp/sand-issue34/failure/work/after-stop-failure.txt`; `events.jsonl` includes successful `beforeProvision` and `afterStop`; `result.json` records `status: failure`, `exitCode: 7`, `failedPhase: workload`; post-delete status check exited 1 with `sand: sandbox not found: issue34fail-20260603-004605-ffdd7d`.
- Interactive-compatible smoke evidence: command `.build/debug/sand ephemeral --from /tmp/sand-issue34/interactive/ephemeral-spec.yaml -- bash -lc "echo interactive-smoke > /workspace/interactive-smoke.txt"` exited 0 with `Run record: /Users/onorbumbum/.sand/ephemeral-runs/20260603-004613-2bc231`; CLI override used the normal workload IO path without transcript capture; host-visible output `/tmp/sand-issue34/interactive/work/interactive-smoke.txt` and After Stop output `/tmp/sand-issue34/interactive/work/after-stop-interactive.txt` were present; post-delete status check exited 1 with `sand: sandbox not found: issue34tty-20260603-004613-2bc231`.
- HITL/default decisions: **Fixed the root cause found during live validation instead of documenting around it**: the durable workload backend path intentionally replaced the `sand` process for TTY behavior, which prevented Ephemeral Run cleanup from resuming. The safe default was to preserve replacement for durable `run`/`shell`, add a child-process inherited IO mode for Ephemeral foreground workloads, and keep ephemeral cleanup in-process.

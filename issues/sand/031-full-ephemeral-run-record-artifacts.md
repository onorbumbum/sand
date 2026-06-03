---
title: Write complete immutable Ephemeral Run Record artifacts
status: blocked
type: issue
category: enhancement
labels:
  - needs-triage
  - sand
  - sandbox-vm
  - ephemeral
  - run-records
  - host-metadata
  - swift
created: 2026-06-03
---

## Parent

- `issues/sand/prd-ephemeral-sandbox-runs.md`

## What to build

Complete Ephemeral Run Record storage so every real run attempt leaves inspectable immutable history under Host Metadata, including original user intent, generated concrete configuration, incremental event history, hook outputs, and final result summary.

## Acceptance criteria

- [ ] Ephemeral Run Records are created after shape validation and before Before Provision Hooks.
- [ ] Run records include a copy of the source Ephemeral Spec and the generated concrete Sandbox Spec.
- [ ] The generated concrete Sandbox Spec is written to the run record before temporary active Host Metadata is created.
- [ ] Structured events are appended incrementally as JSON Lines so a crash mid-run still leaves useful history.
- [ ] Hook stdout and stderr are stored in separate files referenced by JSONL events.
- [ ] `result.json` records final status, failed phase when applicable, relevant exit code, generated Sandbox Name, and manual cleanup guidance when applicable.
- [ ] Run records remain after successful active metadata deletion and are kept indefinitely by default in v1.
- [ ] Deterministic run record tests cover identity allocation, source spec copy, generated spec copy, event appends, hook output files, result summary, and retention behavior.

## Blocked by

- `issues/sand/022-minimal-ephemeral-command-happy-path.md`
- `issues/sand/025-ephemeral-allowed-folders-concrete-spec.md`
- `issues/sand/028-before-provision-hooks.md`
- `issues/sand/029-after-stop-hooks.md`
- `issues/sand/030-ephemeral-failure-cleanup-result-precedence.md`

## Progress

### 2026-06-02 23:31 PDT — RUN-ONLY: blocked by prerequisite issues

- Files shipped: `issues/sand/031-full-ephemeral-run-record-artifacts.md` only.
- Verification: blocker check only; implementation and tests skipped because open blockers remain.
- TDD evidence: RED not run; GREEN not run; refactor not run because issue is blocked before implementation.
- ACs completed: none.
- HITL/default decisions: **Blocked rather than implementing** — run-only instructions require stopping when `Blocked by` issue files still exist outside `issues/sand/done`; `issues/sand/029-after-stop-hooks.md` and `issues/sand/030-ephemeral-failure-cleanup-result-precedence.md` are still open.

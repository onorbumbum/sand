---
title: Preserve durable lifecycle behavior and enforce v1 ephemeral omissions
status: blocked
type: issue
category: enhancement
labels:
  - needs-triage
  - sand
  - sandbox-vm
  - ephemeral
  - regression
  - cli
  - swift
created: 2026-06-03
---

## Parent

- `issues/sand/prd-ephemeral-sandbox-runs.md`

## What to build

Prove that Ephemeral Sandbox Runs do not make durable Sandbox VM commands surprising and that the deliberate v1 omissions remain omitted from the command surface, specs, and runtime behavior.

## Acceptance criteria

- [ ] Durable Sandbox Specs do not accept lifecycle hooks, Foreground Workload fields, or ephemeral run-record fields.
- [ ] Normal `create`, `start`, `stop`, `run`, `shell`, and `apply` behavior is unchanged and does not run ephemeral hooks.
- [ ] No `preserveOnFailure` option is supported in v1.
- [ ] No ephemeral dry-run or validate subcommand is supported in v1.
- [ ] Foreground Workload transcripts are not captured by default.
- [ ] Guest workload environment customization, host hook custom environment fields, and special `SAND_*` hook variables are not supported in v1.
- [ ] No Pi-specific ephemeral shortcut is added; Pi remains a normal Workload Command.
- [ ] Deterministic regression tests cover rejected command/spec shapes and unchanged durable lifecycle behavior.

## Blocked by

- `issues/sand/022-minimal-ephemeral-command-happy-path.md`
- `issues/sand/023-ephemeral-spec-shape-validation.md`
- `issues/sand/027-ephemeral-cli-workload-override.md`
- `issues/sand/028-before-provision-hooks.md`
- `issues/sand/029-after-stop-hooks.md`
- `issues/sand/030-ephemeral-failure-cleanup-result-precedence.md`
- `issues/sand/031-full-ephemeral-run-record-artifacts.md`
- `issues/sand/032-ephemeral-lifecycle-lock-active-metadata.md`

## Progress

### 2026-06-02 23:35 PDT — RUN-ONLY: blocked by prerequisite issues

- Files shipped: `issues/sand/033-durable-lifecycle-non-regression-v1-omissions.md`
- Verification: blocker check failed because prerequisite issue files still exist outside `issues/sand/done`: `issues/sand/029-after-stop-hooks.md`, `issues/sand/030-ephemeral-failure-cleanup-result-precedence.md`, `issues/sand/031-full-ephemeral-run-record-artifacts.md`, `issues/sand/032-ephemeral-lifecycle-lock-active-metadata.md`.
- TDD evidence: RED not run; GREEN not run; refactor not run because the issue is blocked before implementation per run-only instructions.
- ACs completed: none.
- HITL/default decisions: **Marked the issue blocked rather than implementing dependent regression coverage** because local blocker files are still open and AFK run-only mode requires the safer default.

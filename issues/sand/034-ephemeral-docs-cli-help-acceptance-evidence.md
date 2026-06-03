---
title: Update documentation, CLI help, and final Ephemeral Sandbox Run acceptance evidence
status: needs-triage
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

- [ ] Top-level help and command-specific help document `sand ephemeral --from <ephemeral-spec.yaml> [-- <workload override...>]` accurately.
- [ ] README, CLI Reference, Onboarding Guide, Developer Guide, and any other Generated Documentation with Documentation Impact are refreshed or explicitly verified as unchanged.
- [ ] Documentation references the durable-vs-ephemeral boundary and ADR `docs/adr/0001-separate-ephemeral-spec-from-sandbox-spec.md` where appropriate.
- [ ] `swift test`, `make docs-check`, and `make check` pass.
- [ ] Live validation includes a successful Ephemeral Sandbox Run where Before Provision creates a folder, the Foreground Workload writes through a read-write Allowed Folder, After Stop processes host-visible output, the Sandbox VM is deleted, and a run record remains.
- [ ] Live validation includes a nonzero Foreground Workload proving stop, hooks, delete, final failure report, and run record behavior still happen.
- [ ] Interactive-compatible workload behavior is smoke-tested if practical, relying on existing normal workload IO/TTY behavior rather than transcript capture.
- [ ] Final acceptance evidence is recorded in the issue or linked artifact with command output, run record paths, and cleanup status.

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

---
title: Generate CLI Reference from actual sand help output
status: needs-triage
type: issue
category: enhancement
labels:
  - needs-triage
  - sand
  - sandbox-vm
  - docs
  - cli-help
  - documentation-system
created: 2026-05-19
---

## What to build

Create the committed `docs/cli-reference.md` as the canonical CLI Reference. It should be generated from the actual `sand` command surface rather than hand-maintained prose, so command names, usage forms, and examples stay aligned with the product.

## Acceptance criteria

- [ ] Add `docs/cli-reference.md`.
- [ ] The document records the current docs input hash using the agreed Generated Documentation metadata convention.
- [ ] The document clearly states that it is fully generated/managed and should not be hand-edited outside the Documentation Refresh Workflow.
- [ ] The reference covers the v1 command surface: `doctor`, `create`, `list`, `apply`, `delete`, `folders`, sandbox-first `status/start/stop/shell/run/logs/spec`, `--help`, and `--version`.
- [ ] Command usage text is derived from actual `sand --help` / command help output or the same command definitions used by help.
- [ ] The reference distinguishes supported commands from known v1 non-goals.
- [ ] Add a deterministic way for the Documentation Refresh Workflow or script to capture current help output for regeneration.
- [ ] `scripts/docs-check.sh` detects when `docs/cli-reference.md` has stale or missing hash metadata.
- [ ] `make docs-check` passes after regeneration.
- [ ] `swift test` passes.

## Blocked by

- `issues/sand/015-documentation-freshness-gate.md`

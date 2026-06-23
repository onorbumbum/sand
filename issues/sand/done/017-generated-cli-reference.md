---
title: Generate CLI Reference from actual sand help output
status: done
type: issue
category: enhancement
labels:
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

- [x] Add `docs/cli-reference.md`.
- [x] The document records the current docs input hash using the agreed Generated Documentation metadata convention.
- [x] The document clearly states that it is fully generated/managed and should not be hand-edited outside the Documentation Refresh Workflow.
- [x] The reference covers the v1 command surface: `doctor`, `create`, `list`, `apply`, `delete`, `folders`, sandbox-first `status/start/stop/shell/run/logs/spec`, `--help`, and `--version`.
- [x] Command usage text is derived from actual `sand --help` / command help output or the same command definitions used by help.
- [x] The reference distinguishes supported commands from known v1 non-goals.
- [x] Add a deterministic way for the Documentation Refresh Workflow or script to capture current help output for regeneration.
- [x] `scripts/docs-check.sh` detects when `docs/cli-reference.md` has stale or missing hash metadata.
- [x] `make docs-check` passes after regeneration.
- [x] `swift test` passes.

## Dependency note

- `issues/sand/015-documentation-freshness-gate.md` was already satisfied in this repo: `scripts/docs-check.sh`, `scripts/docs-input-hash.sh`, and `make docs-check` existed before this issue was implemented.

## Evidence

- Added `scripts/generate-cli-reference.sh` to regenerate `docs/cli-reference.md` from actual `swift run --package-path <repo> sand` help/version output.
- Registered `docs/cli-reference.md` in `docs/generated-docs-manifest.txt` and added the generator to `docs/docs-input-manifest.txt`.
- Generated docs input hash recorded in `docs/cli-reference.md`: `cb70cafac5bd0c9a03bc7761eea55ccd12f02c78843cd44d44efe2095e68c504`.
- `make docs-check` passed: `docs-check: ok docs/cli-reference.md`; `Documentation Freshness Gate passed.`
- `swift test` passed: 81 tests, 0 failures.

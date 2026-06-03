---
title: Create generated Developer Guide for changing sand
status: done
type: issue
category: enhancement
labels:
  - needs-triage
  - sand
  - sandbox-vm
  - docs
  - developer-guide
  - documentation-system
created: 2026-05-19
---

## What to build

Create `docs/developer-guide.md` as the generated guide for contributors and agents changing `sand`. It should explain how the project is structured, how behavior is tested, how commands are added or changed, and how documentation is refreshed.

## Acceptance criteria

- [x] Add `docs/developer-guide.md`.
- [x] The document records the current docs input hash using the agreed Generated Documentation metadata convention.
- [x] The guide explains the high-level architecture without leaking backend implementation details into the Sandbox VM domain language.
- [x] The guide explains the testing strategy and points to representative test files for CLI routing, Sandbox Specs, folder policy, working-directory mapping, lifecycle coordination, doctor checks, backend error translation, and architecture boundaries.
- [x] The guide explains how to add or change a `sand` command while keeping help, README managed sections, CLI Reference, and tests aligned.
- [x] The guide explains the Documentation Refresh Workflow and when to run it.
- [x] The guide explains the local Definition of Done: behavior tests pass and the Documentation Freshness Gate passes.
- [x] The guide links to `issues/sand/CONTEXT.md` for canonical Sandbox VM language.
- [x] `scripts/docs-check.sh` detects when `docs/developer-guide.md` has stale or missing hash metadata.
- [x] `make docs-check` passes after regeneration.
- [x] `swift test` passes.

## Blocked by

- `issues/sand/015-documentation-freshness-gate.md`
- `issues/sand/016-documentation-refresh-workflow-prompt.md`

No current blocker: both prerequisite capabilities are present in this repo (`scripts/docs-check.sh` and `docs/prompts/refresh-docs.md`).

## Evidence

- Added `docs/developer-guide.md` with generated-doc metadata and docs input hash `cb70cafac5bd0c9a03bc7761eea55ccd12f02c78843cd44d44efe2095e68c504`.
- Registered `docs/developer-guide.md` in `docs/generated-docs-manifest.txt`, so `scripts/docs-check.sh` now checks it for missing or stale hash metadata.
- `make docs-check` passed: CLI Reference, Onboarding Guide, and Developer Guide all matched the current docs input hash.
- `swift test` passed: 81 tests, 0 failures.

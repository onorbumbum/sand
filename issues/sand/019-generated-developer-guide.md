---
title: Create generated Developer Guide for changing sand
status: needs-triage
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

- [ ] Add `docs/developer-guide.md`.
- [ ] The document records the current docs input hash using the agreed Generated Documentation metadata convention.
- [ ] The guide explains the high-level architecture without leaking backend implementation details into the Sandbox VM domain language.
- [ ] The guide explains the testing strategy and points to representative test files for CLI routing, Sandbox Specs, folder policy, working-directory mapping, lifecycle coordination, doctor checks, backend error translation, and architecture boundaries.
- [ ] The guide explains how to add or change a `sand` command while keeping help, README managed sections, CLI Reference, and tests aligned.
- [ ] The guide explains the Documentation Refresh Workflow and when to run it.
- [ ] The guide explains the local Definition of Done: behavior tests pass and the Documentation Freshness Gate passes.
- [ ] The guide links to `issues/sand/CONTEXT.md` for canonical Sandbox VM language.
- [ ] `scripts/docs-check.sh` detects when `docs/developer-guide.md` has stale or missing hash metadata.
- [ ] `make docs-check` passes after regeneration.
- [ ] `swift test` passes.

## Blocked by

- `issues/sand/015-documentation-freshness-gate.md`
- `issues/sand/016-documentation-refresh-workflow-prompt.md`

---
title: Create generated Onboarding Guide for humans and agents
status: done
type: issue
category: enhancement
labels:
  - needs-triage
  - sand
  - sandbox-vm
  - docs
  - onboarding
  - documentation-system
created: 2026-05-19
---

## What to build

Create `docs/onboarding.md` as the generated start-here guide for both new developers and AI agents. It should explain how to approach the repository, which files matter first, how to verify the project, and how to avoid stale documentation.

## Acceptance criteria

- [x] Add `docs/onboarding.md`.
- [x] The document records the current docs input hash using the agreed Generated Documentation metadata convention.
- [x] The guide has a clear "start here" path for humans.
- [x] The guide has a clear "start here" path for AI agents.
- [x] The guide includes a repo map covering `Sources/`, `Tests/`, `README.md`, `issues/sand/CONTEXT.md`, relevant `docs/` files, scripts, and the `Makefile`.
- [x] The guide identifies the first files to read before changing behavior.
- [x] The guide documents the local verification flow, including `swift test`, `make docs-check`, and `make check` once available.
- [x] The guide links to the CLI Reference, Developer Guide, README, and Sandbox VM context language.
- [x] The guide explains the Documentation Refresh Workflow at a high level and points to `docs/prompts/refresh-docs.md`.
- [x] `scripts/docs-check.sh` detects when `docs/onboarding.md` has stale or missing hash metadata.
- [x] `make docs-check` passes after regeneration.
- [x] `swift test` passes.

## Evidence

- Added `docs/onboarding.md` as Generated Documentation with metadata hash `cb70cafac5bd0c9a03bc7761eea55ccd12f02c78843cd44d44efe2095e68c504`.
- Registered `docs/onboarding.md` in `docs/generated-docs-manifest.txt`, so `scripts/docs-check.sh` now checks its hash metadata and would report missing or stale metadata.
- The guide includes human and AI-agent start-here paths, a repo map, first-files-to-read guidance, verification flow, and links to README, CLI Reference, Developer Guide, Sandbox VM context language, and the Documentation Refresh Workflow prompt.
- `make docs-check` passed: `docs-check: ok docs/cli-reference.md`; `docs-check: ok docs/onboarding.md`; `Documentation Freshness Gate passed.`
- `swift test` passed: 81 XCTest tests, 0 failures; Swift Testing run: 0 tests, 0 failures.
- `make check` passed and ran `swift test` followed by `scripts/docs-check.sh`.

## Blocked by

None — `issues/sand/015-documentation-freshness-gate.md` and `issues/sand/016-documentation-refresh-workflow-prompt.md` are already done.

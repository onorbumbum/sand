---
title: Create generated Onboarding Guide for humans and agents
status: needs-triage
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

- [ ] Add `docs/onboarding.md`.
- [ ] The document records the current docs input hash using the agreed Generated Documentation metadata convention.
- [ ] The guide has a clear "start here" path for humans.
- [ ] The guide has a clear "start here" path for AI agents.
- [ ] The guide includes a repo map covering `Sources/`, `Tests/`, `README.md`, `issues/sand/CONTEXT.md`, relevant `docs/` files, scripts, and the `Makefile`.
- [ ] The guide identifies the first files to read before changing behavior.
- [ ] The guide documents the local verification flow, including `swift test`, `make docs-check`, and `make check` once available.
- [ ] The guide links to the CLI Reference, Developer Guide, README, and Sandbox VM context language.
- [ ] The guide explains the Documentation Refresh Workflow at a high level and points to `docs/prompts/refresh-docs.md`.
- [ ] `scripts/docs-check.sh` detects when `docs/onboarding.md` has stale or missing hash metadata.
- [ ] `make docs-check` passes after regeneration.
- [ ] `swift test` passes.

## Blocked by

- `issues/sand/015-documentation-freshness-gate.md`
- `issues/sand/016-documentation-refresh-workflow-prompt.md`

---
title: Add manual Documentation Refresh Workflow prompt and metadata conventions
status: done
type: issue
category: enhancement
labels:
  - sand
  - sandbox-vm
  - docs
  - documentation-system
created: 2026-05-19
---

## What to build

Create the manual agent-run Documentation Refresh Workflow for v1. The workflow should tell an agent exactly how to refresh Generated Documentation from the current repo, how to preserve human-authored sections, and how to update freshness metadata.

This is intentionally not a Bosun workflow yet. It is a checked-in prompt plus deterministic conventions that can later be automated if it proves valuable.

## Acceptance criteria

- [x] Add `docs/prompts/refresh-docs.md` as the canonical Documentation Refresh Workflow prompt.
- [x] The prompt instructs the agent to read the Documentation Input Manifest, compute the current docs input hash, inspect the relevant source/test/docs files, and refresh the registered Generated Documentation.
- [x] The prompt defines metadata conventions for each managed document, including the recorded docs input hash.
- [x] The prompt defines Managed Section markers for section-managed documents such as `README.md`.
- [x] The prompt states that `docs/cli-reference.md` is fully generated from real `sand` help output or command definitions.
- [x] The prompt states that `README.md` is section-managed, not fully overwritten.
- [x] The prompt states that `docs/onboarding.md` and `docs/developer-guide.md` may combine generated sections with preserved human-authored sections.
- [x] The prompt tells the agent to run `make docs-check` and `swift test` after refreshing docs.
- [x] The workflow does not require Bosun, network access, or an LLM quality gate.

## Evidence

- Added `docs/prompts/refresh-docs.md` as the canonical manual agent-run Documentation Refresh Workflow prompt.
- Current docs input hash after adding the prompt: `aaf5ba21494f1095a25fb0fc18f3132d418b1ce97cf5b3b00ed48457aa180a44`.
- `make docs-check` passed; no Generated Documentation is registered yet and the Documentation Freshness Gate reported the current hash.
- `swift test` passed: 81 XCTest tests, 0 failures; Swift Testing run: 0 tests, 0 failures.

## Blocked by

None — `issues/sand/015-documentation-freshness-gate.md` is already done.

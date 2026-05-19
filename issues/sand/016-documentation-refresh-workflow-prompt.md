---
title: Add manual Documentation Refresh Workflow prompt and metadata conventions
status: needs-triage
type: issue
category: enhancement
labels:
  - needs-triage
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

- [ ] Add `docs/prompts/refresh-docs.md` as the canonical Documentation Refresh Workflow prompt.
- [ ] The prompt instructs the agent to read the Documentation Input Manifest, compute the current docs input hash, inspect the relevant source/test/docs files, and refresh the registered Generated Documentation.
- [ ] The prompt defines metadata conventions for each managed document, including the recorded docs input hash.
- [ ] The prompt defines Managed Section markers for section-managed documents such as `README.md`.
- [ ] The prompt states that `docs/cli-reference.md` is fully generated from real `sand` help output or command definitions.
- [ ] The prompt states that `README.md` is section-managed, not fully overwritten.
- [ ] The prompt states that `docs/onboarding.md` and `docs/developer-guide.md` may combine generated sections with preserved human-authored sections.
- [ ] The prompt tells the agent to run `make docs-check` and `swift test` after refreshing docs.
- [ ] The workflow does not require Bosun, network access, or an LLM quality gate.

## Blocked by

- `issues/sand/015-documentation-freshness-gate.md`

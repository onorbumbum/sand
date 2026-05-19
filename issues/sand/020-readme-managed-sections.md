---
title: Convert README to section-managed documentation
status: needs-triage
type: issue
category: enhancement
labels:
  - needs-triage
  - sand
  - sandbox-vm
  - docs
  - readme
  - documentation-system
created: 2026-05-19
---

## What to build

Convert `README.md` into section-managed documentation. Keep the human-authored product positioning and narrative, but mark factual sections that should be refreshed through the Documentation Refresh Workflow so README examples stay aligned with the CLI Reference and current command surface.

## Acceptance criteria

- [ ] Add Managed Section markers to the README for generated factual areas.
- [ ] At minimum, manage sections for quickstart, install/build/test snippets where appropriate, and command surface summary.
- [ ] Preserve human-authored product positioning outside Managed Sections.
- [ ] The README records or participates in the docs input hash convention without creating a self-referential hash loop.
- [ ] The hash/check implementation ignores generated README sections when hashing README inputs, or otherwise handles README section ownership deterministically.
- [ ] The managed quickstart aligns with `docs/cli-reference.md` and actual `sand` help output.
- [ ] The README points humans and agents to `docs/onboarding.md`, `docs/cli-reference.md`, and `docs/developer-guide.md`.
- [ ] `scripts/docs-check.sh` detects stale README managed sections or stale README hash metadata according to the chosen convention.
- [ ] `make docs-check` passes after regeneration.
- [ ] `swift test` passes.

## Blocked by

- `issues/sand/015-documentation-freshness-gate.md`
- `issues/sand/016-documentation-refresh-workflow-prompt.md`
- `issues/sand/017-generated-cli-reference.md`

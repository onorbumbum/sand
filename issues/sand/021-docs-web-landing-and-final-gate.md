---
title: Add web-readable docs landing page and enable final docs gate
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

Add a simple web-readable documentation landing page and finish wiring the Documentation Freshness Gate into the normal project completion path. This should make the committed docs easy to browse on GitHub or any static markdown renderer without introducing a full documentation site generator yet.

## Acceptance criteria

- [ ] Add `docs/index.md` as the documentation landing page.
- [ ] The landing page links to `README.md`, `docs/onboarding.md`, `docs/cli-reference.md`, `docs/developer-guide.md`, `issues/sand/CONTEXT.md`, and the v1 PRD/issues as appropriate.
- [ ] The landing page explains which docs are generated, section-managed, or hand-authored.
- [ ] The landing page explains how to refresh docs and how to check freshness.
- [ ] Register all v1 Generated Documentation with `scripts/docs-check.sh`: README managed sections, Onboarding Guide, CLI Reference, and Developer Guide.
- [ ] `make docs-check` fails when any registered generated/managed doc has a stale docs input hash.
- [ ] `make check` runs `swift test` and `make docs-check`.
- [ ] The final flow for agents and humans is documented: change code/tests, run the Documentation Refresh Workflow if the input hash changes, then run `make check`.
- [ ] No Bosun dependency is introduced.
- [ ] `make check` passes.

## Blocked by

- `issues/sand/017-generated-cli-reference.md`
- `issues/sand/018-generated-onboarding-guide.md`
- `issues/sand/019-generated-developer-guide.md`
- `issues/sand/020-readme-managed-sections.md`

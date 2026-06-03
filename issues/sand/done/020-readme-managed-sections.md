---
title: Convert README to section-managed documentation
status: done
type: issue
category: enhancement
labels:
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

- [x] Add Managed Section markers to the README for generated factual areas.
- [x] At minimum, manage sections for quickstart, install/build/test snippets where appropriate, and command surface summary.
- [x] Preserve human-authored product positioning outside Managed Sections.
- [x] The README records or participates in the docs input hash convention without creating a self-referential hash loop.
- [x] The hash/check implementation ignores generated README sections when hashing README inputs, or otherwise handles README section ownership deterministically.
- [x] The managed quickstart aligns with `docs/cli-reference.md` and actual `sand` help output.
- [x] The README points humans and agents to `docs/onboarding.md`, `docs/cli-reference.md`, and `docs/developer-guide.md`.
- [x] `scripts/docs-check.sh` detects stale README managed sections or stale README hash metadata according to the chosen convention.
- [x] `make docs-check` passes after regeneration.
- [x] `swift test` passes.

## Blocked by

- `issues/sand/015-documentation-freshness-gate.md`
- `issues/sand/016-documentation-refresh-workflow-prompt.md`
- `issues/sand/017-generated-cli-reference.md`

## Evidence

- Added README Managed Sections: `build-and-test`, `install-from-source`, `quickstart`, and `command-surface-summary`.
- Registered `README.md` in `docs/generated-docs-manifest.txt`; README records docs input hash `d039a5ec0acf7a13d194e3162068291d7984f7b884ec33aaed49c1fefad36890`.
- The docs input hash path is deterministic because `docs/docs-input-manifest.txt` already hashes `README.md` with `managed-markdown`, which ignores managed section bodies and `docs-input-hash` metadata.
- Regenerated CLI reference with `scripts/generate-cli-reference.sh` after the README managed-section change.
- Verification passed: `make docs-check`.
- Verification passed: `swift test` (81 tests, 0 failures).
- Verification passed: `make check`.

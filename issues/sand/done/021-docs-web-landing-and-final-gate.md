---
title: Add web-readable docs landing page and enable final docs gate
status: done
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

- [x] Add `docs/index.md` as the documentation landing page.
- [x] The landing page links to `README.md`, `docs/onboarding.md`, `docs/cli-reference.md`, `docs/developer-guide.md`, `issues/sand/CONTEXT.md`, and the v1 PRD/issues as appropriate.
- [x] The landing page explains which docs are generated, section-managed, or hand-authored.
- [x] The landing page explains how to refresh docs and how to check freshness.
- [x] Register all v1 Generated Documentation with `scripts/docs-check.sh`: README managed sections, Onboarding Guide, CLI Reference, and Developer Guide.
- [x] `make docs-check` fails when any registered generated/managed doc has a stale docs input hash.
- [x] `make check` runs `swift test` and `make docs-check`.
- [x] The final flow for agents and humans is documented: change code/tests, run the Documentation Refresh Workflow if the input hash changes, then run `make check`.
- [x] No Bosun dependency is introduced.
- [x] `make check` passes.

## Blocked by

None. The prerequisite docs issues are complete:

- `issues/sand/017-generated-cli-reference.md`
- `issues/sand/018-generated-onboarding-guide.md`
- `issues/sand/019-generated-developer-guide.md`
- `issues/sand/020-readme-managed-sections.md`

## Evidence

- Added `docs/index.md` as a plain Markdown documentation landing page with links to the README, generated guides, Sandbox VM context language, PRD, v1 acceptance docs, and documentation-system issues.
- Documented ownership in `docs/index.md`: README is section-managed; CLI Reference, Onboarding Guide, and Developer Guide are generated; Context, landing page, and refresh prompt are hand-authored.
- Documented the final flow in `docs/index.md`: change code/tests/scripts/docs, run the Documentation Refresh Workflow if the Documentation Input Manifest hash changes, then run `make check`.
- Updated `Makefile` so `make check` runs `$(SWIFT) test` and then `$(MAKE) docs-check`.
- Confirmed `docs/generated-docs-manifest.txt` registers the v1 Generated Documentation set checked by `scripts/docs-check.sh`: `README.md`, `docs/cli-reference.md`, `docs/onboarding.md`, and `docs/developer-guide.md`.
- Refreshed registered Generated Documentation hash metadata to docs input hash `05afb86350b2a28c2d4f15f696cd36e812d87667b711d86486e3d4cdd65bd592`; regenerated `docs/cli-reference.md` with `scripts/generate-cli-reference.sh` from real `swift run --package-path <repo> sand` help output.
- Stale gate check: `DOCS_INPUT_MANIFEST=/tmp/sand021_stale_manifest... make docs-check` failed as expected with stale hash errors for all registered docs and exit `2`.
- Verification passed: `make docs-check`.
- Verification passed: `swift test` (81 tests, 0 failures).
- Verification passed: `make check`.

---
title: Add Documentation Freshness Gate with curated input manifest
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

Add the deterministic foundation for the Documentation System: a curated Documentation Input Manifest, a reproducible input hash, and a Documentation Freshness Gate that can tell agents and humans when Generated Documentation must be refreshed.

This slice should make staleness visible without requiring Bosun, LLM judgment, or broad repository-wide hashing.

## Acceptance criteria

- [ ] Add a committed Documentation Input Manifest, e.g. `docs/docs-input-manifest.txt`, listing the curated inputs that affect Generated Documentation.
- [ ] The first manifest covers public behavior and onboarding inputs, including `Package.swift`, `README.md`, `issues/sand/CONTEXT.md`, CLI-related source/tests, and `docs/prompts/refresh-docs.md` once it exists.
- [ ] Add `scripts/docs-input-hash.sh` that computes a stable hash from the manifest contents and the contents of listed files.
- [ ] Add `scripts/docs-check.sh` that verifies registered Generated Documentation records the current input hash.
- [ ] `docs-check` reports missing docs, missing hash metadata, and stale hash metadata with actionable messages.
- [ ] Add `make docs-check`.
- [ ] Add or prepare `make check` as the single local completion gate that runs `swift test` and the Documentation Freshness Gate once generated docs are registered.
- [ ] The scripts are deterministic, do not call an LLM, do not require network access, and do not invoke Bosun.
- [ ] `swift test` passes.

## Blocked by

None - can start immediately

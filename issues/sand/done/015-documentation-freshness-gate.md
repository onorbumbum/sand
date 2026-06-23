---
title: Add Documentation Freshness Gate with curated input manifest
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

Add the deterministic foundation for the Documentation System: a curated Documentation Input Manifest, a reproducible input hash, and a Documentation Freshness Gate that can tell agents and humans when Generated Documentation must be refreshed.

This slice should make staleness visible without requiring Bosun, LLM judgment, or broad repository-wide hashing.

## Acceptance criteria

- [x] Add a committed Documentation Input Manifest, e.g. `docs/docs-input-manifest.txt`, listing the curated inputs that affect Generated Documentation.
- [x] The first manifest covers public behavior and onboarding inputs, including `Package.swift`, `README.md`, `issues/sand/CONTEXT.md`, CLI-related source/tests, and `docs/prompts/refresh-docs.md` once it exists.
- [x] Add `scripts/docs-input-hash.sh` that computes a stable hash from the manifest contents and the contents of listed files.
- [x] Add `scripts/docs-check.sh` that verifies registered Generated Documentation records the current input hash.
- [x] `docs-check` reports missing docs, missing hash metadata, and stale hash metadata with actionable messages.
- [x] Add `make docs-check`.
- [x] Add or prepare `make check` as the single local completion gate that runs `swift test` and the Documentation Freshness Gate once generated docs are registered.
- [x] The scripts are deterministic, do not call an LLM, do not require network access, and do not invoke Bosun.
- [x] `swift test` passes.

## Evidence

- `bash -n scripts/docs-input-hash.sh` passed.
- `bash -n scripts/docs-check.sh` passed.
- `scripts/docs-input-hash.sh` produced current hash `f4cff82517d4750cbea0f4272e2b7019080d46042706490a2018a7cd12c4042e`.
- `scripts/docs-check.sh` passed with no Generated Documentation registered yet and reported the current input hash.
- Smoke checks verified actionable `docs-check` failures for missing Generated Documentation, missing hash metadata, and stale hash metadata, plus a passing registered-doc case.
- `make docs-check` passed.
- `swift test` passed: 81 XCTest tests, 0 failures; Swift Testing run: 0 tests, 0 failures.
- `make check` passed and ran `swift test` followed by the Documentation Freshness Gate.

## Blocked by

None - can start immediately

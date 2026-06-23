---
title: Document macOS Sandbox VM guests
status: done
type: issue
category: enhancement
labels:
  - ready-for-agent
  - afk
  - sand
  - sandbox-vm
  - macos
  - tart
  - documentation
created: 2026-06-22
---

## Parent

- `issues/sand/prd-macos-sandbox-vm-tart-backend.md`

## What to build

Update the Generated Documentation so macOS guests are first-class and their honest constraints are visible, then re-pass the Documentation Freshness Gate. The README, CLI Reference, Onboarding Guide, and Developer Guide should cover: creating a macOS sandbox via clone or the Install Flow; `--os macos` and the macOS-only `disk:` field; `gui`, signing, and Shared Folder behavior on macOS; the Tart CLI dependency (`brew install cirruslabs/cli/tart`) and that `sand` stays unsigned and entitlement-free; and the platform constraints — Apple's ~2-concurrent-macOS-VM cap, ~100GB per VM and slower boot ("a handful, not dozens"), and that physical-device deploy/debug is unsupported.

## Acceptance criteria

- [x] CLI Reference is regenerated from actual `sand` help and covers `--os macos`, `--disk`, and `gui`.
- [x] README managed sections, Onboarding Guide, and Developer Guide describe macOS guests, the Tart backend, and the split-backend architecture.
- [x] Documentation states `sand` requires the `tart` CLI on PATH and needs no code signing or virtualization entitlement.
- [x] Documentation records the ~2-VM concurrent cap, ~100GB/slower-boot weight, and the unsupported physical-device deploy/debug constraint.
- [x] The Documentation Freshness Gate passes against the updated Documentation Input Manifest.

## Definition of Done

- [x] Generated Documentation is committed, not produced only on demand.
- [x] The Documentation Freshness Gate passes deterministically.
- [x] Behavior claims are generated from or validated against source-of-truth artifacts (CLI help, domain language, ADR-0001), not hand-asserted.

## Blocked by

- `issues/sand/023-clone-and-shell-macos-sandbox.md`
- `issues/sand/024-macos-shared-folders-guest-path.md`
- `issues/sand/025-macos-lifecycle-apply-start-stop-delete.md`
- `issues/sand/026-macos-disk-size-and-clone.md`
- `issues/sand/027-macos-gui-session.md`
- `issues/sand/028-headless-distribution-signing.md`

## Progress

### 2026-06-23 12:18 PDT — Documentation refresh completed

Regenerated `docs/cli-reference.md` from actual `sand` help with docs input hash `cf73295742e49ac61abc5883eed29af6d5023d55211e41bff00b93aaa12f6db4`; fixed the generator artifact that appended `},{` to delete help. Updated README managed command-surface docs, Onboarding Guide, Developer Guide, and the Documentation Input Manifest to include ADR-0001 as a source. Verification passed: `swift test --filter CLICommandRouterTests`, `scripts/docs-input-hash.sh docs/docs-input-manifest.txt`, `make docs-check`, and `make check`.

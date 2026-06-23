---
title: Document macOS Sandbox VM guests
status: ready-for-agent
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

- [ ] CLI Reference is regenerated from actual `sand` help and covers `--os macos`, `--disk`, and `gui`.
- [ ] README managed sections, Onboarding Guide, and Developer Guide describe macOS guests, the Tart backend, and the split-backend architecture.
- [ ] Documentation states `sand` requires the `tart` CLI on PATH and needs no code signing or virtualization entitlement.
- [ ] Documentation records the ~2-VM concurrent cap, ~100GB/slower-boot weight, and the unsupported physical-device deploy/debug constraint.
- [ ] The Documentation Freshness Gate passes against the updated Documentation Input Manifest.

## Definition of Done

- [ ] Generated Documentation is committed, not produced only on demand.
- [ ] The Documentation Freshness Gate passes deterministically.
- [ ] Behavior claims are generated from or validated against source-of-truth artifacts (CLI help, domain language, ADR-0001), not hand-asserted.

## Blocked by

- `issues/sand/023-clone-and-shell-macos-sandbox.md`
- `issues/sand/024-macos-shared-folders-guest-path.md`
- `issues/sand/025-macos-lifecycle-apply-start-stop-delete.md`
- `issues/sand/026-macos-disk-size-and-clone.md`
- `issues/sand/027-macos-gui-session.md`
- `issues/sand/028-headless-distribution-signing.md`

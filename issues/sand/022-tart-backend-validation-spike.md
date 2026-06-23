---
title: Validate Tart as the macOS Sandbox Backend
status: ready-for-agent
type: issue
category: enhancement
labels:
  - ready-for-agent
  - hitl
  - sand
  - sandbox-vm
  - macos
  - tart
  - backend-validation
created: 2026-06-22
---

## Parent

- `issues/sand/prd-macos-sandbox-vm-tart-backend.md`

## What to build

Run the mandatory Tart Backend Validation Spike on real Apple Silicon before any macOS backend code is built, proving that `tart` can satisfy the hard macOS Sandbox VM requirements end to end. Run it top-down by kill-probability with explicit stop conditions, so a hard failure stops work early per ADR-0001 instead of being discovered mid-implementation. Record the live commands, observed results, and a per-requirement pass/fail verdict clearly enough that the project can either proceed with the Tart CLI backend or fall back to the documented in-process Virtualization Framework option.

Prove feasibility via the `tart clone` of a prebuilt Cirrus Xcode image path first — it is seconds to create, ships Xcode, and is not Apple-ID gated. Keep the self-built IPSW + Apple-ID path off this critical path.

## Acceptance criteria

- [ ] Frictionless non-interactive session proven: clone a prebuilt image, inject a generated SSH key, and connect with `shell` with zero username/password prompt. *(stop condition if this fails)*
- [ ] Guest Path symlink survives a real Xcode build: a real project opens and builds with DerivedData resolving correctly when the project lives behind a symlink to `/Volumes/My Shared Files/<tag>`. *(riskiest "should work")*
- [ ] Host-Safe File Ownership proven: a file written from the guest through a read-write Shared Folder shows the host user in `ls -l` on the host and is editable/deletable without sudo.
- [ ] Read-write and read-only mounts honored: a read-only Shared Folder blocks guest writes.
- [ ] Host-only networking proven: the `tart ip` SSH endpoint is reachable from the Host Mac but not from another machine on the LAN.
- [ ] Resource defaults sane: a 4 CPU / 16GB macOS VM completes a real Xcode build in acceptable time.
- [ ] Concurrent-VM cap confirmed empirically: find and document the Nth macOS VM at which boot fails.
- [ ] Validation notes record exact commands, outputs or summaries, and a pass/fail conclusion for each hard requirement under `docs/validation/tart-backend/`.

## Definition of Done

- [ ] Validation evidence is recorded with exact commands, output summaries, and per-requirement pass/fail conclusion.
- [ ] Backend-dependent evidence uses real Tart on real Apple Silicon, not a mock or fake backend.
- [ ] Any failed hard requirement causes an explicit proceed/stop/fallback decision (in-process Virtualization Framework is the only documented fallback), not a display-layer workaround.
- [ ] No non-Apple backend fallback is introduced.

## Blocked by

None - can start immediately

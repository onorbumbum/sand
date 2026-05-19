---
title: Validate Apple container as the first Sandbox Backend
status: needs-triage
type: issue
category: enhancement
labels:
  - needs-triage
  - hitl
  - sand
  - sandbox-vm
  - apple-container
  - backend-validation
created: 2026-05-19
---

## Parent

- `issues/sand/prd-sand-sandbox-vm.md`

## What to build

Run a Backend Validation Spike that proves whether Apple `container` can satisfy the hard Sandbox VM requirements before implementation depends on it. Record the live commands, observed results, and any failed requirement clearly enough that the project can either proceed with the Apple `container` CLI backend or stop and make the explicit fallback decision.

## Acceptance criteria

- [ ] Live validation proves persistent Guest State survives stop/start.
- [ ] Live validation proves read-write Allowed Folders work.
- [ ] Live validation proves read-only Allowed Folders block writes.
- [ ] Live validation proves Host-Safe File Ownership for both files created and files modified from the Sandbox Guest.
- [ ] Live validation proves an interactive Sandbox Session can run as the non-root Sandbox User.
- [ ] Live validation proves passwordless sudo inside the Sandbox Guest.
- [ ] Live validation proves multiple Sandbox Sessions can run concurrently.
- [ ] Live validation proves runtime recreation can preserve Guest State.
- [ ] Live validation proves runtime recreation preserves intended Allowed Folder configuration behavior.
- [ ] Live validation proves Working Directory Mapping can start sessions inside mounted folders.
- [ ] Live validation proves Outbound-Only Networking for package/API access.
- [ ] Live validation proves backend service behavior, including whether auto-start is possible.
- [ ] Live validation proves stop/start preserves Guest State.
- [ ] Live validation proves Developer-Ready Sandbox Image feasibility, including the Default Toolset and Pi CLI path or a clear split of remaining work into the image issue.
- [ ] Live validation confirms `sand` v1 does not need inbound networking or port publishing to satisfy the product requirements.
- [ ] Validation notes include exact commands, outputs or summaries, and pass/fail conclusion for each hard requirement.

## Definition of Done

- [ ] Validation evidence is recorded with exact commands, output summaries, and pass/fail conclusion per hard requirement.
- [ ] Backend-dependent acceptance evidence uses the real Apple backend, not a mock or fake backend.
- [ ] Any failed hard requirement causes an explicit proceed/stop/fallback decision instead of a display-layer workaround.
- [ ] No non-Apple backend fallback, hidden rsync, chmod-after-every-run, or fake backend path is introduced.

## Blocked by

None - can start immediately

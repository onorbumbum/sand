---
title: Validate Apple container as the first Sandbox Backend
status: done
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

- [x] Live validation proves persistent Guest State survives stop/start.
- [x] Live validation proves read-write Allowed Folders work.
- [x] Live validation proves read-only Allowed Folders block writes.
- [x] Live validation proves Host-Safe File Ownership for both files created and files modified from the Sandbox Guest.
- [x] Live validation proves an interactive Sandbox Session can run as the non-root Sandbox User.
- [x] Live validation proves passwordless sudo inside the Sandbox Guest.
- [x] Live validation proves multiple Sandbox Sessions can run concurrently.
- [x] Live validation proves runtime recreation can preserve Guest State.
- [x] Live validation proves runtime recreation preserves intended Allowed Folder configuration behavior.
- [x] Live validation proves Working Directory Mapping can start sessions inside mounted folders.
- [x] Live validation proves Outbound-Only Networking for package/API access.
- [x] Live validation proves backend service behavior, including whether auto-start is possible.
- [x] Live validation proves stop/start preserves Guest State.
- [x] Live validation proves Developer-Ready Sandbox Image feasibility, including the Default Toolset and Pi CLI path or a clear split of remaining work into the image issue.
- [x] Live validation confirms `sand` v1 does not need inbound networking or port publishing to satisfy the product requirements.
- [x] Validation notes include exact commands, outputs or summaries, and pass/fail conclusion for each hard requirement.

## Evidence

- Summary: `docs/validation/apple-container-backend/RESULTS.md`
- Raw log: `docs/validation/apple-container-backend/run-20260518-220950.log`
- Harness: `docs/validation/apple-container-backend/validate.sh`
- Decision: PASS — proceed with Apple `container` CLI behind the `SandboxBackend` boundary.

## Definition of Done

- [x] Validation evidence is recorded with exact commands, output summaries, and pass/fail conclusion per hard requirement.
- [x] Backend-dependent acceptance evidence uses the real Apple backend, not a mock or fake backend.
- [x] Any failed hard requirement causes an explicit proceed/stop/fallback decision instead of a display-layer workaround.
- [x] No non-Apple backend fallback, hidden rsync, chmod-after-every-run, or fake backend path is introduced.

## Blocked by

None - can start immediately

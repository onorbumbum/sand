---
title: Fully implement sand doctor against real host and backend prerequisites
status: needs-triage
type: issue
category: enhancement
labels:
  - needs-triage
  - afk
  - sand
  - sandbox-vm
  - doctor
  - apple-container
created: 2026-05-19
---

## Parent

- `issues/sand/prd-sand-sandbox-vm.md`

## What to build

Implement the complete `sand doctor` command as the prerequisite diagnostic for the real Host Mac and Apple backend. The command should check every v1 prerequisite promised by the PRD and report failures in user-facing Sandbox VM language rather than raw backend dumps.

## Acceptance criteria

- [ ] `sand doctor` checks Apple silicon/macOS support.
- [ ] `sand doctor` checks Apple `container` executable availability.
- [ ] `sand doctor` checks Backend Service status.
- [ ] `sand doctor` attempts or verifies Backend Service auto-start behavior when needed.
- [ ] `sand doctor` checks default Sandbox Image availability.
- [ ] `sand doctor` checks Host Metadata writability under `~/.sand/`.
- [ ] Failure cases produce clear messages explaining the broken prerequisite and likely next step.
- [ ] Successful checks produce concise status output suitable for daily use.
- [ ] Acceptance is demonstrated against the real host/backend, not only mocks or fake backends.

## Definition of Done

- [ ] Relevant deterministic tests are added or updated and `swift test` passes.
- [ ] Backend-dependent acceptance evidence uses the real Apple backend.
- [ ] Fake/in-memory backends are allowed only in tests and cannot be selected by user-facing CLI flags, environment variables, or hidden fallbacks.
- [ ] CLI command handlers do not call Apple `container` directly; backend interaction goes through `SandboxBackend` or Doctor backend probes behind the diagnostic boundary.
- [ ] No display-layer workaround hides a failed backend prerequisite.

## Blocked by

- `issues/sand/000-scaffold-architecture-and-test-harness.md`
- `issues/sand/001-backend-validation-spike.md`
- `issues/sand/001a-domain-contracts-deterministic-tests.md`
- `issues/sand/002-developer-ready-sandbox-image.md`

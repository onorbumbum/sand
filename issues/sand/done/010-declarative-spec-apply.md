---
title: Support declarative specs and real apply reconciliation
status: done
type: issue
category: enhancement
labels:
  - needs-triage
  - afk
  - sand
  - sandbox-vm
  - sandbox-spec
  - apply
  - apple-container
created: 2026-05-19
---

## Parent

- `issues/sand/prd-sand-sandbox-vm.md`

## What to build

Complete the declarative Sandbox Spec workflow. Users should be able to create from a user-authored spec and reconcile manual spec edits with the real backend through `sand apply <name>`, while runtime recreation remains an internal implementation detail and Guest State survives.

## Acceptance criteria

- [x] `sand create --from spec.yaml` creates a real Sandbox VM from a user-authored Sandbox Spec.
- [x] `sand apply <name>` reconciles manual Sandbox Spec edits with the real backend.
- [x] Apply changes real backend configuration, not only Host Metadata.
- [x] Runtime recreation, when needed, remains hidden/internal rather than a user-facing lifecycle command.
- [x] Guest State survives apply flows that require runtime recreation.
- [x] Unsupported future fields such as inbound networking are rejected by v1 Sandbox Spec validation.
- [x] CPU and memory edits after creation are rejected in v1.
- [x] Stopped configuration changes apply immediately.
- [x] Running configuration changes that interrupt active sessions ask first.
- [x] Lifecycle Mutation serialization prevents concurrent apply/create/delete/start/stop corruption.
- [x] Declarative spec validation and apply coordination have deterministic tests independent of Apple `container`.
- [x] Acceptance is demonstrated against the real Apple backend.

## Definition of Done

- [x] Relevant deterministic tests are added or updated and `swift test` passes.
- [x] Backend-dependent acceptance evidence uses the real Apple backend.
- [x] Fake/in-memory backends are allowed only in tests and cannot be selected by user-facing CLI flags, environment variables, or hidden fallbacks.
- [x] CLI command handlers do not call Apple `container` directly; backend interaction goes through `SandboxBackend`.
- [x] No display-layer workaround hides a failed spec, apply, runtime recreation, Guest State, or locking requirement.

## Evidence

- Deterministic tests: `swift test` — 72 tests passing.
- Real backend validation: `docs/validation/declarative-spec-apply/RESULTS.md`
- Raw log: `docs/validation/declarative-spec-apply/run-20260518-235756.log`

## Blocked by

- `issues/sand/008-allowed-folder-lifecycle-policy.md` (done)
- `issues/sand/009-working-directory-mapping.md` (done)

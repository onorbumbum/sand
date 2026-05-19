---
title: Support declarative specs and real apply reconciliation
status: needs-triage
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

- [ ] `sand create --from spec.yaml` creates a real Sandbox VM from a user-authored Sandbox Spec.
- [ ] `sand apply <name>` reconciles manual Sandbox Spec edits with the real backend.
- [ ] Apply changes real backend configuration, not only Host Metadata.
- [ ] Runtime recreation, when needed, remains hidden/internal rather than a user-facing lifecycle command.
- [ ] Guest State survives apply flows that require runtime recreation.
- [ ] Unsupported future fields such as inbound networking are rejected by v1 Sandbox Spec validation.
- [ ] CPU and memory edits after creation are rejected in v1.
- [ ] Stopped configuration changes apply immediately.
- [ ] Running configuration changes that interrupt active sessions ask first.
- [ ] Lifecycle Mutation serialization prevents concurrent apply/create/delete/start/stop corruption.
- [ ] Declarative spec validation and apply coordination have deterministic tests independent of Apple `container`.
- [ ] Acceptance is demonstrated against the real Apple backend.

## Definition of Done

- [ ] Relevant deterministic tests are added or updated and `swift test` passes.
- [ ] Backend-dependent acceptance evidence uses the real Apple backend.
- [ ] Fake/in-memory backends are allowed only in tests and cannot be selected by user-facing CLI flags, environment variables, or hidden fallbacks.
- [ ] CLI command handlers do not call Apple `container` directly; backend interaction goes through `SandboxBackend`.
- [ ] No display-layer workaround hides a failed spec, apply, runtime recreation, Guest State, or locking requirement.

## Blocked by

- `issues/sand/008-allowed-folder-lifecycle-policy.md`
- `issues/sand/009-working-directory-mapping.md`

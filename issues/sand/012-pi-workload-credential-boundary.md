---
title: Accept Pi as a normal Workload Command with sandbox-local identity
status: needs-triage
type: issue
category: enhancement
labels:
  - needs-triage
  - hitl
  - sand
  - sandbox-vm
  - pi
  - credentials
  - apple-container
created: 2026-05-19
---

## Parent

- `issues/sand/prd-sand-sandbox-vm.md`

## What to build

Prove the Pi-first workflow without making `sand` a Pi-specific launcher. Pi should run as an ordinary Workload Command inside the Sandbox Guest, while host Pi identity and host credentials remain outside the sandbox unless explicitly exposed through future non-v1 mechanisms.

## Acceptance criteria

- [ ] `sand <name> run pi [args...]` works as a normal Workload Command in a real Sandbox Guest.
- [ ] `sand` does not parse or understand Pi-specific flags.
- [ ] Host Mac `~/.pi` is not mounted by default.
- [ ] Host credential files are not mounted or forwarded by default.
- [ ] Pi Identity lives in Guest State.
- [ ] Guest Secrets are sandbox-local in v1.
- [ ] There is no Pi-specific `sand <name> pi` shortcut in v1.
- [ ] There is no skill-source or Pi skill syncing behavior in `sand` v1.
- [ ] Acceptance evidence distinguishes unauthenticated smoke checks from any human-authenticated Pi setup.
- [ ] Credential-boundary checks verify by inspection and real guest commands that host `~/.pi`, host credential files, and host secret-forwarding paths are absent by default.

## Definition of Done

- [ ] Relevant deterministic tests are added or updated and `swift test` passes.
- [ ] Backend-dependent acceptance evidence uses the real Apple backend.
- [ ] Fake/in-memory backends are allowed only in tests and cannot be selected by user-facing CLI flags, environment variables, or hidden fallbacks.
- [ ] CLI command handlers do not call Apple `container` directly; backend interaction goes through `SandboxBackend`.
- [ ] No display-layer workaround hides a failed Pi workload, identity, credential-boundary, or out-of-scope behavior requirement.

## Blocked by

- `issues/sand/006-run-opaque-workload-commands.md`
- `issues/sand/008-allowed-folder-lifecycle-policy.md`
- `issues/sand/009-working-directory-mapping.md`
- `issues/sand/010-declarative-spec-apply.md`

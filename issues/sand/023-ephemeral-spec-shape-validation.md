---
title: Validate Ephemeral Spec shape before side effects
status: needs-triage
type: issue
category: enhancement
labels:
  - needs-triage
  - sand
  - sandbox-vm
  - ephemeral
  - validation
  - swift
created: 2026-06-03
---

## Parent

- `issues/sand/prd-ephemeral-sandbox-runs.md`

## What to build

Make Ephemeral Spec parsing and run planning fail fast before any host hooks, run records, active Host Metadata, or backend resources are touched when the user-authored Ephemeral Spec is malformed or incomplete.

## Acceptance criteria

- [ ] Ephemeral Spec shape validation supports `schemaVersion: 1` and rejects unsupported schema versions with a clear validation error.
- [ ] Missing effective Foreground Workload, empty command strings, unsupported command-list shorthand, malformed command shapes, and unsupported Ephemeral Spec fields fail before side effects.
- [ ] User-authored `resolvedHostPath` in Ephemeral Allowed Folders is rejected before side effects.
- [ ] Invalid `namePrefix` values fail validation rather than being silently sanitized.
- [ ] Malformed specs do not create an Ephemeral Run Record, do not run Before Provision Hooks, do not create active Host Metadata, and do not call the backend.
- [ ] EphemeralSpec and EphemeralRunPlan are separate from SandboxSpec while sharing parsing/value helpers only where that keeps real shared rules DRY.
- [ ] Deterministic tests cover valid defaults, malformed YAML/spec shape, unsupported fields, rejected `resolvedHostPath`, command validation, and absence of side effects.

## Blocked by

- `issues/sand/022-minimal-ephemeral-command-happy-path.md`

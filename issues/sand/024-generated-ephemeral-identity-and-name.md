---
title: Generate Ephemeral Run identity and Sandbox Name
status: needs-triage
type: issue
category: enhancement
labels:
  - needs-triage
  - sand
  - sandbox-vm
  - ephemeral
  - host-metadata
  - swift
created: 2026-06-03
---

## Parent

- `issues/sand/prd-ephemeral-sandbox-runs.md`

## What to build

Allocate Ephemeral Run identity in one place after a valid Ephemeral Run Plan exists: run ID, generated Sandbox Name, and run record path. The generated Sandbox Name should use the optional `namePrefix`, default to `ephemeral`, include timestamp plus short random suffix, validate like any Sandbox Name, and be recorded before hooks run.

## Acceptance criteria

- [ ] `namePrefix` is optional and defaults to `ephemeral`.
- [ ] Generated Sandbox Names include the prefix, a timestamp, and a short random suffix to reduce collisions while remaining human-readable.
- [ ] Generated Sandbox Names must pass normal Sandbox Name validation.
- [ ] Identity allocation happens after valid run planning and before Before Provision Hooks.
- [ ] EphemeralRunRecordStore allocates run ID, generated Sandbox Name, and record path as one DRY operation.
- [ ] The generated Sandbox Name is written to the Ephemeral Run Record before hooks run.
- [ ] Deterministic tests cover default prefix, custom prefix, invalid prefix, name validation, uniqueness shape, and record-store allocation behavior.

## Blocked by

- `issues/sand/022-minimal-ephemeral-command-happy-path.md`
- `issues/sand/023-ephemeral-spec-shape-validation.md`

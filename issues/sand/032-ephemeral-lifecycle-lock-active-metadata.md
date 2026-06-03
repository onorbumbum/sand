---
title: Scope lifecycle locks and active metadata for Ephemeral Sandbox Runs
status: needs-triage
type: issue
category: enhancement
labels:
  - needs-triage
  - sand
  - sandbox-vm
  - ephemeral
  - host-metadata
  - lifecycle
  - swift
created: 2026-06-03
---

## Parent

- `issues/sand/prd-ephemeral-sandbox-runs.md`

## What to build

Make Ephemeral Sandbox Runs visible and safe while active without blocking unrelated work for the whole Foreground Workload. Temporary active specs should reuse Host Metadata behavior, appear in normal listings while active, and be removed after successful delete.

## Acceptance criteria

- [ ] Temporary active Sandbox Specs are written through HostMetadataStore before backend provisioning.
- [ ] Active ephemeral Sandbox VMs appear in `sand list` while running or otherwise active.
- [ ] Active temporary specs are removed after successful delete, while Ephemeral Run Records remain inspectable.
- [ ] Duplicate Sandbox Name protection is reused through Host Metadata rather than custom ephemeral-only checks.
- [ ] Lifecycle mutation locks are held during active metadata/backend mutation phases but not during the full Foreground Workload lifetime.
- [ ] MVP behavior does not specially hide or protect the generated ephemeral Sandbox Name from normal commands while active.
- [ ] Deterministic tests verify active metadata ordering, list visibility, cleanup removal, duplicate protection, and lock enter/exit boundaries around long-running workload execution.

## Blocked by

- `issues/sand/022-minimal-ephemeral-command-happy-path.md`
- `issues/sand/030-ephemeral-failure-cleanup-result-precedence.md`

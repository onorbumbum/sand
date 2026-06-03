---
title: Run Before Provision Hooks before resolving folders and provisioning
status: needs-triage
type: issue
category: enhancement
labels:
  - needs-triage
  - sand
  - sandbox-vm
  - ephemeral
  - lifecycle-hooks
  - host-mac
  - swift
created: 2026-06-03
---

## Parent

- `issues/sand/prd-ephemeral-sandbox-runs.md`

## What to build

Add optional Before Provision Hooks that run on the Host Mac before Allowed Folder path resolution and backend provisioning, so an ephemeral workflow can prepare host-side folders or inputs before they are mounted into the Sandbox VM.

## Acceptance criteria

- [ ] Ephemeral Specs may omit Before Provision Hooks or provide an empty list.
- [ ] Before Provision Hooks use the same structured command shape as the Foreground Workload: non-empty `command` plus optional `args` defaulting to empty.
- [ ] Before Provision Hooks run as Host Mac commands relative to the directory containing the Ephemeral Spec.
- [ ] Hook commands resolve through PATH, inherit the `sand` process environment, and use captured non-interactive IO.
- [ ] Hook stdout and stderr are written to run-record files and referenced by events without automatic redaction.
- [ ] Folder path resolution happens after successful Before Provision Hooks, allowing hooks to create referenced folders.
- [ ] Before Provision Hook failure aborts before provisioning, skips After Stop Hooks, records the failure, and does not create backend resources.
- [ ] Deterministic tests use a HostCommandRunner port to verify ordering, working directory, command shape, IO capture, environment behavior, and failure aborts.

## Blocked by

- `issues/sand/025-ephemeral-allowed-folders-concrete-spec.md`

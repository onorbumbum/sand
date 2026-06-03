---
title: Add minimal explicit Ephemeral Sandbox Run happy path
status: needs-triage
type: issue
category: enhancement
labels:
  - needs-triage
  - sand
  - sandbox-vm
  - ephemeral
  - automation
  - swift
  - macos
created: 2026-06-03
---

## Parent

- `issues/sand/prd-ephemeral-sandbox-runs.md`

## What to build

Add the thinnest complete Ephemeral Sandbox Run path: `sand ephemeral --from <ephemeral-spec.yaml>` reads a minimal Ephemeral Spec with an explicit Foreground Workload working directory, creates a temporary Sandbox VM, runs the Foreground Workload, stops and deletes the Sandbox VM, records the attempt, and prints the final result plus Ephemeral Run Record path.

This slice should prove the explicit command and bounded create-run-stop-delete lifecycle without adding hooks, folder defaulting, CLI workload overrides, or full failure semantics yet.

## Acceptance criteria

- [ ] `sand ephemeral --from <ephemeral-spec.yaml>` is routed as a top-level Ephemeral Command, not as a sandbox-first action.
- [ ] A minimal Ephemeral Spec with `schemaVersion: 1`, an explicit workload command, and an explicit workload `workdir` can run end to end through fakeable application boundaries.
- [ ] The Ephemeral Sandbox Run creates temporary active Host Metadata, provisions, starts, runs the Foreground Workload, attempts stop, deletes the Sandbox VM, and removes active Host Metadata on success.
- [ ] The Foreground Workload runs through the existing backend run path and uses normal Workload Command IO/TTY behavior rather than a special Pi or ephemeral backend operation.
- [ ] A basic Ephemeral Run Record is created and the final CLI output includes successful status and the run record path.
- [ ] Normal durable Sandbox VM commands remain available and unchanged by the new command route.
- [ ] Deterministic tests cover the happy path with fake backend, fake Host Metadata, and fake run record storage.

## Blocked by

None - can start immediately

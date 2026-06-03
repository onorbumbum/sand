---
title: Support CLI Foreground Workload override after double dash
status: needs-triage
type: issue
category: enhancement
labels:
  - needs-triage
  - sand
  - sandbox-vm
  - ephemeral
  - cli
  - workload-command
  - swift
created: 2026-06-03
---

## Parent

- `issues/sand/prd-ephemeral-sandbox-runs.md`

## What to build

Support the explicit override form `sand ephemeral --from <ephemeral-spec.yaml> -- <command> [args...]` so users can reuse an Ephemeral Spec while changing only the Foreground Workload command for a run.

## Acceptance criteria

- [ ] CLI parsing recognizes `--` as the boundary between `sand ephemeral` options and the override Workload Command.
- [ ] When an override is present, the effective Foreground Workload command and args come from the CLI rather than the YAML workload command.
- [ ] A CLI override preserves the YAML workload `workdir` when the YAML workload has one.
- [ ] A CLI override is allowed when the YAML has no workload, as long as the effective plan is otherwise valid.
- [ ] Workload arguments after `--` are passed through opaquely and are not parsed as `sand` flags.
- [ ] Missing workload after a trailing `--` fails before side effects.
- [ ] Deterministic CLI router and planning tests cover overrides, preserved workdir, YAML-without-workload, and opaque arguments.

## Blocked by

- `issues/sand/022-minimal-ephemeral-command-happy-path.md`
- `issues/sand/023-ephemeral-spec-shape-validation.md`
- `issues/sand/026-default-foreground-workload-workdir.md`

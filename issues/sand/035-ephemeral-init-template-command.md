---
title: Add Ephemeral Spec init template command for first-run happy path
status: needs-triage
type: issue
category: enhancement
labels:
  - needs-triage
  - sand
  - sandbox-vm
  - ephemeral
  - cli
  - docs
  - swift
  - onboarding
created: 2026-06-03
---

## Parent

- `issues/sand/prd-ephemeral-sandbox-runs.md`

## What to build

Add an easy first-run path for creating a valid Ephemeral Spec YAML file, similar in spirit to the durable `sand create <name>` happy path. A user should not need to know the full Ephemeral Spec schema before trying their first bounded create-run-stop-delete workflow.

Introduce a non-executing template generator command:

```sh
sand ephemeral init <ephemeral-spec.yaml>
sand ephemeral init --stdout
sand ephemeral init <ephemeral-spec.yaml> --force
```

The command writes a runnable starter Ephemeral Spec that demonstrates the happy path: optional setup hook, one read-write Allowed Folder, a foreground workload that writes a host-visible file, and an after-stop hook that reads/processes that output. The generated file should be immediately usable with:

```sh
sand ephemeral --from <ephemeral-spec.yaml>
```

## Acceptance criteria

- [ ] `sand ephemeral init <path>` writes a valid starter Ephemeral Spec YAML file at `<path>`.
- [ ] The starter spec is parseable by the existing Ephemeral Spec parser and exercises the happy path: `schemaVersion`, `description`, `namePrefix`, `beforeProvision`, `allowedFolders`, `workload`, and `afterStop`.
- [ ] The starter spec can run from a fresh directory without manual folder setup; any required folder is created by `beforeProvision`.
- [ ] `sand ephemeral init <path>` refuses to overwrite an existing file and prints a clear error.
- [ ] `sand ephemeral init <path> --force` overwrites an existing file.
- [ ] `sand ephemeral init --stdout` prints the template to stdout and does not require or write a path.
- [ ] Help text documents `sand ephemeral init <path> [--force]` and `sand ephemeral init --stdout` without making it sound like a Sandbox VM is created.
- [ ] README, CLI Reference, Onboarding Guide, Developer Guide, and Generated Documentation freshness metadata are refreshed where impacted.
- [ ] Deterministic tests cover CLI routing, no-overwrite behavior, force overwrite, stdout mode, template parseability, and no backend/metadata side effects.
- [ ] `swift test`, `make docs-check`, and `make check` pass.

## Suggested template shape

The exact wording can change, but the generated YAML should stay small, readable, and runnable:

```yaml
schemaVersion: 1
description: Easy ephemeral smoke test
namePrefix: smoke

beforeProvision:
  - command: mkdir
    args:
      - -p
      - work

allowedFolders:
  - hostPath: ./work
    guestPath: /workspace
    accessMode: read-write

workload:
  command: sh
  args:
    - -lc
    - 'echo "hello from ephemeral" > /workspace/output.txt && ls -la /workspace'
  workdir: /workspace

afterStop:
  - command: sh
    args:
      - -lc
      - 'echo "afterStop saw:" && cat work/output.txt'
```

## Design notes

- Prefer `init` over `create` because this command creates a YAML file, not a Sandbox VM.
- Keep execution explicit: users still run `sand ephemeral --from <ephemeral-spec.yaml>` separately.
- The command should not call backend, Host Metadata, or Ephemeral Run Record code.
- If implementation needs a reusable template constant, keep it close to CLI/application code and test it through public command behavior rather than snapshotting irrelevant formatting.
- Avoid adding a second Ephemeral Spec shape or shorthand as part of this issue.

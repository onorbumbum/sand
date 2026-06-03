---
title: Add Ephemeral Spec init template command for first-run happy path
status: done
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

- [x] `sand ephemeral init <path>` writes a valid starter Ephemeral Spec YAML file at `<path>`.
- [x] The starter spec is parseable by the existing Ephemeral Spec parser and exercises the happy path: `schemaVersion`, `description`, `namePrefix`, `beforeProvision`, `allowedFolders`, `workload`, and `afterStop`.
- [x] The starter spec can run from a fresh directory without manual folder setup; any required folder is created by `beforeProvision`.
- [x] `sand ephemeral init <path>` refuses to overwrite an existing file and prints a clear error.
- [x] `sand ephemeral init <path> --force` overwrites an existing file.
- [x] `sand ephemeral init --stdout` prints the template to stdout and does not require or write a path.
- [x] Help text documents `sand ephemeral init <path> [--force]` and `sand ephemeral init --stdout` without making it sound like a Sandbox VM is created.
- [x] README, CLI Reference, Onboarding Guide, Developer Guide, and Generated Documentation freshness metadata are refreshed where impacted.
- [x] Deterministic tests cover CLI routing, no-overwrite behavior, force overwrite, stdout mode, template parseability, and no backend/metadata side effects.
- [x] `swift test`, `make docs-check`, and `make check` pass.

## Suggested template shape

The exact wording can change, but the generated YAML should stay small, readable, and runnable:

```yaml
schemaVersion: 1
description: Easy ephemeral smoke test
namePrefix: smoke

beforeProvision:
  - command: sh
    args:
      - -lc
      - 'mkdir -p work && echo "beforeProvision prepared work" > work/output.txt'

allowedFolders:
  - hostPath: ./work
    guestPath: /workspace
    accessMode: read-write

workload:
  command: sh
  args:
    - -lc
    - 'echo "workload wrote from Sandbox Guest" >> /workspace/output.txt && ls -la /workspace >> /workspace/output.txt'
  workdir: /workspace

afterStop:
  - command: sh
    args:
      - -lc
      - 'echo "afterStop processed host-visible output" >> work/output.txt && cp work/output.txt work/after-stop.txt && cat work/after-stop.txt'
```

## Design notes

- Prefer `init` over `create` because this command creates a YAML file, not a Sandbox VM.
- Keep execution explicit: users still run `sand ephemeral --from <ephemeral-spec.yaml>` separately.
- The command should not call backend, Host Metadata, or Ephemeral Run Record code.
- If implementation needs a reusable template constant, keep it close to CLI/application code and test it through public command behavior rather than snapshotting irrelevant formatting.
- Avoid adding a second Ephemeral Spec shape or shorthand as part of this issue.

## Progress

### 2026-06-03 09:58 PDT — RUN-ONLY: shipped ephemeral init template command

- Files shipped: `Sources/SandCore/CLI/CLICommandRouter.swift`, `Sources/SandCore/Spec/YAMLValueParsing.swift`, `Sources/SandCore/Ephemeral/EphemeralRunCoordinator.swift`, `Tests/SandCoreTests/CLICommandRouterTests.swift`, `README.md`, `docs/cli-reference.md`, `docs/onboarding.md`, `docs/developer-guide.md`, `scripts/generate-cli-reference.sh`
- Verification: `swift test --filter CLICommandRouterTests` pass (15 tests); `swift test` pass (127 tests); `make docs-check` pass; `make check` pass; `python -m pytest` exit 5 because this Swift repo collected 0 pytest tests.
- TDD evidence: RED `swift test --filter CLICommandRouterTests` failed with unsupported option `init`; GREEN `swift test --filter CLICommandRouterTests` passed after implementation; refactor no behavior refactor needed, targeted tests rerun green.
- ACs completed: all acceptance criteria checked above.
- HITL/default decisions: **Used the safer non-executing CLI-router implementation for `init`, with no application/backend call, because the command only writes or prints a template. Added small YAML scalar unquoting so the generated valid YAML shell snippets parse into runnable command arguments. Updated the starter template to make phase output visible in host files (`work/output.txt` plus `work/after-stop.txt`) because hook stdout/stderr are captured in the run record rather than streamed live.**

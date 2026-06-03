<!-- generated-doc: true -->
<!-- generated-by: scripts/generate-cli-reference.sh -->
<!-- docs-input-hash: 84b5dcd59bfea5f8c56d4932beeed50f19151f9e91b89d3fe92d0dc7afdc2028 -->

# sand CLI Reference

> Fully generated documentation. Do not hand-edit this file outside the Documentation Refresh Workflow. Regenerate it with `scripts/generate-cli-reference.sh` so usage stays aligned with actual `sand` help output.

This reference captures the v1 **Control Surface** for managing **Sandbox VMs**, **Allowed Folders**, **Sandbox Sessions**, and generic **Workload Commands**.

## Generation source

- Docs input hash: `84b5dcd59bfea5f8c56d4932beeed50f19151f9e91b89d3fe92d0dc7afdc2028`
- Generator: `scripts/generate-cli-reference.sh`
- Help source command: `swift run --package-path <repo> sand`
- Usage sections below are captured from actual `sand --help`, `sand <command> --help`, `sand <name> --help`, and `sand --version` output.

## Supported v1 command surface

- Global: `sand --help`, `sand --version`
- Top-level commands: `doctor`, `create`, `ephemeral --from <spec.yaml> [-- <command> [args...]]`, `list`, `apply`, `delete`, `folders`
- Sandbox-first actions: `sand <name> status`, `start`, `stop`, `shell`, `run <command> [args...]`, `logs`, `spec`

## Current v1 boundaries

The v1 command surface is intentionally explicit and small:

- To clear a Sandbox VM completely, delete it and create a new one.
- To run Pi, use the same command shape as any other tool: `sand <name> run pi [args...]`.
- Network access is outbound-only from the Sandbox VM in v1; inbound browser/server callbacks need a handoff flow outside the command surface.
- Commands name the target Sandbox VM explicitly, so it is always clear which environment you are operating.

## `sand --version`

```text
sand 0.1.0-dev
```

## `sand --help`

```text
Usage: sand <command> [options]

Commands:
  doctor                         Verify host prerequisites
  create <name> [options]        Create a Sandbox VM
  ephemeral --from <spec.yaml>   Run a bounded Ephemeral Sandbox Run
  list                           List Sandbox VMs
  apply <name>                   Apply spec changes
  delete <name> [--force]        Delete a Sandbox VM
  folders <action> ...           Manage allowed Host Mac folders
  <name> status                  Show Sandbox VM status
  <name> start                   Start a Sandbox VM
  <name> stop                    Stop a Sandbox VM
  <name> shell                   Open a shell
  <name> run <command> [args...] Run a Workload Command
  <name> logs                    Show logs
  <name> spec                    Print the sandbox spec

Use `sand <command> --help` or `sand <name> --help` for command help.
```

## `sand doctor`

```text
Usage: sand doctor

Verifies host support, backend readiness, default image availability, and ~/.sand writability.
```

## `sand create`

```text
Usage: sand create <name> [--image <image>] [--cpus <count>] [--memory <size>] [--from <spec.yaml>]

Creates a Sandbox VM from generated defaults or from an authored spec.
```

## `sand ephemeral`

```text
Usage: sand ephemeral --from <ephemeral-spec.yaml> [-- <command> [args...]]

Creates a temporary Sandbox VM, runs the spec workload or CLI workload override, stops and deletes it, and prints the run record path.
```

## Ephemeral Spec lifecycle hooks

Ephemeral Specs may omit Host Mac lifecycle hook lists or provide empty lists with `beforeProvision: []` and `afterStop: []`. Hook entries use the same structured command shape as a Foreground Workload: a non-empty `command` plus optional `args`.

```yaml
beforeProvision:
  - command: mkdir
    args:
      - -p
      - work
afterStop:
  - command: archive-output
    args:
      - work/output.txt
```

`beforeProvision` hooks run on the Host Mac before Allowed Folder resolution and provisioning. `afterStop` hooks run on the Host Mac after the Foreground Workload exits and after `sand` attempts to stop the Sandbox VM, including when the workload exits nonzero or the stop attempt fails. Hook output is captured in the Ephemeral Run Record. A failing `afterStop` hook stops remaining after-stop hooks, but delete is still attempted.

Failed Ephemeral Sandbox Runs print the run status, run record path, failed phase, and final exit code. Cleanup/delete failures take precedence over earlier workload failures in the final process exit code. If delete fails, `sand` also records and prints manual cleanup guidance with the generated Sandbox Name and a `sand delete <name> --force` command.

## `sand list`

```text
Usage: sand list

Lists known Sandbox VMs with runtime state, image, and allowed folder count.
```

## `sand apply`

```text
Usage: sand apply <name>

Applies allowed spec changes to an existing Sandbox VM.
```

## `sand delete`

```text
Usage: sand delete <name> [--force]

Deletes the Sandbox VM runtime, guest state volume, and host metadata spec.
```

## `sand folders`

```text
Usage: sand folders <action> ...

Actions:
  folders add <name> <host-path> <rw|ro> [--as <guest-path>]
  folders list <name>
  folders remove <name> <host-path>
```

## Sandbox-first actions

Use `sand <name> --help` to print the supported Sandbox Session and lifecycle actions for a named **Sandbox VM**.

```text
Usage: sand <name> <action> [arguments]

Actions:
  status                         Show status
  start                          Start the Sandbox VM
  stop                           Stop the Sandbox VM
  shell                          Open an interactive shell
  run <command> [args...]        Run a Workload Command
  logs                           Show logs
  spec                           Print the sandbox spec
```

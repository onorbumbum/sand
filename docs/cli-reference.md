<!-- generated-doc: true -->
<!-- generated-by: scripts/generate-cli-reference.sh -->
<!-- docs-input-hash: 8ca860129690ce9cda29fdc549c31473e5389b7443f6b14b493f38741283170e -->

# sand CLI Reference

> Fully generated documentation. Do not hand-edit this file outside the Documentation Refresh Workflow. Regenerate it with `scripts/generate-cli-reference.sh` so usage stays aligned with actual `sand` help output.

This reference captures the v1 **API Surface** for managing **Sandbox VMs**, **Allowed Folders**, **Sandbox Sessions**, and generic **Workload Commands**.

## Generation source

- Docs input hash: `8ca860129690ce9cda29fdc549c31473e5389b7443f6b14b493f38741283170e`
- Generator: `scripts/generate-cli-reference.sh`
- Help source command: `swift run --package-path <repo> sand`
- Usage sections below are captured from actual `sand --help`, `sand <command> --help`, and `sand --version` output.

## Supported v1 command surface

- Global: `sand --help`, `sand --version`
- Top-level commands: `doctor`, `create`, `list`, `apply`, `delete`, `folders`, `status`, `start`, `stop`, `shell`, `run`, `logs`, `spec`

## Current v1 boundaries

The v1 command surface is intentionally explicit and small:

- To clear a Sandbox VM completely, delete it and create a new one.
- To run Pi, use the same command shape as any other tool: `sand run <name> pi [args...]`.
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
  list                           List Sandbox VMs
  apply <name>                   Apply spec changes
  delete <name> [--force]        Delete a Sandbox VM
  folders <action> ...           Manage shared Host Mac folders
  status <name>                  Show Sandbox VM status
  start <name>                   Start a Sandbox VM
  stop <name>                    Stop a Sandbox VM
  shell <name>                   Open a shell
  run <name> <command> [args...] Run a Workload Command
  logs <name>                    Show logs
  spec <name>                    Print the sandbox spec

Use `sand <command> --help` for command help.
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

## `sand list`

```text
Usage: sand list

Lists known Sandbox VMs with runtime state, image, and shared folder count.
```

## `sand apply`

```text
Usage: sand apply <name>

Applies shared spec changes to an existing Sandbox VM.
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

## `sand status`

```text
Usage: sand status <name>

Shows the current status of a Sandbox VM.
```

## `sand start`

```text
Usage: sand start <name>

Starts a Sandbox VM.
```


## `sand stop`


```text
Usage: sand stop <name>

Stops a Sandbox VM.
```

## `sand shell`


```text
Usage: sand shell <name>

Opens an interactive shell in the Sandbox VM.
```

## `sand run`


```text
Usage: sand run <name> <command> [args...]

Runs a command inside the Sandbox VM.
```

## `sand logs`

```text
Usage: sand logs <name>

Shows logs for a Sandbox VM.
```

## `sand spec`


```text
Usage: sand spec <name>

Prints the sandbox spec.
```

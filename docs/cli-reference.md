<!-- generated-doc: true -->
<!-- generated-by: scripts/generate-cli-reference.sh -->
<!-- docs-input-hash: cb70cafac5bd0c9a03bc7761eea55ccd12f02c78843cd44d44efe2095e68c504 -->

# sand CLI Reference

> Fully generated documentation. Do not hand-edit this file outside the Documentation Refresh Workflow. Regenerate it with `scripts/generate-cli-reference.sh` so usage stays aligned with actual `sand` help output.

This reference captures the v1 **Control Surface** for managing **Sandbox VMs**, **Allowed Folders**, **Sandbox Sessions**, and generic **Workload Commands**.

## Generation source

- Docs input hash: `cb70cafac5bd0c9a03bc7761eea55ccd12f02c78843cd44d44efe2095e68c504`
- Generator: `scripts/generate-cli-reference.sh`
- Help source command: `swift run --package-path <repo> sand`
- Usage sections below are captured from actual `sand --help`, `sand <command> --help`, `sand <name> --help`, and `sand --version` output.

## Supported v1 command surface

- Global: `sand --help`, `sand --version`
- Top-level commands: `doctor`, `create`, `list`, `apply`, `delete`, `folders`
- Sandbox-first actions: `sand <name> status`, `start`, `stop`, `shell`, `run <command> [args...]`, `logs`, `spec`

## Known v1 non-goals

These shapes are intentionally outside the supported v1 command surface:

- No `sand reset` command. Use explicit delete plus create for destructive reset flows.
- No Pi-specific shortcut such as `sand <name> pi`. Run Pi as a normal **Workload Command** with `sand <name> run pi [args...]`.
- No inbound networking or port publishing options such as `--inbound`, `--port`, or `--publish`.
- No default Sandbox VM or project-local implicit Sandbox VM selection. Commands name the Sandbox VM explicitly.

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

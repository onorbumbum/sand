<!-- generated-doc: true -->
<!-- generated-by: scripts/generate-cli-reference.sh -->
<!-- docs-input-hash: f330081d82545d7a14955ae522115a318c068b9102c6a7348c04bd0fe946524c -->

# sand CLI Reference

> Fully generated documentation. Do not hand-edit this file outside the Documentation Refresh Workflow. Regenerate it with `scripts/generate-cli-reference.sh` so usage stays aligned with actual `sand` help output.

This reference captures the v1 **Control Surface** for managing **Sandbox VMs**, **Allowed Folders**, **Sandbox Sessions**, and generic **Workload Commands**.

## Generation source

- Docs input hash: `f330081d82545d7a14955ae522115a318c068b9102c6a7348c04bd0fe946524c`
- Generator: `scripts/generate-cli-reference.sh`
- Help source command: `swift run --package-path <repo> sand`
- Usage sections below are captured from actual `sand --help`, `sand <command> --help`, `sand <name> --help`, and `sand --version` output.

## Supported v1 command surface

- Global: `sand --help`, `sand --version`
- Top-level commands: `doctor`, `create`, `sand ephemeral --from <ephemeral-spec.yaml> [-- <workload override...>]`, `sand ephemeral init <path> [--force]`, `sand ephemeral init --stdout`, `list`, `apply`, `delete`, `folders`
- Sandbox-first actions: `sand <name> status`, `start`, `stop`, `shell`, `run <command> [args...]`, `logs`, `spec`

## Current v1 boundaries

The v1 command surface is intentionally explicit and small:

- To clear a Sandbox VM completely, delete it and create a new one.
- To run Pi, use the same command shape as any other tool: `sand <name> run pi [args...]`.
- Network access is outbound-only from the Sandbox VM in v1; inbound browser/server callbacks need a handoff flow outside the command surface.
- Commands name the target Sandbox VM explicitly, so it is always clear which environment you are operating.
- Durable Sandbox Specs describe reusable Sandbox VMs; Ephemeral Specs describe bounded create-run-stop-delete workflows and preserve Ephemeral Run Records. Use `sand ephemeral init <path>` to write a starter Ephemeral Spec before running it explicitly with `sand ephemeral --from <path>`. See `docs/adr/0001-separate-ephemeral-spec-from-sandbox-spec.md` for the durable-vs-ephemeral boundary.

## `sand --version`

```text
sand 0.2.1-dev
```

## `sand --help`

```text
Usage: sand <command> [options]

Commands:
  doctor                         Verify host prerequisites
  create <name> [options]        Create a Sandbox VM
  sand ephemeral --from <ephemeral-spec.yaml> [-- <workload override...>]
                             Run a bounded Ephemeral Sandbox Run
  sand ephemeral init <path> [--force]
                             Write a starter Ephemeral Spec YAML file
  sand ephemeral init --stdout
                             Print the starter Ephemeral Spec YAML file
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
Usage: sand ephemeral --from <ephemeral-spec.yaml> [-- <workload override...>]
       sand ephemeral init <path> [--force]
       sand ephemeral init --stdout

`sand ephemeral --from` creates a temporary Sandbox VM, runs the spec workload or CLI workload override, stops and deletes it, and prints the run record path.

`sand ephemeral init` writes a starter Ephemeral Spec YAML file or prints it with --stdout. It only generates a template and does not create a Sandbox VM.
```

## Ephemeral Spec starter template

Use `sand ephemeral init <path>` to write a runnable starter Ephemeral Spec YAML file, or `sand ephemeral init --stdout` to print the same template. The init command is non-executing: it does not create a Sandbox VM, touch Host Metadata, or create an Ephemeral Run Record. Existing files are left untouched unless `--force` is provided. The starter writes phase-visible content into `work/output.txt`, copies a post-work snapshot to `work/after-stop.txt`, and still captures hook stdout/stderr in the Ephemeral Run Record rather than streaming hook output live.

Run the generated template explicitly after review:

```sh
sand ephemeral init ephemeral-spec.yaml
sand ephemeral --from ephemeral-spec.yaml
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

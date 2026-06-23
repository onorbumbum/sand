<!-- generated-doc: true -->
<!-- generated-by: scripts/generate-cli-reference.sh -->
<!-- docs-input-hash: 6f1147572af21e71a953e7287318f4fb9c3e797f24df4d603b3f0c0cc302896f -->

# sand CLI Reference

> Fully generated documentation. Do not hand-edit this file outside the Documentation Refresh Workflow. Regenerate it with `scripts/generate-cli-reference.sh` so usage stays aligned with actual `sand` help output.

This reference captures the v1 **API Surface** for managing Linux and macOS **Sandbox VMs**, **Shared Folders**, **Sandbox Sessions**, and generic **Workload Commands**.

## Generation source

- Docs input hash: `6f1147572af21e71a953e7287318f4fb9c3e797f24df4d603b3f0c0cc302896f`
- Generator: `scripts/generate-cli-reference.sh`
- Help source command: `swift run --package-path <repo> sand`
- Usage sections below are captured from actual `sand --help`, `sand <command> --help`, and `sand --version` output.

## Supported v1 command surface

- Global: `sand --help`, `sand --version`
- Top-level commands: `doctor`, `create`, `bootstrap`, `list`, `apply`, `delete`, `folders`, `signing`, `status`, `start`, `stop`, `shell`, `run`, `gui`, `logs`, `spec`

## Current v1 boundaries

The v1 command surface is intentionally explicit and small:

- To clear a Sandbox VM completely, delete it and create a new one.
- To run Pi, use the same command shape as any other tool: `sand run <name> pi [args...]`.
- Network access is outbound-only from the Sandbox VM in v1; inbound browser/server callbacks need a handoff flow outside the command surface.
- Commands name the target Sandbox VM explicitly, so it is always clear which environment you are operating.

## macOS Sandbox VMs

macOS guests are first-class Sandbox VMs backed by Tart. Use `sand create <name> --os macos --from <registry-image-or-local-sandbox>` to clone an existing Tart-compatible image or stopped local sandbox. Use `sand create <name> --from-ipsw <latest|path|url>` for the macOS Install Flow, then complete first boot in `sand gui <name>` and run `sand bootstrap <name>`.

`--disk <size>` is a macOS-only create-time Disk Size field. The default macOS disk is about 100GB, clone disk size is grow-only, and in-place disk resize is not part of the v1 command surface.

`sand gui <name>` opens a macOS GUI Session through Tart VNC and the Host Mac Screen Sharing app. Screen Sharing may ask for credentials. For Cirrus Tart registry images, use username `admin` and password `admin`; for self-built IPSW VMs, use the Sandbox User credentials created during first boot. `gui` is for VM desktop setup and Apple-ID-gated work; it does not forward a host-connected physical iPhone or iPad into the Sandbox Guest.

macOS support requires the Tart CLI on `PATH` (`brew install cirruslabs/cli/tart`). `sand` itself remains an unsigned, entitlement-free CLI because Tart carries the Virtualization Framework entitlement.

Plan macOS Sandbox VMs as a handful, not dozens: Apple's macOS guest license allows roughly two concurrent macOS VMs per Host Mac, and each VM is heavy compared with a Linux Sandbox VM.

## `sand --version`

```text
sand 0.2.4-dev
```

## `sand --help`

```text
Usage: sand <command> [options]

Commands:
  doctor                         Verify host prerequisites
  create <name> [options]        Create a Sandbox VM
  bootstrap <name>               Finish first-boot setup of a self-built macOS base
  list                           List Sandbox VMs
  apply <name>                   Apply spec changes
  delete <name> [--force]        Delete a Sandbox VM
  folders <action> ...           Manage shared Host Mac folders
  signing <action> ...           Install macOS Signing Credentials Guest Secrets
  status <name>                  Show Sandbox VM status
  start <name>                   Start a Sandbox VM
  stop <name>                    Stop a Sandbox VM
  shell <name>                   Open a shell
  run <name> <command> [args...] Run a Workload Command
  gui <name>                     Open a graphical desktop session
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
Usage: sand create <name> [--os <linux|macos>] [--image <image>] [--from <spec.yaml|image|local-sandbox>] [--from-ipsw <latest|path|url>] [--cpus <count>] [--memory <size>] [--disk <size>]

Creates a Sandbox VM from generated defaults, an authored Linux spec, a backend image, or a stopped local macOS sandbox.

Options:
  --os <linux|macos>                Choose the guest OS; linux is the default, macos uses the Tart backend.
  --disk <size>                     macOS-only create-time Disk Size, defaulting to about 100GB.
  --from <image-or-local-sandbox>   Clone a backend image or stopped local macOS sandbox.
  --from-ipsw <latest|path|url>     Build a self-made macOS base via the macOS Install Flow.

macOS sources are open-ended and must be explicit:
  --from <image-or-local-sandbox>   Clone any Tart-compatible macOS image (Sequoia, Tahoe, pinned digest) or a stopped local sandbox.
  --from-ipsw <latest|path|url>     Build a self-made macOS base via `tart create --from-ipsw`. Creates a setup-required VM;
                                    run `sand gui <name>` to complete first boot, then `sand bootstrap <name>`.

Use `sand gui <name>` to open a macOS graphical desktop session for first boot or Apple-ID-gated setup.
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

## `sand bootstrap`

```text
Usage: sand bootstrap <name>

Prepares a self-built macOS Sandbox VM for normal `sand shell` and `sand run` access.

Use this only after `sand create <name> --from-ipsw <latest|path|url>` and first-boot setup in `sand gui <name>`. A fresh IPSW install needs one manual macOS setup pass before `sand` can connect without passwords.

`bootstrap` installs sand's SSH key, verifies SSH and passwordless sudo, finishes guest configuration, and marks the Sandbox VM ready. Cloned Tart registry images such as `macos-sequoia-base` and `macos-sequoia-xcode` do not need this step.
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

## `sand signing`

```text
Usage: sand signing install <name> --certificate <p12> (--certificate-password <password> | --certificate-password-env <var>) --profile <mobileprovision> (--keychain-password <password> | --keychain-password-env <var>) [--keychain <name>]

Installs macOS Signing Credentials into Guest State as a Guest Secret. The Host Mac keychain is never mounted or shared.

Prefer the `--*-password-env` flags so passwords are read from environment variables instead of appearing in shell history or the process list.
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

## `sand gui`


```text
Usage: sand gui <name>

Opens a macOS graphical desktop session through Tart VNC and Host Mac Screen Sharing.

Screen Sharing may ask for credentials. For Cirrus Tart registry images, use username `admin` and password `admin`. For self-built IPSW VMs, use the Sandbox User credentials created during first boot. This password is only for GUI access; `sand shell` and `sand run` use sand's injected SSH key.
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

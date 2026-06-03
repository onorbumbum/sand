# sand

<!-- section-managed-doc: true -->
<!-- managed-sections: build-and-test, install-from-source, quickstart, command-surface-summary -->
<!-- docs-input-hash: 84b5dcd59bfea5f8c56d4932beeed50f19151f9e91b89d3fe92d0dc7afdc2028 -->

> A safer place to run Pi and other developer tools.

`sand` creates small, named Linux environments on your Apple silicon Mac. Each environment feels like a little computer: it has its own files, tools, shell state, and login state, but it can only see the Mac folders you choose to share with it.

## Why sand exists

Modern coding agents and developer CLIs are powerful because they can read code, run commands, install packages, and keep working state. That same power is risky when the tool runs directly in your everyday Mac shell, where your home directory, credentials, dotfiles, project history, and local machine state are all nearby.

`sand` gives those tools a dedicated workspace. Pi can still work like a capable coding assistant, but the boundary is easier to understand: the Sandbox VM gets its own Linux world, and your Mac only exposes the folders you explicitly allow.

For the longer write-up on why I built it, read [Sand — simple VMs for Mac](https://onuruzunismail.com/blog/sand.html).

## Project status

`sand` is experimental alpha software, released under the [Apache License 2.0](LICENSE). It is provided as-is, without a support guarantee or response SLA.

Public GitHub issues are welcome for bugs, questions, and feature ideas. Please report security vulnerabilities through GitHub private vulnerability reporting, not public issues. External pull requests are not accepted yet.

## The problem it solves

`sand` helps answer a practical question:

> “How do I let a powerful tool work on this project without giving it my whole computer?”

It does that by making three things explicit:

1. **Where work runs** — inside a named Sandbox VM, not directly in your normal shell.
2. **What the sandbox can see** — only the Allowed Folders you add.
3. **What persists** — guest tools, package caches, shell config, Pi identity, and other sandbox-local state survive normal stop/start.

## How it works

| Everyday idea | In `sand` |
| --- | --- |
| “Make me a little Linux computer for this work.” | `sand create demo` |
| “Let it work on this project.” | `sand folders add demo ~/Projects/my-project rw --as /workspace` |
| “Let it read these references, but not edit them.” | `sand folders add demo ~/Reference ro --as /reference` |
| “Run Pi in the sandbox.” | `sand demo run pi` |
| “Open a shell in the sandbox.” | `sand demo shell` |
| “Pause it without losing its setup.” | `sand demo stop` |
| “Remove it when I am done.” | `sand delete demo` |

## Current alpha scope

This alpha is intentionally focused on the daily loop:

- create, list, inspect, start, stop, apply, log, and delete Sandbox VMs
- add Host Mac folders as read-write or read-only Guest Paths
- run Pi or any other command inside the Sandbox VM with `sand <name> run <command> [args...]`
- start commands in the matching Guest Path when your Mac current directory is inside an Allowed Folder
- open an interactive Sandbox Session with `sand <name> shell`
- keep Guest State under `/state/sandbox` across stop/start for the same Sandbox VM
- use the Developer-Ready Sandbox image with common development tools already installed

## Current boundaries

In this version, access is intentionally simple: choose folders, run commands, keep guest state. Host credentials and Host Mac Pi config are not shared automatically. Inbound port publishing is not part of the first release, so browser callback logins need the handoff flow described below.

## Documentation

Start with the docs when onboarding humans or AI agents to work on the project:

- [`docs/onboarding.md`](docs/onboarding.md) teaches the repo map, first files to read, working loop, and local verification flow.
- [`docs/cli-reference.md`](docs/cli-reference.md) is generated from current `sand` help output and is the detailed command reference.
- [`docs/developer-guide.md`](docs/developer-guide.md) explains architecture, testing strategy, command-change workflow, and Definition of Done.

The documentation refresh workflow is a guardrail for changes with Documentation Impact. It is not the default work mode for agents; agents should start from the task, product language, code, and tests.

## Delete cleanup behavior

`sand delete <name>` removes the disposable Runtime Instance, Guest State volume, and Host Metadata. Cleanup tolerates already-missing backend resources, so rerunning delete can finish Host Metadata cleanup after a partially completed backend delete.

## Prerequisites

- Apple silicon Mac.
- Swift toolchain compatible with this package (`Package.swift` uses Swift tools 6.2 and declares macOS v26).
- Apple `container` CLI installed and available on `PATH`.
- Apple `container` backend service running or startable by `container system start`.
- The developer-ready image built locally: `sand/developer-ready:ubuntu-lts`.

## Build and smoke-test the developer-ready image

<!-- docs:managed:start id="build-and-test" source="Package.swift Makefile scripts/build-developer-ready-image.sh scripts/smoke-developer-ready-image.sh" -->
Build and verify the default **Sandbox Image**:

```sh
scripts/build-developer-ready-image.sh
scripts/smoke-developer-ready-image.sh
```

Optional environment variables:

```sh
SAND_DEVELOPER_READY_IMAGE=sand/developer-ready:ubuntu-lts scripts/build-developer-ready-image.sh
PI_CLI_VERSION=0.73.1 scripts/build-developer-ready-image.sh
```

Run the local project checks:

```sh
swift test
make docs-check
make check
```

`make check` runs the XCTest suite followed by the Documentation Freshness Gate.
<!-- docs:managed:end -->

## Install from source

<!-- docs:managed:start id="install-from-source" source="Makefile Package.swift docs/cli-reference.md" -->
Build a release binary:

```sh
swift build -c release
```

Install it on your `PATH` with the repository `Makefile`:

```sh
PREFIX=$HOME/.local make install
export PATH="$HOME/.local/bin:$PATH"
```

Verify the installed binary:

```sh
sand --version
sand --help
sand doctor
```

Uninstall:

```sh
PREFIX=$HOME/.local make uninstall
```
<!-- docs:managed:end -->

## Quickstart

The paths below are illustrative. Replace them with real folders on your Host Mac.

<!-- docs:managed:start id="quickstart" source="docs/cli-reference.md and actual sand help output" -->
```sh
# 1. Verify prerequisites first.
sand doctor

# 2. Create a Sandbox VM.
sand create demo

# 3. Inspect list, status, and spec.
sand list
sand demo status
sand demo spec

# 4. Allow a Host Mac project folder read-write at /workspace.
sand folders add demo "$HOME/Projects/my-project" rw --as /workspace

# 5. Allow a Host Mac reference folder read-only at /reference.
sand folders add demo "$HOME/Reference" ro --as /reference
sand folders list demo

# 6. Run Workload Commands from a mapped Host Mac current working directory.
cd "$HOME/Projects/my-project"
sand demo run pwd
sand demo run bash -lc 'echo hello-from-sand > sand-smoke.txt && ls -la'

# 7. Open a Sandbox Session.
sand demo shell

# 8. Stop/start and verify Guest State persistence.
sand demo run bash -lc 'echo persisted > /state/sandbox/persistence-check'
sand demo stop
sand demo start
sand demo run cat /state/sandbox/persistence-check

# 9. View logs.
sand demo logs

# 10. Delete the Sandbox VM.
sand delete demo --force
```
<!-- docs:managed:end -->

Persistence expectation: Allowed Folder contents persist because they are host files. Guest State written under `/state/sandbox` persists across `sand <name> stop` and `sand <name> start` for the same Sandbox VM. Deleting the Sandbox VM removes its Guest State volume and Host Metadata spec.

## Subscription and OAuth logins inside a Sandbox VM

Some CLI tools, including Pi/OpenAI-style subscription logins, start a temporary callback server on `localhost` during login. In `sand` v1, `localhost` in your Host Mac browser is **not** the Sandbox Guest's `localhost`, and v1 does not publish inbound guest ports to the Host Mac.

Use a two-terminal callback handoff instead.

Terminal A: start the login and leave it running:

```sh
sand demo run pi login
```

Open the authorization URL in your Host Mac browser. After approval, the browser may try to load a URL like this and fail:

```text
http://localhost:1455/auth/callback?code=...&scope=...&state=...
```

That failure is expected. Copy the full callback URL from the browser address bar.

Terminal B: send that exact callback URL to the Sandbox Guest while Terminal A is still waiting:

```sh
sand demo run curl -sS 'http://localhost:1455/auth/callback?code=...&scope=...&state=...'
```

Quote the URL so shell `&` characters are not interpreted. The callback URL is usually short-lived and tied to the still-running login process, so rerun the login if Terminal A exited or the code expired.

The resulting identity and tokens live in the Sandbox VM's Guest State. `sand` does not mount your Host Mac `~/.pi` or forward host credentials by default.

## CLI command surface

For the complete generated reference, see [`docs/cli-reference.md`](docs/cli-reference.md).

<!-- docs:managed:start id="command-surface-summary" source="docs/cli-reference.md and actual sand help output" -->
Supported v1 commands:

- Global: `sand --help`, `sand --version`
- Top-level commands: `sand doctor`, `sand create <name> [options]`, `sand ephemeral --from <spec.yaml> [-- <command> [args...]]`, `sand list`, `sand apply <name>`, `sand delete <name> [--force]`, `sand folders <action> ...`
- Sandbox-first actions: `sand <name> status`, `sand <name> start`, `sand <name> stop`, `sand <name> shell`, `sand <name> run <command> [args...]`, `sand <name> logs`, `sand <name> spec`

Command help:

```sh
sand --help
sand doctor --help
sand create --help
sand ephemeral --help
sand list --help
sand apply --help
sand delete --help
sand folders --help
sand demo --help
```

Folder actions:

```sh
sand folders add demo "$HOME/Projects/my-project" rw --as /workspace
sand folders add demo "$HOME/Reference" ro --as /reference
sand folders list demo
sand folders remove demo "$HOME/Reference"
```

Current v1 boundaries:

- To clear a Sandbox VM completely, delete it and create a new one.
- To run Pi, use the same command shape as any other tool: `sand <name> run pi [args...]`.
- Network access is outbound-only from the Sandbox VM in v1; inbound browser/server callbacks need the handoff flow described above.
- Commands name the target Sandbox VM explicitly, so it is always clear which environment you are operating.
- Failed Ephemeral Sandbox Runs report the failed phase and final exit code; delete failures include manual cleanup guidance for the generated Sandbox Name.
<!-- docs:managed:end -->

## Specs

Generated specs look like this:

```yaml
schemaVersion: 1
name: demo
image: sand/developer-ready:ubuntu-lts
resources:
  cpus: 4
  memory: 8GB
allowedFolders:
  []
```

Allowed folders are explicit:

```yaml
allowedFolders:
  - hostPath: ~/Projects/my-project
    resolvedHostPath: /Users/me/Projects/my-project
    guestPath: /workspace
    accessMode: read-write
```

v1 rejects unsupported spec fields for features outside the accepted scope, including inbound networking / port publishing.

## Notes on example verification

The command shapes in this README are aligned with `sand --help` and covered by CLI parser tests where practical. Examples that depend on machine-specific paths, an installed Apple `container` runtime, or a locally built image are illustrative until run on a prepared Host Mac.

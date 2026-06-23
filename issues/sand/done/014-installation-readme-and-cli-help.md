---
title: Add installation path, README, and CLI help for v1 Sandbox VM
status: needs-triage
type: issue
category: enhancement
labels:
  - needs-triage
  - sand
  - sandbox-vm
  - docs
  - installation
  - cli-help
created: 2026-05-19
---

## Parent

- `issues/sand/prd-sand-sandbox-vm.md`

## What to build

Make the accepted v1 Sandbox VM usable by someone starting from the repository. The product behavior is accepted, but v1 is not shippable until a user can understand what `sand` is, install it, verify prerequisites, run the first workflow, and discover supported commands from the CLI itself.

Bundle the docs and CLI discoverability work together so README examples and `sand --help` stay aligned with the actual v1 command surface.

## Acceptance criteria

- [x] Add a repository `README.md` that explains what `sand` is: a small isolated Linux computer backed by Apple `container`, with explicit Host Mac folder access and generic Workload Commands.
- [x] README states v1 scope and non-goals clearly.
- [x] README lists prerequisites, including supported macOS/Swift expectations, Apple `container`, and the developer-ready image.
- [x] README documents how to build and smoke-test the developer-ready image using the existing scripts.
- [x] README documents install from source, including a release build and putting the `sand` binary on `PATH`.
- [x] Add an install path that is easy to run from the repo, such as a `Makefile` target or script with configurable prefix, e.g. `PREFIX=$HOME/.local make install`.
- [x] Add uninstall instructions or an uninstall target.
- [x] README documents `sand doctor` as the first verification command after install.
- [x] README includes a quickstart that covers the accepted daily workflow:
  - create a Sandbox VM
  - inspect list/status/spec
  - add a read-write Allowed Folder
  - add a read-only Allowed Folder
  - run a Workload Command from a mapped Host Mac cwd
  - open a shell session
  - stop/start and verify persistence expectation
  - view logs
  - delete the Sandbox VM
- [x] README documents the active v1 command surface and examples for each supported command.
- [x] README documents v1 limitations/out-of-scope features: reset command, Pi shortcut command, inbound networking config, editor integration, shell completion, default/project-local implicit sandbox selection, host `~/.pi` mount, host credential forwarding, and non-Apple backend fallback.
- [x] `sand --help` prints concise top-level usage, supported commands, and points to `sand <command> --help` where relevant.
- [x] `sand --version` prints a stable product version or clearly documented development version.
- [x] Supported command groups expose useful help without mutating state:
  - `sand create --help`
  - `sand delete --help`
  - `sand apply --help`
  - `sand folders --help`
  - `sand <name> --help` or equivalent sandbox-action help
- [x] Unsupported/out-of-scope commands still fail clearly and are not accidentally introduced while adding help.
- [x] README examples are manually checked against the real CLI where practical, or any unchecked examples are explicitly marked as illustrative.
- [x] `swift test` passes.
- [x] Installation/help evidence is recorded in this issue or a linked evidence file.

## Definition of Done

- [x] A new user can clone the repo, follow README install instructions, run `sand doctor`, and understand the v1 workflow without reading source code.
- [x] CLI help and README describe the same command surface.
- [x] Install/uninstall paths do not require hidden machine-specific assumptions.
- [x] No fake/in-memory backend becomes selectable through install, help, flags, environment variables, or hidden fallback behavior.
- [x] CLI command handlers still do not call Apple `container` directly; backend interaction remains behind the Apple backend adapter boundary.
- [x] `swift test` passes.

## Evidence

Implemented in:

- `README.md`
- `Makefile`
- `Sources/SandCore/CLI/CLICommandRouter.swift`
- `Tests/SandCoreTests/CLICommandRouterTests.swift`

Verification run on 2026-05-19:

```sh
swift test
# passed: 79 tests, 0 failures

tmp=$(mktemp -d)
PREFIX="$tmp" make install
"$tmp/bin/sand" --version
"$tmp/bin/sand" --help
"$tmp/bin/sand" create --help
"$tmp/bin/sand" delete --help
"$tmp/bin/sand" apply --help
"$tmp/bin/sand" folders --help
"$tmp/bin/sand" demo --help
PREFIX="$tmp" make uninstall
test ! -e "$tmp/bin/sand"
rm -rf "$tmp"
```

Observed version/help output included:

```text
sand 0.1.0-dev
Usage: sand <command> [options]
Usage: sand create <name> [--image <image>] [--cpus <count>] [--memory <size>] [--from <spec.yaml>]
Usage: sand delete <name> [--force]
Usage: sand apply <name>
Usage: sand folders <action> ...
Usage: sand <name> <action> [arguments]
```

## Blocked by

- `issues/sand/013-final-v1-acceptance-pass.md`

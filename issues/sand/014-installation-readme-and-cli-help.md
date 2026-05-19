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

- [ ] Add a repository `README.md` that explains what `sand` is: a small isolated Linux computer backed by Apple `container`, with explicit Host Mac folder access and generic Workload Commands.
- [ ] README states v1 scope and non-goals clearly.
- [ ] README lists prerequisites, including supported macOS/Swift expectations, Apple `container`, and the developer-ready image.
- [ ] README documents how to build and smoke-test the developer-ready image using the existing scripts.
- [ ] README documents install from source, including a release build and putting the `sand` binary on `PATH`.
- [ ] Add an install path that is easy to run from the repo, such as a `Makefile` target or script with configurable prefix, e.g. `PREFIX=$HOME/.local make install`.
- [ ] Add uninstall instructions or an uninstall target.
- [ ] README documents `sand doctor` as the first verification command after install.
- [ ] README includes a quickstart that covers the accepted daily workflow:
  - create a Sandbox VM
  - inspect list/status/spec
  - add a read-write Allowed Folder
  - add a read-only Allowed Folder
  - run a Workload Command from a mapped Host Mac cwd
  - open a shell session
  - stop/start and verify persistence expectation
  - view logs
  - delete the Sandbox VM
- [ ] README documents the active v1 command surface and examples for each supported command.
- [ ] README documents v1 limitations/out-of-scope features: reset command, Pi shortcut command, inbound networking config, editor integration, shell completion, default/project-local implicit sandbox selection, host `~/.pi` mount, host credential forwarding, and non-Apple backend fallback.
- [ ] `sand --help` prints concise top-level usage, supported commands, and points to `sand <command> --help` where relevant.
- [ ] `sand --version` prints a stable product version or clearly documented development version.
- [ ] Supported command groups expose useful help without mutating state:
  - `sand create --help`
  - `sand delete --help`
  - `sand apply --help`
  - `sand folders --help`
  - `sand <name> --help` or equivalent sandbox-action help
- [ ] Unsupported/out-of-scope commands still fail clearly and are not accidentally introduced while adding help.
- [ ] README examples are manually checked against the real CLI where practical, or any unchecked examples are explicitly marked as illustrative.
- [ ] `swift test` passes.
- [ ] Installation/help evidence is recorded in this issue or a linked evidence file.

## Definition of Done

- [ ] A new user can clone the repo, follow README install instructions, run `sand doctor`, and understand the v1 workflow without reading source code.
- [ ] CLI help and README describe the same command surface.
- [ ] Install/uninstall paths do not require hidden machine-specific assumptions.
- [ ] No fake/in-memory backend becomes selectable through install, help, flags, environment variables, or hidden fallback behavior.
- [ ] CLI command handlers still do not call Apple `container` directly; backend interaction remains behind the Apple backend adapter boundary.
- [ ] `swift test` passes.

## Blocked by

- `issues/sand/013-final-v1-acceptance-pass.md`

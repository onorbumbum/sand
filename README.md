# sand

<!-- section-managed-doc: true -->
<!-- managed-sections: build-and-test, install-from-source, quickstart, command-surface-summary -->
<!-- docs-input-hash: fcb2d9220f229525556adcd44c2a84f009cfd04ed10e610d13379103b3affd70 -->

`sand` creates and manages small isolated Linux computers on an Apple silicon Host Mac. Each Sandbox VM is backed by Apple `container`, has its own Guest State, and only sees Host Mac folders that you explicitly allow. Work is run with generic Workload Commands: `sand <name> run <command> [args...]`.

## v1 scope

v1 is intentionally small:

- create, list, inspect, start, stop, apply, log, and delete Sandbox VMs
- map explicit Host Mac folders as read-write or read-only Guest Paths
- run arbitrary Workload Commands inside a Sandbox VM from a mapped Host Mac current working directory
- open an interactive shell inside a Sandbox VM
- keep guest state under `/state/sandbox` across stop/start for the same Sandbox VM
- use the developer-ready Linux image as the default image

## Documentation

Start with the generated guides when onboarding humans or agents:

- [`docs/onboarding.md`](docs/onboarding.md) explains the repo map, first files to read, and local verification flow.
- [`docs/cli-reference.md`](docs/cli-reference.md) is generated from current `sand` help output and is the detailed command reference.
- [`docs/developer-guide.md`](docs/developer-guide.md) covers architecture, testing strategy, and the documentation update workflow.

This README is section-managed: the product positioning and narrative stay hand-authored, while marked **Managed Sections** are refreshed through the Documentation Refresh Workflow so examples stay aligned with the current command surface.

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
- Top-level commands: `sand doctor`, `sand create <name> [options]`, `sand list`, `sand apply <name>`, `sand delete <name> [--force]`, `sand folders <action> ...`
- Sandbox-first actions: `sand <name> status`, `sand <name> start`, `sand <name> stop`, `sand <name> shell`, `sand <name> run <command> [args...]`, `sand <name> logs`, `sand <name> spec`

Command help:

```sh
sand --help
sand doctor --help
sand create --help
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

Known v1 non-goals:

- No `sand reset` command. Use explicit delete plus create for destructive reset flows.
- No Pi-specific shortcut such as `sand <name> pi`. Run Pi as a normal **Workload Command** with `sand <name> run pi [args...]`.
- No inbound networking or port publishing options such as `--inbound`, `--port`, or `--publish`.
- No default Sandbox VM or project-local implicit Sandbox VM selection. Commands name the Sandbox VM explicitly.
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

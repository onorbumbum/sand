# sand

`sand` creates and manages small isolated Linux computers on an Apple silicon Host Mac. Each Sandbox VM is backed by Apple `container`, has its own guest state, and only sees Host Mac folders that you explicitly allow. Work is run with generic Workload Commands: `sand <name> run <command> [args...]`.

## v1 scope

v1 is intentionally small:

- create, list, inspect, start, stop, apply, log, and delete Sandbox VMs
- map explicit Host Mac folders as read-write or read-only guest paths
- run arbitrary Workload Commands inside a Sandbox VM from a mapped Host Mac current working directory
- open an interactive shell inside a Sandbox VM
- keep guest state under `/state/sandbox` across stop/start for the same Sandbox VM
- use the developer-ready Linux image as the default image

## Known issues / TODO

- `sand delete <name>` is not fully idempotent yet. If Apple `container` removes the runtime but fails while deleting the persistent state volume, host metadata can remain in `~/.sand`; a later delete may report the runtime as missing instead of completing metadata cleanup. Fix: make delete tolerate already-missing runtime/volume during cleanup, then remove host metadata when cleanup is complete.

## Prerequisites

- Apple silicon Mac.
- Swift toolchain compatible with this package (`Package.swift` uses Swift tools 6.2 and declares macOS v26).
- Apple `container` CLI installed and available on `PATH`.
- Apple `container` backend service running or startable by `container system start`.
- The developer-ready image built locally: `sand/developer-ready:ubuntu-lts`.

## Build and smoke-test the developer-ready image

```sh
scripts/build-developer-ready-image.sh
scripts/smoke-developer-ready-image.sh
```

Optional environment variables:

```sh
SAND_DEVELOPER_READY_IMAGE=sand/developer-ready:ubuntu-lts scripts/build-developer-ready-image.sh
PI_CLI_VERSION=0.73.1 scripts/build-developer-ready-image.sh
```

## Install from source

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

## Quickstart

The paths below are illustrative. Replace them with real folders on your Host Mac.

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

# 7. Open a shell session.
sand demo shell

# 8. Stop/start and verify guest-state persistence.
sand demo run bash -lc 'echo persisted > /state/sandbox/persistence-check'
sand demo stop
sand demo start
sand demo run cat /state/sandbox/persistence-check

# 9. View logs.
sand demo logs

# 10. Delete the Sandbox VM.
sand delete demo --force
```

Persistence expectation: allowed Host Mac folder contents persist because they are host files. Guest state written under `/state/sandbox` persists across `sand <name> stop` and `sand <name> start` for the same Sandbox VM. Deleting the Sandbox VM removes its guest state volume and host metadata spec.

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

### `sand --help`

Prints top-level usage, supported commands, and where to find command help.

```sh
sand --help
```

### `sand --version`

Prints the product version. Development builds currently print a documented development version such as `sand 0.1.0-dev`.

```sh
sand --version
```

### `sand doctor`

Checks host support, Apple `container` readiness, default image availability, and `~/.sand` writability.

```sh
sand doctor
sand doctor --help
```

### `sand create`

Create from defaults:

```sh
sand create demo
sand create demo --cpus 6 --memory 12GB --image sand/developer-ready:ubuntu-lts
```

Create from a spec file:

```sh
sand create demo --from spec.yaml
sand create --from spec.yaml
```

Help:

```sh
sand create --help
```

### `sand list`

```sh
sand list
sand list --help
```

### `sand apply`

Apply allowed spec changes. Resource CPU and memory changes are immutable after creation.

```sh
sand apply demo
sand apply --help
```

### `sand delete`

```sh
sand delete demo
sand delete demo --force
sand delete --help
```

### `sand folders`

Add, list, or remove explicit Host Mac folder access.

```sh
sand folders add demo "$HOME/Projects/my-project" rw --as /workspace
sand folders add demo "$HOME/Reference" ro --as /reference
sand folders list demo
sand folders remove demo "$HOME/Reference"
sand folders --help
```

Access modes:

- `rw` / `read-write`
- `ro` / `read-only`

### Sandbox actions: `sand <name> <action>`

```sh
sand demo status
sand demo start
sand demo stop
sand demo shell
sand demo run echo hello
sand demo run bash -lc 'python3 --version && node --version'
sand demo logs
sand demo spec
sand demo --help
```

`run` treats everything after `run` as an opaque Workload Command. There is no special handling for `pi` or any other command name.

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

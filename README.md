# sand

<!-- section-managed-doc: true -->
<!-- managed-sections: build-and-test, install-from-source, quickstart, command-surface-summary -->
<!-- docs-input-hash: 7f022acc9b4aae7476723c6e67756f13766d6e726a6bf6d42ea9406620b1053b -->

> A safer place to run Pi and other developer tools.

`sand` creates small, named Linux or macOS Sandbox VMs on your Apple silicon Mac. Each environment feels like a little computer: it has its own files, tools, shell state, and login state, but it can only see the Mac folders you choose to share with it.

## Why sand exists

Modern coding agents and developer CLIs are powerful because they can read code, run commands, install packages, and keep working state. That same power is risky when the tool runs directly in your everyday Mac shell, where your home directory, credentials, dotfiles, project history, and local machine state are all nearby.

`sand` gives those tools a dedicated workspace. Pi can still work like a capable coding assistant, but the boundary is easier to understand: the Sandbox VM gets its own guest world, and your Mac only exposes the folders you explicitly allow.

For the longer write-up on why I built it, read [Sand — simple VMs for Mac](https://onuruzunismail.com/blog/sand.html).

## Project status

`sand` is experimental alpha software, released under the [Apache License 2.0](LICENSE). It is provided as-is, without a support guarantee or response SLA.

Public GitHub issues are welcome for bugs, questions, and feature ideas. Please report security vulnerabilities through GitHub private vulnerability reporting, not public issues. External pull requests are not accepted yet.

## The problem it solves

`sand` helps answer a practical question:

> “How do I let a powerful tool work on this project without giving it my whole computer?”

It does that by making three things explicit:

1. **Where work runs** — inside a named Sandbox VM, not directly in your normal shell.
2. **What the sandbox can see** — only the Shared Folders you add.
3. **What persists** — guest tools, package caches, shell config, Pi identity, and other sandbox-local state survive normal stop/start.

## How it works

| Everyday idea | In `sand` |
| --- | --- |
| “Make me a little Linux computer for this work.” | `sand create demo` |
| “Let it work on this project.” | `sand folders add demo ~/Projects/my-project rw --as /workspace` |
| “Let it read these references, but not edit them.” | `sand folders add demo ~/Reference ro --as /reference` |
| “Run Pi in the sandbox.” | `sand run demo pi` |
| “Open a shell in the sandbox.” | `sand shell demo` |
| “Pause it without losing its setup.” | `sand stop demo` |
| “Remove it when I am done.” | `sand delete demo` |

## Current alpha scope

This alpha is intentionally focused on the daily loop:

- create, list, inspect, start, stop, apply, log, and delete Sandbox VMs
- add Host Mac folders as read-write or read-only Guest Paths
- run Pi or any other command inside the Sandbox VM with `sand run <name> <command> [args...]`
- start commands in the matching Guest Path when your Mac current directory is inside an Allowed Folder
- open an interactive Sandbox Session with `sand shell <name>`
- keep Guest State under `/state/sandbox` across stop/start for the same Sandbox VM
- use the Developer-Ready Sandbox image with common development tools already installed
- create macOS Sandbox VMs through Tart for Xcode/iOS work
- open macOS GUI Sessions with `sand gui <name>`
- install macOS Signing Credentials as Guest Secrets for headless distribution signing

## Current boundaries

In this version, access is intentionally simple: choose folders, run commands, keep guest state. Host credentials and Host Mac Pi config are not shared automatically. macOS Signing Credentials are injected into the Sandbox Guest keychain as Guest Secrets; the Host Mac keychain is not mounted or shared. Simulator builds do not need signing or Apple ID. Physical-device deploy/debug is unsupported because macOS guests do not get USB passthrough; `gui` gives desktop access to the VM, not a forwarded host device. Inbound port publishing is not part of the first release, so browser callback logins need the handoff flow described below.

## More docs

- [`docs/cli-reference.md`](docs/cli-reference.md) lists every command and option.
- [`docs/onboarding.md`](docs/onboarding.md) maps the repository for contributors.
- [`docs/developer-guide.md`](docs/developer-guide.md) explains the architecture, tests, and release checks.

## Delete cleanup behavior

`sand delete <name>` removes the disposable Runtime Instance, Guest State volume, and Host Metadata. Cleanup tolerates already-missing backend resources, so rerunning delete can finish Host Metadata cleanup after a partially completed backend delete.

## Prerequisites

- Apple silicon Mac.
- Swift toolchain compatible with this package (`Package.swift` uses Swift tools 6.2 and declares macOS v26).
- Apple `container` CLI installed and available on `PATH` for Linux Sandbox VMs.
- Apple `container` backend service running or startable by `container system start` for Linux Sandbox VMs.
- Tart CLI installed and available on `PATH` for macOS Sandbox VMs.
- The developer-ready image built locally: `sand/developer-ready:ubuntu-lts`.

## Getting started

From a cloned checkout:

```sh
PREFIX=$HOME/.local make install
export PATH="$HOME/.local/bin:$PATH"
sand doctor
```

Create a Linux Sandbox VM for regular coding-agent work:

```sh
sand create demo
sand folders add demo "$HOME/Projects/my-project" rw --as /workspace
cd "$HOME/Projects/my-project"
sand run demo pwd
sand shell demo
```

Create a lightweight macOS Sandbox VM for shell, GUI, and Shared Folder checks:

```sh
brew install cirruslabs/cli/tart
sand create macbase --os macos --from ghcr.io/cirruslabs/macos-sequoia-base:latest
mkdir -p ~/sand-macos-test
echo "hello from host" > ~/sand-macos-test/from-host.txt
sand folders add macbase ~/sand-macos-test rw --as /workspace
sand run macbase /bin/zsh -lc 'cat /workspace/from-host.txt && echo "hello from guest" > /workspace/from-guest.txt'
cat ~/sand-macos-test/from-guest.txt
```

Create an Xcode-ready macOS Sandbox VM when you need iOS Simulator builds or distribution signing:

```sh
sand create iosbox --os macos --from ghcr.io/cirruslabs/macos-sequoia-xcode:latest
sand run iosbox /usr/bin/xcodebuild -version
```

Build a macOS VM from an Apple IPSW only when you want your own fresh base image:

```sh
sand create cleanmac --os macos --from-ipsw latest
sand gui cleanmac
sand bootstrap cleanmac
```

`bootstrap` is only for the IPSW path. The first GUI boot creates the macOS user and enables the basics; `sand bootstrap` then installs sand's SSH key and finishes the guest setup so `sand shell` and `sand run` work without passwords. Cloned Tart registry images such as `macos-sequoia-base` and `macos-sequoia-xcode` are already ready for normal `sand` commands.

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
sand status demo
sand spec demo

# 4. Allow a Host Mac project folder read-write at /workspace.
sand folders add demo "$HOME/Projects/my-project" rw --as /workspace

# 5. Allow a Host Mac reference folder read-only at /reference.
sand folders add demo "$HOME/Reference" ro --as /reference
sand folders list demo

# 6. Run Workload Commands from a mapped Host Mac current working directory.
cd "$HOME/Projects/my-project"
sand run demo pwd
sand run demo bash -lc 'echo hello-from-sand > sand-smoke.txt && ls -la'

# 7. Open a Sandbox Session.
sand shell demo

# 8. Stop/start and verify Guest State persistence.
sand run demo bash -lc 'echo persisted > /state/sandbox/persistence-check'
sand stop demo
sand start demo
sand run demo cat /state/sandbox/persistence-check

# 9. View logs.
sand logs demo

# 10. Delete the Sandbox VM.
sand delete demo --force
```
<!-- docs:managed:end -->

Persistence expectation: Allowed Folder contents persist because they are host files. Guest State written under `/state/sandbox` persists across `sand stop <name>` and `sand start <name>` for the same Sandbox VM. Deleting the Sandbox VM removes its Guest State volume and Host Metadata spec.

## Subscription and OAuth logins inside a Sandbox VM

Some CLI tools, including Pi/OpenAI-style subscription logins, start a temporary callback server on `localhost` during login. In `sand` v1, `localhost` in your Host Mac browser is **not** the Sandbox Guest's `localhost`, and v1 does not publish inbound guest ports to the Host Mac.

Use a two-terminal callback handoff instead.

Terminal A: start the login and leave it running:

```sh
sand run demo pi login
```

Open the authorization URL in your Host Mac browser. After approval, the browser may try to load a URL like this and fail:

```text
http://localhost:1455/auth/callback?code=...&scope=...&state=...
```

That failure is expected. Copy the full callback URL from the browser address bar.

Terminal B: send that exact callback URL to the Sandbox Guest while Terminal A is still waiting:

```sh
sand run demo curl -sS 'http://localhost:1455/auth/callback?code=...&scope=...&state=...'
```

Quote the URL so shell `&` characters are not interpreted. The callback URL is usually short-lived and tied to the still-running login process, so rerun the login if Terminal A exited or the code expired.

The resulting identity and tokens live in the Sandbox VM's Guest State. `sand` does not mount your Host Mac `~/.pi` or forward host credentials by default.

## CLI command surface

For the complete generated reference, see [`docs/cli-reference.md`](docs/cli-reference.md).

<!-- docs:managed:start id="command-surface-summary" source="docs/cli-reference.md and actual sand help output" -->
Supported v1 commands:

- Global: `sand --help`, `sand --version`
- Top-level commands: `sand doctor`, `sand create <name> [options]`, `sand bootstrap <name>`, `sand list`, `sand apply <name>`, `sand delete <name> [--force]`, `sand folders <action> ...`, `sand signing <action> ...`
- Sandbox actions: `sand status <name>`, `sand start <name>`, `sand stop <name>`, `sand shell <name>`, `sand run <name> <command> [args...]`, `sand gui <name>`, `sand logs <name>`, `sand spec <name>`

Command help:

```sh
sand --help
sand doctor --help
sand create --help
sand list --help
sand apply --help
sand bootstrap --help
sand delete --help
sand folders --help
```

Folder actions:

```sh
sand folders add demo "$HOME/Projects/my-project" rw --as /workspace
sand folders add demo "$HOME/Reference" ro --as /reference
sand folders list demo
sand folders remove demo "$HOME/Reference"
```

macOS Sandbox VMs use a split-backend architecture: Linux guests run through Apple's `container` CLI, while macOS guests run through Tart. Both backends stay behind the same Sandbox Backend interface, so `shell`, `run`, Shared Folders, Working Directory Mapping, Guest State, and Sandbox Specs keep one user-facing model.

macOS support needs the Tart CLI on `PATH`:

```sh
brew install cirruslabs/cli/tart
sand doctor
```

`sand` itself stays unsigned and entitlement-free; Tart carries the Virtualization Framework entitlement.

macOS sources are explicit and open-ended. Choose the smallest image that fits the job:

```sh
# Lightweight macOS base, no Xcode: shell, GUI, and Shared Folders.
sand create macbase --os macos --from ghcr.io/cirruslabs/macos-sequoia-base:latest

# Xcode-ready macOS image. Use this for iOS Simulator builds or distribution signing tests.
sand create iosbox --os macos --from ghcr.io/cirruslabs/macos-sequoia-xcode:latest

# Size the macOS VM disk at create time. Disk Size is macOS-only and grow-only for clones.
sand create iosbig --os macos --disk 150GB --from ghcr.io/cirruslabs/macos-sequoia-base:latest

# Or build a self-made macOS base from an IPSW.
# First boot happens in the GUI; bootstrap then enables normal sand shell/run access.
sand create cleanmac --os macos --from-ipsw latest
sand gui cleanmac
sand bootstrap cleanmac
```

Shared Folder check for the lightweight base image:

```sh
mkdir -p ~/sand-macos-test
echo "hello from host" > ~/sand-macos-test/from-host.txt
sand folders add macbase ~/sand-macos-test rw --as /workspace
sand run macbase /bin/zsh -lc 'ls -la /workspace && cat /workspace/from-host.txt && echo "hello from guest" > /workspace/from-guest.txt'
cat ~/sand-macos-test/from-guest.txt
```

macOS Shared Folders use the same chosen Guest Path as Linux. Tart mounts at macOS's fixed `/Volumes/My Shared Files/<tag>` location, and `sand` hides that backend detail behind a guest-side symlink. `sand gui <name>` opens the VM desktop through Tart VNC and Host Mac Screen Sharing.

macOS signing:

```sh
sand create iosbox --os macos --from ghcr.io/cirruslabs/macos-sequoia-xcode:latest
# Read passwords from environment variables so they never land in shell history or the process list.
export P12_PASSWORD=... KEYCHAIN_PASSWORD=...
sand signing install iosbox --certificate "$HOME/Secrets/dist.p12" --certificate-password-env P12_PASSWORD --profile "$HOME/Secrets/App.mobileprovision" --keychain-password-env KEYCHAIN_PASSWORD
# Unlock the signing keychain in the build session, then archive with manual signing.
sand run iosbox /bin/zsh -lc 'security unlock-keychain -p "'$KEYCHAIN_PASSWORD'" "$HOME/Library/Keychains/sand-signing.keychain-db" && xcodebuild -scheme App -configuration Release archive CODE_SIGN_STYLE=Manual'
```

> Headless signing needs the injected keychain unlocked in the same session as `xcodebuild`. Without the `security unlock-keychain` step, `codesign` fails with `errSecInternalComponent`. Distribution signing uses Manual signing (`CODE_SIGN_STYLE=Manual` with `DEVELOPMENT_TEAM`, `PROVISIONING_PROFILE_SPECIFIER`, and `CODE_SIGN_IDENTITY`).

Current v1 boundaries:

- To clear a Sandbox VM completely, delete it and create a new one.
- To run Pi, use the same command shape as any other tool: `sand run <name> pi [args...]`.
- Network access is outbound-only from the Sandbox VM in v1; inbound browser/server callbacks need the handoff flow described above.
- Commands name the target Sandbox VM explicitly, so it is always clear which environment you are operating.
- macOS Sandbox VMs are heavy: expect about 100GB per VM and slower boot than Linux Sandbox VMs.
- Apple's macOS guest licensing caps practical concurrent macOS Sandbox VMs at roughly two per Host Mac, so plan for a handful of macOS sandboxes, not dozens.
- Physical-device deploy/debug is unsupported because macOS guests do not get USB passthrough; `gui` shows the VM desktop, not a host-connected iPhone or iPad.
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
sharedFolders:
  []
```

Shared folders are explicit:

```yaml
sharedFolders:
  - hostPath: ~/Projects/my-project
    resolvedHostPath: /Users/me/Projects/my-project
    guestPath: /workspace
    accessMode: read-write
```

v1 rejects unsupported spec fields for features outside the accepted scope, including inbound networking / port publishing.


---
title: Build sand, a CLI-first Sandbox VM runner for Pi and developer workloads
status: needs-triage
type: prd
category: enhancement
labels:
  - needs-triage
  - enhancement
  - sand
  - sandbox-vm
  - swift
  - macos
  - pi
created: 2026-05-19
---

## Problem Statement

The user wants a safer, easier way to run Pi and related developer workloads without giving them broad access to the Host Mac. Today Pi runs directly in the user's normal shell, with access to the user's real home directory, shell environment, credentials, and machine state. That makes powerful coding-agent behavior convenient, but the isolation boundary is too weak: a mistake or overly broad command can touch anything the user's shell can touch.

The desired mental model is an isolated small Linux computer: a Sandbox VM that can have broad/root-level control inside its own Sandbox Guest, while seeing only the Host Mac folders explicitly shared by the user. The Sandbox VM should have persistent Guest State for installed tools, shell config, package caches, Pi identity, and Guest Secrets, but it must not inherit Host Mac credentials or Pi config by default.

This is an internal, Pi-first tool, but it should not become a Pi-specific launcher. The first API Surface should be a Swift CLI named `sand`. Running Pi should be as simple as running a Workload Command inside the sandbox, for example `sand mybox run pi [args...]`. The same primitive should support future internal harnesses such as `aslan-agent` without `sand` understanding their flags.

The solution must not become a shallow pile of Apple `container` command wrappers. It must follow Ousterhout-style deep module design: a small, stable, testable domain/spec layer and a deep Sandbox Backend that hides backend-specific details behind a shallow interface. The Apple `container` CLI is the preferred first backend only if a Backend Validation Spike proves it satisfies hard product requirements, especially persistent Guest State and Host-Safe File Ownership.

## Solution

Build `sand`, a CLI-first Swift tool for creating, configuring, applying, running, inspecting, and deleting Sandbox VMs on Apple silicon macOS.

Each Sandbox VM is defined by a declarative Sandbox Spec. The spec is the source of truth and is stored in Host Metadata under `~/.sand/`. The spec includes the Sandbox Name, Sandbox Image, Resource Profile, Shared Folders, Guest Paths, and Access Modes. It deliberately excludes unsupported future concerns such as inbound networking for v1. CLI mutation commands update the Sandbox Spec and auto-apply by default. Manual spec edits can be reconciled with `sand apply <name>`.

The default Sandbox VM is a Developer-Ready Sandbox built from a prebuilt Sandbox Image based on Ubuntu LTS. It includes the Default Toolset: git, curl, ca-certificates, sudo, openssh-client, Python 3 with venv/pip, Node/npm, tmux, ripgrep, build-essential, and the Pi CLI. The default Resource Profile is 4 CPUs and 8GB RAM with create-time overrides only. `sand create` writes and applies the initial Sandbox Spec, provisions Guest State, and leaves the Sandbox VM stopped.

Daily use is sandbox-first and explicit:

- `sand <name> shell` opens an interactive Sandbox Session as the Sandbox User.
- `sand <name> run <command> [args...]` runs an opaque Workload Command inside the Sandbox VM.
- Daily commands auto-start the target Sandbox VM when stopped.
- Working Directory Mapping starts the session in the matching Guest Path when the Host Mac cwd is inside an Shared Folder; otherwise `sand` warns and starts in `/workspace` or the Sandbox User home.

The Sandbox Guest may allow broad/root-level control inside the VM through a non-root Sandbox User with passwordless sudo. That power must not escape to the Host Mac. The only Host Mac filesystem surface is the set of Shared Folders, each with an explicit read-only or read-write Access Mode. Read-write Shared Folders must preserve Host-Safe File Ownership: files created or modified from the Sandbox VM must remain editable and deletable by the Host Mac user without sudo.

V1 networking is Outbound-Only Networking. The Sandbox Guest may reach the internet for package installs, git, APIs, and Pi provider calls, but `sand` does not model inbound networking or port publishing in the first version.

The first Sandbox Backend shells out to Apple `container`, but only through a deep `SandboxBackend` module. If the Apple `container` CLI fails hard requirements during the Backend Validation Spike, the project evaluates direct Apple Containerization Swift APIs. If direct Containerization also fails, the project stops rather than silently switching to Docker, Lima, Colima, OrbStack, or hidden workaround designs.

## User Stories

1. As the user, I want to run Pi inside a Sandbox VM, so that Pi does not run directly in my Host Mac shell.
2. As the user, I want the Sandbox VM to feel like a small Linux computer, so that I can reason about it like a VM rather than a special agent launcher.
3. As the user, I want Pi to have broad control inside the Sandbox Guest, so that coding-agent workflows are not constantly blocked by guest permissions.
4. As the user, I want Pi's broad control inside the Sandbox Guest not to imply broad control over the Host Mac, so that the host boundary remains meaningful.
5. As the user, I want to choose which Host Mac folders are visible to the Sandbox VM, so that the sandbox sees only intentional workspaces.
6. As the user, I want each Shared Folder to have an explicit Access Mode, so that I can distinguish read-only reference material from read-write working folders.
7. As the user, I want read-write Shared Folders to preserve Host-Safe File Ownership, so that files created by Pi remain editable and deletable from macOS without sudo.
8. As the user, I want the Sandbox VM to have persistent Guest State, so that installed tools, shell config, package caches, Pi identity, and Guest Secrets survive stop/start.
9. As the user, I want Guest State to be separate from Host Metadata, so that `sand` management data and guest filesystem state do not blur together.
10. As the user, I want credentials used by the Sandbox VM to be Guest Secrets only in v1, so that host tokens and credential files are not mounted or forwarded by default.
11. As the user, I want Pi Identity to live in Guest State, so that sandboxed Pi behaves like it has its own computer.
12. As the user, I want the first API Surface to be a CLI, so that I can use the tool naturally from terminal workflows.
13. As the user, I want the CLI to be named `sand`, so that commands are short and memorable.
14. As the user, I want Sandbox Names to be global per user, so that I can use the same named Sandbox VM from any directory.
15. As the user, I want daily commands to be sandbox-first, so that `sand mybox shell` and `sand mybox run pi` read like operating a named computer.
16. As the user, I want no default or implicit project-local sandbox in v1, so that commands are explicit and unsurprising.
17. As the user, I want `sand create mybox` to create a stopped Sandbox VM, so that I can configure Shared Folders before first use.
18. As the user, I want `sand create mybox` to provision Guest State, so that the sandbox is real after creation rather than just a YAML file.
19. As the user, I want daily commands to auto-start a stopped Sandbox VM, so that running a Workload Command does not require a separate start step.
20. As the user, I want `sand mybox shell` to open an interactive shell without a username/password prompt, so that entering the sandbox is frictionless.
21. As the user, I want `sand mybox run pi [args...]` to execute Pi as a normal Workload Command, so that `sand` does not need to understand Pi flags.
22. As the user, I want `sand mybox run aslan-agent [args...]` or similar future commands to work the same way, so that `sand` is not hard-coded to only one harness.
23. As the user, I want `sand` to treat Workload Commands as opaque, so that command-specific behavior stays inside the workload.
24. As the user, I want no `sand mybox pi` shortcut in v1, so that the command surface stays generic and small.
25. As the user, I want the default Sandbox Image to include the Pi CLI, so that the primary internal workflow works without manual setup.
26. As the user, I want the default Sandbox Image to include common development tools, so that daily work can begin without raw Ubuntu bootstrapping.
27. As the user, I want the default Base Image to be Ubuntu LTS, so that developer tooling and package installation are predictable.
28. As the user, I want the default Resource Profile to be 4 CPUs and 8GB RAM, so that coding agents have enough room to work.
29. As the user, I want optional create-time CPU and memory overrides, so that I can create larger or smaller sandboxes when needed.
30. As the user, I do not want CPU and memory editing after create in v1, so that lifecycle complexity stays low.
31. As the user, I want a Sandbox Spec to define each Sandbox VM, so that configuration is inspectable and reproducible.
32. As the user, I want `sand create` to generate a Sandbox Spec by default, so that I do not have to hand-write YAML for the happy path.
33. As the user, I want `sand create --from` to support a user-authored spec, so that I can create a sandbox declaratively when useful.
34. As the user, I want `sand <name> spec` to print the active Sandbox Spec, so that I can inspect the source of truth.
35. As the user, I want editor integration omitted in v1, so that the command surface stays focused.
36. As the user, I want `sand apply <name>` to reconcile backend reality with the Sandbox Spec, so that manual spec edits and drift can be corrected.
37. As the user, I want runtime recreation to remain hidden/internal, so that I think in terms of applying specs rather than backend mechanics.
38. As the user, I want CLI configuration mutations to auto-apply by default, so that `sand folders add` actually makes the folder usable.
39. As the user, I want config changes to apply immediately when the Sandbox VM is stopped, so that offline edits are frictionless.
40. As the user, I want config changes that interrupt a running Sandbox VM to ask first, so that active Pi or shell sessions are not killed unexpectedly.
41. As the user, I want multiple Sandbox Sessions to run concurrently against the same Sandbox VM, so that I can use multiple terminals like a normal VM.
42. As the user, I want Lifecycle Mutations to be serialized, so that create/delete/apply/start/stop operations cannot corrupt Host Metadata or backend state.
43. As the user, I want `sand folders add mybox ~/Projects rw` to add a read-write Shared Folder, so that projects can be modified from inside the sandbox.
44. As the user, I want `sand folders add mybox ~/Downloads ro` to add a read-only Shared Folder, so that reference material can be visible without making it mutable.
45. As the user, I want `rw` and `ro` aliases accepted, so that daily folder commands are concise.
46. As the user, I want the Sandbox Spec to store canonical `read-write` and `read-only` values, so that declarative config stays readable.
47. As the user, I want default Guest Paths derived under `/workspace`, so that mounted folders have predictable locations inside the Sandbox VM.
48. As the user, I want an optional `--as` Guest Path override, so that I can choose a clearer path when the default is not right.
49. As the user, I want adding an existing host folder to update its Access Mode or Guest Path, so that folder commands are idempotent and scriptable.
50. As the user, I want duplicate Guest Paths rejected, so that one path inside the Sandbox VM never ambiguously refers to multiple host folders.
51. As the user, I want overlapping host folders rejected in v1, so that access rules and Working Directory Mapping remain unambiguous.
52. As the user, I want folder validation to resolve symlinks, so that duplicate and overlap checks cannot be bypassed by alternate paths.
53. As the user, I want `sand` to preserve display paths separately from resolved real paths, so that output stays human-friendly while validation stays safe.
54. As the user, I want `sand folders list mybox` to show host path, Guest Path, and Access Mode, so that I can audit what the Sandbox VM can see.
55. As the user, I want `sand folders remove mybox <host-path>` to remove an Shared Folder, so that I can narrow sandbox access.
56. As the user, I want a Sandbox VM to be creatable with no Shared Folders, so that I can create a pure isolated Linux environment when needed.
57. As the user, I want folder setup to be part of the coding-agent happy path, so that project and site workflows are easy.
58. As the user, I want Working Directory Mapping from Host Mac cwd to Guest Path, so that running `sand mybox run pi` from a mounted project starts Pi in the corresponding guest project path.
59. As the user, I want a warning when the host cwd is not inside an Shared Folder, so that I understand why the sandbox cannot see the current project.
60. As the user, I want commands from an unmapped cwd to start in `/workspace` or the Sandbox User home, so that the command still works when I did not intend a project context.
61. As the user, I want Outbound-Only Networking in v1, so that the sandbox can install packages and call APIs without exposing inbound services.
62. As the user, I want inbound port publishing out of scope for v1, so that networking remains simple and safe.
63. As the user, I want `sand list` to show concise Sandbox Status, so that I can see which sandboxes exist and whether they are running.
64. As the user, I want `sand mybox status` to show useful configuration and backend status, so that I can diagnose a specific Sandbox VM.
65. As the user, I want `sand mybox logs` to expose minimal runtime/backend logs, so that failed starts and applies can be debugged.
66. As the user, I want `sand doctor` to check prerequisites, so that I can quickly see whether Apple container, platform support, service status, image availability, and Host Metadata are healthy.
67. As the user, I want `sand` to auto-start the Apple container Backend Service when needed, so that I do not have to manage backend plumbing manually.
68. As the user, I want backend service failures reported clearly, so that I can fix real prerequisites rather than guess.
69. As the user, I want destructive deletion to prompt by default, so that I do not accidentally delete Guest State.
70. As the user, I want `sand delete mybox --force` to skip confirmation, so that scripts can intentionally delete sandboxes.
71. As the user, I want no separate reset command in v1, so that destructive lifecycle semantics remain simple: delete plus create.
72. As the user, I want `sand mybox start` and `sand mybox stop` to preserve Guest State, so that stop/start behaves like powering a VM off and on.
73. As the user, I want stop/start not to mean reset, so that installed tools and Pi config survive normal lifecycle operations.
74. As the user, I want `sand mybox run` to behave naturally for the current terminal, so that interactive commands and redirected commands both work without explicit TTY policy.
75. As the user, I want `sand mybox shell` to be interactive, so that shell access feels like entering a normal VM.
76. As the user, I want the Sandbox User to be non-root with passwordless sudo, so that daily files and tools run as a normal user while guest administration remains easy.
77. As the user, I want no guest username/password prompt, so that Sandbox Sessions feel instantaneous.
78. As the user, I want Host Mac `~/.pi` not mounted by default, so that the sandbox does not inherit host Pi identity or config.
79. As the user, I want host credential files not mounted by default, so that the security boundary is real.
80. As the user, I want skill sharing to be handled outside `sand` v1, so that `sand` does not become a Pi skill manager.
81. As the maintainer, I want `sand` implemented as a Swift CLI, so that it aligns with Apple-native tooling and can later use direct Containerization APIs if necessary.
82. As the maintainer, I want the Apple `container` CLI backend validated before full implementation, so that we do not build on an unproven assumption.
83. As the maintainer, I want Host-Safe File Ownership explicitly tested in the validation spike, so that the hardest filesystem requirement is proven early.
84. As the maintainer, I want persistent Guest State explicitly tested in the validation spike, so that stop/start and runtime recreation are not speculative.
85. As the maintainer, I want read-only and read-write Shared Folders tested in the validation spike, so that Access Mode behavior is real.
86. As the maintainer, I want interactive Sandbox Sessions tested in the validation spike, so that shell access is proven before CLI polish.
87. As the maintainer, I want concurrent sessions tested in the validation spike, so that the VM mental model holds.
88. As the maintainer, I want runtime recreation while preserving Guest State tested in the validation spike, so that `apply` can be implemented honestly.
89. As the maintainer, I want outbound networking tested in the validation spike, so that developer and Pi workflows can reach package registries and APIs.
90. As the maintainer, I want the default Sandbox Image build tested, so that the Developer-Ready Sandbox is reproducible.
91. As the maintainer, I want a deep Sandbox Backend module, so that backend details do not leak into CLI commands or the Sandbox Spec.
92. As the maintainer, I want the domain/spec layer tested with fake backends, so that most behavior is deterministic and fast.
93. As the maintainer, I want implementation to be test-first, so that design decisions are executable before backend work expands.
94. As the maintainer, I want no direct backend command calls spread through the CLI layer, so that future backend replacement is possible.
95. As the maintainer, I want no display-layer hacks for failed hard requirements, so that the tool does not hide broken isolation or ownership semantics.
96. As the maintainer, I want direct Apple Containerization APIs evaluated only if the Apple `container` CLI fails, so that we avoid premature low-level integration.
97. As the maintainer, I want the project to stop if direct Containerization also fails, so that we do not silently switch to non-Apple backends against the design decision.
98. As the maintainer, I want the command surface to stay small in v1, so that the product can reach a working vertical slice quickly.
99. As the maintainer, I want no desktop UI in v1, so that the CLI and backend model are proven before presentation work.
100. As the maintainer, I want future desktop UI to wrap the same underlying model, so that UI does not create a second source of truth.
101. As the maintainer, I want the Sandbox Spec to exclude future placeholders like inbound networking, so that v1 config reflects real supported behavior.
102. As the maintainer, I want `sand` to fail clearly when a selected Sandbox Image lacks a requested Workload Command, so that workload installation remains explicit.
103. As the maintainer, I want small focused commits through the validation and domain layers, so that the build remains green and progress is reviewable.
104. As the maintainer, I want CI-friendly deterministic tests for the core domain, so that changes do not require a live Apple container environment for every behavior check.
105. As the maintainer, I want live/manual backend tests recorded for backend-dependent acceptance, so that hard requirements are not certified by mocks.

## Implementation Decisions

- Build `sand` as a Swift CLI.
- The product concept is **Sandbox VM**, not Pi Sandbox, Docker container, or generic container manager.
- The tool is internal and Pi-first, but Workload Commands remain generic and opaque.
- The first command surface is CLI-first; any desktop UI is out of scope for v1 and should later wrap the same model.
- Daily CLI syntax is sandbox-first and explicit: `sand <sandbox-name> <action>`.
- There is no default sandbox or project-local implicit sandbox selection in v1.
- Sandbox Names are globally unique per Host Mac user.
- `sand` stores Host Metadata under `~/.sand/`.
- Each Sandbox VM is defined by a declarative Sandbox Spec.
- The Sandbox Spec is the source of truth for name, image, Resource Profile, Shared Folders, Guest Paths, and Access Modes.
- The Sandbox Spec excludes inbound networking and other unsupported future placeholders in v1.
- `sand create` generates a Sandbox Spec by default.
- `sand create --from` supports user-authored specs.
- `sand create` writes and applies the initial Sandbox Spec, provisions Guest State, and leaves the Sandbox VM stopped.
- `sand <sandbox-name> spec` prints the active Sandbox Spec.
- Editor integration for specs is omitted in v1.
- `sand apply <sandbox-name>` is the user-facing declarative reconciliation command.
- Runtime recreation remains hidden/internal and is used only when required by Apply or config mutation.
- CLI configuration mutations update the Sandbox Spec and auto-apply by default.
- Configuration changes that require runtime recreation apply immediately when stopped and ask before interrupting a running Sandbox VM.
- Lifecycle Mutations are serialized.
- Normal Sandbox Sessions and Workload Commands may run concurrently.
- The first v1 command surface is:
  - `sand doctor`
  - `sand create <name> [--from spec.yaml] [--cpus n] [--memory size] [--image image]`
  - `sand list`
  - `sand apply <name>`
  - `sand delete <name> [--force]`
  - `sand <name> status`
  - `sand <name> start`
  - `sand <name> stop`
  - `sand <name> shell`
  - `sand <name> run <command> [args...]`
  - `sand <name> logs`
  - `sand <name> spec`
  - `sand folders add <name> <host-path> <rw|ro|read-write|read-only> [--as <guest-path>]`
  - `sand folders list <name>`
  - `sand folders remove <name> <host-path>`
- `sand` provides no Pi-specific shortcut command in v1.
- A Pi Workload is invoked through the generic run action.
- `sand` does not parse or understand Workload Command flags.
- `shell` is interactive.
- `run` behaves naturally for the current terminal; explicit TTY policy/options are avoided in v1.
- Daily commands auto-start the target Sandbox VM when stopped.
- Stop/start preserve Guest State.
- A separate reset command is omitted in v1; delete plus create is the explicit destructive flow.
- Destructive deletion prompts by default and requires a force option to skip confirmation.
- `sand list` and `sand <name> status` show Sandbox Status rather than raw backend dumps.
- `sand doctor` verifies Apple container availability, service status, Apple silicon/macOS support, default image availability, and Host Metadata writability.
- `sand <name> logs` exposes minimal runtime/backend logs for debugging.
- `sand` auto-starts the Apple container Backend Service when needed and reports failures clearly.
- The default Base Image is Ubuntu LTS.
- The default Sandbox Image is a Developer-Ready Sandbox image that includes the Default Toolset.
- The Default Toolset includes git, curl, ca-certificates, sudo, openssh-client, Python 3 with venv/pip, Node/npm, tmux, ripgrep, build-essential, and the Pi CLI.
- The default Resource Profile is 4 CPUs and 8GB RAM.
- CPU and memory may be overridden at create time only in v1.
- Daily Sandbox Sessions run as a non-root Sandbox User.
- The Sandbox User has passwordless sudo.
- Sandbox Sessions must not prompt for guest username or password.
- Pi Identity lives in Guest State by default, not in the Host Mac's Pi configuration.
- Credentials used by the Sandbox VM are Guest Secrets only in v1.
- Host credential files and host `~/.pi` are not mounted by default.
- Skill Source management is out of scope for v1.
- Shared Folders are the only Host Mac filesystem surface exposed to the Sandbox VM.
- Each Shared Folder has an Access Mode and a Guest Path.
- Access Mode inputs accept `rw`, `ro`, `read-write`, and `read-only`.
- The Sandbox Spec stores canonical `read-write` and `read-only` terms.
- Guest Paths default to a workspace path derived from the host folder name.
- `--as` allows explicit Guest Path override.
- Adding an existing host folder updates its Access Mode or Guest Path rather than duplicating it.
- Two different Shared Folders cannot share the same Guest Path.
- Overlapping host folders are rejected in v1.
- Folder validation and Working Directory Mapping use resolved real paths while preserving display paths for user output.
- Read-write Shared Folders must preserve Host-Safe File Ownership.
- A Sandbox VM may be created with no Shared Folders.
- Working Directory Mapping starts sessions in the matching Guest Path when the host cwd is inside an Shared Folder.
- If the host cwd is not inside an Shared Folder, `sand` warns and starts in `/workspace` or the Sandbox User home.
- V1 uses Outbound-Only Networking.
- Inbound port publishing is out of scope for v1.
- The first Sandbox Backend shells out to Apple `container`.
- Backend details must not leak into the API Surface or Sandbox Spec.
- Apple `container` CLI is acceptable only after a Backend Validation Spike passes.
- If Apple `container` CLI fails hard requirements, evaluate direct Apple Containerization Swift APIs.
- If direct Apple Containerization also fails, stop rather than falling through to non-Apple backends.
- No Docker, Lima, Colima, OrbStack, hidden rsync, chmod-after-every-run, or display-layer workaround is accepted without an explicit new decision.
- Respect ADR-0001: Apple `container` first, direct Containerization second, stop before non-Apple backends.
- Respect ADR-0002: Sandbox Spec is the source of truth.
- Respect ADR-0003: backend integration stays behind a deep SandboxBackend module.

Major modules to build:

- CLI Command Router: parses `sand` commands, maps them to domain operations, handles user-facing output, and does not call backend commands directly.
- Sandbox Spec Model: owns the declarative schema, defaults, canonical terms, parsing, rendering, and validation.
- Host Metadata Store: owns reading/writing active Sandbox Specs, backend IDs, schema version, and metadata locking under `~/.sand/`.
- Folder Policy Module: owns Shared Folder normalization, Access Mode normalization, Guest Path derivation, duplicate checks, overlap checks, realpath validation, and removal behavior.
- Working Directory Mapper: maps Host Mac cwd to Guest Path or returns the warning/default start location.
- Lifecycle Coordinator: owns create, apply, start, stop, delete flows, auto-start behavior, interruption prompts, and lifecycle mutation serialization.
- SandboxBackend Protocol: exposes backend readiness, provisioning, applying specs, lifecycle, command execution, status, logs, and deletion through a shallow domain-shaped interface.
- Apple Container CLI Backend: hides all Apple `container` command invocation, output parsing, volume/runtime naming, service start, and backend-specific error translation.
- Sandbox Image Builder/Definition: owns the default Developer-Ready Sandbox image definition and build/publish mechanics.
- Doctor Check Module: owns prerequisite checks and diagnostic reporting.
- Sandbox Status Presenter: converts domain/backend status into concise list/status output without dumping raw backend structures.
- Prompt/Confirmation Module: owns destructive delete confirmation and running-config-change interruption prompts.
- Backend Validation Spike Harness: proves hard backend requirements with live/manual checks before full backend commitment.

Deep module opportunities:

- Sandbox Spec Model should be a deep module with a small parse/validate/render/defaults interface while hiding YAML shape and normalization details.
- Folder Policy should be a deep module with a small add/list/remove/validate interface while hiding symlink resolution, overlap rules, mode normalization, and guest path rules.
- Working Directory Mapper should be a deep module with a small map-or-default interface while hiding path canonicalization and warning construction.
- Lifecycle Coordinator should be a deep module with a small create/apply/start/stop/delete/run/shell interface while hiding metadata transactions, backend calls, prompts, and auto-start behavior.
- Sandbox Backend should be a deep module with a shallow protocol while hiding Apple `container` CLI command shape, runtime recreation, volume mechanics, service management, and error parsing.
- Doctor Check should be a deep module with a small run-checks interface while hiding platform/backend probing details.

## Testing Decisions

- TDD is required for deterministic domain/spec behavior before backend integration work.
- Good tests assert external behavior and stable contracts, not private implementation details.
- Domain tests should use fake backends for fast deterministic feedback.
- Backend-dependent tests must be live/manual integration checks and must record exact commands/results when used for acceptance.
- Do not certify Host-Safe File Ownership, persistent Guest State, Access Modes, concurrent sessions, or outbound networking with mocks alone.
- Test the Sandbox Spec Model for default generation, explicit image/resource overrides, `--from` parsing, YAML rendering, unsupported future fields rejection, and canonical Access Mode storage.
- Test Sandbox Name validation and global uniqueness behavior.
- Test Host Metadata Store for creating, reading, updating, and deleting specs without corrupting existing metadata.
- Test Host Metadata Store locking/serialization behavior for concurrent Lifecycle Mutations.
- Test Folder Policy for `rw`/`ro` normalization, read-write/read-only canonicalization, Guest Path defaults, `--as` overrides, duplicate host folder updates, duplicate Guest Path rejection, overlapping host folder rejection, symlink realpath handling, and display path preservation.
- Test `folders add` as a spec mutation that auto-applies through a fake backend.
- Test `folders remove` as a spec mutation that auto-applies through a fake backend.
- Test that config changes apply immediately when stopped.
- Test that config changes requiring interruption ask before applying when running.
- Test Working Directory Mapping when cwd is inside an Shared Folder.
- Test Working Directory Mapping when cwd is outside all Shared Folders and returns warning plus default location.
- Test Working Directory Mapping with symlinked cwd paths.
- Test Lifecycle Coordinator create flow: spec generation, Guest State provisioning through backend, and stopped final state.
- Test daily command auto-start behavior with fake backend state transitions.
- Test start and stop preserve Guest State at the domain contract level.
- Test delete prompts by default and skips prompt with force.
- Test delete removes Host Metadata and delegates Guest State/backend cleanup.
- Test that reset is not part of the v1 command surface.
- Test CLI command parsing for all v1 commands.
- Test sandbox-first daily syntax.
- Test that `run` passes Workload Command arguments through unchanged.
- Test that Pi is not special-cased in command parsing.
- Test `shell` dispatches an interactive Sandbox Session request.
- Test `run` and `shell` use mapped working directory where available.
- Test multiple normal Sandbox Sessions are not serialized by Lifecycle Mutation locks.
- Test Lifecycle Mutations are serialized.
- Test `sand list` and `sand <name> status` render Sandbox Status from domain status, not raw backend output.
- Test `sand <name> spec` prints the active Sandbox Spec.
- Test `sand apply <name>` reconciles spec through the Lifecycle Coordinator and fake backend.
- Test `sand doctor` reports missing backend executable, stopped Backend Service, unsupported platform, missing/default image, and unwritable Host Metadata.
- Test Apple Container CLI Backend command construction through unit tests that assert domain intent rather than scattering raw command expectations through CLI tests.
- Test Apple Container CLI Backend error translation with fixture outputs from Apple `container` failures.
- Test Sandbox Image definition with at least a build-file lint or smoke build path where practical.
- Backend Validation Spike must prove:
  - persistent Guest State via backend volume/state mechanism
  - read-write Shared Folders
  - read-only Shared Folders
  - Host-Safe File Ownership
  - interactive Sandbox Session as Sandbox User
  - passwordless sudo inside Sandbox Guest
  - concurrent sessions
  - runtime recreation while preserving Guest State
  - Working Directory Mapping into mounted folders
  - Outbound-Only Networking
  - default Sandbox Image includes Default Toolset and Pi CLI
  - Backend Service auto-start behavior
  - stop/start preserves Guest State
- Prior art for deterministic tests can follow the current repo's small-module style: fast unit tests around deep modules, fakes for external providers/backends, and separate live/manual checks for real integration paths.
- Prior art for PRD/issue workflow follows existing local issue markdown files with frontmatter status, type, category, labels, and `needs-triage` entry state.
- The validation spike should be the first vertical tracer bullet before building the full CLI.
- The next vertical slice after the spike should create a Sandbox Spec, apply it through a fake backend, and run a fake Workload Command with Working Directory Mapping.
- Integration work should proceed only after deterministic tests define the domain contract.
- Keep commits small and keep the build green; if the backend live path fails, fix the root cause or stop according to ADR-0001.

## Out of Scope

- Desktop UI or Docker Desktop-style app in v1.
- Inbound networking, port publishing, localhost forwarding, or service exposure in v1.
- A Pi-specific `sand mybox pi` shortcut in v1.
- Pi flag parsing, Pi onboarding logic, Pi auth inspection, or Pi config management inside `sand`.
- Skill Source management or Pi skill syncing in v1.
- Mounting Host Mac `~/.pi` by default.
- Mounting or forwarding host credentials, host SSH agent, host token files, or Host Mac secrets by default.
- Reset command in v1.
- Changing CPU or memory after creation in v1.
- Shell completion in v1.
- Editor integration for specs in v1.
- Default/project-local implicit sandbox selection in v1.
- Inbound network fields in the v1 Sandbox Spec.
- Non-Apple backend fallback to Docker, Lima, Colima, or OrbStack.
- Hidden rsync/chmod/sync workarounds for failed hard requirements unless explicitly approved as a new design.
- A production sandbox security certification beyond the defined Host Mac filesystem and credential boundaries.
- Multi-user host management or shared sandboxes.
- Remote hosts or cloud sandboxes.
- Kubernetes, orchestration, or generalized container management.
- Broad resource manager or dynamic tuning UI.
- Full observability platform, telemetry product, or high-cardinality event store.

## Further Notes

The highest-risk requirement is Host-Safe File Ownership. The Backend Validation Spike must answer this before the project invests in CLI polish. The second highest-risk requirement is persistent Guest State that survives stop/start and runtime recreation while remaining separate from Shared Folders.

The Apple `container` docs indicate support for named containers, bind mounts with read-only flags, exec, start/stop/list/inspect/logs/stats, named volumes, resource settings, port publishing, and Apple-native VM-per-container isolation. Those capabilities appear promising, but the PRD deliberately treats them as unproven until live validation confirms the exact `sand` requirements.

This PRD is intentionally delivery-biased: validate backend assumptions first, write deterministic tests for deep modules, keep the command surface small, avoid speculative UI, and do not accept shallow wrappers. That follows the combined guidance from Beck/Farley/Fowler/Ousterhout-style design: prove the risky integration, keep modules deep and testable, and build a thin vertical slice before broadening.

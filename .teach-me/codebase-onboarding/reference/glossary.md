# Glossary

## Product model

- **Host Mac** — The macOS machine running `sand` and holding real user files.
- **Sandbox VM** — A named, managed Linux environment created by `sand` on the Host Mac.
- **Sandbox Guest** — The Linux side inside a Sandbox VM where commands, shells, and tools run.
- **Allowed Folder** — A Host Mac folder explicitly mounted into a Sandbox VM.
- **Access Mode** — The permission for an Allowed Folder: canonical `read-write` or `read-only`; CLI aliases include `rw` and `ro`.
- **Guest Path** — The Linux path where an Allowed Folder appears, such as `/workspace` or `/reference`.
- **Guest State** — Persistent Linux-side state for a Sandbox VM: installed tools, shell config, package caches, and sandbox-local app identity.
- **Runtime Instance** — The running backend process for a Sandbox VM; it can be stopped/started around persistent Guest State.
- **Sandbox Session** — An interactive shell connection into the Sandbox VM as the Sandbox User.
- **Workload Command** — An opaque command plus arguments executed inside the Sandbox VM, e.g. `pwd`, `bash -lc ...`, or `pi`.

## Specs and policy

- **Sandbox Spec** — Durable YAML contract for a reusable Sandbox VM: name, image, resources, and Allowed Folders.
- **Host Metadata** — Host-side records under sand's control: Sandbox Specs and Ephemeral Run Records.
- **FolderPolicy** — Rules for adding/updating/removing Allowed Folders, normalizing Access Modes, deriving Guest Paths, and rejecting overlaps or duplicate Guest Paths.
- **Working Directory Mapping** — Mapping the Host Mac current directory into the corresponding Guest Path; falls back to `/workspace` with a warning when outside Allowed Folders.

## Code architecture

- **CLICommandRouter** — Parses command shapes and creates typed application requests.
- **SandboxApplication** — Protocol seam between CLI parsing and application behavior.
- **LifecycleCoordinator** — Orchestrates metadata, policies, runtime status, start/stop, run/shell/log/status/spec/folder flows.
- **SandboxBackend** — Narrow adapter port for backend operations such as readiness, provision, apply, start, stop, run, shell, status, logs, and delete.
- **CommandResult** — Success/failure result that flows back to `main.swift` and becomes the process exit code.

## Ephemeral runs

- **Ephemeral Spec** — Recipe for one bounded create-run-stop-cleanup-delete workflow; separate from durable Sandbox Specs.
- **Ephemeral Sandbox Run** — One explicit execution of an Ephemeral Spec via `sand ephemeral --from ...`.
- **Before Provision Hook** — Host Mac hook run before provisioning an ephemeral sandbox.
- **Foreground Workload** — The main command run inside the Sandbox Guest; its process lifetime controls when cleanup begins.
- **After Stop Hook** — Host Mac hook run after the Foreground Workload exits and sand attempts to stop the Sandbox VM.
- **Ephemeral Run Record** — Immutable Host Metadata for an ephemeral attempt: source spec, generated spec, phase events, hook output paths, result, failed phase, and cleanup guidance.

## Documentation workflow

- **Documentation Impact** — A change that affects public behavior, CLI help, examples, product language, contributor workflow, docs tooling, or docs manifests.
- **Generated docs** — Documents such as `docs/cli-reference.md` produced from real command/help output; do not hand-edit generated bodies.
- **Managed README sections** — README regions between `<!-- docs:managed:start ... -->` and `<!-- docs:managed:end -->` refreshed by the docs workflow.
- **Documentation Freshness Gate** — `make docs-check`, which verifies generated/managed docs against the current docs input hash.

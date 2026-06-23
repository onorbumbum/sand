# Research — codebase-onboarding

## Strategy

Local-first. Web research not used; repo docs, source, and tests are sufficient.

## Distilled findings

### Product model

`sand` is a Swift CLI for creating and managing Sandbox VMs on an Apple silicon Host Mac. A Sandbox VM is an isolated Linux environment with persistent Guest State and explicit Allowed Folders. Users run generic Workload Commands inside the Sandbox VM; Pi is intentionally just one Workload Command, not a special `sand` mode.

Core vocabulary comes from `issues/sand/CONTEXT.md`: Sandbox VM, Host Mac, Sandbox Guest, Allowed Folder, Access Mode, Guest Path, Working Directory Mapping, Guest State, Runtime Instance, Sandbox Session, Lifecycle Mutation, Workload Command, Ephemeral Sandbox Run, Ephemeral Spec, Ephemeral Run Record, Sandbox Backend, Host Metadata.

### User workflow

The practical usage path from README/CLI docs:

1. `sand doctor`
2. `sand create demo`
3. `sand list`, `sand demo status`, `sand demo spec`
4. `sand folders add demo <host-path> rw --as /workspace`
5. `sand demo run <command>`
6. `sand demo shell`
7. `sand demo stop`, `sand demo start`
8. `sand demo logs`
9. `sand ephemeral init ephemeral-spec.yaml`, then `sand ephemeral --from ephemeral-spec.yaml`
10. `sand delete demo --force`

OAuth/browser callback limitation matters for users: inbound localhost is not published in v1, so CLI login callbacks use a two-terminal handoff.

### Developer workflow

The project is a Swift Package with:

- executable product `sand`, target `Sources/sand/main.swift`,
- library product `SandCore`, target `Sources/SandCore/`,
- tests under `Tests/SandCoreTests/`,
- local gates in `Makefile`: `swift test`, `make docs-check`, `make check`.

For behavior changes, start from tests that own the behavior, not docs. The developer guide maps concerns to test files.

### Architecture map

High-level flow:

```text
main.swift
  → CLICommandRouter
  → SandboxApplication protocol
  → LifecycleCoordinator
  → HostMetadataStore + SandboxBackend + policies/presenters
```

Key modules:

- `CLI/`: parses command shapes, prints help/version, rejects unsupported v1 shapes, creates request structs.
- `Lifecycle/`: orchestrates user-visible lifecycle operations, folder mutations, run/shell auto-start, status/log/spec output, and locks Lifecycle Mutations.
- `Backend/`: narrow adapter boundary; first backend uses Apple `container`, but backend details should not leak into product language.
- `Metadata/`: Host Metadata storage under `~/.sand/`; active specs, created specs, locks, run records.
- `Spec/`: Sandbox Spec model, YAML rendering/parsing, validation rules.
- `FolderPolicy/`: Allowed Folder add/update/remove rules, Access Mode parsing, Guest Path defaults, overlap rejection.
- `WorkingDirectory/`: maps Host Mac current directory into Guest Path or falls back with warning.
- `Ephemeral/`: separate bounded create-run-stop-delete flow with hooks and immutable Ephemeral Run Records.
- `Doctor/`: host/backend/image/metadata readiness checks.
- `Status/` and `Prompt/`: presentation and confirmation boundaries.

### Important design boundaries

- Durable Sandbox Specs and Ephemeral Specs are separate. Normal lifecycle commands remain boring; ephemeral runs preserve records after cleanup.
- Pi must stay on the generic Workload Command path.
- Workload Commands are opaque; `sand` should not inspect workload-specific flags.
- Backend implementation wording belongs inside backend code/tests, not user-facing help/docs.
- Inbound networking/port publishing is out of v1 scope.
- Resource Profile edits are create-time-only in v1.
- Documentation is generated/managed when public behavior changes; do not refresh docs just to silence a failing gate.

### Testing/debugging map

Representative tests:

- Command routing/help: `CLICommandRouterTests.swift`
- Specs/YAML/resource rules: `SandboxSpecTests.swift`
- Folder policies: `FolderPolicyTests.swift`
- Working directory mapping: `WorkingDirectoryMapperTests.swift`
- Lifecycle orchestration: `LifecycleCoordinatorTests.swift`
- Ephemeral flow: `EphemeralRunCoordinatorTests.swift`, `EphemeralRunRecordStoreTests.swift`
- Doctor checks: `DoctorChecksTests.swift`, `AppleContainerCLIBackendDoctorTests.swift`
- Backend language translation: `BackendErrorTranslationTests.swift`
- Architecture boundaries: `ArchitectureBoundaryTests.swift`
- Pi/credential boundaries: `PiWorkloadCredentialBoundaryValidationTests.swift`

Debugging should begin by classifying the symptom by command area, then reading the matching tests/source pair, then reproducing with targeted `swift test` or app commands, then running `make check`.

## Course design consequences

A good sequence:

1. Use the app as a user.
2. Draw the product/domain mental model.
3. Map the repo and docs.
4. Trace a simple durable command.
5. Understand specs, folders, and working-directory mapping.
6. Understand ephemeral runs and why they are separate.
7. Learn testing/debugging patterns.
8. Make a small change test-first.
9. Refresh docs only when the change has Documentation Impact.
10. Finish with an integrated maintenance/debugging scenario.

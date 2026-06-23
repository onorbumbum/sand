<!-- generated-doc: true -->
<!-- generated-by: docs/prompts/refresh-docs.md -->
<!-- docs-input-hash: d423445febdaed9019d045042030464047c07d640c5ec6d274d8efe4e7956ae3 -->

# sand Developer Guide

> Guide for changing `sand` safely. It teaches the project architecture, tests, command workflow, and completion gate for humans and AI agents.

## Canonical language and boundaries

Use [`issues/sand/CONTEXT.md`](https://github.com/onorbumbum/sand/blob/main/issues/sand/CONTEXT.md) as the source of truth for user-facing language. The product is a **Sandbox VM** tool for a **Host Mac** with explicit **Shared Folders**, persistent **Guest State**, **Sandbox Sessions**, and generic **Workload Commands**. Pi is a workload, not a special `sand` command.

Keep backend-specific wording inside backend implementation and tests. User-facing docs, errors, help, and specs should describe the Sandbox VM domain, not the underlying adapter.

macOS Sandbox VMs are first-class but heavier than Linux Sandbox VMs. They require Tart on `PATH` (`brew install cirruslabs/cli/tart`), while `sand` itself remains unsigned and entitlement-free because Tart carries the Virtualization Framework entitlement. Document the honest platform limits whenever macOS behavior is user-facing: roughly two concurrent macOS Sandbox VMs per Host Mac, about 100GB per VM with slower boot, and no physical-device deploy/debug because macOS guests do not get USB passthrough.

## Public repository stance

`sand` is experimental alpha software under the Apache License 2.0. Public issues are welcome for bugs, questions, and feature ideas, but there is no support guarantee or response SLA. Report security vulnerabilities through GitHub private vulnerability reporting, not public issues. External pull requests are not accepted yet.

## High-level architecture

`SandCore` keeps the command surface shallow and the domain modules small:

| Area | Main files | Responsibility |
| --- | --- | --- |
| CLI routing | `Sources/sand/main.swift`, `Sources/SandCore/CLI/CLICommandRouter.swift`, `Sources/SandCore/CLI/SandboxApplication.swift` | Parse `sand` arguments, print help/version, reject unsupported v1 command shapes, and call the application boundary. |
| Lifecycle coordination | `Sources/SandCore/Lifecycle/LifecycleCoordinator.swift` | Orchestrate create, bootstrap, apply, delete, start, stop, status, logs, spec, shell, run, and folder mutations. Lifecycle Mutations are serialized; normal Sandbox Sessions and Workload Commands are not. |
| Sandbox Specs | `Sources/SandCore/Spec/SandboxSpec.swift` | Model and validate v1 Sandbox Specs, defaults, YAML rendering/parsing, unsupported fields, and immutable Resource Profile updates. |
| Shared Folders | `Sources/SandCore/FolderPolicy/FolderPolicy.swift` | Normalize Access Modes, choose default Guest Paths, preserve display paths, resolve real paths, reject overlapping Host Mac folders, and prevent duplicate Guest Paths. |
| Working Directory Mapping | `Sources/SandCore/WorkingDirectory/WorkingDirectoryMapper.swift` | Map the Host Mac current directory into the matching Guest Path when it is inside an Shared Folder; otherwise warn and use `/workspace`. |
| Host Metadata | `Sources/SandCore/Metadata/HostMetadataStore.swift` | Store active Sandbox Specs and creation-time specs under Host Metadata, and provide the lifecycle mutation lock. |
| Doctor Checks | `Sources/SandCore/Doctor/DoctorChecks.swift` | Verify supported Host Mac platform, Sandbox Backend readiness, default Sandbox Image availability through the backend, and Host Metadata writability. |
| Sandbox Backend | `Sources/SandCore/Backend/SandboxBackend.swift`, `Sources/SandCore/Backend/AppleContainerCLIBackend.swift`, `Sources/SandCore/Backend/TartCLIBackend.swift`, `Sources/SandCore/Backend/BackendErrorTranslation.swift` | Hide backend operations behind a narrow interface and translate backend failures into Sandbox VM language. |
| Status and prompts | `Sources/SandCore/Status/StatusPresenter.swift`, `Sources/SandCore/Prompt/PromptConfirmation.swift` | Present concise Sandbox Status and ask before destructive or interrupting Lifecycle Mutations. |

The intended dependency direction is CLI → application boundary → domain/policy/backend interfaces. Backend adapter details should not spread into general domain modules.

The split-backend decision is recorded in [`docs/adr/0001-split-backends-linux-container-macos-tart.md`](adr/0001-split-backends-linux-container-macos-tart.md): Linux shells out to Apple `container`; macOS shells out to Tart; both pull or clone OCI-backed images and run with sand-controlled Shared Folders. The user-facing API stays stable across both backends, but CLI help may name `--os macos`, `--disk`, Tart installation, or `gui` when those are direct user obligations.

macOS-specific implementation constraints:

- `disk:` / `--disk <size>` is macOS-only, create-time, and grow-only for clones.
- Shared Folders must preserve the chosen Guest Path even though Tart exposes them at `/Volumes/My Shared Files/<tag>`; the Tart backend owns the guest-side symlink.
- `sand gui <name>` is macOS-only and opens a GUI Session through Tart VNC plus Host Mac Screen Sharing. Screen Sharing may ask for credentials: `admin` / `admin` for Cirrus Tart registry images, or the Sandbox User credentials created during first boot for self-built IPSW VMs.
- Signing Credentials are Guest Secrets injected into the Sandbox Guest keychain; the Host Mac keychain is never mounted.
- Simulator work does not need signing or Apple ID. Distribution signing is supported through injected Signing Credentials. Physical-device deploy/debug is unsupported.

## Testing strategy

Behavior is specified with XCTest under `Tests/SandCoreTests/`. Start with the representative test before changing the matching source file:

| Concern | Representative tests |
| --- | --- |
| CLI routing and command surface | `Tests/SandCoreTests/CLICommandRouterTests.swift` checks help/version output, every v1 command shape, opaque Workload Command routing, and absent commands such as `reset` and Pi shortcuts. |
| Sandbox Spec contract | `Tests/SandCoreTests/SandboxSpecTests.swift` checks generated defaults, render/parse round trips, authored specs, unsupported future fields, immutable Resource Profile edits, and Sandbox Name validation. |
| Folder policy | `Tests/SandCoreTests/FolderPolicyTests.swift` checks Access Mode aliases, default Guest Path derivation, canonical storage, duplicate Host Mac folder updates, duplicate Guest Path rejection, and overlap rejection using resolved paths. |
| Working Directory Mapping | `Tests/SandCoreTests/WorkingDirectoryMapperTests.swift` checks exact and nested Shared Folder mapping, symlink-resolved mapping, and fallback warning behavior outside Shared Folders. |
| Lifecycle coordination | `Tests/SandCoreTests/LifecycleCoordinatorTests.swift` checks create rollback, IPSW setup-required bootstrap flow, apply prompts, status/list/spec/logs output, run/shell auto-start, folder mutation auto-apply, deletion prompts, lifecycle locks, and concurrent session boundaries. |
| Doctor Checks | `Tests/SandCoreTests/DoctorChecksTests.swift` and `Tests/SandCoreTests/AppleContainerCLIBackendDoctorTests.swift` check platform gating, Host Metadata writability, backend readiness, default Sandbox Image checks, and backend command construction. |
| Backend behavior and error translation | `Tests/SandCoreTests/TartCLIBackendTests.swift` checks macOS backend command construction, including Signing Credentials injection, and `Tests/SandCoreTests/BackendErrorTranslationTests.swift` checks that raw backend failures become actionable Sandbox VM messages without leaking adapter internals. |
| Architecture boundaries | `Tests/SandCoreTests/ArchitectureBoundaryTests.swift` checks that fake backends stay out of product sources and backend-specific implementation wording stays inside the adapter. |
| Pi workload and credential boundaries | `Tests/SandCoreTests/PiWorkloadCredentialBoundaryValidationTests.swift` checks validation evidence that Pi runs as an ordinary Workload Command and Host Mac credentials are not mounted by default. |

Use targeted tests while iterating, then run:

```sh
make check
```

`make check` runs `swift test` and the Documentation Freshness Gate.

## Adding or changing a `sand` command

1. Name the behavior in Sandbox VM language from [`issues/sand/CONTEXT.md`](https://github.com/onorbumbum/sand/blob/main/issues/sand/CONTEXT.md). If the feature is outside v1 scope, add an explicit rejection test rather than silently accepting the shape.
2. Add or update routing in `CLICommandRouter.swift` and, when needed, request types or methods on `SandboxApplication.swift`.
3. Implement orchestration in `LifecycleCoordinator.swift` or the smallest matching domain module. Keep Workload Commands opaque; do not inspect workload-specific flags.
4. Update help text in `CLICommandRouter.swift`. The CLI Reference is generated from help output, so help is part of the source of truth.
5. Add or update tests in `CLICommandRouterTests.swift` for the command shape and in the relevant domain/lifecycle/backend test file for behavior.
6. Run targeted tests, then `make check`.
7. If command behavior, help text, examples, or onboarding changed, refresh generated/managed docs using [`docs/prompts/refresh-docs.md`](prompts/refresh-docs.md). Do not refresh docs for implementation-only refactors.

## Working rules for AI agents

- Read the issue and relevant docs before editing.
- Prefer the smallest change that preserves existing module boundaries.
- Do not introduce user-facing backend implementation details.
- Keep Pi on the same Workload Command path as other tools, so the user-facing model stays consistent.
- Do not weaken tests to make a change pass.
- Do not update docs hashes just to silence `make docs-check`.
- Record real verification evidence before finishing.

## Documentation as a guardrail

The documentation system exists to help contributors and agents work correctly, not to make every task a docs task. Most implementation changes should start in code and tests.

Run the Documentation Refresh Workflow only when the change has Documentation Impact:

- public behavior or CLI help changed,
- README examples or quickstart changed,
- Sandbox VM domain language changed,
- onboarding/developer workflow changed,
- docs manifests, freshness scripts, or generation scripts changed.

When needed:

```sh
scripts/generate-cli-reference.sh   # if command help/version output changed
scripts/docs-input-hash.sh docs/docs-input-manifest.txt
make docs-check
```

The full refresh workflow is defined in [`docs/prompts/refresh-docs.md`](prompts/refresh-docs.md). Preserve Managed Section markers in section-managed docs and refresh registered generated/managed docs against current source-of-truth inputs.

## Local Definition of Done

A change is done locally when:

- behavior tests pass with `swift test`,
- the full gate passes with `make check`,
- any Documentation Impact has been handled through the documented refresh workflow,
- public language follows [`issues/sand/CONTEXT.md`](https://github.com/onorbumbum/sand/blob/main/issues/sand/CONTEXT.md),
- the issue or final response records honest evidence for commands run and any limitations.

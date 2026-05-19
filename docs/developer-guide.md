<!-- generated-doc: true -->
<!-- generated-by: docs/prompts/refresh-docs.md -->
<!-- docs-input-hash: cb70cafac5bd0c9a03bc7761eea55ccd12f02c78843cd44d44efe2095e68c504 -->

# sand Developer Guide

> Generated guide for contributors and agents changing `sand`. Refresh this document through the Documentation Refresh Workflow when the docs input hash changes.

## Canonical language and boundaries

Use [`issues/sand/CONTEXT.md`](../issues/sand/CONTEXT.md) as the source of truth for user-facing language. The product is a **Sandbox VM** tool for a **Host Mac** with explicit **Allowed Folders**, persistent **Guest State**, **Sandbox Sessions**, and generic **Workload Commands**. Pi is a workload, not a special `sand` command.

Keep backend-specific wording inside backend implementation and tests. User-facing docs, errors, help, and specs should describe the Sandbox VM domain, not the underlying adapter.

## High-level architecture

`SandCore` keeps the command surface shallow and the domain modules small:

| Area | Main files | Responsibility |
| --- | --- | --- |
| CLI routing | `Sources/sand/main.swift`, `Sources/SandCore/CLI/CLICommandRouter.swift`, `Sources/SandCore/CLI/SandboxApplication.swift` | Parse `sand` arguments, print help/version, reject unsupported v1 command shapes, and call the application boundary. |
| Lifecycle coordination | `Sources/SandCore/Lifecycle/LifecycleCoordinator.swift` | Orchestrate create, apply, delete, start, stop, status, logs, spec, shell, run, and folder mutations. Lifecycle Mutations are serialized; normal Sandbox Sessions and Workload Commands are not. |
| Sandbox Specs | `Sources/SandCore/Spec/SandboxSpec.swift` | Model and validate v1 Sandbox Specs, defaults, YAML rendering/parsing, unsupported fields, and immutable Resource Profile updates. |
| Allowed Folders | `Sources/SandCore/FolderPolicy/FolderPolicy.swift` | Normalize Access Modes, choose default Guest Paths, preserve display paths, resolve real paths, reject overlapping Host Mac folders, and prevent duplicate Guest Paths. |
| Working Directory Mapping | `Sources/SandCore/WorkingDirectory/WorkingDirectoryMapper.swift` | Map the Host Mac current directory into the matching Guest Path when it is inside an Allowed Folder; otherwise warn and use `/workspace`. |
| Host Metadata | `Sources/SandCore/Metadata/HostMetadataStore.swift` | Store active Sandbox Specs and creation-time specs under Host Metadata, and provide the lifecycle mutation lock. |
| Doctor Checks | `Sources/SandCore/Doctor/DoctorChecks.swift` | Verify supported Host Mac platform, Sandbox Backend readiness, default Sandbox Image availability through the backend, and Host Metadata writability. |
| Sandbox Backend | `Sources/SandCore/Backend/SandboxBackend.swift`, `Sources/SandCore/Backend/AppleContainerCLIBackend.swift`, `Sources/SandCore/Backend/BackendErrorTranslation.swift` | Hide backend operations behind a narrow interface and translate backend failures into Sandbox VM language. |
| Status and prompts | `Sources/SandCore/Status/StatusPresenter.swift`, `Sources/SandCore/Prompt/PromptConfirmation.swift` | Present concise Sandbox Status and ask before destructive or interrupting Lifecycle Mutations. |

The intended dependency direction is CLI -> application boundary -> domain/policy/backend interfaces. Backend adapter details should not spread into CLI help, Sandbox Specs, or general domain modules.

## Testing strategy

Behavior is specified with XCTest under `Tests/SandCoreTests/`. Start with the representative test before changing the matching source file:

| Concern | Representative tests |
| --- | --- |
| CLI routing and command surface | `Tests/SandCoreTests/CLICommandRouterTests.swift` checks help/version output, every v1 command shape, opaque Workload Command routing, and absent commands such as `reset` and Pi shortcuts. |
| Sandbox Spec contract | `Tests/SandCoreTests/SandboxSpecTests.swift` checks generated defaults, render/parse round trips, authored specs, unsupported future fields, immutable Resource Profile edits, and Sandbox Name validation. |
| Folder policy | `Tests/SandCoreTests/FolderPolicyTests.swift` checks Access Mode aliases, default Guest Path derivation, canonical storage, duplicate Host Mac folder updates, duplicate Guest Path rejection, and overlap rejection using resolved paths. |
| Working Directory Mapping | `Tests/SandCoreTests/WorkingDirectoryMapperTests.swift` checks exact and nested Allowed Folder mapping, symlink-resolved mapping, and fallback warning behavior outside Allowed Folders. |
| Lifecycle coordination | `Tests/SandCoreTests/LifecycleCoordinatorTests.swift` checks create rollback, apply prompts, status/list/spec/logs output, run/shell auto-start, folder mutation auto-apply, deletion prompts, lifecycle locks, and concurrent session boundaries. |
| Doctor Checks | `Tests/SandCoreTests/DoctorChecksTests.swift` and `Tests/SandCoreTests/AppleContainerCLIBackendDoctorTests.swift` check platform gating, Host Metadata writability, backend readiness, default Sandbox Image checks, and backend command construction. |
| Backend error translation | `Tests/SandCoreTests/BackendErrorTranslationTests.swift` checks that raw backend failures become actionable Sandbox VM messages without leaking adapter internals. |
| Architecture boundaries | `Tests/SandCoreTests/ArchitectureBoundaryTests.swift` checks that fake backends stay out of product sources and backend-specific implementation wording stays inside the adapter. |
| Pi workload and credential boundaries | `Tests/SandCoreTests/PiWorkloadCredentialBoundaryValidationTests.swift` checks validation evidence that Pi runs as an ordinary Workload Command and Host Mac credentials are not mounted by default. |

The preferred local gate is:

```sh
swift test
make docs-check
```

`make check` runs both.

## Adding or changing a `sand` command

1. Name the behavior in Sandbox VM language from [`issues/sand/CONTEXT.md`](../issues/sand/CONTEXT.md). If the feature is outside v1 scope, add an explicit rejection test rather than silently accepting the shape.
2. Add or update routing in `CLICommandRouter.swift` and, when needed, request types or methods on `SandboxApplication.swift`.
3. Implement orchestration in `LifecycleCoordinator.swift` or the smallest matching domain module. Keep Workload Commands opaque; do not inspect workload-specific flags.
4. Update help text in `CLICommandRouter.swift`. The CLI Reference is generated from help output, so help is part of the source of truth.
5. Add or update tests in `CLICommandRouterTests.swift` for the command shape and in the relevant domain/lifecycle/backend test file for behavior.
6. If the command changes public behavior or examples, update README managed sections through the Documentation Refresh Workflow rather than hand-maintaining divergent prose.
7. Regenerate the CLI Reference with:

   ```sh
   scripts/generate-cli-reference.sh
   ```

8. Refresh registered Generated Documentation so `docs/cli-reference.md`, `docs/onboarding.md`, `docs/developer-guide.md`, and any registered README managed sections record the current docs input hash and match the current behavior.
9. Run `swift test` and `make docs-check` before committing.

## Documentation Refresh Workflow

Run the Documentation Refresh Workflow whenever a change affects public behavior, CLI help, README managed sections, domain language, executable behavior specs, docs scripts, or generated documentation itself.

The workflow is defined in [`docs/prompts/refresh-docs.md`](prompts/refresh-docs.md). In short:

1. Read `docs/docs-input-manifest.txt`, `docs/generated-docs-manifest.txt`, all required manifest inputs, optional inputs that exist, and existing generated docs.
2. Compute the current docs input hash:

   ```sh
   scripts/docs-input-hash.sh docs/docs-input-manifest.txt
   ```

3. Refresh every registered Generated Documentation file using current source, tests, CLI help, README, and context language.
4. Record the hash near the top of each generated document using the agreed metadata convention:

   ```md
   <!-- docs-input-hash: <64-character-sha256> -->
   ```

5. Preserve Managed Section markers and only replace managed content in section-managed docs.
6. Run `make docs-check` and `swift test`.
7. Record evidence: hash used, documents refreshed, generation sources, verification results, and conflicts or skipped inputs.

Do not update a document's hash just to bypass drift. If the hash is stale, refresh the document against the current inputs.

## Local Definition of Done

A change is done locally when:

- Behavior tests pass with `swift test`.
- The Documentation Freshness Gate passes with `make docs-check`.
- Generated Documentation that has Documentation Impact has been refreshed and records the current docs input hash.
- Public language follows [`issues/sand/CONTEXT.md`](../issues/sand/CONTEXT.md).
- The issue records honest evidence for the commands run and any limitations.

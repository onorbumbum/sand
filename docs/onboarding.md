<!-- generated-doc: true -->
<!-- generated-by: docs/prompts/refresh-docs.md -->
<!-- docs-input-hash: 05afb86350b2a28c2d4f15f696cd36e812d87667b711d86486e3d4cdd65bd592 -->

# sand Onboarding Guide

> Generated start-here guide for humans and AI agents. Refresh this document through the Documentation Refresh Workflow when the docs input hash changes.

## What this repo is

`sand` is a Swift CLI for creating and managing **Sandbox VMs**: isolated Linux machines on a **Host Mac** with persistent **Guest State**, explicit **Allowed Folders**, and generic **Workload Commands**. Pi is an important workload, but `sand` is not a Pi-specific launcher.

Use the product language in [`issues/sand/CONTEXT.md`](../issues/sand/CONTEXT.md). Prefer terms like **Sandbox VM**, **Allowed Folder**, **Guest Path**, **Sandbox Session**, and **Workload Command**.

## Start here: humans

1. Read [`README.md`](../README.md) for scope, prerequisites, install steps, and the v1 command surface.
2. Read [`issues/sand/CONTEXT.md`](../issues/sand/CONTEXT.md) before changing behavior or documentation language.
3. Read [`docs/cli-reference.md`](cli-reference.md) for the generated command reference.
4. If changing implementation, find the relevant module under `Sources/SandCore/` and the matching tests under `Tests/SandCoreTests/`.
5. Run local verification before considering work complete:

   ```sh
   swift test
   make docs-check
   make check
   ```

6. If your change affects public behavior, command output, onboarding, domain language, or documentation workflow, refresh Generated Documentation with [`docs/prompts/refresh-docs.md`](prompts/refresh-docs.md).

## Start here: AI agents

1. Read the task issue, then read these files before editing:
   - [`README.md`](../README.md)
   - [`issues/sand/CONTEXT.md`](../issues/sand/CONTEXT.md)
   - [`docs/docs-input-manifest.txt`](docs-input-manifest.txt)
   - [`docs/generated-docs-manifest.txt`](generated-docs-manifest.txt)
   - [`docs/prompts/refresh-docs.md`](prompts/refresh-docs.md) when touching Generated Documentation
2. Keep the project language aligned with the Sandbox VM context. Do not describe the product as a generic Docker/container wrapper.
3. Make the smallest change that satisfies the issue. Keep behavior claims tied to source, tests, CLI help, README, and the context language.
4. Update Generated Documentation only through the documented refresh conventions. Do not hand-edit generated hash metadata to hide drift.
5. Run the relevant gate. At minimum run `swift test`; when docs are touched, also run `make docs-check`. `make check` runs both.
6. Record evidence in the issue file before committing.

## Repo map

| Path | Purpose |
| --- | --- |
| `Sources/sand/main.swift` | CLI executable entry point. |
| `Sources/SandCore/CLI/` | Command routing and application orchestration for the `sand` Control Surface. |
| `Sources/SandCore/Backend/` | Sandbox Backend interfaces and Apple `container` backend plumbing. Backend details should not leak into user-facing language. |
| `Sources/SandCore/Doctor/` | Doctor Checks for Host Mac support, backend readiness, default image availability, and Host Metadata writability. |
| `Sources/SandCore/Domain/` | Small domain types such as Sandbox Name and Workload Command. |
| `Sources/SandCore/FolderPolicy/` | Allowed Folder validation, Access Mode handling, Guest Path rules, duplicate and overlap policy. |
| `Sources/SandCore/Lifecycle/` | Lifecycle Mutation coordination around create, apply, start, stop, delete, and run flows. |
| `Sources/SandCore/Metadata/` | Host Metadata storage under `~/.sand/`. |
| `Sources/SandCore/Prompt/` | Confirmation behavior for destructive or interrupting actions. |
| `Sources/SandCore/Spec/` | Sandbox Spec model and validation. |
| `Sources/SandCore/Status/` | User-facing Sandbox Status presentation. |
| `Sources/SandCore/WorkingDirectory/` | Working Directory Mapping from Host Mac paths into Guest Paths. |
| `Tests/SandCoreTests/` | XCTest coverage for domain, CLI, lifecycle, backend boundaries, folder policy, docs-adjacent behavior, and fixtures. Start here before changing behavior. |
| `README.md` | Human-facing overview, prerequisites, installation, quickstart, and command examples. Section-managed by the Documentation Refresh Workflow. |
| `issues/sand/CONTEXT.md` | Canonical domain language and relationships. Read this before naming user-facing behavior. |
| `docs/onboarding.md` | This generated start-here guide for humans and AI agents. |
| `docs/cli-reference.md` | Generated CLI Reference derived from real help output or command definitions/tests. |
| `docs/developer-guide.md` | Planned generated guide for architecture, testing strategy, and change workflow. Link to it from docs once present. |
| `docs/docs-input-manifest.txt` | Curated Documentation Input Manifest used to compute freshness. |
| `docs/generated-docs-manifest.txt` | Registry of Generated Documentation checked by the freshness gate. |
| `docs/prompts/refresh-docs.md` | Manual agent-run Documentation Refresh Workflow and metadata conventions. |
| `docs/validation/` | Backend and behavior validation evidence that supports implementation decisions. |
| `scripts/build-developer-ready-image.sh` | Builds the Developer-Ready Sandbox Image. |
| `scripts/smoke-developer-ready-image.sh` | Smoke-tests the Developer-Ready Sandbox Image. |
| `scripts/docs-input-hash.sh` | Computes the deterministic docs input hash. |
| `scripts/docs-check.sh` | Documentation Freshness Gate for registered Generated Documentation. |
| `scripts/generate-cli-reference.sh` | Regenerates `docs/cli-reference.md` from current CLI help/version output. |
| `Makefile` | Local build, test, docs-check, check, install, and uninstall targets. |

## First files to read before changing behavior

Read in this order:

1. [`issues/sand/CONTEXT.md`](../issues/sand/CONTEXT.md) for names, boundaries, and non-goals.
2. [`README.md`](../README.md) for current user-facing behavior and examples.
3. [`docs/cli-reference.md`](cli-reference.md) for the generated command surface.
4. The relevant `Sources/SandCore/` module.
5. The corresponding tests in `Tests/SandCoreTests/`.
6. [`docs/prompts/refresh-docs.md`](prompts/refresh-docs.md) if the change has Documentation Impact.

## Local verification flow

Use fast, deterministic checks:

```sh
swift test
make docs-check
make check
```

- `swift test` runs the XCTest suite for `SandCore`.
- `make docs-check` runs `scripts/docs-check.sh`, which computes the current Documentation Input Manifest hash and verifies every registered Generated Documentation file records that hash.
- `make check` is the single local completion gate and currently runs `swift test` followed by the Documentation Freshness Gate.

For CLI documentation changes, regenerate the CLI Reference with:

```sh
scripts/generate-cli-reference.sh
```

Then rerun `make docs-check` and `swift test`.

## Documentation Refresh Workflow

Generated Documentation is committed, human-facing documentation. It is refreshed through the manual agent-run workflow in [`docs/prompts/refresh-docs.md`](prompts/refresh-docs.md), not through ad hoc edits or hidden LLM memory.

At a high level, the workflow is:

1. Read the Documentation Input Manifest, generated docs registry, source files, tests, README, context language, and existing generated docs.
2. Compute the current docs input hash with `scripts/docs-input-hash.sh docs/docs-input-manifest.txt`.
3. Refresh every registered Generated Documentation file while preserving any Managed Sections.
4. Record the current docs input hash near the top of each generated document.
5. Run `make docs-check` and `swift test`.
6. Report the hash used, documents refreshed, generation sources, verification results, and any skipped/conflicting inputs.

## Avoiding stale documentation

- Treat `docs/docs-input-manifest.txt` as the curated list of inputs that can make Generated Documentation stale.
- Treat `docs/generated-docs-manifest.txt` as the list of generated documents that must record the current docs input hash.
- Do not update a document's `docs-input-hash` unless the document has actually been refreshed against the current inputs.
- If `make docs-check` fails, refresh the affected Generated Documentation instead of bypassing the gate.

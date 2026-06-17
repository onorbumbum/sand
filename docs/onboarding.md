<!-- generated-doc: true -->
<!-- generated-by: docs/prompts/refresh-docs.md -->
<!-- docs-input-hash: 4611688f2471ede3a9c27aa0340797287c49354225e6bbf68a7472d6629486cd -->

# sand Onboarding Guide

> Start here when you need to work on `sand`. This guide is for orienting humans and AI agents to the project, not for turning agents into documentation editors.

## What this repo is

`sand` is a Swift CLI for creating and managing **Sandbox VMs**: isolated Linux machines on a **Host Mac** with persistent **Guest State**, explicit **Shared Folders**, and generic **Workload Commands**. Pi is the primary workflow, and the same sandbox can run other developer tools when needed.

`sand` is experimental alpha software released under the Apache License 2.0. Public issues are welcome, but there is no support guarantee or response SLA, and external pull requests are not accepted yet.

Use the product language in [`issues/sand/CONTEXT.md`](https://github.com/onorbumbum/sand/blob/main/issues/sand/CONTEXT.md). Prefer terms like **Sandbox VM**, **Shared Folder**, **Guest Path**, **Sandbox Session**, and **Workload Command**.

## Start here: humans

1. Read [`README.md`](https://github.com/onorbumbum/sand/blob/main/README.md) for product scope, prerequisites, install steps, and quickstart.
2. Read [`docs/cli-reference.md`](cli-reference.md) when you need exact command shapes.
3. Read [`issues/sand/CONTEXT.md`](https://github.com/onorbumbum/sand/blob/main/issues/sand/CONTEXT.md) before naming user-facing behavior.
4. If changing implementation, start from the relevant `Sources/SandCore/` module and its matching tests under `Tests/SandCoreTests/`.
5. Run the local completion gate before considering work done:

   ```sh
   make check
   ```

## Start here: AI agents

Your job is to make the project better while preserving its product language, behavior contracts, and verification loop. Do not start by editing docs. Start by understanding the change.

1. **Read the task first.** Identify the requested behavior, bug, or documentation outcome.
2. **Read the product language.** Use [`issues/sand/CONTEXT.md`](https://github.com/onorbumbum/sand/blob/main/issues/sand/CONTEXT.md) to avoid overloaded or misleading terms.
3. **Read the user-facing contract.** Use [`README.md`](https://github.com/onorbumbum/sand/blob/main/README.md) and [`docs/cli-reference.md`](cli-reference.md) to understand current public behavior.
4. **Find the code and tests that own the behavior.** For most changes, pair one `Sources/SandCore/` area with one or more `Tests/SandCoreTests/` files.
5. **Make the smallest coherent change.** Keep Workload Commands opaque, keep backend details behind the Sandbox Backend, and do not introduce shortcuts that violate v1 boundaries.
6. **Verify with real commands.** Run targeted checks while working, then run `make check` before the final answer or commit.
7. **Update docs only when the change has Documentation Impact.** If public behavior, CLI help, onboarding instructions, domain language, or docs tooling changed, follow [`docs/prompts/refresh-docs.md`](prompts/refresh-docs.md). Otherwise do not churn generated docs.
8. **Leave evidence.** In an issue or final response, record what changed and which verification commands passed.

## Working loop for agents

Use this loop for most implementation tasks:

```text
Read task → read context language → locate behavior tests → inspect source → change code/docs → run verification → record evidence
```

Prefer source-backed claims. If docs and code disagree, treat that as a finding: inspect tests and command help before deciding which source is stale.

## Repo map

| Path | Purpose |
| --- | --- |
| `Sources/sand/main.swift` | CLI executable entry point. |
| `Sources/SandCore/CLI/` | Command routing and application orchestration for the `sand` API Surface. |
| `Sources/SandCore/Backend/` | Sandbox Backend interfaces and Apple `container` backend plumbing. Backend details should not leak into user-facing language. |
| `Sources/SandCore/Doctor/` | Doctor Checks for Host Mac support, backend readiness, default image availability, and Host Metadata writability. |
| `Sources/SandCore/Domain/` | Small domain types such as Sandbox Name and Workload Command. |
| `Sources/SandCore/FolderPolicy/` | Shared Folder validation, Access Mode handling, Guest Path rules, duplicate and overlap policy. |
| `Sources/SandCore/Lifecycle/` | Lifecycle Mutation coordination around create, apply, start, stop, delete, and run flows. |
| `Sources/SandCore/Metadata/` | Host Metadata storage under `~/.sand/`. |
| `Sources/SandCore/Prompt/` | Confirmation behavior for destructive or interrupting actions. |
| `Sources/SandCore/Spec/` | Sandbox Spec model and validation. |
| `Sources/SandCore/Status/` | User-facing Sandbox Status presentation. |
| `Sources/SandCore/WorkingDirectory/` | Working Directory Mapping from Host Mac paths into Guest Paths. |
| `Tests/SandCoreTests/` | XCTest coverage for domain, CLI, lifecycle, backend boundaries, folder policy, and validation evidence. Start here before changing behavior. |
| `README.md` | Human-facing overview, prerequisites, installation, quickstart, and command examples. |
| `issues/sand/CONTEXT.md` | Canonical domain language and relationships. Read this before naming user-facing behavior. |
| `docs/onboarding.md` | This start-here guide for humans and AI agents working on the project. |
| `docs/cli-reference.md` | Generated CLI Reference derived from real help output or command definitions/tests. |
| `docs/developer-guide.md` | Architecture, testing strategy, command-change workflow, and local Definition of Done. |
| `docs/docs-input-manifest.txt` | Curated Documentation Input Manifest used to compute freshness. |
| `docs/generated-docs-manifest.txt` | Registry of generated/managed docs checked by the freshness gate. |
| `docs/prompts/refresh-docs.md` | Only for refreshing generated/managed docs when a change has Documentation Impact. |
| `docs/validation/` | Backend and behavior validation evidence that supports implementation decisions. |
| `scripts/build-developer-ready-image.sh` | Builds the Developer-Ready Sandbox Image. |
| `scripts/smoke-developer-ready-image.sh` | Smoke-tests the Developer-Ready Sandbox Image. |
| `scripts/docs-input-hash.sh` | Computes the deterministic docs input hash. |
| `scripts/docs-check.sh` | Documentation Freshness Gate for registered generated/managed docs. |
| `scripts/generate-cli-reference.sh` | Regenerates `docs/cli-reference.md` from current CLI help/version output. |
| `Makefile` | Local build, test, docs-check, check, install, and uninstall targets. |

## First files to read before changing behavior

Read in this order:

1. [`issues/sand/CONTEXT.md`](https://github.com/onorbumbum/sand/blob/main/issues/sand/CONTEXT.md) for product names and implementation boundaries.
2. [`README.md`](https://github.com/onorbumbum/sand/blob/main/README.md) for current user-facing behavior and examples.
3. [`docs/cli-reference.md`](cli-reference.md) for the generated command surface.
4. The relevant `Sources/SandCore/` module.
5. The corresponding tests in `Tests/SandCoreTests/`.
6. [`docs/prompts/refresh-docs.md`](prompts/refresh-docs.md) only if the change has Documentation Impact.

## Local verification flow

Use fast, deterministic checks:

```sh
swift test
make docs-check
make check
```

- `swift test` runs the XCTest suite for `SandCore`.
- `make docs-check` verifies that registered generated/managed docs record the current Documentation Input Manifest hash.
- `make check` is the single local completion gate and currently runs `swift test` followed by the Documentation Freshness Gate.

For CLI documentation changes, regenerate the CLI Reference with:

```sh
scripts/generate-cli-reference.sh
```

Then rerun `make docs-check` and `swift test`.

## When documentation needs updating

Documentation updates are a consequence of product changes, not the default task. Refresh generated/managed docs when you change one of these:

- public CLI behavior or help text,
- README quickstart or examples,
- Sandbox VM domain language,
- onboarding or developer workflow instructions,
- docs freshness scripts or manifests.

When that happens, use [`docs/prompts/refresh-docs.md`](prompts/refresh-docs.md). Do not update a document's `docs-input-hash` unless the document has actually been refreshed against the current inputs.

## Avoiding stale documentation

- Treat `docs/docs-input-manifest.txt` as the curated list of inputs that can make generated/managed docs stale.
- Treat `docs/generated-docs-manifest.txt` as the list of docs that must record the current docs input hash.
- If `make docs-check` fails, refresh the affected docs against the current inputs instead of bypassing the gate.

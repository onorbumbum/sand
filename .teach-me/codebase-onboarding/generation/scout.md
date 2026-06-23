# Scout — codebase-onboarding

## Subject classification

- Domain: Swift CLI / local developer tooling / Sandbox VM product
- Learning modes: conceptual, procedural, diagnostic
- Grounding needs: repo, tests, docs, examples
- Source strategy: local-first; web research likely unnecessary unless the learner wants background on Swift Package/XCTest/Apple container

## Local sources inspected

- `README.md` — product purpose, prerequisites, install, quickstart, CLI surface, OAuth handoff, alpha boundaries.
- `docs/onboarding.md` — start-here workflow for humans and AI agents, repo map, verification flow.
- `docs/developer-guide.md` — architecture table, testing strategy, command-change workflow, Definition of Done.
- `docs/cli-reference.md` — generated command surface and current v1 boundaries.
- `issues/sand/CONTEXT.md` — canonical Sandbox VM domain language.
- `docs/adr/0001-separate-ephemeral-spec-from-sandbox-spec.md` — durable-vs-ephemeral design boundary.
- `Package.swift` and `Makefile` — Swift package shape and local gates.
- `Sources/sand/main.swift`, `Sources/SandCore/CLI/CLICommandRouter.swift` — app composition and command routing.

## Repo shape

- Swift package with executable product `sand` and library `SandCore`.
- Core code is organized by domain modules under `Sources/SandCore/`: CLI, Backend, Doctor, Domain, Ephemeral, FolderPolicy, Lifecycle, Metadata, Prompt, Spec, Status, WorkingDirectory.
- Tests live under `Tests/SandCoreTests/` and map directly to behavior areas.
- Documentation is generated/managed in several places; docs freshness is enforced with `make docs-check` and `make check`.

## Course implications

- Course should serve two entry paths: app user onboarding and developer/maintainer onboarding.
- Strong first lesson should establish product language: Host Mac, Sandbox VM, Allowed Folder, Guest State, Workload Command, Ephemeral Sandbox Run.
- User path should teach install/prereqs, create/add folders/run/shell/stop/delete, OAuth callback handoff, and ephemeral runs.
- Developer path should teach repo map, command routing, lifecycle/backend boundaries, test-first workflow, docs-refresh rules, and debugging via tests/logs/status/spec.
- Avoid deep implementation before the learner can run the app and explain the domain model.

## Constraints noticed

- `.teach-me/` appears not to be ignored in this git repo. Optional: add it to `.gitignore` if these course artifacts should stay local.
- Do not treat Pi as special product behavior; docs repeatedly state Pi is a normal Workload Command.
- Do not leak Apple container/backend details into user-facing language except in backend/deep implementation contexts.

# Resources

## Primary local docs

- `README.md` — product purpose, prerequisites, install, quickstart, Allowed Folder examples, OAuth callback handoff.
- `issues/sand/CONTEXT.md` — canonical Sandbox VM language and product model.
- `docs/onboarding.md` — repo map, working loop, local verification flow.
- `docs/developer-guide.md` — architecture, testing strategy, command-change workflow, Documentation Impact, Definition of Done.
- `docs/cli-reference.md` — generated command surface; refresh, do not hand-edit.
- `docs/adr/0001-separate-ephemeral-spec-from-sandbox-spec.md` — durable vs ephemeral design decision.

## Architecture entry points

- `Package.swift` — products and targets.
- `Sources/sand/main.swift` — executable composition root.
- `Sources/SandCore/CLI/CLICommandRouter.swift` — command parsing and dispatch.
- `Sources/SandCore/CLI/SandboxApplication.swift` — request/result boundary.
- `Sources/SandCore/Lifecycle/LifecycleCoordinator.swift` — durable lifecycle orchestration.
- `Sources/SandCore/Backend/SandboxBackend.swift` — backend adapter port.
- `Sources/SandCore/Spec/SandboxSpec.swift` — durable spec model/YAML.
- `Sources/SandCore/FolderPolicy/FolderPolicy.swift` — Allowed Folder policy.
- `Sources/SandCore/WorkingDirectory/WorkingDirectoryMapper.swift` — Host cwd to Guest Path mapping.
- `Sources/SandCore/Ephemeral/EphemeralRunCoordinator.swift` — bounded ephemeral run phases.

## Test landmarks

- `Tests/SandCoreTests/CLICommandRouterTests.swift`
- `Tests/SandCoreTests/SandboxSpecTests.swift`
- `Tests/SandCoreTests/FolderPolicyTests.swift`
- `Tests/SandCoreTests/WorkingDirectoryMapperTests.swift`
- `Tests/SandCoreTests/LifecycleCoordinatorTests.swift`
- `Tests/SandCoreTests/EphemeralRunCoordinatorTests.swift`
- `Tests/SandCoreTests/DoctorChecksTests.swift`
- `Tests/SandCoreTests/AppleContainerCLIBackendDoctorTests.swift`
- `Tests/SandCoreTests/BackendErrorTranslationTests.swift`
- `Tests/SandCoreTests/ArchitectureBoundaryTests.swift`

## Verification and docs commands

```bash
swift test --filter <TestClassOrMethod>
swift test
make docs-check
make check
scripts/generate-cli-reference.sh
scripts/docs-input-hash.sh docs/docs-input-manifest.txt
```

## Docs freshness files

- `docs/docs-input-manifest.txt` — inputs that can make generated/managed docs stale.
- `docs/generated-docs-manifest.txt` — registered generated/managed Markdown outputs.
- `scripts/docs-check.sh` — freshness gate.
- `docs/prompts/refresh-docs.md` — managed-section refresh workflow.

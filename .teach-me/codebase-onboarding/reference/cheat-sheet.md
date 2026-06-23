# sand Onboarding Cheat Sheet

## 1. User command loop

```bash
sand doctor
sand create demo
sand list
sand demo status
sand demo spec
sand folders add demo "$HOME/Projects/my-project" rw --as /workspace
sand folders add demo "$HOME/Reference" ro --as /reference
sand folders list demo
cd "$HOME/Projects/my-project" && sand demo run pwd
sand demo run pi
sand demo shell
sand demo stop
sand demo start
sand demo logs
sand ephemeral init ephemeral-spec.yaml
sand ephemeral --from ephemeral-spec.yaml
sand delete demo --force
```

Safety check: mount the smallest writable project folder; mount references read-only; confirm `folders list` before running powerful tools.

## 2. Mental model sketch

Host Mac contains a named Sandbox VM. Inside the VM is the Sandbox Guest. Only Allowed Folder arrows cross the boundary:

`Host path -> Guest Path (Access Mode)`

Add Guest State inside the guest, Runtime Instance as the disposable running process, Sandbox Session for interactive shell, and Workload Command for opaque commands like `pi`.

## 3. Repo map

| Concern | First source area | Representative tests | Docs |
|---|---|---|---|
| Command shape/help | `Sources/SandCore/CLI/` | `CLICommandRouterTests.swift` | `docs/cli-reference.md` |
| Durable lifecycle | `Sources/SandCore/Lifecycle/` | `LifecycleCoordinatorTests.swift` | `docs/developer-guide.md` |
| Sandbox Specs/YAML | `Sources/SandCore/Spec/` | `SandboxSpecTests.swift` | `issues/sand/CONTEXT.md` |
| Allowed Folders | `Sources/SandCore/FolderPolicy/` | `FolderPolicyTests.swift` | README examples |
| Working directory | `Sources/SandCore/WorkingDirectory/` | `WorkingDirectoryMapperTests.swift` | Developer guide |
| Ephemeral runs | `Sources/SandCore/Ephemeral/` | `EphemeralRunCoordinatorTests.swift` | ADR 0001 |
| Doctor checks | `Sources/SandCore/Doctor/` + backend doctor code | `DoctorChecksTests.swift`, `AppleContainerCLIBackendDoctorTests.swift` | README prerequisites |
| Backend wording/boundaries | `Sources/SandCore/Backend/` | `BackendErrorTranslationTests.swift`, `ArchitectureBoundaryTests.swift` | Developer guide |

## 4. Durable command trace: `sand demo run pwd`

`Sources/sand/main.swift` → construct metadata store/backend/coordinator/router → `CLICommandRouter.dispatch` → sandbox-first `demo run ...` → `RunRequest` with opaque `WorkloadCommand` → `LifecycleCoordinator.run` → read Sandbox Spec from Host Metadata → map Host Mac cwd with `WorkingDirectoryMapper` → backend `status` → backend `start` if stopped → backend `run` → `CommandResult.processExitCode`.

## 5. Folder and working-directory rules

- `rw` / `read-write` store as `read-write`.
- `ro` / `read-only` store as `read-only`.
- Default Guest Path: `/workspace/` + last component of the display host path.
- Same resolved host folder added again = update existing mapping.
- Different host folder with same Guest Path = reject.
- Overlapping resolved host folders = reject.
- Host cwd inside an Allowed Folder maps suffix into the Guest Path.
- Host cwd outside all Allowed Folders starts at `/workspace` with a warning.

## 6. Ephemeral run sequence

`ephemeral init` writes/prints a starter spec only. It does not create a Sandbox VM or Host Metadata.

`ephemeral --from` executes:

1. Create run record attempt
2. Run `beforeProvision` hooks on Host Mac
3. Generate concrete Sandbox Spec
4. Create temporary active Host Metadata
5. Provision/start Sandbox VM
6. Run Foreground Workload in Sandbox Guest
7. Attempt stop
8. Run `afterStop` hooks on Host Mac
9. Attempt delete cleanup
10. Write final result and print run record path

Cleanup/delete failures can dominate earlier workload failures because leftover resources need attention.

## 7. Debugging loop

Symptom → classify behavior area → targeted test → owning source → narrow reproduction → fix/assessment → targeted verification → `make check` → evidence note.

Useful commands:

```bash
swift test --filter CLICommandRouterTests
swift test --filter FolderPolicyTests
swift test --filter WorkingDirectoryMapperTests
swift test --filter LifecycleCoordinatorTests
swift test --filter EphemeralRunCoordinatorTests
swift test --filter BackendErrorTranslationTests
swift test --filter ArchitectureBoundaryTests
make check
```

Do not weaken tests to pass. Change expected output only when the product contract changed.

## 8. Small change workflow

1. Write desired behavior in one sentence.
2. Pick owning test file.
3. Add/update the smallest red test.
4. Change smallest source area.
5. Preserve boundaries: Workload Commands opaque; unsupported v1 surfaces rejected; request structs carry CLI data inward.
6. Run targeted `swift test --filter ...`.
7. Run `make check`.
8. Record evidence and Documentation Impact decision.

## 9. Documentation Impact

Docs-impacting: CLI help/output changes, README examples, public behavior, product language, contributor workflow, docs scripts, docs manifests.

Not docs-impacting: private refactors, helper renames, test-only cleanup, behavior-preserving internal rewrites.

Help-change path:

```bash
swift test --filter CLICommandRouterTests
scripts/generate-cli-reference.sh
make docs-check
make check
```

Never hand-edit generated CLI reference bodies or paste hashes into stale docs.

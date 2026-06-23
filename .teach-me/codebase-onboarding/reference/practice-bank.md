# Practice Bank

## 1. Safe-use dry run

Fill in real project/reference paths and one success signal per command:

```text
sand doctor →
sand create <name> →
sand folders add <name> <project> rw --as /workspace →
sand folders add <name> <reference> ro --as /reference →
sand folders list <name> →
cd <project> && sand <name> run pwd →
sand <name> run pi →
sand <name> shell →
sand <name> stop && sand <name> start →
sand <name> logs →
sand delete <name> --force →
```

Check: writable access is minimal; references are read-only; delete is deliberate.

## 2. Draw the model

Sketch: Host Mac → Sandbox VM → Sandbox Guest. Add two Allowed Folder arrows with Guest Path and Access Mode. Add Guest State, Runtime Instance, Sandbox Session, and Workload Command. Explain in three sentences how this protects the Host Mac.

## 3. Symptom-to-file drills

For each symptom, choose first test command and first source area:

1. Duplicate Guest Path is accepted for two different host folders.
2. Nested Host Mac cwd maps to `/workspace` instead of the expected Guest Path.
3. `sand mybox run pi --model gpt-5 -- literal` no longer passes args opaquely.
4. Backend error leaks raw `container start` wording.
5. `sand ephemeral init --stdout` appears to call application execution.
6. `sand doctor` reports a missing default image as ready.

Answer cues: FolderPolicy, WorkingDirectoryMapper, CLICommandRouter, BackendErrorTranslation/ArchitectureBoundary, CLICommandRouter ephemeral init, Doctor/backend doctor tests.

## 4. Durable command trace

Annotate one command in 8-12 lines:

```text
Command: sand demo run pwd
1. Sources/sand/main.swift —
2. CLICommandRouter —
3. RunRequest / SandboxApplication —
4. LifecycleCoordinator —
5. HostMetadataStore —
6. WorkingDirectoryMapper —
7. SandboxBackend —
8. CommandResult / process exit —
```

Stop at the backend port; do not explain low-level backend process construction.

## 5. Folder-policy predictions

Starting with no folders:

1. Add `/Users/onur/Projects/sand` as `rw`, no `--as`.
2. Add the same resolved host path as `ro --as /code`.
3. Add `/Users/onur/Projects` as `rw --as /workspace/projects`.
4. Add `/Users/onur/Downloads` as `ro --as /code`.
5. Launch from `/Users/onur/Desktop`.

Decide: accepted, update, rejected, or fallback. Include resulting Guest Path or warning.

## 6. Ephemeral triage map

Write the phase order and first artifact to inspect for each failed phase:

- beforeProvision
- provision/start
- Foreground Workload
- stop
- afterStop
- delete cleanup

Include: `sand ephemeral init` is template-only; `sand ephemeral --from` executes the bounded run.

## 7. Red-green-refactor checklist

Choose one tiny change and fill:

```text
Desired behavior:
Owning test file:
First red test name:
First source file:
Request/boundary file if CLI shape changes:
Boundary to preserve:
Targeted verification:
Full verification:
Evidence to record:
```

Good boundaries: Workload Commands stay opaque; unsupported v1 surfaces fail before application/backend work; generated docs are not edited before behavior is clear.

## 8. Documentation Impact classification

Classify each as docs-impacting or not, then choose verification path:

1. Add a supported flag to `sand create` and update help.
2. Fix an overlap-detection bug with user-visible rejection behavior.
3. Rename a private helper.
4. Change README quickstart commands.
5. Update `docs/docs-input-manifest.txt`.
6. Refactor backend error translation internals with identical user-facing output.

## 9. Capstone triage card

```text
User symptom:
Expected Sandbox VM behavior:
Observed or simulated behavior path:
First reproduction command or test:
Owning tests:
Owning source modules:
Minimal behavior change to make or describe:
Targeted verification:
Full verification:
Documentation Impact decision:
Final maintainer note:
Limitations / not verified:
```

Scenario: after `sand folders add demo ~/Projects/sand rw --as /workspace/sand`, `sand demo run pwd` from `~/Projects/sand/Sources` starts at `/workspace` with the fallback warning. Expected Guest Path: `/workspace/sand/Sources`.

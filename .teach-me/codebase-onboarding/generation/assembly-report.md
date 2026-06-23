# Assembly Report — codebase-onboarding

## Inputs

- Course directory: `/Users/onorbumbum/_PROJECTS/sand/.teach-me/codebase-onboarding`
- Plan: `plan.json`
- Draft directory: `generation/drafts`
- Drafts found: 10 JSON files
  - `lesson-01.json`
  - `lesson-02.json`
  - `lesson-03.json`
  - `lesson-04.json`
  - `lesson-05.json`
  - `lesson-06.json`
  - `lesson-07.json`
  - `lesson-08.json`
  - `lesson-09.json`
  - `lesson-10.json`
- Accepted: 10
- Rejected: 0
- Ordering source: `plan.json` `lessonOutline`
- Normalization applied:
  - Preserved planned lesson IDs and lesson order.
  - Joined array-form `signsOfSuccess` values into compact Markdown bullet strings for practice beats.
  - Normalized beat-level source objects into compact strings; preserved lesson-level source lists.

## Course Shape

- Lesson count: 10
- Total beats: 104
- Beat count range: 9–12 beats per lesson
- Interaction mix:
  - `explain`: 50
  - `single-choice`: 12
  - `multi-choice`: 11
  - `prediction`: 10
  - `practice`: 11
  - `checkpoint`: 10
- Final validation: passed with `validate-course.py`.

## Per-Lesson Summaries

### lesson-01 — Run the app like a user

- Objective: Use the main sand command loop from doctor through delete without touching internals.
- Summary: Walks the user path: verify host, create a Sandbox VM, attach intentional folders, run commands, inspect state, use Pi as a workload, and clean up.
- Main practice: Build a personal dry-run checklist with commands, real paths, and success signals.
- References used: `README.md`, `docs/cli-reference.md`, `issues/sand/CONTEXT.md`.
- References needed: quickstart loop, Allowed Folder examples, dry-run checklist.

### lesson-02 — Draw the Sandbox VM mental model

- Objective: Explain the product model using sand's canonical language.
- Summary: Builds the boundary diagram: Host Mac, Sandbox VM, Sandbox Guest, Allowed Folders, Guest Paths, Access Modes, Guest State, Runtime Instance, Sandbox Session, Workload Command, and outbound-only network handoff.
- Main practice: Draw and label the architecture sketch, then explain Host Mac protection in three sentences.
- References used: `issues/sand/CONTEXT.md`, `README.md`, `docs/cli-reference.md`.
- References needed: glossary cluster, diagram note, OAuth callback handoff reminder.

### lesson-03 — Tour the repo like a maintainer

- Objective: Map the repository into product docs, source modules, tests, scripts, and completion gates.
- Summary: Turns the repo into a behavior-first map: package targets, executable composition root, SandCore neighborhoods, test landmarks, docs, and Makefile gates.
- Main practice: Map three hypothetical tasks to first source area and first test file.
- References used: `Package.swift`, `Sources/sand/main.swift`, `Sources/SandCore/CLI/*`, `docs/onboarding.md`, `docs/developer-guide.md`, `docs/cli-reference.md`, `issues/sand/CONTEXT.md`, ADR 0001, `Makefile`.
- References needed: repo map, local gates, symptom-to-file drills.

### lesson-04 — Trace one durable command

- Objective: Follow a normal command from CLI arguments to application request to lifecycle coordination to backend boundary.
- Summary: Traces `sand demo run pwd` through `main.swift`, router dispatch, request structs, lifecycle orchestration, metadata, working-directory mapping, backend boundary, and exit code.
- Main practice: Annotate one durable command path in 8–12 lines.
- References used: `Sources/sand/main.swift`, `CLICommandRouter.swift`, `SandboxApplication.swift`, `LifecycleCoordinator.swift`, `SandboxBackend.swift`, `HostMetadataStore.swift`, `WorkingDirectoryMapper.swift`, routing and lifecycle tests, developer guide.
- References needed: durable command trace diagram, `sand create demo` trace drill.

### lesson-05 — Understand specs, folders, and working directories

- Objective: Explain how sand decides what a Sandbox VM can see and where commands start.
- Summary: Explains Sandbox Spec, FolderPolicy, Access Mode normalization, Guest Path derivation, duplicate/overlap rejection, and Host cwd mapping/fallback.
- Main practice: Predict accepted/rejected folder mappings and resulting command working directories.
- References used: `issues/sand/CONTEXT.md`, `SandboxSpec.swift`, `FolderPolicy.swift`, `WorkingDirectoryMapper.swift`, matching tests, `docs/cli-reference.md`.
- References needed: glossary terms, folder-policy decision rules, Access Mode table, CWD-to-Guest-Path drills.

### lesson-06 — Understand Ephemeral Sandbox Runs

- Objective: Explain why ephemeral runs are separate and trace their bounded lifecycle.
- Summary: Separates durable Sandbox Specs from Ephemeral Specs and traces `sand ephemeral --from` through hooks, foreground workload, cleanup, and run records.
- Main practice: Build an ephemeral triage map with phase order and first artifacts to inspect.
- References used: ADR 0001, `issues/sand/CONTEXT.md`, `docs/cli-reference.md`, `EphemeralRunCoordinator.swift`, ephemeral tests, router tests.
- References needed: ephemeral glossary terms, init-vs-run contrast, phase-order drill, cleanup precedence note.

### lesson-07 — Debug from symptoms to tests

- Objective: Use the test suite and repo map to diagnose behavior without guessing.
- Summary: Teaches symptom classification, targeted test selection, source inspection, narrow reproduction, evidence recording, and respect for boundary tests.
- Main practice: For failure reports, choose first targeted test command and first source area.
- References used: `docs/developer-guide.md`, `docs/onboarding.md`, `Makefile`, `CLICommandRouterTests.swift`, `BackendErrorTranslationTests.swift`, `ArchitectureBoundaryTests.swift`.
- References needed: symptom-to-test/source map, failure-report drills, final `make check` reminder.

### lesson-08 — Make a small change test-first

- Objective: Practice a safe code change workflow using a tiny command-surface or policy example.
- Summary: Converts the debugging map into red-green-refactor: desired behavior, owning test, smallest source change, boundary preservation, targeted verification, full gate.
- Main practice: Draft a tiny-change checklist with exact files, commands, and one boundary not crossed.
- References used: `docs/developer-guide.md`, `CLICommandRouter.swift`, `SandboxApplication.swift`, `CLICommandRouterTests.swift`, `FolderPolicyTests.swift`, `WorkingDirectoryMapperTests.swift`.
- References needed: tiny change type map, red-green-refactor prompts, Workload Command opacity reminder.

### lesson-09 — Know when documentation changes

- Objective: Apply the Documentation Impact rule and refresh docs only when needed.
- Summary: Defines Documentation Impact, generated/managed boundaries, docs manifests, hashing, freshness gates, and local Definition of Done.
- Main practice: Classify scenarios as docs-impacting or not, then choose the verification path.
- References used: `docs/developer-guide.md`, `docs/onboarding.md`, docs manifests, `docs/prompts/refresh-docs.md`, docs scripts, `generate-cli-reference.sh`, `Makefile`.
- References needed: Documentation Impact checklist, help-change command path, manifest roles, classification drills.

### lesson-10 — Integrated maintainer scenario

- Objective: Combine user model, repo map, tracing, testing, debugging, and docs decisions on one realistic issue.
- Summary: Runs a capstone Working Directory Mapping issue from product-language symptom to tests, source modules, minimal change, verification, docs impact, and maintainer note.
- Main practice: Complete a capstone triage card and write a concise evidence-based maintainer note.
- References used: `issues/sand/CONTEXT.md`, `docs/onboarding.md`, `docs/developer-guide.md`, `docs/cli-reference.md`, `WorkingDirectoryMapper.swift`, `WorkingDirectoryMapperTests.swift`, `LifecycleCoordinator.swift`, `LifecycleCoordinatorTests.swift`, `Makefile`.
- References needed: triage card template, symptom-to-verification row, glossary terms, local verification commands.

## References Generated

### `reference/glossary.md`

Term clusters:

- Product model: Host Mac, Sandbox VM, Sandbox Guest, Allowed Folder, Access Mode, Guest Path, Guest State, Runtime Instance, Sandbox Session, Workload Command.
- Specs and policy: Sandbox Spec, Host Metadata, FolderPolicy, Working Directory Mapping.
- Code architecture: CLICommandRouter, SandboxApplication, LifecycleCoordinator, SandboxBackend, CommandResult.
- Ephemeral runs: Ephemeral Spec, Ephemeral Sandbox Run, Before Provision Hook, Foreground Workload, After Stop Hook, Ephemeral Run Record.
- Documentation workflow: Documentation Impact, generated docs, managed README sections, Documentation Freshness Gate.

### `reference/cheat-sheet.md`

Sections:

1. User command loop
2. Mental model sketch
3. Repo map
4. Durable command trace
5. Folder and working-directory rules
6. Ephemeral run sequence
7. Debugging loop
8. Small change workflow
9. Documentation Impact

### `reference/resources.md`

Sections:

- Primary local docs
- Architecture entry points
- Test landmarks
- Verification and docs commands
- Docs freshness files

### `reference/practice-bank.md`

Sections:

1. Safe-use dry run
2. Draw the model
3. Symptom-to-file drills
4. Durable command trace
5. Folder-policy predictions
6. Ephemeral triage map
7. Red-green-refactor checklist
8. Documentation Impact classification
9. Capstone triage card

## Issues / Follow-Up

- No planned lesson draft was missing.
- No extra draft IDs were accepted.
- No rejected drafts.
- Final `lessons.json` validates.
- Viewer artifacts were not published by the assembler task; run `publish-viewer.py` as a separate publish step if needed.

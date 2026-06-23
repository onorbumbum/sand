# Teach-Me Lesson Writer Task: lesson-04

You are a lesson writer subagent for a `teach-me` course.

## Non-negotiable output

Write exactly one JSON file:

`/Users/onorbumbum/_PROJECTS/sand/.teach-me/codebase-onboarding/generation/drafts/lesson-04.json`

Do not modify any other file. Do not write HTML. Do not write Markdown as the deliverable.

## Current lesson outline

```json
{
  "id": "lesson-04",
  "title": "Trace one durable command",
  "objective": "Follow a normal command from CLI arguments to application request to lifecycle coordination to backend boundary.",
  "prerequisites": [
    "lesson-03"
  ],
  "enteringState": "Learner can name repo areas but has not followed execution flow.",
  "leavingState": "Learner can trace `sand demo run pwd` or `sand create demo` through router, request structs, LifecycleCoordinator, metadata, policies, and SandboxBackend.",
  "mustCover": [
    "main.swift construction of metadata store, backend, coordinator, router",
    "CLICommandRouter dispatch pattern",
    "SandboxApplication as the application boundary",
    "LifecycleCoordinator orchestration role",
    "SandboxBackend as narrow adapter port",
    "Where CommandResult becomes process exit code"
  ],
  "mustNotCover": [
    "Every command branch",
    "Deep Process execution code",
    "Ephemeral flow details"
  ],
  "practiceGoal": "Annotate the path of one command with file names and responsibilities.",
  "referenceTargets": [
    "cheat-sheet",
    "practice-bank"
  ]
}
```

## Full course outline for boundaries

Use this to avoid overlap. Stay in your lane: cover `mustCover`; avoid `mustNotCover`; do not teach other lesson objectives.

```json
[
  {
    "id": "lesson-01",
    "title": "Run the app like a user",
    "objective": "Use the main sand command loop from doctor through delete without touching internals.",
    "prerequisites": [
      "Local repo available",
      "Basic terminal comfort"
    ],
    "enteringState": "Learner has not used sand or knows only that it is a safer place to run tools.",
    "leavingState": "Learner can describe and rehearse the end-to-end user workflow: doctor, create, inspect, add folders, run, shell, stop/start, logs, ephemeral init/run, delete.",
    "mustCover": [
      "What sand is in one paragraph",
      "Prerequisites from README at a high level",
      "The quickstart command sequence",
      "Allowed Folder examples with read-write and read-only intent",
      "Pi as an ordinary Workload Command",
      "What success looks like after each command"
    ],
    "mustNotCover": [
      "Swift implementation details",
      "Backend adapter internals",
      "Deep Ephemeral Spec parsing",
      "Documentation refresh workflow"
    ],
    "practiceGoal": "Build a personal dry-run checklist for using sand safely on a project.",
    "referenceTargets": [
      "cheat-sheet",
      "practice-bank"
    ]
  },
  {
    "id": "lesson-02",
    "title": "Draw the Sandbox VM mental model",
    "objective": "Explain the product model using sand's canonical language.",
    "prerequisites": [
      "lesson-01"
    ],
    "enteringState": "Learner has seen the user workflow but may not know why each command exists.",
    "leavingState": "Learner can draw Host Mac, Sandbox VM, Sandbox Guest, Allowed Folders, Guest Paths, Guest State, Runtime Instance, Sandbox Session, and Workload Command relationships.",
    "mustCover": [
      "Canonical terms from issues/sand/CONTEXT.md",
      "Host Mac vs Sandbox Guest boundary",
      "Allowed Folder and Access Mode model",
      "Guest State persistence vs Runtime Instance disposability",
      "Workload Command opacity",
      "Outbound-only networking and OAuth callback handoff at a user-model level"
    ],
    "mustNotCover": [
      "Long glossary dump",
      "Apple container implementation details",
      "Unsupported future networking features"
    ],
    "practiceGoal": "Label a small architecture sketch and explain why sand protects the Host Mac.",
    "referenceTargets": [
      "glossary",
      "cheat-sheet"
    ]
  },
  {
    "id": "lesson-03",
    "title": "Tour the repo like a maintainer",
    "objective": "Map the repository into product docs, source modules, tests, scripts, and completion gates.",
    "prerequisites": [
      "lesson-02"
    ],
    "enteringState": "Learner understands the product vocabulary but not where the implementation lives.",
    "leavingState": "Learner can find the right file or test for a user-facing behavior without browsing randomly.",
    "mustCover": [
      "Package.swift products and targets",
      "Sources/sand/main.swift as composition root",
      "Sources/SandCore module folders and responsibilities",
      "Tests/SandCoreTests mapping to behavior areas",
      "README, onboarding, developer guide, CLI reference, CONTEXT, ADR",
      "Makefile gates: swift test, make docs-check, make check"
    ],
    "mustNotCover": [
      "Line-by-line source reading",
      "Changing files yet",
      "Assuming generated docs are hand-edited"
    ],
    "practiceGoal": "Given three hypothetical tasks, choose the first source file and first test file to inspect.",
    "referenceTargets": [
      "cheat-sheet",
      "practice-bank"
    ]
  },
  {
    "id": "lesson-04",
    "title": "Trace one durable command",
    "objective": "Follow a normal command from CLI arguments to application request to lifecycle coordination to backend boundary.",
    "prerequisites": [
      "lesson-03"
    ],
    "enteringState": "Learner can name repo areas but has not followed execution flow.",
    "leavingState": "Learner can trace `sand demo run pwd` or `sand create demo` through router, request structs, LifecycleCoordinator, metadata, policies, and SandboxBackend.",
    "mustCover": [
      "main.swift construction of metadata store, backend, coordinator, router",
      "CLICommandRouter dispatch pattern",
      "SandboxApplication as the application boundary",
      "LifecycleCoordinator orchestration role",
      "SandboxBackend as narrow adapter port",
      "Where CommandResult becomes process exit code"
    ],
    "mustNotCover": [
      "Every command branch",
      "Deep Process execution code",
      "Ephemeral flow details"
    ],
    "practiceGoal": "Annotate the path of one command with file names and responsibilities.",
    "referenceTargets": [
      "cheat-sheet",
      "practice-bank"
    ]
  },
  {
    "id": "lesson-05",
    "title": "Understand specs, folders, and working directories",
    "objective": "Explain how sand decides what a Sandbox VM can see and where commands start.",
    "prerequisites": [
      "lesson-04"
    ],
    "enteringState": "Learner knows command flow but not the key domain policies inside it.",
    "leavingState": "Learner can reason about Sandbox Specs, Allowed Folder updates, duplicate Guest Paths, overlapping host folders, Access Modes, and Working Directory Mapping.",
    "mustCover": [
      "SandboxSpec role and YAML surface",
      "FolderPolicy add/update/remove rules",
      "Default Guest Path derivation",
      "Access Mode aliases and canonical terms",
      "Overlap rejection and duplicate Guest Path rejection",
      "WorkingDirectoryMapper fallback behavior"
    ],
    "mustNotCover": [
      "Full YAML parser implementation",
      "Backend mount command construction details",
      "Unrelated command routing"
    ],
    "practiceGoal": "Predict accepted/rejected folder mappings and command working directories for realistic examples.",
    "referenceTargets": [
      "glossary",
      "cheat-sheet",
      "practice-bank"
    ]
  },
  {
    "id": "lesson-06",
    "title": "Understand Ephemeral Sandbox Runs",
    "objective": "Explain why ephemeral runs are separate and trace their bounded lifecycle.",
    "prerequisites": [
      "lesson-05"
    ],
    "enteringState": "Learner understands durable Sandbox VM commands but not ephemeral runs.",
    "leavingState": "Learner can describe Ephemeral Spec, beforeProvision hooks, Foreground Workload, afterStop hooks, cleanup, and Ephemeral Run Records.",
    "mustCover": [
      "ADR decision: durable Sandbox Specs separate from Ephemeral Specs",
      "`sand ephemeral init` as non-executing template generation",
      "`sand ephemeral --from` as explicit bounded run",
      "EphemeralRunCoordinator phases",
      "Run record purpose",
      "Failure/result precedence at a conceptual level"
    ],
    "mustNotCover": [
      "All EphemeralSpec parser details",
      "Every failure branch",
      "Treating ephemeral as normal lifecycle command shorthand"
    ],
    "practiceGoal": "Order the phases of an ephemeral run and identify where to look when one phase fails.",
    "referenceTargets": [
      "glossary",
      "cheat-sheet",
      "practice-bank"
    ]
  },
  {
    "id": "lesson-07",
    "title": "Debug from symptoms to tests",
    "objective": "Use the test suite and repo map to diagnose behavior without guessing.",
    "prerequisites": [
      "lesson-06"
    ],
    "enteringState": "Learner can trace architecture but may not know where to start when something fails.",
    "leavingState": "Learner can classify a symptom, pick representative tests, inspect source, reproduce locally, and record verification evidence.",
    "mustCover": [
      "Testing strategy table from developer guide",
      "Symptom-to-test mapping",
      "Targeted `swift test` vs full `make check`",
      "Reading failures for behavior intent",
      "Backend error translation and architecture boundary tests as guardrails",
      "Do not weaken tests to make changes pass"
    ],
    "mustNotCover": [
      "Writing a new feature yet",
      "Large XCTest tutorial",
      "Blindly running every command before forming a hypothesis"
    ],
    "practiceGoal": "For several failure reports, choose the first test command and first source area to inspect.",
    "referenceTargets": [
      "cheat-sheet",
      "practice-bank"
    ]
  },
  {
    "id": "lesson-08",
    "title": "Make a small change test-first",
    "objective": "Practice a safe code change workflow using a tiny command-surface or policy example.",
    "prerequisites": [
      "lesson-07"
    ],
    "enteringState": "Learner can debug and navigate but has not changed behavior.",
    "leavingState": "Learner can write or update a focused test, make the smallest code change, run targeted verification, and avoid breaking boundaries.",
    "mustCover": [
      "Start from the desired behavior and owning test file",
      "CLICommandRouterTests for command shapes",
      "Domain/policy tests for behavior rules",
      "Request structs and application boundary when command shape changes",
      "Keeping Workload Commands opaque",
      "Running targeted tests then make check"
    ],
    "mustNotCover": [
      "Inventing a large new feature",
      "Changing docs before behavior is clear",
      "Bypassing v1 unsupported-command boundaries"
    ],
    "practiceGoal": "Draft a red-green-refactor checklist for a hypothetical tiny change, including exact files and commands.",
    "referenceTargets": [
      "cheat-sheet",
      "practice-bank"
    ]
  },
  {
    "id": "lesson-09",
    "title": "Know when documentation changes",
    "objective": "Apply the Documentation Impact rule and refresh docs only when needed.",
    "prerequisites": [
      "lesson-08"
    ],
    "enteringState": "Learner can change behavior but may not understand generated docs and freshness gates.",
    "leavingState": "Learner can decide whether docs need refresh, run the correct scripts, preserve generated/managed boundaries, and avoid fake hash updates.",
    "mustCover": [
      "Documentation Impact definition",
      "Generated docs vs managed README sections",
      "docs-input-manifest and generated-docs-manifest roles",
      "scripts/generate-cli-reference.sh for CLI help changes",
      "scripts/docs-input-hash.sh and make docs-check at a high level",
      "Local Definition of Done from developer guide"
    ],
    "mustNotCover": [
      "Manual rewriting of generated docs",
      "Refreshing docs for every implementation-only refactor",
      "Docs process before learner understands behavior changes"
    ],
    "practiceGoal": "Classify example changes as docs-impacting or not, then choose the correct verification path.",
    "referenceTargets": [
      "cheat-sheet",
      "practice-bank"
    ]
  },
  {
    "id": "lesson-10",
    "title": "Integrated maintainer scenario",
    "objective": "Combine user model, repo map, tracing, testing, debugging, and docs decisions on one realistic issue.",
    "prerequisites": [
      "lesson-09"
    ],
    "enteringState": "Learner has learned each skill separately.",
    "leavingState": "Learner can handle a small sand issue from report to plan to verification evidence with confidence.",
    "mustCover": [
      "Read a user symptom in product language",
      "Reproduce or simulate the behavior path",
      "Choose tests and source modules",
      "Make or describe a minimal change",
      "Run targeted and full verification",
      "Decide Documentation Impact",
      "Write a concise final maintainer note with evidence and limitations"
    ],
    "mustNotCover": [
      "A huge multi-module feature",
      "Unverified claims",
      "Revision-history or process meta-commentary in final artifacts"
    ],
    "practiceGoal": "Complete a capstone triage card for a realistic sand bug or small enhancement.",
    "referenceTargets": [
      "glossary",
      "cheat-sheet",
      "practice-bank",
      "resources"
    ]
  }
]
```

## Plan

```json
{
  "schemaVersion": 1,
  "course": {
    "title": "sand Onboarding: User, Developer, Maintainer",
    "topic": "This codebase: onboarding a new developer and a new user to use the app, and helping a developer maintain and debug it",
    "mission": "Help a beginner use sand safely, understand the codebase as if they had built it, make small changes test-first, and debug maintenance failures with confidence.",
    "learnerProfile": {
      "currentLevel": "Beginner with sand, Swift/XCTest, and CLI developer tooling.",
      "targetLevel": "Can use sand end-to-end, explain the product/domain model, navigate the repo, trace commands through the architecture, make small tested changes, and debug common failures.",
      "preferences": [
        "Django-tutorial-style progression",
        "Project-based walkthroughs where each lesson builds on the previous one",
        "App walkthroughs before internals",
        "Conceptual diagrams and mental models before or alongside code",
        "Real repo files and commands",
        "Small toy examples only when they clarify the real repo"
      ],
      "constraints": [
        "Use only local repo sources",
        "No web research",
        "Balance Swift syntax, docs process, architecture theory, and internals by introducing each at the moment it becomes useful",
        "Preserve sand product language and v1 boundaries"
      ]
    },
    "subjectProfile": {
      "domain": "Swift CLI for Sandbox VM developer tooling",
      "learningMode": [
        "conceptual",
        "procedural",
        "diagnostic"
      ],
      "groundingNeeds": [
        "repo",
        "examples",
        "tests",
        "docs"
      ],
      "sourceStrategy": "local-first"
    }
  },
  "lessonOutline": [
    {
      "id": "lesson-01",
      "title": "Run the app like a user",
      "objective": "Use the main sand command loop from doctor through delete without touching internals.",
      "prerequisites": [
        "Local repo available",
        "Basic terminal comfort"
      ],
      "enteringState": "Learner has not used sand or knows only that it is a safer place to run tools.",
      "leavingState": "Learner can describe and rehearse the end-to-end user workflow: doctor, create, inspect, add folders, run, shell, stop/start, logs, ephemeral init/run, delete.",
      "mustCover": [
        "What sand is in one paragraph",
        "Prerequisites from README at a high level",
        "The quickstart command sequence",
        "Allowed Folder examples with read-write and read-only intent",
        "Pi as an ordinary Workload Command",
        "What success looks like after each command"
      ],
      "mustNotCover": [
        "Swift implementation details",
        "Backend adapter internals",
        "Deep Ephemeral Spec parsing",
        "Documentation refresh workflow"
      ],
      "practiceGoal": "Build a personal dry-run checklist for using sand safely on a project.",
      "referenceTargets": [
        "cheat-sheet",
        "practice-bank"
      ]
    },
    {
      "id": "lesson-02",
      "title": "Draw the Sandbox VM mental model",
      "objective": "Explain the product model using sand's canonical language.",
      "prerequisites": [
        "lesson-01"
      ],
      "enteringState": "Learner has seen the user workflow but may not know why each command exists.",
      "leavingState": "Learner can draw Host Mac, Sandbox VM, Sandbox Guest, Allowed Folders, Guest Paths, Guest State, Runtime Instance, Sandbox Session, and Workload Command relationships.",
      "mustCover": [
        "Canonical terms from issues/sand/CONTEXT.md",
        "Host Mac vs Sandbox Guest boundary",
        "Allowed Folder and Access Mode model",
        "Guest State persistence vs Runtime Instance disposability",
        "Workload Command opacity",
        "Outbound-only networking and OAuth callback handoff at a user-model level"
      ],
      "mustNotCover": [
        "Long glossary dump",
        "Apple container implementation details",
        "Unsupported future networking features"
      ],
      "practiceGoal": "Label a small architecture sketch and explain why sand protects the Host Mac.",
      "referenceTargets": [
        "glossary",
        "cheat-sheet"
      ]
    },
    {
      "id": "lesson-03",
      "title": "Tour the repo like a maintainer",
      "objective": "Map the repository into product docs, source modules, tests, scripts, and completion gates.",
      "prerequisites": [
        "lesson-02"
      ],
      "enteringState": "Learner understands the product vocabulary but not where the implementation lives.",
      "leavingState": "Learner can find the right file or test for a user-facing behavior without browsing randomly.",
      "mustCover": [
        "Package.swift products and targets",
        "Sources/sand/main.swift as composition root",
        "Sources/SandCore module folders and responsibilities",
        "Tests/SandCoreTests mapping to behavior areas",
        "README, onboarding, developer guide, CLI reference, CONTEXT, ADR",
        "Makefile gates: swift test, make docs-check, make check"
      ],
      "mustNotCover": [
        "Line-by-line source reading",
        "Changing files yet",
        "Assuming generated docs are hand-edited"
      ],
      "practiceGoal": "Given three hypothetical tasks, choose the first source file and first test file to inspect.",
      "referenceTargets": [
        "cheat-sheet",
        "practice-bank"
      ]
    },
    {
      "id": "lesson-04",
      "title": "Trace one durable command",
      "objective": "Follow a normal command from CLI arguments to application request to lifecycle coordination to backend boundary.",
      "prerequisites": [
        "lesson-03"
      ],
      "enteringState": "Learner can name repo areas but has not followed execution flow.",
      "leavingState": "Learner can trace `sand demo run pwd` or `sand create demo` through router, request structs, LifecycleCoordinator, metadata, policies, and SandboxBackend.",
      "mustCover": [
        "main.swift construction of metadata store, backend, coordinator, router",
        "CLICommandRouter dispatch pattern",
        "SandboxApplication as the application boundary",
        "LifecycleCoordinator orchestration role",
        "SandboxBackend as narrow adapter port",
        "Where CommandResult becomes process exit code"
      ],
      "mustNotCover": [
        "Every command branch",
        "Deep Process execution code",
        "Ephemeral flow details"
      ],
      "practiceGoal": "Annotate the path of one command with file names and responsibilities.",
      "referenceTargets": [
        "cheat-sheet",
        "practice-bank"
      ]
    },
    {
      "id": "lesson-05",
      "title": "Understand specs, folders, and working directories",
      "objective": "Explain how sand decides what a Sandbox VM can see and where commands start.",
      "prerequisites": [
        "lesson-04"
      ],
      "enteringState": "Learner knows command flow but not the key domain policies inside it.",
      "leavingState": "Learner can reason about Sandbox Specs, Allowed Folder updates, duplicate Guest Paths, overlapping host folders, Access Modes, and Working Directory Mapping.",
      "mustCover": [
        "SandboxSpec role and YAML surface",
        "FolderPolicy add/update/remove rules",
        "Default Guest Path derivation",
        "Access Mode aliases and canonical terms",
        "Overlap rejection and duplicate Guest Path rejection",
        "WorkingDirectoryMapper fallback behavior"
      ],
      "mustNotCover": [
        "Full YAML parser implementation",
        "Backend mount command construction details",
        "Unrelated command routing"
      ],
      "practiceGoal": "Predict accepted/rejected folder mappings and command working directories for realistic examples.",
      "referenceTargets": [
        "glossary",
        "cheat-sheet",
        "practice-bank"
      ]
    },
    {
      "id": "lesson-06",
      "title": "Understand Ephemeral Sandbox Runs",
      "objective": "Explain why ephemeral runs are separate and trace their bounded lifecycle.",
      "prerequisites": [
        "lesson-05"
      ],
      "enteringState": "Learner understands durable Sandbox VM commands but not ephemeral runs.",
      "leavingState": "Learner can describe Ephemeral Spec, beforeProvision hooks, Foreground Workload, afterStop hooks, cleanup, and Ephemeral Run Records.",
      "mustCover": [
        "ADR decision: durable Sandbox Specs separate from Ephemeral Specs",
        "`sand ephemeral init` as non-executing template generation",
        "`sand ephemeral --from` as explicit bounded run",
        "EphemeralRunCoordinator phases",
        "Run record purpose",
        "Failure/result precedence at a conceptual level"
      ],
      "mustNotCover": [
        "All EphemeralSpec parser details",
        "Every failure branch",
        "Treating ephemeral as normal lifecycle command shorthand"
      ],
      "practiceGoal": "Order the phases of an ephemeral run and identify where to look when one phase fails.",
      "referenceTargets": [
        "glossary",
        "cheat-sheet",
        "practice-bank"
      ]
    },
    {
      "id": "lesson-07",
      "title": "Debug from symptoms to tests",
      "objective": "Use the test suite and repo map to diagnose behavior without guessing.",
      "prerequisites": [
        "lesson-06"
      ],
      "enteringState": "Learner can trace architecture but may not know where to start when something fails.",
      "leavingState": "Learner can classify a symptom, pick representative tests, inspect source, reproduce locally, and record verification evidence.",
      "mustCover": [
        "Testing strategy table from developer guide",
        "Symptom-to-test mapping",
        "Targeted `swift test` vs full `make check`",
        "Reading failures for behavior intent",
        "Backend error translation and architecture boundary tests as guardrails",
        "Do not weaken tests to make changes pass"
      ],
      "mustNotCover": [
        "Writing a new feature yet",
        "Large XCTest tutorial",
        "Blindly running every command before forming a hypothesis"
      ],
      "practiceGoal": "For several failure reports, choose the first test command and first source area to inspect.",
      "referenceTargets": [
        "cheat-sheet",
        "practice-bank"
      ]
    },
    {
      "id": "lesson-08",
      "title": "Make a small change test-first",
      "objective": "Practice a safe code change workflow using a tiny command-surface or policy example.",
      "prerequisites": [
        "lesson-07"
      ],
      "enteringState": "Learner can debug and navigate but has not changed behavior.",
      "leavingState": "Learner can write or update a focused test, make the smallest code change, run targeted verification, and avoid breaking boundaries.",
      "mustCover": [
        "Start from the desired behavior and owning test file",
        "CLICommandRouterTests for command shapes",
        "Domain/policy tests for behavior rules",
        "Request structs and application boundary when command shape changes",
        "Keeping Workload Commands opaque",
        "Running targeted tests then make check"
      ],
      "mustNotCover": [
        "Inventing a large new feature",
        "Changing docs before behavior is clear",
        "Bypassing v1 unsupported-command boundaries"
      ],
      "practiceGoal": "Draft a red-green-refactor checklist for a hypothetical tiny change, including exact files and commands.",
      "referenceTargets": [
        "cheat-sheet",
        "practice-bank"
      ]
    },
    {
      "id": "lesson-09",
      "title": "Know when documentation changes",
      "objective": "Apply the Documentation Impact rule and refresh docs only when needed.",
      "prerequisites": [
        "lesson-08"
      ],
      "enteringState": "Learner can change behavior but may not understand generated docs and freshness gates.",
      "leavingState": "Learner can decide whether docs need refresh, run the correct scripts, preserve generated/managed boundaries, and avoid fake hash updates.",
      "mustCover": [
        "Documentation Impact definition",
        "Generated docs vs managed README sections",
        "docs-input-manifest and generated-docs-manifest roles",
        "scripts/generate-cli-reference.sh for CLI help changes",
        "scripts/docs-input-hash.sh and make docs-check at a high level",
        "Local Definition of Done from developer guide"
      ],
      "mustNotCover": [
        "Manual rewriting of generated docs",
        "Refreshing docs for every implementation-only refactor",
        "Docs process before learner understands behavior changes"
      ],
      "practiceGoal": "Classify example changes as docs-impacting or not, then choose the correct verification path.",
      "referenceTargets": [
        "cheat-sheet",
        "practice-bank"
      ]
    },
    {
      "id": "lesson-10",
      "title": "Integrated maintainer scenario",
      "objective": "Combine user model, repo map, tracing, testing, debugging, and docs decisions on one realistic issue.",
      "prerequisites": [
        "lesson-09"
      ],
      "enteringState": "Learner has learned each skill separately.",
      "leavingState": "Learner can handle a small sand issue from report to plan to verification evidence with confidence.",
      "mustCover": [
        "Read a user symptom in product language",
        "Reproduce or simulate the behavior path",
        "Choose tests and source modules",
        "Make or describe a minimal change",
        "Run targeted and full verification",
        "Decide Documentation Impact",
        "Write a concise final maintainer note with evidence and limitations"
      ],
      "mustNotCover": [
        "A huge multi-module feature",
        "Unverified claims",
        "Revision-history or process meta-commentary in final artifacts"
      ],
      "practiceGoal": "Complete a capstone triage card for a realistic sand bug or small enhancement.",
      "referenceTargets": [
        "glossary",
        "cheat-sheet",
        "practice-bank",
        "resources"
      ]
    }
  ]
}
```

## Scout

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


## Research

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


## Interview

# Interview — codebase-onboarding

## Transcript

**Q1. Main success outcome?**

User chose: all three, balanced.

Course must onboard:
- a new user to use the app,
- a new developer to understand and modify the codebase,
- a maintainer to debug failures confidently.

**Q2. Assumed level?**

User answered: beginner.

Interpretation:
- Beginner-friendly for Swift/XCTest, CLI tooling, and `sand` product knowledge.
- Do not skip core concepts, but avoid patronizing explanations.

**Q3. Preferred examples/materials?**

User likes the Django tutorial style:
- project-based,
- everything builds on previous steps,
- use repo files and commands,
- include toy examples where useful,
- start with app walkthroughs,
- explain concepts with graphs/mental models before or around code.

**Q4. What should be avoided?**

Avoid wrong timing, not whole categories.

Swift syntax, docs process, architecture theory, and internals are all acceptable when they appear at the right moment and support the current task.

**Q5. Tangible wins?**

By the end, learner should be able to:
- run a Sandbox VM end-to-end,
- map/read/write folders safely,
- run Pi inside `sand`,
- trace a CLI command from router → coordinator → backend,
- add/change a command with tests,
- debug a failing ephemeral run,
- hold a good mental model of what lives where and what modules do,
- feel as if they wrote the thing.

**Q6. Extra materials?**

Only this repo.

**Q7. Web research?**

Local repo is sufficient. Avoid web research.

## Final brief

Build a local-first course for beginner learners that combines app-user onboarding, developer onboarding, and maintainer/debugger onboarding. Use a Django-tutorial-like progression: start by using the product, then explain the mental model, then trace the implementation, then make and verify a small change, then debug realistic failures. The course should use real repo files and commands, with small toy examples only when they clarify a concept before applying it to the real code.


## Beat schema

Allowed beat types only:
- explain: {id,type,title?,text,sources?}
- single-choice: {id,type,prompt,choices:[{id,text,correct}],feedback?,sources?}
- multi-choice: {id,type,prompt,choices:[{id,text,correct}],feedback?,sources?}
- prediction: {id,type,prompt,answer,explanation?,sources?}
- practice: {id,type,instruction,copyText?,signsOfSuccess,hints?,sources?}
- checkpoint: {id,type,recap,readyPrompt?,sources?}
Constraints:
- 6-10 beats preferred; 12 max.
- Explain beats max ~120 words.
- Include at least 2 interactive beats: single-choice, multi-choice, prediction, or practice.
- No HTML/CSS/JS. Output JSON only.
- Use stable beat IDs: beat-01, beat-02, ...
- Keep practice generic enough for the subject; do not assume coding unless this course is coding.

## Required JSON shape

```json
{
  "id": "lesson-04",
  "title": "...",
  "objective": "...",
  "summary": "2-4 sentence summary",
  "sources": [{"label":"...","path":"..."}, {"label":"...","url":"..."}],
  "beats": [],
  "referenceNeeds": ["..."]
}
```

Final answer in your chat should be only a brief completion note after writing the file.

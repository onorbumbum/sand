---
title: Add Ephemeral Sandbox Runs for bounded create-run-cleanup-delete workflows
status: done
type: prd
category: enhancement
completed: 2026-06-03
labels:
  - enhancement
  - sand
  - sandbox-vm
  - ephemeral
  - automation
  - swift
  - macos
created: 2026-06-03
---

## Problem Statement

The user wants `sand` to support bounded agent and developer workflows where a Sandbox VM is created for one task, does useful work, performs host-side post-work actions, and is deleted automatically. Today `sand` supports durable Sandbox VMs well: a user can create a named Sandbox VM, configure Allowed Folders, run a Workload Command or shell, stop it, and return later. That is the right model for reusable environments, but it is awkward for one-shot agent work.

The desired workflow is: prepare Host Mac folders, create a temporary Sandbox VM from a declarative definition, mount those folders, run Pi, a shell, or another foreground workload inside the Sandbox Guest, wait until that foreground process exits, stop the Sandbox VM, run host-side post-work commands against host-visible outputs, delete the Sandbox VM, and preserve a record of what happened.

This must not make normal lifecycle commands surprising. `sand create`, `sand <name> start`, `sand <name> stop`, `sand <name> run`, and `sand <name> shell` should remain boring durable-Sandbox-VM commands. Ephemeral behavior must be explicit and must not add hidden hooks to durable Sandbox Specs.

The feature also needs to preserve the existing Host Mac credential boundary. The Foreground Workload runs inside the Sandbox Guest and should not inherit Host Mac credentials or environment. Host-side hooks are explicitly Host Mac automation and therefore run as the Host Mac user, but they must be clearly modeled and logged.

## Solution

Add an explicit Ephemeral Command:

```sh
sand ephemeral --from <ephemeral-spec.yaml> [-- <workload override...>]
```

An Ephemeral Spec is a separate YAML definition for a bounded Ephemeral Sandbox Run. It contains Sandbox VM template fields similar to a Sandbox Spec, plus optional Lifecycle Hooks, a Foreground Workload, and human context. It is not a durable Sandbox Spec and is not stored as an active reusable Sandbox VM config.

An Ephemeral Sandbox Run always follows the same high-level lifecycle once execution begins:

1. Parse and shape-validate the Ephemeral Spec and effective Foreground Workload.
2. Allocate an Ephemeral Run Identity with a run ID, generated Sandbox Name, and run record directory.
3. Create an immutable Ephemeral Run Record.
4. Run optional Before Provision Hooks on the Host Mac.
5. Resolve and validate Allowed Folders after Before Provision Hooks, because hooks may create folders.
6. Generate a concrete Sandbox Spec and store it in the run record.
7. Temporarily create active Host Metadata for the generated Sandbox VM.
8. Provision and start the Sandbox VM.
9. Run the Foreground Workload inside the Sandbox Guest using normal workload IO/TTY behavior.
10. When the Foreground Workload exits, attempt to stop the Sandbox VM.
11. Run optional After Stop Hooks on the Host Mac after the stop attempt.
12. Attempt to delete the Sandbox VM and remove temporary active Host Metadata.
13. Write a result summary and print final status plus the run record path.

Ephemeral Specs are separate from durable Sandbox Specs by design. This is recorded in `docs/adr/0001-separate-ephemeral-spec-from-sandbox-spec.md`. The separation avoids mixing reusable VM configuration with bounded create-run-cleanup-delete automation.

Ephemeral Run Records live under Host Metadata and are kept indefinitely by default. They preserve the source Ephemeral Spec, the generated concrete Sandbox Spec, event logs, hook output files, and final result summary. Completed ephemeral Sandbox VMs are not kept as active reusable Sandbox VMs, but past run artifacts remain inspectable and reusable.

## User Stories

1. As the user, I want to run a bounded ephemeral workflow, so that a Sandbox VM can be created, used, stopped, and deleted for one task.
2. As the user, I want the ephemeral workflow to be explicit, so that normal durable Sandbox VM commands remain unsurprising.
3. As the user, I want the command to be `sand ephemeral --from <yaml>`, so that ephemeral is understood as the whole create-run-stop-delete operation.
4. As the user, I want to provide an Ephemeral Spec YAML file, so that bounded workflows are declarative and reusable.
5. As the user, I want the Ephemeral Spec to be separate from durable Sandbox Specs, so that reusable VM configuration is not mixed with one-shot automation.
6. As the user, I want the Ephemeral Spec to include normal VM template fields like image, resources, and Allowed Folders, so that I can describe the temporary Sandbox VM in one file.
7. As the user, I want image and resources to be optional in the Ephemeral Spec, so that common ephemeral workflows use the normal Sandbox VM defaults.
8. As the user, I want `schemaVersion: 1` in the Ephemeral Spec, so that the spec format is versioned like other declarative config.
9. As the user, I want an optional description in the Ephemeral Spec, so that run history has human context.
10. As the user, I want an optional `namePrefix`, so that generated ephemeral Sandbox Names are understandable in logs and lists.
11. As the user, I want `namePrefix` to default to `ephemeral`, so that simple specs require less YAML.
12. As the user, I want generated Sandbox Names to include a timestamp and short random suffix, so that names are unique and human-readable.
13. As the user, I want invalid `namePrefix` values to fail validation, so that `sand` does not silently sanitize names into surprising values.
14. As the user, I want the generated Sandbox Name to satisfy Sandbox Name validation, so that ephemeral VMs behave like normal Sandbox VMs while active.
15. As the user, I want Before Provision Hooks to run on the Host Mac before provisioning, so that I can prepare folders before they are mounted.
16. As the user, I want Before Provision Hooks to run before folder path resolution, so that a hook can create a folder referenced by an Allowed Folder.
17. As the user, I want Before Provision Hooks to be optional, so that simple ephemeral workflows do not require setup commands.
18. As the user, I want After Stop Hooks to run on the Host Mac after the foreground work ends and after `sand` attempts to stop the Sandbox VM, so that I can process host-visible results.
19. As the user, I want After Stop Hooks to be optional, so that deletion-only ephemeral workflows are simple.
20. As the user, I want After Stop Hooks not to imply cleanup only, so that I can use them for copying, archiving, committing, uploading, or other post-work actions.
21. As the user, I want hooks to use the same structured command shape as workloads, so that the YAML stays consistent.
22. As the user, I want hook and workload `args` to be optional, so that commands without arguments are easy to write.
23. As the user, I want empty command strings to be invalid, so that malformed specs fail before creating resources.
24. As the user, I want command-list shorthand omitted in v1, so that there is one clear command shape.
25. As the user, I want hooks to run relative to the Ephemeral Spec directory, so that project-local paths are stable regardless of caller cwd.
26. As the user, I want relative Allowed Folder host paths to resolve relative to the Ephemeral Spec directory, so that specs are portable.
27. As the user, I want absolute Allowed Folder host paths to be supported, so that I can intentionally reference fixed host locations.
28. As the user, I want `~/...` host paths to expand to the Host Mac home directory, so that common user paths are convenient.
29. As the user, I want user-authored Ephemeral Specs to reject `resolvedHostPath`, so that generated Host Metadata does not leak into reusable user intent.
30. As the user, I want resolved paths recorded in the generated concrete Sandbox Spec, so that run history shows exactly what was mounted.
31. As the user, I want Allowed Folder `guestPath` to be optional, so that defaults are consistent with normal folder behavior.
32. As the user, I want default Guest Paths to use the display host path's last component, so that `./work` maps predictably to `/workspace/work`.
33. As the user, I want read-write Allowed Folders in ephemeral runs, so that the Foreground Workload can produce host-visible outputs.
34. As the user, I want read-only Allowed Folders in ephemeral runs, so that reference material can be visible without being mutable.
35. As the user, I want full folder policy validation after Before Provision Hooks, so that duplicate Guest Paths and overlapping resolved host folders are still rejected.
36. As the user, I want structural validation before Before Provision Hooks, so that malformed YAML does not run host commands.
37. As the user, I want the Ephemeral Run Record to be created after structural validation but before hooks run, so that real run attempts are recorded without filling history with typos.
38. As the user, I want malformed specs to fail without a run record, so that history contains actual run attempts.
39. As the user, I want missing effective workloads to fail without a run record, so that no host setup runs when there is no command to execute.
40. As the user, I want the Foreground Workload to come from the Ephemeral Spec by default, so that repeated runs are easy.
41. As the user, I want a CLI workload override after `--`, so that I can reuse the same spec with a different foreground command.
42. As the user, I want a CLI workload override to preserve YAML `workdir` when present, so that I can change what runs without changing where it runs.
43. As the user, I want CLI workload override to be allowed even when YAML has no workload, so that a spec can define the VM template and hooks while the command comes from the CLI.
44. As the user, I want `workload.workdir` to be optional, so that the common case can default from Allowed Folders.
45. As the user, I want the default Foreground Workload working directory to be the first read-write Allowed Folder's Guest Path, so that work starts in the host-visible workspace by default.
46. As the user, I want the Foreground Workload to fail before provisioning if there is no read-write Allowed Folder and no explicit workdir, so that work is not silently lost when the Sandbox VM is deleted.
47. As the user, I want interactive workloads like Pi or bash to work naturally, so that ephemeral can support manual sessions as well as scripts.
48. As the user, I want ephemeral cleanup to begin when the Foreground Workload exits, so that exiting Pi or a shell completes the bounded workflow.
49. As the user, I want the Foreground Workload to use the same IO/TTY behavior as normal `sand <name> run`, so that interactive terminal behavior is preserved.
50. As the user, I do not want workload transcripts captured by default, so that interactive sessions are not recorded unexpectedly or leak secrets.
51. As the user, I want hook stdout and stderr captured, so that setup and post-work automation can be debugged.
52. As the user, I want hook output stored as separate files referenced by event logs, so that multiline output does not bloat structured logs.
53. As the user, I want hook output not to be automatically redacted in v1, so that behavior is predictable and I know to avoid printing secrets.
54. As the user, I want host hooks to run as the Host Mac user, so that they can operate on host-visible files naturally.
55. As the user, I want host hooks to inherit the `sand` process environment, so that normal host tools work with expected PATH and environment.
56. As the user, I do not want special `SAND_*` hook environment variables in v1, so that the first version stays simple.
57. As the user, I want host hook commands to resolve through PATH, so that normal command invocation works.
58. As the user, I want host hooks to use captured non-interactive IO, so that hooks are automation rather than hidden interactive prompts.
59. As the user, I do not want guest workload environment customization in v1, so that the Host Mac credential boundary stays simple.
60. As the user, I want Before Provision Hook failure to abort before provisioning, so that failed setup does not create a partial VM.
61. As the user, I want Before Provision Hook failure not to run After Stop Hooks, so that post-work actions do not run when no work happened.
62. As the user, I want provisioning or start failure before workload start to skip After Stop Hooks, so that post-work actions do not run when the workload never ran.
63. As the user, I want provisioning/start failure to still attempt cleanup of any partially created resources, so that ephemeral does not leave resources behind unnecessarily.
64. As the user, I want Foreground Workload failure to still attempt stop, After Stop Hooks, and delete, so that ephemeral semantics remain strong.
65. As the user, I want After Stop Hooks to run after a workload exits nonzero, so that partial outputs can still be processed.
66. As the user, I want After Stop Hooks to run after a stop attempt even if stop fails, so that host-visible outputs can still be processed.
67. As the user, I want After Stop Hook failure to stop remaining after-stop hooks, so that dependent post-work commands do not run after a failed earlier step.
68. As the user, I want deletion still attempted after After Stop Hook failure, so that ephemeral resources are cleaned up by default.
69. As the user, I want no preserve-on-failure option in v1, so that ephemeral means create-run-stop-post-work-delete consistently.
70. As the user, I want delete failure to be recorded clearly, so that I know what manual cleanup is needed.
71. As the user, I want delete failure to leave enough active metadata and backend resources for manual cleanup, so that I can recover from backend problems.
72. As the user, I want final CLI output to include run status and the run record path, so that I can inspect history immediately.
73. As the user, I want failed final CLI output to include failed phase and exit code, so that I know where the run failed.
74. As the user, I want successful final CLI output to include the run record path, so that I can review what happened later.
75. As the user, I want the final process exit code to reflect the most important failed phase, so that scripts can react to failure.
76. As the user, I want cleanup/delete failures to override earlier workload failure in the final exit code, so that immediate cleanup problems are not hidden.
77. As the user, I want Ephemeral Run Records kept indefinitely in v1, so that I can inspect and reuse past specs manually.
78. As the user, I want run records to include the source Ephemeral Spec, so that I can see the original intent.
79. As the user, I want run records to include the generated concrete Sandbox Spec, so that I can see exactly what ran.
80. As the user, I want run records to include structured event logs, so that run history can be inspected and tested.
81. As the user, I want run records to include `result.json`, so that final status is easy to read without scanning logs.
82. As the user, I want events recorded incrementally, so that a crash mid-run still leaves useful history.
83. As the user, I want events stored as JSON Lines, so that logs are structured but still inspectable.
84. As the user, I want no dry-run command in v1, so that the first version remains focused.
85. As the user, I want no separate validate command in v1, so that validation happens at run start without extra command surface.
86. As the user, I want reusable Ephemeral Specs over time, so that I can run the same workflow again later.
87. As the user, I do not need safe concurrent runs from the same Ephemeral Spec guaranteed in v1, so that the implementation stays simple.
88. As the user, I want generated run IDs and Sandbox Names to reduce accidental name collisions, so that overlapping attempts are less likely to collide at the VM name level.
89. As the user, I want active ephemeral Sandbox VMs to appear in `sand list` while running, so that they are visible as real temporary VMs.
90. As the user, I want active ephemeral specs removed after successful delete, so that completed ephemeral VMs do not become reusable durable Sandbox VMs.
91. As the user, I want the copied source and generated specs in the run record to remain after active metadata removal, so that history is preserved.
92. As the maintainer, I want an EphemeralRunCoordinator deep module, so that the create-run-stop-post-work-delete saga is hidden behind a small testable interface.
93. As the maintainer, I want EphemeralRunCoordinator to depend on lower-level ports rather than LifecycleCoordinator, so that durable lifecycle behavior does not grow special-case flags.
94. As the maintainer, I want EphemeralRunCoordinator to reuse existing domain types and policies, so that Sandbox VM rules remain consistent.
95. As the maintainer, I want temporary active specs written through Host Metadata, so that list/status/delete visibility and duplicate protection are reused.
96. As the maintainer, I want active specs written before backend provisioning, so that normal metadata-before-backend invariants are preserved.
97. As the maintainer, I want generated concrete specs written to the run record before active metadata creation, so that failed provisioning still records exactly what was attempted.
98. As the maintainer, I want the Foreground Workload to use the existing backend run path, so that IO/TTY behavior and backend abstraction are reused.
99. As the maintainer, I want host hooks to use a HostCommandRunner port, so that host automation is not coupled to backend command plumbing.
100. As the maintainer, I want run records managed by an EphemeralRunRecordStore port, so that history artifacts are separate from active Host Metadata.
101. As the maintainer, I want EphemeralRunRecordStore to allocate the whole run identity, so that run ID, Sandbox Name, and record path are generated in one DRY place.
102. As the maintainer, I want EphemeralSpec to be a separate type from SandboxSpec, so that separate concepts do not blur.
103. As the maintainer, I want EphemeralSpec and SandboxSpec to share YAML/value parsing helpers where appropriate, so that parsing mechanics are not duplicated.
104. As the maintainer, I want an EphemeralRunPlan, so that spec parsing, defaulting, and CLI override behavior can be tested without touching backend resources.
105. As the maintainer, I want identity allocation to happen after building a valid plan, so that planning is independent from filesystem/run-history allocation.
106. As the maintainer, I want unresolved Allowed Folder intents in the plan, so that resolution can happen after Before Provision Hooks.
107. As the maintainer, I want concrete Sandbox Spec generation to reuse FolderPolicy, so that duplicate, overlap, access mode, and default Guest Path behavior remains consistent.
108. As the maintainer, I want lifecycle locks held only during mutation phases, not during the whole foreground workload, so that interactive ephemeral sessions do not block unrelated lifecycle commands for hours.
109. As the maintainer, I want MVP behavior not to specially protect the generated ephemeral VM from normal commands while running, so that implementation remains small.
110. As the maintainer, I want an ADR documenting separate Ephemeral Spec/Run Record from durable Sandbox Spec, so that future maintainers understand the boundary.

## Implementation Decisions

- Add an explicit Ephemeral Command shaped as `sand ephemeral --from <ephemeral-spec.yaml> [-- <workload override...>]`.
- Omit `run` from the command because ephemeral is the full create-run-stop-post-work-delete operation.
- Use a separate Ephemeral Spec rather than adding hooks/workload fields to durable Sandbox Specs.
- Use a separate Ephemeral Run Record rather than preserving completed ephemeral Sandbox VMs as active reusable Sandbox Specs.
- Follow ADR `0001-separate-ephemeral-spec-from-sandbox-spec`.
- Ephemeral Sandbox Runs always create, attempt stop, and attempt delete once provisioning starts.
- The first version does not support preserve-on-failure.
- The first version does not support dry-run or validate subcommands.
- The first version does not promise safe concurrent runs from the same Ephemeral Spec.
- Ephemeral Specs use `schemaVersion: 1`.
- Ephemeral Specs support optional `description` copied to the run record.
- Ephemeral Specs support optional `namePrefix`, defaulting to `ephemeral`.
- Generated Sandbox Names use name prefix plus timestamp plus short random suffix.
- Invalid name prefixes fail validation rather than being sanitized.
- Generated Sandbox Names must pass Sandbox Name validation.
- Ephemeral Specs may omit image and resources and use normal Sandbox VM defaults.
- Ephemeral Specs may omit Allowed Folders only when an explicit workload workdir exists.
- Ephemeral Allowed Folders support read-write and read-only Access Modes.
- Ephemeral Allowed Folder `guestPath` is optional and defaults consistently with normal folder policy.
- Ephemeral Allowed Folder `resolvedHostPath` is rejected in user-authored Ephemeral Specs.
- Relative Ephemeral Spec host paths resolve relative to the Ephemeral Spec directory.
- Host path resolution and full folder policy validation happen after Before Provision Hooks.
- Basic shape validation happens before Before Provision Hooks.
- Before Provision Hooks and After Stop Hooks are optional and may be omitted or empty.
- Hooks and Foreground Workload use the same structured command shape: `command` plus optional `args`.
- `args` defaults to an empty array for hooks and workload.
- Command-list shorthand is omitted in v1.
- Empty command strings are invalid.
- Hook commands run on the Host Mac as the Host Mac user.
- Hook commands run relative to the Ephemeral Spec directory.
- Hook commands inherit the `sand` process environment.
- Hook commands resolve through PATH.
- Hook commands use captured non-interactive IO.
- Hook stdout and stderr are recorded in separate run-record files.
- Hook output is not automatically redacted in v1.
- Special `SAND_*` hook environment variables are omitted in v1.
- Host-side hook custom env is omitted in v1.
- Foreground Workload runs inside the Sandbox Guest.
- Foreground Workload uses normal workload IO/TTY behavior.
- Foreground Workload transcript capture is omitted in v1.
- Guest workload environment customization is omitted in v1.
- Effective workload comes from CLI override when present, otherwise from the Ephemeral Spec.
- CLI workload override uses `--` as the boundary and preserves YAML workload workdir when present.
- If neither YAML workload nor CLI override exists, validation fails before a run record is created.
- Workload `workdir` lives under workload, not top-level.
- Workload `workdir` defaults to the first read-write Allowed Folder's effective Guest Path.
- If no read-write Allowed Folder exists and no explicit workdir exists, validation fails before provisioning.
- Before Provision Hook failure aborts before provisioning and skips After Stop Hooks.
- Provisioning or start failure before workload start skips After Stop Hooks but still attempts cleanup of partial resources.
- Foreground Workload exit, whether zero or nonzero, triggers stop attempt, After Stop Hooks, and delete attempt.
- After Stop Hooks run after the stop attempt and do not require successful stop.
- After Stop Hook failure stops remaining after-stop hooks but still attempts delete.
- Delete failure records manual cleanup guidance.
- Final CLI output includes status and run record path.
- Failed final CLI output includes failed phase, exit code, and run record path.
- Final process exit code reflects phase priority, with later cleanup/delete failures overriding earlier workload failure when they require immediate attention.
- Ephemeral Run Records are created after shape validation and before Before Provision Hooks.
- Ephemeral Run Records record the generated Sandbox Name before hooks run.
- Ephemeral Run Records include the source Ephemeral Spec.
- Ephemeral Run Records include the generated concrete Sandbox Spec.
- Ephemeral Run Records include structured incremental JSON Lines events.
- Ephemeral Run Records include hook stdout/stderr files referenced by events.
- Ephemeral Run Records include a separate `result.json` summary.
- Ephemeral Run Records are kept indefinitely by default in v1.
- Active temporary Sandbox Specs may exist while an ephemeral run is active.
- Active temporary Sandbox Specs are removed after successful delete.
- Active ephemeral Sandbox VMs appear in `sand list` while running.
- Implement a deep EphemeralRunCoordinator module that owns phase ordering, cleanup semantics, and result precedence.
- EphemeralRunCoordinator depends directly on lower-level ports rather than calling LifecycleCoordinator.
- EphemeralRunCoordinator reuses existing SandboxSpec, SandboxName, ResourceProfile, SandboxImage, GuestPath, AccessMode, WorkloadCommand, FolderPolicy, SandboxBackend, and HostMetadataStore concepts.
- EphemeralRunCoordinator writes temporary active specs through HostMetadataStore create/delete behavior.
- EphemeralRunCoordinator calls backend provision/start/run/stop/delete rather than introducing ephemeral backend operations.
- Add a HostCommandRunner port for host-side hooks.
- Add an EphemeralRunRecordStore port for run identity allocation and run record writes.
- EphemeralRunRecordStore allocates the full Ephemeral Run Identity: run ID, generated Sandbox Name, and record path.
- Add a separate EphemeralSpec type and parser.
- Extract shared YAML/value parsing helpers where useful so SandboxSpec and EphemeralSpec do not duplicate parsing mechanics.
- Add an EphemeralRunPlan as an immutable validated user-intent value.
- Build the EphemeralRunPlan before identity allocation.
- Keep unresolved Allowed Folder intents in the plan.
- Resolve folder intents into a concrete SandboxSpec after Before Provision Hooks.
- Use FolderPolicy to build and validate concrete Allowed Folders.
- Hold lifecycle mutation locks during active metadata/backend mutation phases, not during the entire Foreground Workload.
- Do not add special protection against normal commands targeting the generated ephemeral Sandbox Name in v1.

## Testing Decisions

- Tests should focus on external behavior and module boundaries, not incidental implementation details.
- EphemeralSpec parsing tests should cover schema version, optional defaults, invalid fields, rejected `resolvedHostPath`, command shape, optional args, empty command validation, namePrefix validation, description, and workload override behavior.
- EphemeralRunPlan tests should cover effective workload selection, CLI override preserving workdir, default workload workdir from first read-write Allowed Folder, failure without read-write folder or explicit workdir, optional guestPath defaulting, and unresolved folder intents.
- Folder resolution tests should verify relative paths resolve relative to the Ephemeral Spec directory after Before Provision Hooks and that FolderPolicy still catches duplicate Guest Paths and overlapping resolved host paths.
- EphemeralRunCoordinator tests should use fake backend, fake Host Metadata store, fake HostCommandRunner, and fake EphemeralRunRecordStore to verify phase ordering.
- Coordinator tests should cover successful run, beforeProvision failure, provision failure, start failure, workload nonzero exit, stop failure, afterStop failure, delete failure, and result precedence.
- Coordinator tests should verify active Host Metadata is created before backend provisioning and removed after successful delete.
- Coordinator tests should verify generated concrete Sandbox Spec is written to the run record before active metadata creation.
- Coordinator tests should verify After Stop Hooks run after workload exit and stop attempt, including when stop fails.
- Coordinator tests should verify After Stop Hooks do not run when provisioning/start fails before the workload starts.
- HostCommandRunner tests should verify hooks run with captured non-interactive IO, inherited environment, PATH resolution, and spec-directory working directory.
- Run record tests should verify identity allocation, source spec copy, generated spec copy, JSONL event appends, hook output file paths, result summary, and indefinite record retention behavior.
- CLI routing tests should verify `sand ephemeral --from <file>`, `--` workload override, validation errors, and no conflict with existing sandbox-first commands.
- Backend integration should reuse prior backend validation patterns; most ephemeral behavior should be covered by deterministic tests with fake backend and fake stores.
- Live validation should include at least one real ephemeral run that creates a folder in Before Provision, mounts it, runs a foreground command that writes to it, runs an After Stop Hook against host-visible output, deletes the Sandbox VM, and leaves a run record.
- Live validation should include a nonzero workload exit proving cleanup/delete still happens and final failure is reported.
- Live validation should include an interactive-compatible workload smoke path if practical, relying on existing TTY behavior rather than transcript capture.
- Existing prior art includes CLI router tests for command parsing, lifecycle coordinator tests for phase behavior, FolderPolicy tests for folder validation, SandboxSpec tests for YAML parsing/defaults, HostMetadataStore tests for active spec behavior, and backend adapter tests for run/start/stop/delete calls.

## Out of Scope

- Slicing implementation issues; this PRD intentionally captures the full feature and slicing will happen later.
- Adding lifecycle hooks to durable Sandbox Specs.
- Running hooks automatically during normal `create`, `start`, `stop`, `run`, `shell`, or `apply` commands.
- A `preserveOnFailure` option in v1.
- Ephemeral dry-run command.
- Ephemeral validate command.
- Safe concurrent runs from the same Ephemeral Spec as a guaranteed behavior.
- Special protection or hiding for generated ephemeral Sandbox Names while active.
- Workload transcript capture.
- Automatic secret redaction in hook logs.
- Guest workload environment customization.
- Host hook custom environment fields.
- Special `SAND_*` hook environment variables.
- Interactive host hooks.
- Command-list shorthand in YAML.
- A cleanup/retention command for old Ephemeral Run Records.
- Inbound networking or port publishing.
- Pi-specific ephemeral shortcuts.
- Desktop UI.

## Completion Record

Completed on 2026-06-03 through the local issue queue from `issues/sand/022-minimal-ephemeral-command-happy-path.md` through `issues/sand/034-ephemeral-docs-cli-help-acceptance-evidence.md`.

Delivered scope:

- Added the explicit `sand ephemeral --from <ephemeral-spec.yaml> [-- <workload override...>]` command.
- Implemented Ephemeral Spec parsing, shape validation, generated run identity, CLI workload override, default workload workdir behavior, lifecycle hooks, cleanup semantics, result precedence, run records, active metadata visibility, and durable lifecycle regression coverage.
- Preserved the durable-vs-ephemeral boundary documented in `docs/adr/0001-separate-ephemeral-spec-from-sandbox-spec.md`.
- Refreshed generated docs and CLI help/reference for the new command surface.
- Bumped installed development version to `0.2.0-dev` after completion.

Verification recorded by the closing issues includes deterministic XCTest coverage, documentation freshness checks, `make check`, and final live acceptance evidence in `issues/sand/done/034-ephemeral-docs-cli-help-acceptance-evidence.md`.

## Further Notes

This feature was implemented test-first. The architectural goal was a deep EphemeralRunCoordinator with a small interface that hides a complicated saga. Avoid scattering `ephemeral` conditionals across normal lifecycle code. Reuse existing domain types and policies where they represent real shared rules, but keep Ephemeral Spec, run planning, host hooks, and run records as separate concepts.

The key product distinction is durable versus ephemeral: durable Sandbox VMs are reusable named environments managed by normal lifecycle commands; Ephemeral Sandbox Runs are bounded workflows that create, use, post-process, delete, and record what happened.

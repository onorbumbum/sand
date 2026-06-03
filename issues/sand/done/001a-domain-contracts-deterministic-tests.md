---
title: Implement deterministic domain contracts before real backend slices
status: needs-triage
type: issue
category: enhancement
labels:
  - needs-triage
  - afk
  - sand
  - sandbox-vm
  - domain
  - testing
  - sandbox-spec
created: 2026-05-19
---

## Parent

- `issues/sand/prd-sand-sandbox-vm.md`

## What to build

Implement the core deterministic domain/spec behavior with tests before broad real-backend feature work. This creates the executable contracts for the Sandbox Spec, Host Metadata, Folder Policy, Working Directory Mapping, CLI parsing, and Lifecycle Coordinator behavior using test-only fakes where external backend behavior is not the subject under test.

This issue is the first real tracer bullet through the application model: parse a command, mutate or read the Sandbox Spec/Host Metadata, coordinate lifecycle intent through a fake backend, and verify externally visible behavior without Apple `container`.

## Acceptance criteria

- [x] Sandbox Spec defaults are tested for default image, 4 CPUs, 8GB RAM, empty Allowed Folders, and no unsupported future fields.
- [x] Sandbox Spec parsing and rendering are tested for generated specs and `create --from` style user-authored specs.
- [x] Unsupported v1 fields such as inbound networking are rejected by spec validation.
- [x] CPU and memory edits after creation are rejected at the domain/spec contract level.
- [x] Sandbox Name validation and global uniqueness behavior are tested.
- [x] Host Metadata Store tests cover create, read, update, delete, schema version handling, and corruption-safe writes.
- [x] Host Metadata Store locking tests prove Lifecycle Mutations are serialized.
- [x] Folder Policy tests cover `rw`/`ro` normalization, canonical `read-write`/`read-only` storage, default Guest Path derivation, `--as` overrides, duplicate host folder updates, duplicate Guest Path rejection, overlapping host folder rejection, symlink realpath handling, and display path preservation.
- [x] Working Directory Mapper tests cover cwd inside an Allowed Folder, nested paths, symlinked cwd paths, and cwd outside all Allowed Folders with warning/default location.
- [x] Lifecycle Coordinator tests cover create, apply, start, stop, delete, auto-start for daily commands, prompt decisions, and fake-backend state transitions.
- [x] Tests prove normal `run` and `shell` requests are not serialized behind Lifecycle Mutation locks.
- [x] CLI parser/dispatch tests cover every v1 command shape from the PRD.
- [x] Tests prove `run` passes Workload Command arguments through unchanged and does not special-case Pi.
- [x] Tests prove `reset`, Pi shortcut commands, inbound networking config, default/project-local implicit sandbox selection, and editor integration are absent from the v1 command surface.
- [x] Fake backends are used only for deterministic tests and cannot satisfy product acceptance criteria.
- [x] `swift test` passes.

## Definition of Done

- [x] Deterministic tests are committed for all domain behavior added in this issue.
- [x] No product CLI flag, environment variable, or hidden fallback selects a fake backend.
- [x] No raw Apple `container` invocation exists outside the Apple backend adapter boundary.
- [x] No display-layer workaround hides missing backend/domain behavior.
- [x] The build remains green with `swift test`.

## Blocked by

- `issues/sand/000-scaffold-architecture-and-test-harness.md`

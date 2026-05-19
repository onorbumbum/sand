---
title: Scaffold sand architecture, module boundaries, and test harness
status: done
type: issue
category: enhancement
labels:
  - needs-triage
  - afk
  - sand
  - sandbox-vm
  - architecture
  - testing
created: 2026-05-19
---

## Parent

- `issues/sand/prd-sand-sandbox-vm.md`

## What to build

Create the Swift package structure and architectural skeleton for `sand` before feature implementation spreads backend details through the CLI. This issue establishes the executable, test target, module seams, and enforcement points for deep modules with shallow interfaces.

This slice should not implement the full product. It should create enough real structure that later vertical slices have a proper place to put domain logic, backend integration, tests, and user-facing CLI routing.

## Acceptance criteria

- [x] A SwiftPM package exists with a `sand` executable target.
- [x] A deterministic test target exists and runs with `swift test` without requiring Apple `container`.
- [x] The CLI command router is separated from domain/lifecycle/backend implementation.
- [x] A `SandboxBackend` protocol exists with domain-shaped operations for readiness, provision/apply, lifecycle, sessions/commands, status, logs, and deletion.
- [x] The Apple `container` integration has a dedicated adapter boundary and is not called directly from CLI command handlers.
- [x] Test-only fake backend support exists only in test code or test-support code and is not selectable by end users as a product backend.
- [x] Initial module boundaries exist for Sandbox Spec Model, Host Metadata Store, Folder Policy, Working Directory Mapper, Lifecycle Coordinator, Doctor Checks, Status Presenter, Prompt/Confirmation, and Backend Error Translation.
- [x] The Sandbox Spec type does not contain Apple `container` command details, backend IDs, or future unsupported fields such as inbound networking.
- [x] A test proves the CLI layer dispatches a representative command through the domain/lifecycle boundary instead of shelling out to Apple `container`.
- [x] `swift test` passes.

## Definition of Done

- [x] Deterministic tests are committed for the scaffolded contracts.
- [x] No product CLI flag, environment variable, or hidden fallback selects a fake backend.
- [x] No raw Apple `container` invocation exists outside the Apple backend adapter boundary.
- [x] No display-layer workaround hides missing backend/domain behavior.
- [x] The build remains green with `swift test`.

## Blocked by

None - can start immediately

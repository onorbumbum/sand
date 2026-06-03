---
title: Run the final full v1 Sandbox VM acceptance pass
status: done
type: issue
category: enhancement
labels:
  - needs-triage
  - hitl
  - sand
  - sandbox-vm
  - acceptance
  - apple-container
created: 2026-05-19
---

## Parent

- `issues/sand/prd-sand-sandbox-vm.md`

## What to build

Run and record one complete v1 daily workflow against the real product and real Apple backend. This is the final acceptance issue that proves the separate slices compose into the intended Sandbox VM experience: a small isolated Linux computer with explicit Host Mac folder access and generic Workload Commands.

## Acceptance criteria

- [x] Run `sand doctor` and record successful prerequisite output.
- [x] Create a Sandbox VM and record create output.
- [x] Inspect `sand list`, `sand <name> status`, and `sand <name> spec`.
- [x] Add a read-write project Allowed Folder.
- [x] Add a read-only reference Allowed Folder.
- [x] Run a Workload Command from a mapped Host Mac cwd.
- [x] Open an interactive Sandbox Session.
- [x] Verify Sandbox User, passwordless sudo, and concurrent session behavior.
- [x] Verify Host-Safe File Ownership from the Host Mac after guest writes.
- [x] Stop and start the Sandbox VM and verify Guest State persists.
- [x] Apply a manual Sandbox Spec edit and verify backend reconciliation.
- [x] View logs for the Sandbox VM.
- [x] Delete the Sandbox VM and verify metadata/backend cleanup.
- [x] Confirm out-of-scope v1 features are absent: reset command, Pi shortcut command, inbound networking config, editor integration, shell completion, default/project-local implicit sandbox selection, host `~/.pi` mount, host credential forwarding, and non-Apple backend fallback.
- [x] Acceptance evidence is recorded in the issue or linked from the issue.
- [x] `swift test` passes before the final manual acceptance pass.
- [x] No fake/in-memory backend is selectable by user-facing CLI flags, environment variables, or hidden fallbacks.
- [x] A code inspection or automated check confirms CLI command handlers do not call Apple `container` directly.

## Evidence

- `issues/sand/013-final-v1-acceptance-evidence.md`

## Definition of Done

- [x] The full v1 workflow is run against the real product and real Apple backend.
- [x] Final evidence includes commands, output summaries, and pass/fail conclusions.
- [x] No final acceptance criterion is satisfied by mocks, fake backends, or display-layer masking.
- [x] `swift test` passes.
- [x] No raw Apple `container` invocation exists outside the Apple backend adapter boundary.

## Blocked by

- `issues/sand/000-scaffold-architecture-and-test-harness.md`
- `issues/sand/001-backend-validation-spike.md`
- `issues/sand/001a-domain-contracts-deterministic-tests.md`
- `issues/sand/002-developer-ready-sandbox-image.md`
- `issues/sand/003-doctor-command.md`
- `issues/sand/004-create-list-status-spec.md`
- `issues/sand/005-start-stop-delete-guest-state.md`
- `issues/sand/006-run-opaque-workload-commands.md`
- `issues/sand/007-shell-sessions-sandbox-user.md`
- `issues/sand/008-allowed-folder-lifecycle-policy.md`
- `issues/sand/009-working-directory-mapping.md`
- `issues/sand/010-declarative-spec-apply.md`
- `issues/sand/011-logs-backend-error-translation.md`
- `issues/sand/012-pi-workload-credential-boundary.md`

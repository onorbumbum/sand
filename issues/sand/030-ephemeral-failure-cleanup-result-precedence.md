---
title: Enforce Ephemeral Sandbox Run cleanup semantics and result precedence
status: needs-triage
type: issue
category: enhancement
labels:
  - needs-triage
  - sand
  - sandbox-vm
  - ephemeral
  - cleanup
  - failure-handling
  - swift
created: 2026-06-03
---

## Parent

- `issues/sand/prd-ephemeral-sandbox-runs.md`

## What to build

Make the EphemeralRunCoordinator own the full create-run-stop-post-work-delete saga for failure cases, including which cleanup actions are attempted, which hooks are skipped, what final status is reported, and which failure controls the final process exit code.

## Acceptance criteria

- [ ] Before Provision Hook failure aborts before provisioning, skips After Stop Hooks, records failure, and returns failure status.
- [ ] Provisioning or start failure before the Foreground Workload starts skips After Stop Hooks but still attempts cleanup of any partially created resources.
- [ ] Foreground Workload nonzero exit still triggers stop, After Stop Hooks, delete, and a final failure report.
- [ ] Stop failure does not prevent After Stop Hooks or delete from being attempted.
- [ ] After Stop Hook failure stops remaining after-stop hooks but still attempts delete.
- [ ] Delete failure records manual cleanup guidance, including the generated Sandbox Name and cleanup command.
- [ ] Final CLI output includes run status, run record path, failed phase, and exit code for failed runs.
- [ ] Final process exit code follows phase priority, with cleanup/delete failures overriding earlier workload failures when they require immediate attention.
- [ ] Deterministic coordinator tests cover before-hook failure, provision failure, start failure, workload nonzero, stop failure, after-stop failure, delete failure, and result precedence.

## Blocked by

- `issues/sand/022-minimal-ephemeral-command-happy-path.md`
- `issues/sand/028-before-provision-hooks.md`
- `issues/sand/029-after-stop-hooks.md`

---
title: Resolve Ephemeral Allowed Folders into a concrete Sandbox Spec
status: needs-triage
type: issue
category: enhancement
labels:
  - needs-triage
  - sand
  - sandbox-vm
  - ephemeral
  - allowed-folders
  - swift
created: 2026-06-03
---

## Parent

- `issues/sand/prd-ephemeral-sandbox-runs.md`

## What to build

Allow Ephemeral Specs to describe temporary Sandbox VM template fields and Allowed Folders, then resolve those folder intents into a concrete Sandbox Spec using existing folder rules after pre-run planning. The generated concrete Sandbox Spec should contain resolved host paths and be suitable for temporary active Host Metadata.

## Acceptance criteria

- [ ] Ephemeral Specs may include image, resources, and Allowed Folders; omitted image/resources use normal Sandbox VM defaults.
- [ ] Ephemeral Allowed Folders support read-write and read-only Access Modes plus optional Guest Paths.
- [ ] Relative `hostPath` values resolve relative to the Ephemeral Spec directory; absolute paths remain absolute; `~/...` expands to the Host Mac home directory.
- [ ] Default Guest Paths use the display host path's last component consistently with normal folder behavior.
- [ ] FolderPolicy is reused so duplicate Guest Paths, overlapping resolved host folders, access modes, and other folder rules stay consistent with durable Sandbox VMs.
- [ ] The generated concrete Sandbox Spec records resolved paths, while the source Ephemeral Spec remains user-authored intent.
- [ ] Deterministic tests cover relative/absolute/home paths, ro/rw modes, guest path defaulting, duplicate Guest Paths, overlap rejection, and generated spec contents.

## Blocked by

- `issues/sand/023-ephemeral-spec-shape-validation.md`
- `issues/sand/024-generated-ephemeral-identity-and-name.md`

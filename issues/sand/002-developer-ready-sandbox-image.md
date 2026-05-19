---
title: Build the Developer-Ready Sandbox Image
status: needs-triage
type: issue
category: enhancement
labels:
  - needs-triage
  - afk
  - sand
  - sandbox-vm
  - sandbox-image
  - apple-container
created: 2026-05-19
---

## Parent

- `issues/sand/prd-sand-sandbox-vm.md`

## What to build

Create the default Developer-Ready Sandbox Image used by `sand create`. The image should be based on Ubuntu LTS and include the full Default Toolset so a newly created Sandbox VM can run developer and Pi workloads without first-run bootstrapping.

## Acceptance criteria

- [ ] The default Sandbox Image builds from an Ubuntu LTS base.
- [ ] The image includes git, curl, ca-certificates, sudo, openssh-client, Python 3 with venv/pip, Node/npm, tmux, ripgrep, build-essential, and the Pi CLI.
- [ ] A real Sandbox Guest launched from the image can run smoke checks for each Default Toolset command.
- [ ] The image config creates or supports the non-root Sandbox User required by daily Sandbox Sessions.
- [ ] The image config supports passwordless sudo for the Sandbox User.
- [ ] Build and smoke-check commands are documented or scripted so the image can be reproduced.

## Definition of Done

- [ ] Relevant deterministic checks or smoke scripts are added or updated and documented.
- [ ] Real image smoke evidence is recorded from a real Sandbox Guest/backend path.
- [ ] Fake/in-memory backends are not used to satisfy product acceptance.
- [ ] No product CLI flag, environment variable, or hidden fallback selects a fake backend.
- [ ] No display-layer workaround hides a failed image, user, sudo, ownership, or tool availability requirement.

## Blocked by

- `issues/sand/001-backend-validation-spike.md`

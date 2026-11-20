---
title: Live View: Fill login from the password manager
status: ready-for-agent
type: issue
category: migration
labels:
  - sand
  - aslan-browser-retirement
  - ops
  - live-view
  - security
created: 2026-11-20
---

## Parent

- `issues/sand/prd-retire-aslan-browser.md`

## What to build

Replace Aslan's Bitwarden-backed sign-in. Decision first (PRD): Bitwarden session on the Mini, or not. If yes: the viewer gets Fill login; Ops lists vault items matching the page's host; Onur picks one; Ops types username and password into the focused fields as key events. The secret never reaches an agent, an `/api/*` response, the activity log or a file.

## Acceptance criteria

- [ ] Onur-initiated only; no agent-callable path.
- [ ] Tests prove the secret is absent from API responses, logs and `sand-browser activity`.
- [ ] Works while Onur has control; refused otherwise.

## Blocked by

- `issues/sand/037-client-browser-sandboxes.md`

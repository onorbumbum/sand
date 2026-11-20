---
title: A Browser Sandbox for every client with web work
status: ready-for-agent
type: issue
category: migration
labels:
  - sand
  - aslan-browser-retirement
  - operations
  - browser-sandbox
created: 2026-11-20
---

## Parent

- `issues/sand/prd-retire-aslan-browser.md`

## What to build

From the 032 log and Ops tasks, list clients whose work touches the web. For each: `sand create <client id lowercased> --browser`, share the client folder read-write at `/workspace`, and have Onur sign in to that client's accounts once in the Live View. Keep `web` as the general sandbox for non-client work. Confirm Worker briefs show the Browser section for each.

## Acceptance criteria

- [ ] Each listed client has a Browser Sandbox named after its Client ID, with its folder shared.
- [ ] Onur has signed in to each client's accounts in its own sandbox; no client's sessions are in another's.
- [ ] Live Browsers lists them; idle stop keeps at most about three running.

## Blocked by

- `issues/sand/032-measure-aslan-browser-use.md`

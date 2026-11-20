---
title: A Browser Sandbox for every client with web work
status: in-progress
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

- [x] Each listed client has a Browser Sandbox named after its Client ID, with its folder shared.
- [ ] Onur has signed in to each client's accounts in its own sandbox; no client's sessions are in another's.
- [x] Live Browsers lists them; idle stop keeps at most about three running.

## Blocked by

- `issues/sand/032-measure-aslan-browser-use.md`

## Progress

### 2026-11-20 — Four client Browser Sandboxes created

Clients chosen with Onur from open Ops web work (DCC 20 tasks, WCM 8, DWCA 5, AGT 3; the 032 log was too new to rank): `sand create <id> --browser` then `sand folders add <id> ~/_SITES/<site> rw --as /workspace` for `dcc` (deepcleancrew.com), `wcm` (wecaremedicareplans.com), `dwca` (dutchwindowcleaningartist.com), `agt` (aguilar-team.com). Each was started once to check: `/workspace` lists the site repo and is writable, `sand-browser status` answers; then stopped. `GET /api/browsers` lists all four with their Client IDs, stopped; `web` stays the general sandbox (recreated on the new image the same day). Worker briefs show the Browser section for any client whose sandbox exists (`runner.clj` `browser-section`); the section now points to the sand-browser skill, `tree`/refs and named tabs.

## Waiting on Onur

- Sign in to each client's accounts once, in its own sandbox only: Ops → Live Browsers → `dcc`, `wcm`, `dwca`, `agt` (Google Business / Google Ads / Meta / LinkedIn as each client uses them). Then tick the second criterion.

